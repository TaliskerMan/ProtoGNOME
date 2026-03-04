# ProtoGNOME

A native GNOME application for managing Proton compatibility tools for Steam on Linux.

ProtoGNOME is a **fork of [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt)** rebuilt with Flutter for a native GNOME experience. It requires no KDE or Qt dependencies.

## Features

- 🚀 **Install/remove** GE-Proton, Boxtron, Luxtorpeda, SteamTinkerLaunch, and more
- ⚡ **Apply a single Proton version to ALL games at once** *(ProtoGNOME exclusive!)*
- 🗄️ **SQLite backend** for caching release lists and preferences
- 🎨 **Native GNOME UI** built with Flutter (no KDE/Qt/Flatpak required)
- 🔍 **Game search** and per-game Proton override management

## Installation

Download the latest `.deb` from [Releases](https://github.com/ProtoGNOME/ProtoGNOME/releases):

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
git clone https://github.com/ProtoGNOME/ProtoGNOME.git
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
