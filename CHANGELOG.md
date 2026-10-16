# Changelog — ProtoGNOME

All notable changes to the ProtoGNOME project are documented in this file. This project adheres to Semantic Versioning.

---

## [Unreleased]

### Security — verification is now required (2026-10-16 review)
- **Unverifiable downloads are refused.** Previously a release without a
  `.sha512sum`/`.sha256sum` file was installed anyway with only a log line,
  although the README said it would be refused. Now every install must pass
  every available check — the publisher's checksum file and GitHub's recorded
  SHA-256 digest for the asset — and a release with neither is shown as
  "Can't be verified" with no Install button.
- **GitHub asset digests are checked** in addition to publisher checksum files.
- **Luxtorpeda's checksums are used.** It publishes bare `.sha512` files, which
  were not recognised.
- **Right build, right checksum.** GE-Proton now ships `-aarch64` and `-x86_64`
  archives; ProtoGNOME took whichever was listed last and any checksum file in
  the release. It now picks the x86_64 build and that file's own checksum.
- **Clear failure messages.** A failed install said "Check your internet
  connection" even when verification failed; it now gives the real reason.

### Removed
- **Boxtron** and **SteamTinkerLaunch**: their releases publish no checksums
  (SteamTinkerLaunch has no release files at all), so they can never be
  verified.
- **Proton-GE (tkg)**: wine-tkg-git's releases are 2021–22 Arch Linux Wine
  packages (`.pkg.tar.zst`), not a Proton build Steam can use. `.tar.zst`
  extraction (and the undeclared `zstd` dependency) went with it.
- Previously installed copies keep working; remove them by deleting their
  folder from the launcher's tools folder.

### Fixed
- **Steam on a fresh install is offered.** Steam was only listed as a target
  once its `compatibilitytools.d` folder existed, which Steam doesn't create
  until a tool is installed. It is now offered whenever Steam is found.
- **Flatpak and Snap Steam are detected** (the same folders ProtonUp-Qt checks).
- **"Steam not found" banner** no longer tells users to set a path in Settings,
  which has no such option.
- **Tools are only offered for launchers they work with:** GE-Proton for Steam
  and Heroic, Luxtorpeda for Steam only. Lutris is no longer a target (it runs
  Wine builds, which neither tool is), and ProtoGNOME no longer creates
  `~/.local/share/lutris/runners/wine`.

### Changed
- **New application icon**: a square 512×512 icon replaces the 687×689 one
  (which was installed as if it were 256×256). The package now installs it at
  512, 256, 128, 64, 48 and 32 px, and the app's Home and About screens use it.
- The package Homepage now points to github.com/TaliskerMan/ProtoGNOME.
- Database schema v2 (adds `asset_digest`); the release cache is refreshed
  once on upgrade.

---

## [1.0.13] - 2026-09-26

### Fixed
- **Parallel multi-stream range download corruption:** Isolated concurrent chunk downloads to individual `.partN` temporary files assembled in order upon completion, preventing mutual file handle truncation.
- **HTTP status verification:** Enforced strict HTTP 206 Partial Content validation, rejecting non-range 200 OK responses.
- **CDN redirect resolution:** Disabled automatic redirect following on initial HEAD probe to properly capture 302 `location` headers from edge CDNs.
- **Temporary part cleanup:** Guaranteed part file deletion in `finally` blocks upon completion or failure.
- **Archive extraction error logging:** Added `_tarOk` helper logging `stderr` output to `LoggerService` when tar extraction fails.

### Added
- **Unit tests:** Added unit tests verifying 6-chunk splitting and continuity for downloads > 100 MB.

---

## [1.0.12] - 2026-08-14

### Added
- **Parallel multi-connection downloader:** Implemented multi-stream HTTP range downloader in `GitHubReleaseService` splitting large downloads (>10 MB) into 4 to 8 parallel range streams for 3x to 6x faster download speeds.

---

## [1.0.11] - 2026-08-14

### Fixed
- **SQLite3 FFI resolution:** Overrode Linux sqlite3 FFI dynamic library resolution via `open.overrideFor` to load `libsqlite3.so.0`, resolving `SqfliteFfiException` on systems missing development symlinks.

---

## [1.0.10] - 2026-08-14

### Fixed
- **Tool detection with arch suffix:** Added support for matching tools with architecture suffixes (e.g. `GE-Proton11-5-x86_64`) and internal `version` files.

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
