# ProtoGNOME Plan

## Release v1.0.13 Plan

- [x] Test new patch in `patch/protognome-parallel-download-fix.patch` against test suite and build pipeline.
- [x] Auto-increment version to `1.0.13+6` across `pubspec.yaml`, `lib/main.dart`, `lib/screens/settings_screen.dart`, `debian/changelog`, `CHANGELOG.md`, and `sonar-project.properties`.
- [x] Add unit tests for 6-stream range chunk partitioning and continuity in `test/github_release_service_test.dart`.
- [x] Run security and quality scans:
  - [x] Semgrep static analysis (`semgrep scan --config auto lib/`)
  - [x] SonarQube analysis via `sonar-scanner` and verify Quality Gate status
  - [x] Snyk security audit & SCA evaluation with SBOM Grype audit
- [x] Build release package via `./build_release.sh` (generates signed 64-bit DEB, SHA256/SHA512 checksums, GPG detached signature, SBOM, source archive).
- [ ] Commit changes, create `v1.0.13` git tag, push to origin.
- [ ] Create GitHub Release `v1.0.13` with release notes and attach all required assets.

