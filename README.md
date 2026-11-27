# ProtoGNOME

A native GNOME application for managing Proton compatibility tools for Steam on Linux.

ProtoGNOME is a **fork of [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt)** rebuilt with Flutter for a native GNOME experience. It requires no KDE or Qt dependencies.

## Features

- 🚀 **Install/remove** GE-Proton and Luxtorpeda, verified before every install (with parallel multi-stream downloads for archives > 10 MB)
- 🎮 **Steam (native, Flatpak or Snap) and Heroic**; each tool is offered only for launchers it works with
- ⚡ **Read-only per-game Proton compatibility tool viewer**
- 🗄️ **SQLite backend** (`libsqlite3-0`) for caching release lists and preferences
- 🔍 **Game search** and per-game assigned tool list
- 🧭 **4-section side navigation rail**: **Tools**, **Games**, **Settings** (including optional keyring-stored GitHub API Token), and **About**

## Security

ProtoGNOME downloads and installs executable Proton runtimes, so the download/install pipeline is built defensively:

- **Integrity verification is required.** Before extracting anything, ProtoGNOME checks the download against every check available for it: the publisher's checksum file (`.sha512sum`, `.sha256sum`, `.sha512` or `.sha256`) and GitHub's recorded SHA-256 digest for the file. A mismatch refuses the install, and a release with neither is shown as **"Can't be verified"** and cannot be installed at all.
- **Only verifiable tools are offered.** Boxtron and SteamTinkerLaunch were removed because their releases publish no checksums, and "Proton-GE (tkg)" because wine-tkg-git's releases are Arch Linux Wine packages that Steam can't use. Tools you installed with an earlier version still work; to remove one, delete its folder from your launcher's tools folder (for Steam, `~/.local/share/Steam/compatibilitytools.d/`).
- **Right build for your computer:** where a release offers several CPU builds (GE-Proton ships x86_64 and aarch64), ProtoGNOME picks the x86_64 build and that build's own checksum.
- **Archive extraction safety:** ZIP entries are bounded with `path.isWithin`, and `.tar.gz`/`.tar.xz` archives are listed and validated (absolute paths and `..` members rejected) before extraction, rather than relying solely on the system `tar`.
- **No shell string interpolation:** `tar` is invoked with array-form arguments, never `bash -c` string wrappers.
- **Isolated staging:** downloads and intermediate extraction use private `Directory.systemTemp` directories, cleaned up afterwards.
- **Download size cap:** oversized responses (> 4 GiB) are rejected to avoid disk exhaustion.
- **Read-only Steam integration:** ProtoGNOME parses `config.vdf`/`libraryfolders.vdf` but never writes them.
- **Token storage:** the optional GitHub PAT is stored in the system keyring (libsecret), not in plaintext.
- **Audit log:** activity is traced to `~/.local/state/protognome/app.log` with CR/LF log-injection sanitization, `0600` owner-only permissions, and 5 MiB log rotation.
- **Network:** ProtoGNOME contacts only GitHub. It has no telemetry and uses the desktop's own font (nothing is downloaded at start-up).

## Installation

Download `protognome_1.0.16-1_amd64.deb`, its SHA-512/SHA-256 checksums, detached GPG signature, and `chuck_pubkey.asc` from [Releases](https://github.com/TaliskerMan/ProtoGNOME/releases/latest):

```bash
# Verify SHA-512 checksum and GPG detached signature
sha512sum -c protognome_1.0.16-1_amd64.deb.sha512
gpg --import chuck_pubkey.asc
gpg --verify protognome_1.0.16-1_amd64.deb.asc protognome_1.0.16-1_amd64.deb

# Install with automatic dependency resolution
sudo apt install ./protognome_1.0.16-1_amd64.deb
```

## Building from Source

```bash
# Requirements: Flutter 3.41+, cmake, ninja-build, libgtk-3-dev, libsecret-1-dev, g++
git clone https://github.com/TaliskerMan/ProtoGNOME.git
cd ProtoGNOME
flutter pub get --enforce-lockfile
bash build_release.sh
```

## License & Attribution

GNU General Public License v3.0 — see [LICENSE](LICENSE).

- **Original work:** [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt) © 2021–2024 DavidoTek and contributors, licensed under the GNU GPL v3.0.
- **ProtoGNOME fork:** © 2026 Chuck Talk (`chuck@nordheim.online`), [Nordheim Online, LLC](https://nordheim.online), licensed under the GNU GPL v3.0.

## Acknowledgements

- [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt) by DavidoTek and contributors — the original Qt-based tool this project is forked from
- [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom) by GloriousEggroll
- [Luxtorpeda](https://github.com/luxtorpeda-dev/luxtorpeda) by luxtorpeda-dev
