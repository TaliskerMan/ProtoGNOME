#!/usr/bin/env bash
# ProtoGNOME Release Builder
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Version is single-sourced from pubspec.yaml (no auto-increment) to avoid the
# drift between pubspec, debian/changelog, the git tag, and the built .deb.
VERSION="$(grep '^version:' "${SCRIPT_DIR}/pubspec.yaml" | awk '{print $2}' | cut -d'+' -f1)"
if [ -z "${VERSION}" ]; then
  echo "ERROR: could not read version from pubspec.yaml" >&2
  exit 1
fi
PKG_NAME="protognome"

# Check for flutter bin
FLUTTER="flutter"
if [ ! -x "$(which flutter 2>/dev/null)" ]; then
    if [ -f "${HOME}/flutter/bin/flutter" ]; then
        FLUTTER="${HOME}/flutter/bin/flutter"
    fi
fi

# Fix clang++ linker issue on some arm64/Linux environments
if [ -d "/usr/lib/gcc/aarch64-linux-gnu/13" ]; then
    export LIBRARY_PATH="/usr/lib/gcc/aarch64-linux-gnu/13:${LIBRARY_PATH:-}"
fi
if [ -d "/usr/include/c++/13" ]; then
    export CPLUS_INCLUDE_PATH="/usr/include/c++/13:/usr/include/aarch64-linux-gnu/c++/13:${CPLUS_INCLUDE_PATH:-}"
fi

ARCH=$(dpkg --print-architecture)
UNAME_M=$(uname -m)
if [ "$UNAME_M" = "x86_64" ]; then
    FLUTTER_ARCH="x64"
elif [ "$UNAME_M" = "aarch64" ]; then
    FLUTTER_ARCH="arm64"
else
    FLUTTER_ARCH="$UNAME_M"
fi

ARTIFACTS="${SCRIPT_DIR}/artifacts"
BUILD_DIR="${SCRIPT_DIR}/build/linux/${FLUTTER_ARCH}/release/bundle"
DEB_ROOT="${SCRIPT_DIR}/deb_pkg"

echo "==> ProtoGNOME Release Builder v${VERSION}"
mkdir -p "${ARTIFACTS}"

echo "==> Building Flutter Linux release..."
cd "${SCRIPT_DIR}"
"${FLUTTER}" build linux --release

echo "==> Preparing DEB package structure..."
rm -rf "${DEB_ROOT}"
mkdir -p "${DEB_ROOT}/DEBIAN"
mkdir -p "${DEB_ROOT}/usr/bin"
mkdir -p "${DEB_ROOT}/usr/lib/protognome"
mkdir -p "${DEB_ROOT}/usr/share/applications"
mkdir -p "${DEB_ROOT}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${DEB_ROOT}/usr/share/doc/protognome"

echo "==> Copying build artifacts..."
# Copy the main binary
cp "${BUILD_DIR}/protognome" "${DEB_ROOT}/usr/lib/protognome/"
# Copy shared data (Flutter libs and data dir)
cp -r "${BUILD_DIR}/lib/." "${DEB_ROOT}/usr/lib/protognome/lib/"
cp -r "${BUILD_DIR}/data/." "${DEB_ROOT}/usr/lib/protognome/data/"

# Wrapper script (so /usr/bin/protognome works)
cat > "${DEB_ROOT}/usr/bin/protognome" << 'WRAPPER'
#!/bin/bash
exec /usr/lib/protognome/protognome "$@"
WRAPPER
chmod +x "${DEB_ROOT}/usr/bin/protognome"

# Desktop file
cp "${SCRIPT_DIR}/share/applications/protognome.desktop" \
   "${DEB_ROOT}/usr/share/applications/io.protognome.protognome.desktop"
sed -i 's/^StartupWMClass=.*/StartupWMClass=io.protognome.protognome/' \
   "${DEB_ROOT}/usr/share/applications/io.protognome.protognome.desktop"

# Icon
cp "${SCRIPT_DIR}/assets/icons/proto.png" \
   "${DEB_ROOT}/usr/share/icons/hicolor/256x256/apps/protognome.png"

