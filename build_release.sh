#!/usr/bin/env bash
# ProtoGNOME Release Builder
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.1"
PKG_NAME="protognome"
FLUTTER="${HOME}/flutter/bin/flutter"
ARTIFACTS="${SCRIPT_DIR}/artifacts"
BUILD_DIR="${SCRIPT_DIR}/build/linux/x64/release/bundle"
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
   "${DEB_ROOT}/usr/share/applications/"

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
Architecture: amd64
Installed-Size: ${INSTALLED_SIZE}
Depends: libgtk-3-0, libblkid1, liblzma5, libsecret-1-0
Recommends: steam
Maintainer: Chuck Talk <chuck@nordheim.online>
Homepage: https://github.com/ProtoGNOME/ProtoGNOME
Description: Native GNOME Proton compatibility tool manager
 ProtoGNOME is a native GNOME application for managing Proton
 compatibility tools for Steam on Linux. Fork of ProtonUp-Qt with
 no KDE/Qt dependencies. Adds batch-apply Proton version to all games.
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
DEB_FILE="${ARTIFACTS}/${PKG_NAME}_${VERSION}-1_amd64.deb"
dpkg-deb --build --root-owner-group "${DEB_ROOT}" "${DEB_FILE}"

echo "==> Generating SHA256 and SHA512 hashes..."
sha256sum "${DEB_FILE}" > "${DEB_FILE}.sha256"
sha512sum "${DEB_FILE}" > "${DEB_FILE}.sha512"

echo "==> Signing .deb with GPG..."
if command -v gpg > /dev/null 2>&1; then
    gpg --local-user 1779CD0F50DBB64C187908264863C73517D810F8 --detach-sign --armor "${DEB_FILE}"
    echo "    Signed: ${DEB_FILE}.asc"
else
    echo "    WARNING: gpg not found - package NOT signed!"
fi

echo ""
echo "==================================="
echo "  Build complete!"
echo "  Package : ${DEB_FILE}"
echo "  SHA256  : ${DEB_FILE}.sha256"
echo "  SHA512  : ${DEB_FILE}.sha512"
echo "  GPG sig : ${DEB_FILE}.asc"
echo "==================================="
