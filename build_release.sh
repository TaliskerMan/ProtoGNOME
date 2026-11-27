#!/usr/bin/env bash
# ProtoGNOME Release Builder
# SPDX-License-Identifier: GPL-3.0-or-later
# CP-ChangeComments (2026-11-27, v1.0.16+10): Added ~/.local/flutter lookup,
# lockfile enforcement, path-sanitized CycloneDX SBOM, binary/hash GPG signatures,
# and sorted basename SHA512SUMS/SHA256SUMS manifests.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(grep '^version:' "${SCRIPT_DIR}/pubspec.yaml" | awk '{print $2}' | cut -d'+' -f1)"
if [[ -z "${VERSION}" ]]; then
    echo "ERROR: could not read version from pubspec.yaml" >&2
    exit 1
fi
readonly PKG_NAME="protognome"
readonly SBOM_JSON="Audit/SBOM-Linux.json"
readonly GPG_KEY="chuck@nordheim.online"

# Resolve Flutter SDK binary across PATH, ~/.local/flutter, and ~/flutter
FLUTTER="flutter"
if ! command -v "${FLUTTER}" >/dev/null 2>&1; then
    if [[ -x "${HOME}/.local/flutter/bin/flutter" ]]; then
        FLUTTER="${HOME}/.local/flutter/bin/flutter"
    elif [[ -x "${HOME}/flutter/bin/flutter" ]]; then
        FLUTTER="${HOME}/flutter/bin/flutter"
    fi
fi

# Fix clang++ linker issue on some arm64/Linux environments
if [[ -d "/usr/lib/gcc/aarch64-linux-gnu/13" ]]; then
    export LIBRARY_PATH="/usr/lib/gcc/aarch64-linux-gnu/13:${LIBRARY_PATH:-}"
fi
if [[ -d "/usr/include/c++/13" ]]; then
    export CPLUS_INCLUDE_PATH="/usr/include/c++/13:/usr/include/aarch64-linux-gnu/c++/13:${CPLUS_INCLUDE_PATH:-}"
fi

ARCH=$(dpkg --print-architecture)
UNAME_M=$(uname -m)
if [[ "$UNAME_M" = "x86_64" ]]; then
    FLUTTER_ARCH="x64"
elif [[ "$UNAME_M" = "aarch64" ]]; then
    FLUTTER_ARCH="arm64"
else
    FLUTTER_ARCH="$UNAME_M"
fi

ARTIFACTS="${SCRIPT_DIR}/artifacts"
BUILD_DIR="${SCRIPT_DIR}/build/linux/${FLUTTER_ARCH}/release/bundle"
DEB_ROOT="${SCRIPT_DIR}/deb_pkg"

echo "==> ProtoGNOME Release Builder v${VERSION}"
rm -rf "${ARTIFACTS}"
mkdir -p "${ARTIFACTS}"

echo "==> Building Flutter Linux release..."
cd "${SCRIPT_DIR}"
"${FLUTTER}" pub get --enforce-lockfile
"${FLUTTER}" build linux --release

echo "==> Generating SBOM via Syft..."
SYFT_BIN="syft"
if ! command -v syft &> /dev/null; then
    if [[ -f "${HOME}/.local/bin/syft" ]]; then
        SYFT_BIN="${HOME}/.local/bin/syft"
    elif [[ -f "./syft" ]]; then
        SYFT_BIN="./syft"
    fi
fi
if command -v "${SYFT_BIN}" &> /dev/null; then
    mkdir -p Audit
    "${SYFT_BIN}" dir:. \
        --source-name "${PKG_NAME}" \
        --source-version "${VERSION}-1" \
        --exclude ./venv \
        --exclude ./android \
        --exclude ./ios \
        --exclude ./macos \
        --exclude ./windows \
        --exclude ./build \
        --exclude ./packaging_output \
        --exclude ./Audit \
        --exclude ./dist \
        --exclude ./plan \
        --exclude ./.dart_tool \
        --exclude ./artifacts \
        --exclude ./deb_pkg \
        --exclude './**/node_modules' \
        -o cyclonedx-json > "${SBOM_JSON}"
    sed -i "s|${SCRIPT_DIR}/\?||g" "${SBOM_JSON}"
    cp "${SBOM_JSON}" Audit/SBOM-Linux
    cp "${SBOM_JSON}" Audit/sbom.json
fi

echo "==> Preparing DEB package structure..."
rm -rf "${DEB_ROOT}"
mkdir -p "${DEB_ROOT}/DEBIAN"
mkdir -p "${DEB_ROOT}/usr/bin"
mkdir -p "${DEB_ROOT}/usr/lib/protognome"
mkdir -p "${DEB_ROOT}/usr/share/applications"
mkdir -p "${DEB_ROOT}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${DEB_ROOT}/usr/share/doc/protognome"

echo "==> Copying build artifacts..."
cp "${BUILD_DIR}/protognome" "${DEB_ROOT}/usr/lib/protognome/"
cp -r "${BUILD_DIR}/lib/." "${DEB_ROOT}/usr/lib/protognome/lib/"
cp -r "${BUILD_DIR}/data/." "${DEB_ROOT}/usr/lib/protognome/data/"

cat > "${DEB_ROOT}/usr/bin/protognome" << 'WRAPPER'
#!/bin/bash
exec /usr/lib/protognome/protognome "$@"
WRAPPER
chmod +x "${DEB_ROOT}/usr/bin/protognome"

cp "${SCRIPT_DIR}/share/applications/protognome.desktop" \
   "${DEB_ROOT}/usr/share/applications/io.protognome.protognome.desktop"
