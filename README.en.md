# Taidi App

*[Suomeksi (README.md)](README.md)*

When a room or an app grid is a mess, you tidy it up. In Finglish: **Taidi App**.

Taidi App makes the Sailfish OS application launcher (Lipstick) compact and easy to organize:
1. **5×7 compact grid** – fits your pinned apps and folders onto a single screen without endless scrolling.
2. **One-tap folder management** – no more fighting with drag-and-drop hover timers.
3. **Clean `.patch` implementation** – ships zero proprietary Jolla code; patches your device's existing QML files in place.
4. **CLI tool (`taidi`)** – reads and atomically updates `~/.config/lipstick/applications.menu` directly.

Tested on Sailfish OS 5.2 (Jolla Phone 2026).

---

## How it works

In stock Lipstick, grouping 60+ apps into folders by dragging icons on top of each other is slow and finicky.

Taidi App applies two small QML patches and installs a lightweight CLI helper:

- **Inside a folder:** Adds a **`+ Apps`** button next to the folder title. Tap it to check/uncheck apps in and out of the folder directly.
- **In the main grid:** Long-pressing an icon (reorder mode) shows a top bar to create a new folder, or lets you tap any app to move it straight into an existing folder.
- **Single-app folders:** Fixes the stock Lipstick behavior where a folder automatically destroys itself if only one app remains inside.
- **Safe patching:** No proprietary QML files are stored in this repository. The installer runs a `--dry-run` verification first, applies unified diffs using a dependency-free Python patcher, and keeps `.taidi_orig` backups. If Lipstick fails to start, the installer automatically rolls back the changes.

---

## Installation

### Directly on the phone (Terminal / SSH):

```bash
git clone https://github.com/tsaknorris/taidi-app.git
cd taidi-app
./scripts/install.sh
```

The script asks for your `devel-su` password to patch the launcher QML files, configures the 5×7 grid via `dconf`, and restarts Lipstick along with the user session boosters.

### From a PC over SSH:

```bash
./scripts/deploy_remote.sh 192.168.2.15
```
*(Replace the IP with your phone's address: `192.168.2.15` for USB developer mode, or your Wi-Fi/Hotspot IP).*

---

## CLI Usage: `taidi`

`taidi` reads and modifies `~/.config/lipstick/applications.menu` directly as the single source of truth and writes changes atomically (`os.replace`), so manual changes made in the UI are never overwritten.

```bash
# Show current root apps and folder contents
taidi status

# Organize installed apps into sensible default folders (8 pinned root apps + 9 folders)
taidi init-default

# Move an app into a folder (matches by app name or .desktop id)
taidi move "WhatsApp" "Social"
taidi move "DOOM" "Games"

# Move an app back to the root grid
taidi move "WhatsApp" root

# Create or rename a folder
taidi create-folder "Games" icon-launcher-folder-11
taidi rename-folder "Games" "Pelit"

# Delete a folder (moves its apps back to the root grid, nothing is lost)
taidi delete-folder "Pelit"
```

---

## Uninstall / Restore

To revert back to stock Sailfish OS launcher files and grid settings:

```bash
./scripts/uninstall.sh
```

This reverses the patches (`patch -R`), restores `.taidi_orig` backups if needed, resets the experimental `dconf` grid keys, and restarts Lipstick.

Emergency manual recovery over SSH if ever needed:
```bash
devel-su cp -f /usr/share/lipstick-jolla-home-qt5/launcher/*.taidi_orig /usr/share/lipstick-jolla-home-qt5/launcher/
systemctl --user restart lipstick && systemctl --user start user-session.target post-user-session.target
```

---

## License

MIT (c) 2026 tsaknorris.
Patches are applied locally to Sailfish OS Lipstick components on the target device.
