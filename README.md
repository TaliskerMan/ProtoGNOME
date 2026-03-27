# ProtoGNOME

A native GNOME application for managing Proton compatibility tools for Steam on Linux.

ProtoGNOME is a **fork of [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt)** rebuilt with Flutter for a native GNOME experience. It requires no KDE or Qt dependencies.

## Features

- 🚀 **Install/remove** GE-Proton, Boxtron, Luxtorpeda, SteamTinkerLaunch, and more
- ⚡ **Read-only per-game Proton compatibility tool viewer**
- 🗄️ **SQLite backend** for caching release lists and preferences
- 🔍 **Game search** and per-game assigned tool list

## Security Hardening (v1.0.7+)

> [!IMPORTANT]
> **Why was this version rebuilt?**
> ProtoGNOME v1.0.7 includes critical security patches to protect users from malicious local exploits and injection attacks.
> - **Command Injection Protection**: The `.tar.zst` extraction mechanism was rewritten to explicitly rely on secure, native Dart subprocess routing instead of unsafe `bash -c` string wrapper logic.
> - **Insecure Space Protection**: Sandbox environments explicitly manage and lock all intermediate `/tmp/` staging files rather than resolving shared directories.
> - **Audit Trails**: ProtoGNOME now ships with a localized system tracer tracking behaviors to `~/.local/state/protognome/app.log`.

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
