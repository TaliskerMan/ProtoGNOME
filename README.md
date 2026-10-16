# ProtoGNOME

A native GNOME application for managing Proton compatibility tools for Steam on Linux.

ProtoGNOME is a **fork of [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt)** rebuilt with Flutter for a native GNOME experience. It requires no KDE or Qt dependencies.

## Features

- 🚀 **Install/remove** GE-Proton and Luxtorpeda, verified before every install
- 🎮 **Steam (native, Flatpak or Snap) and Heroic**; each tool is offered only for launchers it works with
- ⚡ **Read-only per-game Proton compatibility tool viewer**
- 🗄️ **SQLite backend** for caching release lists and preferences
- 🔍 **Game search** and per-game assigned tool list

## Security

ProtoGNOME downloads and installs executable Proton runtimes, so the download/install pipeline is built defensively:

- **Integrity verification is required.** Before extracting anything, ProtoGNOME checks the download against every check available for it: the publisher's checksum file (`.sha512sum`, `.sha256sum`, `.sha512` or `.sha256`) and GitHub's recorded SHA-256 digest for the file. A mismatch refuses the install, and a release with neither is shown as **"Can't be verified"** and cannot be installed at all.
- **Only verifiable tools are offered.** Boxtron and SteamTinkerLaunch were removed because their releases publish no checksums, and "Proton-GE (tkg)" because wine-tkg-git's releases are Arch Linux Wine packages that Steam can't use. Tools you installed with an earlier version still work; to remove one, delete its folder from your launcher's tools folder (for Steam, `~/.local/share/Steam/compatibilitytools.d/`).
- **Right build for your computer:** where a release offers several CPU builds (GE-Proton ships x86_64 and aarch64), ProtoGNOME picks the x86_64 build and that build's own checksum.
- **Archive extraction safety:** ZIP entries are bounded with `path.isWithin`, and `.tar.gz`/`.tar.xz` archives are listed and validated (absolute paths and `..` members rejected) before extraction, rather than relying solely on the system `tar`.
- **No shell string interpolation:** `tar` is invoked with array-form arguments, never `bash -c` string wrappers.
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