# Copyright
cp "${SCRIPT_DIR}/LICENSE" \
   "${DEB_ROOT}/usr/share/doc/protognome/copyright"

echo "==> Writing DEBIAN/control..."
INSTALLED_SIZE=$(du -sk "${DEB_ROOT}" | awk '{print $1}')
cat > "${DEB_ROOT}/DEBIAN/control" << CONTROL
Package: protognome
Version: ${VERSION}-1
Section: games
Priority: optional
Architecture: ${ARCH}
Installed-Size: ${INSTALLED_SIZE}
Depends: libgtk-3-0, libblkid1, liblzma5, libsecret-1-0
Recommends: steam
Maintainer: Chuck Talk <chuck@nordheim.online>
Homepage: https://github.com/ProtoGNOME/ProtoGNOME
Description: Native GNOME Proton compatibility tool manager
 ProtoGNOME is a native GNOME application for managing Proton
 compatibility tools for Steam on Linux. Fork of ProtonUp-Qt with
 no KDE/Qt dependencies. Safe read-only viewer for game settings.
CONTROL

echo "==> Writing DEBIAN/postinst..."
cat > "${DEB_ROOT}/DEBIAN/postinst" << 'POSTINST'
#!/bin/bash
set -e
if command -v gtk-update-icon-cache > /dev/null 2>&1; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor
fi
if command -v update-desktop-database > /dev/null 2>&1; then
    update-desktop-database /usr/share/applications
fi
POSTINST
chmod 755 "${DEB_ROOT}/DEBIAN/postinst"

echo "==> Building .deb package..."
DEB_FILE="${ARTIFACTS}/${PKG_NAME}_${VERSION}-1_${ARCH}.deb"
dpkg-deb --build --root-owner-group "${DEB_ROOT}" "${DEB_FILE}"

echo "==> Generating SHA256 and SHA512 hashes..."
sha256sum "${DEB_FILE}" > "${DEB_FILE}.sha256"
sha512sum "${DEB_FILE}" > "${DEB_FILE}.sha512"

echo "==> Signing .deb with GPG..."
if command -v gpg > /dev/null 2>&1; then
    gpg --local-user chuck@nordheim.online --detach-sign --armor "${DEB_FILE}"
    gpg --export -a chuck@nordheim.online > "${ARTIFACTS}/pubkey.asc"
    echo "    Signed: ${DEB_FILE}.asc"
else
    echo "    WARNING: gpg not found - package NOT signed!"
fi

# Copy to NOBuilds directory
echo "==> Copying to NOBuilds directory..."
NOBUILDS_DIR="${HOME}/NOBuilds/ProtoGNOME/v${VERSION}"
mkdir -p "${NOBUILDS_DIR}"

cp "${DEB_FILE}" "${NOBUILDS_DIR}/"
cp "${DEB_FILE}.asc" "${NOBUILDS_DIR}/" || true
cp "${DEB_FILE}.sha256" "${NOBUILDS_DIR}/" || true
cp "${DEB_FILE}.sha512" "${NOBUILDS_DIR}/" || true
cp "${ARTIFACTS}/pubkey.asc" "${NOBUILDS_DIR}/" || true
cp LICENSE "${NOBUILDS_DIR}/"
cp README.md "${NOBUILDS_DIR}/"
cp Audit/sbom.json "${NOBUILDS_DIR}/" || true

# Generate source code archive
echo "Generating source tarball..."
tar --exclude=build --exclude=.dart_tool --exclude=.git -czf "${NOBUILDS_DIR}/protognome_source.tar.gz" .

echo ""
echo "==================================="
echo "  Build complete!"
echo "  Package : ${DEB_FILE}"
echo "  SHA256  : ${DEB_FILE}.sha256"
echo "  SHA512  : ${DEB_FILE}.sha512"
echo "  GPG sig : ${DEB_FILE}.asc"
echo "  Local   : ${NOBUILDS_DIR}"
echo "==================================="
