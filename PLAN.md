# Plan for ProtoGNOME

## Release v1.0.14: Security Hardening & Strict Verification
- Download Verification:
  - Enforce mandatory download verification: publisher checksum and GitHub SHA-256 asset digest.
  - Refuse unverifiable downloads with clear actionable error messages.
  - Support Luxtorpeda's `.sha512` files and x86_64 architecture-specific matching for GE-Proton.
- Cleanup & Compatibility:
  - Remove unverifiable tools (Boxtron, SteamTinkerLaunch, Proton-GE tkg).
  - Fix crash in launcher dropdown after installing/removing tools.
  - Dynamically display installed package version in Settings.
  - Remove external web font download at startup in favor of native desktop font.
  - Support Flatpak, Snap, and native Steam directories.
- Quality Gates & Packaging:
  - SonarQube & Flutter analysis passing clean.
  - Syft CycloneDX SBOM and Grype CVE scan passing clean.
  - Compile 64-bit Debian package (`protognome_1.0.14-1_amd64.deb`).
  - Cryptographically sign with GPG key (`chuck@nordheim.online`).
  - Stage in `~/NOBuilds/ProtoGNOME-10-16-2026-1.0.14/` and publish to GitHub Releases.
