# Changelog — ProtoGNOME

All notable changes to the ProtoGNOME project are documented in this file. This project adheres to Semantic Versioning.

---

## [1.0.8] - 2026-06-22

### Added
- **Download integrity verification:** Before extracting a downloaded runtime,
  ProtoGNOME now fetches the published `.sha512sum`/`.sha256sum` asset, computes
  the hash over the downloaded file, and refuses to install on mismatch (or when
  verification cannot be performed). This completes the integrity feature the
  data model already carried.
- **Download size cap:** Reject oversized `Content-Length` and abort mid-stream
  if a download exceeds a 4 GiB sanity bound, preventing disk exhaustion.
- **Tests:** Unit tests for the VDF parser, GitHub asset selection, checksum
  parsing, and archive-member validation.

### Changed
- **Tar extraction hardened:** `.tar.gz`/`.tar.xz`/`.tar.zst` archives are now
  listed and validated (rejecting absolute paths and `..` members) before
  extraction, matching the ZIP branch's zip-slip protection instead of trusting
  the system `tar`.
- **GitHub token moved to the system keyring:** The optional PAT is now stored
  via the platform secret store (libsecret) instead of plaintext in SQLite; any
  existing token is migrated and the plaintext copy scrubbed. A rate-limited
  state is now surfaced.
- **Single-sourced version (1.0.8):** `build_release.sh` reads the version from
  `pubspec.yaml` and no longer auto-increments, ending the pubspec/changelog/tag
  drift.

### Repo
- Untracked the generated `artifacts/` package tree (now `.gitignore`d); releases
  belong in GitHub Releases. `debian/` remains the single packaging source.

---

## [1.0.7] - 2026-06-10

### Added
- **System Tracer Logging:** Added native `LoggerService` writing execution tracks to `$XDG_STATE_HOME/protognome/app.log` (defaulting to `~/.local/state/protognome/app.log`).
- **Post-Install Triggers:** Updated packaging pipeline to run `gtk-update-icon-cache` and `update-desktop-database` automatically on package install.
- **SQLite Database Cache:** SQLite backend caching integration via `sqflite_common_ffi` and `sqlite3_flutter_libs` to accelerate application launch and local settings query lookup.

### Changed
- **Secure Process Execution:** Replaced shell wrappers (`bash -c`) for `.tar.gz`, `.tar.xz`, and `.tar.zst` extraction with native Dart `Process.run` subprocess routing to prevent command injection hazards.
- **Isolated Staging Area:** Restricted archive extraction temp targets to isolated folders under `Directory.systemTemp` instead of shared `/tmp/`.
- **Packaging Pipeline:** Updated `build_release.sh` to include automatic size calculation, GPG detached signatures with Chuck's key (`chuck@nordheim.online`), and SHA256/SHA512 checksum file generation.

### Fixed
- **Zip Path Traversal Vulnerability:** Enforced strict boundaries validating zip entries using `path.isWithin` checking against the target directory bounds.
