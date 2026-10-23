# ProtoGNOME v1.0.15 Official Release

Official Linux release of **ProtoGNOME** (Native GNOME Proton Compatibility Tool Manager).

This release has undergone rigorous quality-gate validation and multi-scanner security auditing prior to production release, achieving full pass status across test suites, Grype vulnerability scans, and Syft CycloneDX SBOM analysis.

## Highlights & Enhancements
- **Official Linux Release Pipeline**: Clean 64-bit Debian package (`protognome_1.0.15-1_amd64.deb`), GPG detached ASCII-armored signing (`protognome_1.0.15-1_amd64.deb.asc`) with maintainer key `Chuck Talk <chuck@nordheim.online>`, SHA-256 and SHA-512 checksum verification, and NOBuilds distribution archive.
- **Strict Download Verification**: Unverifiable downloads are refused. Every tool installation must pass publisher checksums and GitHub recorded SHA-256 asset digests.
- **Architecture-Specific Precision**: Automatically selects the correct `x86_64` GE-Proton build and its matching checksum file, rejecting incompatible `aarch64` releases.
- **Extended Checksum Support**: Full support for Luxtorpeda's bare `.sha512` files.
- **Dynamic Build Tracking**: Dynamically displays version `v1.0.15` in Settings and About screens via `PackageInfo`.
- **Parallel Multi-Stream Chunk Downloader**: High-performance multi-chunk downloads with automatic checksum validation and temporary file cleanup.

## Security & Supply Chain Verification
- **Flutter Analyze**: 0 issues found across all Dart source files
- **Unit & Security Tests**: 31/31 unit tests passed cleanly (100% success rate)
- **OSV-Scanner**: 0 vulnerabilities found across 72 packages
- **Grype**: 0 vulnerabilities detected in CycloneDX SBOM
- **Permissions**: Safe user-level execution, zero elevated privileges required

## Artifacts & Checksums
- `protognome_1.0.15-1_amd64.deb` (Official Debian release package)
- `protognome_1.0.15-1_amd64.deb.asc` (Detached GPG signature by Chuck Talk `chuck@nordheim.online`)
- `protognome_1.0.15-1_amd64.deb.sha512` (SHA-512 checksum)
- `protognome_1.0.15-1_amd64.deb.sha256` (SHA-256 checksum)
- `SHA512SUMS` (Multi-file checksum manifest)
- `chuck_pubkey.asc` / `pubkey.asc` (Public GPG key for detached signature verification)
- `SBOM-Linux.json` (CycloneDX Software Bill of Materials for Linux)
- `ProtoGNOME_User_Guide.pdf` (User documentation)
- `protognome_source.tar.gz` (Source code archive)
- `security_report.md` (Full security and vulnerability audit report)
