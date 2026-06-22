# ProtoGNOME

A native GNOME application for managing Proton compatibility tools for Steam on Linux.

ProtoGNOME is a **fork of [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt)** rebuilt with Flutter for a native GNOME experience. It requires no KDE or Qt dependencies.

## Features

- 🚀 **Install/remove** GE-Proton, Boxtron, Luxtorpeda, SteamTinkerLaunch, and more
- ⚡ **Read-only per-game Proton compatibility tool viewer**
- 🗄️ **SQLite backend** for caching release lists and preferences
- 🔍 **Game search** and per-game assigned tool list

## Security

ProtoGNOME downloads and installs executable Proton runtimes, so the download/install pipeline is built defensively:

- **Integrity verification (v1.0.8+):** downloaded archives are checked against the release's published `.sha512sum`/`.sha256sum` before extraction; a mismatch — or a download that can't be verified — refuses to install.
- **Archive extraction safety:** ZIP entries are bounded with `path.isWithin`, and `.tar.gz`/`.tar.xz`/`.tar.zst` archives are listed and validated (absolute paths and `..` members rejected) before extraction, rather than relying solely on the system `tar`.
- **No shell string interpolation:** subprocesses (`tar`, `zstd`) are invoked with array-form arguments, never `bash -c` string wrappers.
- **Isolated staging:** downloads and intermediate extraction use private `Directory.systemTemp` directories, cleaned up afterwards.
- **Download size cap:** oversized responses are rejected to avoid disk exhaustion.
- **Read-only Steam integration:** ProtoGNOME parses `config.vdf`/`libraryfolders.vdf` but never writes them.
- **Token storage:** the optional GitHub PAT is stored in the system keyring (libsecret), not in plaintext.
- **Audit log:** activity is traced to `~/.local/state/protognome/app.log`.

## Installation

Download the latest `.deb` from [Releases](https://github.com/TaliskerMan/ProtoGNOME/releases):

```bash
# Verify the package
sha256sum -c protognome_*.deb.sha256
gpg --verify protognome_*.deb.asc

# Install
sudo dpkg -i protognome_*.deb
sudo apt-get install -f  # fix dependencies if needed
```

## Building from Source

```bash
# Requirements: Flutter 3.24+, cmake, ninja-build, libgtk-3-dev, g++
git clone https://github.com/TaliskerMan/ProtoGNOME.git
cd ProtoGNOME
flutter pub get
bash build_release.sh
```

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).

ProtoGNOME is a fork of ProtonUp-Qt © 2021-2024 DavidoTek, licensed under GPL v3.

## Acknowledgements

- [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt) by DavidoTek — the original Qt-based tool this is forked from
- [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom) by GloriousEggroll