sed -i 's/^StartupWMClass=.*/StartupWMClass=io.protognome.protognome/' \
   "${DEB_ROOT}/usr/share/applications/io.protognome.protognome.desktop"

readonly -a ICON_SIZES=(512x512 256x256 128x128 64x64 48x48 32x32)
for size in "${ICON_SIZES[@]}"; do
    src="${SCRIPT_DIR}/share/icons/hicolor/${size}/apps/protognome.png"
    if [[ ! -f "${src}" ]]; then
        echo "ERROR: missing icon ${src}" >&2
        exit 1
    fi
    mkdir -p "${DEB_ROOT}/usr/share/icons/hicolor/${size}/apps"
    cp "${src}" "${DEB_ROOT}/usr/share/icons/hicolor/${size}/apps/protognome.png"
done

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
Depends: libgtk-3-0, libblkid1, liblzma5, libsecret-1-0, libsqlite3-0
Recommends: steam
Maintainer: Chuck Talk <chuck@nordheim.online>
Homepage: https://github.com/TaliskerMan/ProtoGNOME
Description: Native GNOME Proton compatibility tool manager
 ProtoGNOME is a native GNOME application for managing Proton
 compatibility tools for Steam and Heroic on Linux. Fork of
 ProtonUp-Qt with no KDE/Qt dependencies and mandatory checksum
 and GitHub digest verification.
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
(
    cd "${ARTIFACTS}"
    sha256sum "$(basename "${DEB_FILE}")" > "$(basename "${DEB_FILE}").sha256"
    sha512sum "$(basename "${DEB_FILE}")" > "$(basename "${DEB_FILE}").sha512"
)

echo "==> Signing .deb with GPG..."
if command -v gpg > /dev/null 2>&1; then
    gpg --batch --no-tty --yes --pinentry-mode loopback --local-user "${GPG_KEY}" --detach-sign --armor --output "${DEB_FILE}.asc" "${DEB_FILE}"
    gpg --batch --no-tty --yes --pinentry-mode loopback --local-user "${GPG_KEY}" --detach-sign --output "${DEB_FILE}.sig" "${DEB_FILE}"
    gpg --batch --no-tty --yes --pinentry-mode loopback --local-user "${GPG_KEY}" --detach-sign --armor --output "${DEB_FILE}.sha512.asc" "${DEB_FILE}.sha512"
    gpg --batch --no-tty --export -a "${GPG_KEY}" > "${ARTIFACTS}/pubkey.asc"
    cp "${ARTIFACTS}/pubkey.asc" "${ARTIFACTS}/chuck_pubkey.asc"
    echo "    Signed: ${DEB_FILE}.asc / .sig / .sha512.asc"
else
    echo "    WARNING: gpg not found - package NOT signed!" >&2
fi

# write_directory_checksums computes sorted basename SHA512SUMS and SHA256SUMS manifests inside target_dir.
write_directory_checksums() {
    local target_dir="$1"
    (
        cd "${target_dir}"
        rm -f -- SHA512SUMS SHA256SUMS
        find . -maxdepth 1 -type f ! -name 'SHA512SUMS' ! -name 'SHA256SUMS' -printf '%P\n' | LC_ALL=C sort | xargs sha512sum > SHA512SUMS
        find . -maxdepth 1 -type f ! -name 'SHA512SUMS' ! -name 'SHA256SUMS' -printf '%P\n' | LC_ALL=C sort | xargs sha256sum > SHA256SUMS
    )
}

echo "==> Copying to NOBuilds directory..."
DATE_STR="$(date +%m-%d-%Y)"
NOBUILDS_DIR="${HOME}/NOBuilds/ProtoGNOME/v${VERSION}"
NOBUILDS_PATTERN_DIR="${HOME}/NOBuilds/ProtoGNOME-${DATE_STR}-${VERSION}"
mkdir -p "${NOBUILDS_DIR}" "${NOBUILDS_PATTERN_DIR}"

echo "Generating source tarball..."
tar --exclude=build --exclude=.dart_tool --exclude=.git --exclude=artifacts --exclude=deb_pkg --exclude=Audit --exclude=.scannerwork --exclude=.sonarlint --exclude='**/node_modules' -czf "${ARTIFACTS}/protognome_source.tar.gz" .

if [[ -f docs/ProtoGNOME_User_Guide.pdf ]]; then
    cp docs/ProtoGNOME_User_Guide.pdf "${ARTIFACTS}/"
fi
if [[ -f Audit/security_report.md ]]; then
    cp Audit/security_report.md "${ARTIFACTS}/"
fi
cp "${SBOM_JSON}" "${ARTIFACTS}/SBOM-Linux.json" || true
cp Audit/sbom.json "${ARTIFACTS}/sbom.json" || true

write_directory_checksums "${ARTIFACTS}"

for target_dir in "${NOBUILDS_DIR}" "${NOBUILDS_PATTERN_DIR}"; do
    cp -- "${ARTIFACTS}/"* "${target_dir}/"
    cp LICENSE "${target_dir}/"
    cp README.md "${target_dir}/"
    cp Audit/SBOM-Linux "${target_dir}/" || true
    write_directory_checksums "${target_dir}"
done

echo ""
echo "==================================="
echo "  Build complete!"
echo "  Package : ${DEB_FILE}"
echo "  SHA256  : ${DEB_FILE}.sha256"
echo "  SHA512  : ${DEB_FILE}.sha512"
echo "  GPG sig : ${DEB_FILE}.asc / .sig"
echo "  Local   : ${NOBUILDS_PATTERN_DIR}"
echo "==================================="
