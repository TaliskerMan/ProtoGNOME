# Changelog — ProtoGNOME

All notable changes to the ProtoGNOME project are documented in this file. This project adheres to Semantic Versioning.

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
