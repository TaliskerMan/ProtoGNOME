title: ProtoGNOME
subtitle: Installation and User Guide
version: 1.0.14
platforms: Linux (GNOME)
## About ProtoGNOME

ProtoGNOME installs and removes compatibility tools for Linux gaming, such as **GE-Proton**, for Steam and the Heroic Games Launcher. It also shows which compatibility tool each of your Steam games uses. It's a GNOME-friendly app with no KDE or Qt dependencies.

ProtoGNOME is a community fork of **ProtonUp-Qt** by DavidoTek, rebuilt with Flutter. It is not affiliated with Valve, Steam, ProtonUp-Qt or the authors of the tools it installs.

**What ProtoGNOME does**

- Lists recent releases of two compatibility tools, GE-Proton and Luxtorpeda, straight from their GitHub projects.
- Downloads and installs a release into Steam or Heroic with one click, and removes it again.
- Verifies every download before installing it, and refuses anything it can't verify.
- Shows your Steam games and the compatibility tool assigned to each (read-only).

ProtoGNOME is free, open-source software under the GNU General Public License v3. Source: github.com/TaliskerMan/ProtoGNOME.

## Supported tools and launchers

| Tool | Source project | What it's for |
|---|---|---|
| GE-Proton | GloriousEggroll/proton-ge-custom | Proton with extra fixes and codecs |
| Luxtorpeda | luxtorpeda-dev/luxtorpeda | Runs some games on native Linux engines |

ProtoGNOME offers only tools whose releases it can verify. Earlier versions also listed Boxtron and SteamTinkerLaunch, whose releases publish no checksums, and "Proton-GE (tkg)", whose releases are Arch Linux Wine packages that Steam can't use. Copies you installed earlier keep working; to remove one, delete its folder from your launcher's tools folder (listed below).

| Launcher | Where tools are installed |
|---|---|
| Steam | Steam's `compatibilitytools.d` folder, for example `~/.local/share/Steam/compatibilitytools.d` (created on the first install) |
| Heroic Games Launcher | `~/.config/heroic/tools/proton` |

ProtoGNOME finds Steam in `~/.local/share/Steam`, `~/.steam/root`, `~/.steam/steam` and `~/.steam/debian-installation`, and also the **Flatpak** (`~/.var/app/com.valvesoftware.Steam/data/Steam`) and **Snap** (`~/snap/steam/common/.local/share/Steam`) versions. It uses the first one it finds, in that order.

GE-Proton works with Steam and Heroic; **Luxtorpeda works only with Steam**, so it can't be installed into Heroic. Lutris isn't offered: it runs Wine builds, and neither tool is one.

## System requirements

| | |
|---|---|
| Operating system | 64-bit (amd64) Debian, Ubuntu, Pop!_OS or a derivative |
| Libraries | GTK 3, libsecret and SQLite (`libsqlite3-0`), installed with the package |
| Also needed | `tar` and `xz-utils` (normally already installed) |
| Network | Internet connection to reach GitHub |
| Disk space | Several hundred MB per Proton version |

## Installing ProtoGNOME

Each release includes `protognome_<version>_amd64.deb`, SHA-256 and SHA-512 checksums, a detached GPG signature and the Nordheim Online public key (`pubkey.asc`).

```
sha256sum -c protognome_<version>_amd64.deb.sha256
gpg --import pubkey.asc
gpg --verify protognome_<version>_amd64.deb.asc protognome_<version>_amd64.deb
sudo apt install ./protognome_<version>_amd64.deb
```

Open **ProtoGNOME** from your applications menu.

### Building from source

```
# Requires Flutter 3.24+, cmake, ninja-build, libgtk-3-dev and g++
git clone https://github.com/TaliskerMan/ProtoGNOME.git
cd ProtoGNOME
flutter pub get
bash build_release.sh
```

### Uninstalling

`sudo apt remove protognome`. Tools you installed stay in your launchers' folders; remove them in ProtoGNOME first if you don't want them.

## Quick start

1. Open ProtoGNOME and choose **Tools** in the side rail.
2. Choose where to install (**Steam** or **Heroic**) from the launcher list.
3. Pick a tool, for example **GE-Proton**. ProtoGNOME lists its recent releases.
4. Click **Install** next to the release you want. When it finishes, it's marked **Installed**.
5. Restart Steam. In a game's **Properties → Compatibility**, choose the new tool.

## Using ProtoGNOME

The side rail has four sections: **Tools**, **Games**, **Settings** and **About**. Banners at the top warn you if Steam wasn't found, or if Steam is running: Steam only reads its tool list at start-up, so restart it after installing or removing tools.

### Tools

