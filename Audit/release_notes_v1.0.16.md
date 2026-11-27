# ProtoGNOME v1.0.16 Official Linux Release

**ProtoGNOME** is a native GTK 3 / Flutter GNOME application for managing **GE-Proton** and **Luxtorpeda** compatibility tools across **Steam** (native, Flatpak, and Snap) and **Heroic Games Launcher** on Linux — forked from [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt) with zero KDE/Qt dependencies and mandatory cryptographic verification of every downloaded runtime.

## What's Changed Since v1.0.15 (`v1.0.15+9` – `v1.0.16+10`)
- **SonarQube Cloud & Snyk Full Remediation (`TaliskerMan_ProtoGNOME`):** Resolved all 24 SonarQube Cloud findings (including 2 security vulnerabilities and 22 code smells) across the C++17 GTK runner (`linux/my_application.cc`), ES module user-guide builder (`docs/guide/build_guide.js`), and release build script (`build_release.sh`) — achieving **Quality Gate `OK` (`0` Bugs, `0` Vulnerabilities, `0` Code Smells)** and **`0` Snyk Code & Open Source issues**.
- **Owner-Only Rotated Diagnostic Logging (`CP-Logging`):** Hardened `~/.local/state/protognome/app.log` in `LoggerService` with CR/LF log-injection sanitization (`LoggerService.sanitize`), `0600` owner-only permissions, and 5 MiB automatic rotation.
- **About & Settings Attribution (`CP-AboutPage`, `CP-NordheimLogo`, `CP-AutoIncrement`):** Added full semantic + build-number version display (`1.0.16+10`), hyperlinked Nordheim Online badge (`https://nordheim.online`), and complete GPL-3.0 upstream (`DavidoTek / ProtonUp-Qt`) + fork (`Chuck Talk <chuck@nordheim.online>, Nordheim Online, LLC`) attribution.
- **Refreshed Documentation & CycloneDX SBOM (`v1.0.16`):** Updated `README.md`, `ProtoGNOME_User_Guide.md`, and the branded `ProtoGNOME_User_Guide.pdf` (`v1.0.16+10`), and generated path-sanitized CycloneDX SBOMs (`0` Grype/OSV/Trivy findings).

## Package Integrity & Verification

| Asset | Description |
|---|---|
| `protognome_1.0.16-1_amd64.deb` | Debian/Ubuntu 64-bit (`amd64`) desktop package |
| `protognome_1.0.16-1_amd64.deb.asc` | GPG ASCII-armored detached signature |
| `protognome_1.0.16-1_amd64.deb.sig` | GPG binary detached signature |
| `protognome_1.0.16-1_amd64.deb.sha512` | SHA-512 package checksum |
| `protognome_1.0.16-1_amd64.deb.sha512.asc` | GPG detached signature on SHA-512 checksum |
| `protognome_1.0.16-1_amd64.deb.sha256` | SHA-256 package checksum |
| `pubkey.asc` / `chuck_pubkey.asc` | Maintainer GPG public key (`Chuck Talk <chuck@nordheim.online>`) |
| `protognome_source.tar.gz` | Corresponding GPL-3.0 source archive |
| `SBOM-Linux.json` / `sbom.json` | CycloneDX Software Bill of Materials (SBOM) |
| `security_report.md` | Multi-scanner security and quality audit report |
| `ProtoGNOME_User_Guide.pdf` | Official User Guide & manual (`v1.0.16+10`) |
| `SHA512SUMS` / `SHA256SUMS` | Combined release asset checksum manifests |

### Verification & Installation

```bash
# Verify SHA-512 checksum
sha512sum -c protognome_1.0.16-1_amd64.deb.sha512

# Import Chuck Talk's release signing key and verify GPG detached signature
gpg --import chuck_pubkey.asc
gpg --verify protognome_1.0.16-1_amd64.deb.asc protognome_1.0.16-1_amd64.deb

# Install
sudo apt install ./protognome_1.0.16-1_amd64.deb
```
