# Plan for ProtoGNOME

## Release v1.0.16: Official Linux Release, Quality Gates & Website Sync (2026-11-27)
- [x] Audit `TaliskerMan/ProtoGNOME` repository, `~/sarules`, GitHub docs (`README.md`, `ProtoGNOME_User_Guide.md`), and live `https://nordheim.online/protognome/` (`Page 546`).
- [x] Bump version to `1.0.16+10` (`protognome_1.0.16-1_amd64.deb`), align `AboutScreen` & `SettingsScreen` (`CP-AboutPage`, `CP-NordheimLogo`, `CP-AutoIncrement`), harden `docs/guide/build_guide.js` + `build_release.sh`, and regenerate `docs/ProtoGNOME_User_Guide.pdf`.
- [x] Run `flutter analyze`, `flutter test`, `shellcheck`, Snyk Code (`snyk code test`), OSV-Scanner, Grype/Trivy, and verify SonarQube Cloud (`TaliskerMan_ProtoGNOME`) Quality Gate `OK`.
- [x] Execute `build_release.sh` to compile 64-bit Flutter Linux release, build GPG-signed `protognome_1.0.16-1_amd64.deb`, generate CycloneDX SBOM & SHA-512/SHA-256 manifests, stage in `~/NOBuilds/ProtoGNOME-11-27-2026-1.0.16/`, and publish GitHub Release `v1.0.16`.
- [x] Update `https://nordheim.online/protognome/` (`Page 546`) to remove the YouTube placeholder mockup & shop link and resolve all documentation discrepancies.

## Release v1.0.14: Security Hardening & Strict Verification
- [x] Download Verification:
  - [x] Enforce mandatory download verification: publisher checksum and GitHub SHA-256 asset digest.
  - [x] Refuse unverifiable downloads with clear actionable error messages.
  - [x] Support Luxtorpeda's `.sha512` files and x86_64 architecture-specific matching for GE-Proton.
- [x] Cleanup & Compatibility:
  - [x] Remove unverifiable tools (Boxtron, SteamTinkerLaunch, Proton-GE tkg).
  - [x] Fix crash in launcher dropdown after installing/removing tools.
  - [x] Dynamically display installed package version in Settings.
  - [x] Remove external web font download at startup in favor of native desktop font.
  - [x] Support Flatpak, Snap, and native Steam directories.
- [x] Quality Gates & Packaging:
  - [x] SonarQube & Flutter analysis passing clean.
  - [x] Syft CycloneDX SBOM and Grype CVE scan passing clean.
  - [x] Compile 64-bit Debian package (`protognome_1.0.14-1_amd64.deb`).
  - [x] Cryptographically sign with GPG key (`chuck@nordheim.online`).
  - [x] Stage in `~/NOBuilds/` and publish to GitHub Releases.

## Release v1.0.15: Official Linux Commercial Release Build (2026-10-23)
- [x] Phase 1: Environment & Quality Gates
  - [x] Auto-increment version in `pubspec.yaml` to `1.0.15+8` per `CP-AutoIncrement`
  - [x] Update `debian/changelog` with release `1.0.15+8` entry
  - [x] Static analysis: `flutter analyze` passing with 0 issues
  - [x] Full unit test suites: 31/31 unit tests passing (100% pass rate)
- [x] Phase 2: Packaging & Cryptographic Signing
  - [x] Build 64-bit Debian package: `protognome_1.0.15-1_amd64.deb` without elevated privileges
  - [x] Generate SHA-256 and SHA-512 cryptographic checksums
  - [x] Sign package with detached GPG ASCII armor signature (`protognome_1.0.15-1_amd64.deb.asc`) using maintainer key `Chuck Talk <chuck@nordheim.online>` (`D60BA098CDA22A20BD8BB6834E99214B22CFEE40`)
  - [x] Export public GPG key (`chuck_pubkey.asc`, `pubkey.asc`)
- [x] Phase 3: Supply Chain & Security Audits
  - [x] Generate CycloneDX Linux SBOM via Syft (`Audit/SBOM-Linux.json`, `Audit/sbom.json`) per `CP-SBOM`
  - [x] Scan dependencies with OSV-Scanner (72 packages, 0 vulnerabilities)
  - [x] Scan SBOM with Grype (0 CVEs)
  - [x] Author comprehensive security report (`Audit/security_report.md`) per `CP-SecurityAudit`
- [x] Phase 4: Distribution & Release
  - [x] Stage complete release archives in `/home/freecode/NOBuilds/ProtoGNOME-10-23-2026-1.0.15/` and `/home/freecode/NOBuilds/ProtoGNOME/v1.0.15/`
  - [x] Publish official release `v1.0.15` on `https://github.com/TaliskerMan/ProtoGNOME` with all signed packages, checksums, and SBOM manifests
  - [x] Commit and push changes to GitHub repository