| Control | What it does |
|---|---|
| Launcher list | Where to install: Steam or Heroic. A launcher that isn't installed is marked "(Not Installed)". |
| Tool chips | Switch between GE-Proton and Luxtorpeda |
| Release list | Recent releases, with date and download size |
| Install | Downloads, verifies and installs that release. Downloads over 10 MB use several parallel connections; the finished file is verified the same way. A release that can't be verified shows **Can't be verified** instead. |
| Remove | Deletes an installed release after you confirm |
| Refresh release list | Fetches the latest releases from GitHub |

### Games

Lists the games in your Steam libraries, with the compatibility tool each one uses. Type in **Search games…** to filter, or click **Refresh game list**. This view is read-only: change a game's tool in Steam itself.

### Settings

| Section | What it shows or does |
|---|---|
| Steam Installation | The detected Steam folder, compatibility-tools folder and config folder, and whether the installation looks valid |
| GitHub API Token | Optional personal access token to raise GitHub's rate limit (see below) |
| About ProtoGNOME | The installed version, license and author |

### About

Version, license, and credits to ProtonUp-Qt.

## How installs are protected

Compatibility tools are programs that run your games, so ProtoGNOME is careful about what it installs:

- **Verification is required.** Before installing, ProtoGNOME checks the download against everything available for it: the checksum file its authors publish (`.sha512sum`, `.sha256sum`, `.sha512` or `.sha256`; GE-Proton and Luxtorpeda both publish one) and the SHA-256 digest GitHub records for every uploaded file. Every check must pass.
- **No checksum, no install.** A release with neither a checksum file nor a GitHub digest is marked **Can't be verified** and has no Install button.
- **The right build.** GE-Proton publishes x86_64 and aarch64 builds; ProtoGNOME picks the x86_64 build and checks it against that build's own checksum.
- **Safe extraction.** Archive contents are checked before extraction; any file that would land outside the install folder is refused.
- **No shell commands.** `tar` is run directly, with fixed arguments.
- **Private staging.** Downloads are unpacked in a private temporary folder, then cleaned up.
- **Size limit.** Downloads over 4 GB are refused.
- **Steam's files are read, never written.** ProtoGNOME reads Steam's `config.vdf` and `libraryfolders.vdf` to list games but doesn't change them.

## GitHub token (optional)

GitHub limits how often an app can check releases without signing in (about 60 requests an hour). If you see a rate-limit message:

1. On GitHub, create a **personal access token** with no extra scopes (public read access is enough).
2. In ProtoGNOME, open **Settings → GitHub API Token**, paste it, and click **Save token**.

The token is stored in your desktop's keyring (libsecret), not in a plain file.

## Privacy and files

ProtoGNOME contacts only GitHub (to list and download releases). It has no telemetry, and it uses your desktop's own font rather than downloading one.

| Item | Location |
|---|---|
| Release cache and preferences | `~/.local/share/io.protognome.protognome/protognome.db` |
| Activity log | `~/.local/state/protognome/app.log` |
| GitHub token | Your desktop keyring |

## Troubleshooting

**"GitHub API rate limit exceeded".** Wait an hour, or add a GitHub token in Settings.

**Steam isn't detected.** ProtoGNOME looks in the native, Flatpak and Snap Steam folders listed above; the path can't be set by hand. Install Steam and run it once, then restart ProtoGNOME.

**Install is missing for Luxtorpeda in Heroic.** Luxtorpeda works only with Steam; choose Steam in the launcher list.

**A new tool doesn't appear in Steam.** Restart Steam completely (Steam → Exit, then reopen).

**"could not be verified against its published checksum".** The download was corrupted or altered, or the checksum couldn't be fetched. Try again later; don't install it another way.

**A release shows "Can't be verified".** Its authors published no checksum and GitHub has no digest for it, so ProtoGNOME won't install it.

**"Failed to load dynamic library 'libsqlite3.so'" (versions up to 1.0.13).** Fixed in 1.0.14: ProtoGNOME now loads the system SQLite library (`libsqlite3-0`). Update ProtoGNOME.

**Something else went wrong.** Check `~/.local/state/protognome/app.log`.

## Support and license

Report problems on GitHub (github.com/TaliskerMan/ProtoGNOME) or email **chuck@nordheim.online**.

ProtoGNOME is a fork of ProtonUp-Qt, © 2021–2024 DavidoTek, licensed under the GNU GPL v3. The compatibility tools it installs are separate projects under their own licenses.

| | |
|---|---|
| Website | nordheim.online |
| Source code | github.com/TaliskerMan/ProtoGNOME |
| License | GNU GPL v3 (no warranty) |
| Copyright | © 2026 Chuck Talk, Nordheim Online, LLC (ProtoGNOME changes) |
