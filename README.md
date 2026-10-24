# 🧹 TAIDI APP (Taidi)

> **"Kun työpöytä on sekaisin, se siivotaan – ei 'tidy up', vaan TAIDI APP!"** 🇫🇮

**Taidi App** is a fast, touch-friendly application folder and grid organizer for **Sailfish OS** (tested on Jolla Phone 2026, Sailfish OS 5.2+).

Instead of endlessly scrolling through pages of unorganized application icons, **Taidi App** compacts your home launcher grid and provides zero-drag, one-tap folder management directly on your screen and via CLI.

---

## ✨ Features

- **📱 5×7 Compact Launcher Grid:**
  - Displays up to 35 icons per screen in portrait mode (7×4 in landscape).
  - Fits all your core apps and folders onto **a single screen**.
  - Optimized launcher icon scale and label metrics for clean readability.

- **📂 One-Tap Folder Management (No Frustrating Drag-and-Drop):**
  - **Inside Folders:** Tap **`+ Apps`** in the folder header to open the App Manager. Tap any app to immediately add it to or remove it from the folder.
  - **On Main Grid:** Long-press any icon to enter Edit Mode:
    - Tap **`+ New Folder`** in the top action bar to create a folder instantly.
    - Tap any app to open **`Move "<App>" to...`**, letting you send it to any folder or create a new folder with one tap.
  - **Folder Customization:** Tap the folder title to rename it, or tap the folder shape icon to choose from 16 Jolla icons.
  - **No Accidental Folder Destruction:** Fixes the stock Sailfish behavior where 1-item folders auto-destructed.

- **🛠️ Powerful CLI Tool (`taidi`):**
  - Standalone Python 3 manager stored in user space (`~/.config/lipstick/applications.menu` and `~/.local/share/taidi/folders.json`).
  - Automatic categorization, JSON backup, and strict XML integrity validation (guarantees zero apps are ever lost or duplicated).

- **🛡️ 100% Reversible (Zero Risk):**
  - Includes a one-command restore script (`uninstall.sh` / `revert.sh`) that returns your phone to the exact stock launcher state at any time.

---

## 🚀 Installation

### Option A: Local Installation (On the Jolla Phone)

1. Copy or clone this repository to your device:
   ```bash
   git clone https://github.com/tsaknorris/taidi-app.git
   cd taidi-app
   ```
2. Run the installer:
   ```bash
   chmod +x scripts/install.sh
   ./scripts/install.sh
   ```
   *(Prompts for `devel-su` root privileges to install the QML launcher patch to `/usr/share/lipstick-jolla-home-qt5/launcher/` and restarts Lipstick.)*

3. Apply default categorization (optional):
   ```bash
   taidi init-default
   ```

---

### Option B: Remote Installation from PC over SSH

1. Connect your PC to your Jolla (USB networking `192.168.2.15` or WLAN/Hotspot).
2. Run from your computer:
   ```bash
   ./scripts/deploy_remote.sh <JOLLA_IP>
   ```
   *(e.g., `./scripts/deploy_remote.sh 192.168.2.15`)*

---

## 📖 CLI Usage (`taidi`)

Once installed, the `taidi` command is available in your shell:

```bash
# Check status and verify XML/app integrity
taidi status

# Apply default smart grouping (8 root pinned apps + 9 logical folders)
taidi init-default

# Create a new folder
taidi create-folder "Work" icon-launcher-folder-05

# Move an app to a folder (supports search by name or desktop filename)
taidi move "Slack" "Work"
taidi move "DOOM" "Games"

# Move an app back to the main grid
taidi move "Slack" root

# Rename or delete a folder
taidi rename-folder "Work" "Office"
taidi delete-folder "Office"  # Safely returns all contained apps to the root grid

# Synchronize lipstick's XML changes back into folders.json
taidi sync-from-menu
```

---

## 🔄 Uninstallation / Restore Stock State

To revert your phone back to the stock Sailfish OS launcher, run:

```bash
./scripts/uninstall.sh
```
or run the device backup script:
```bash
~/lipstick_backup/revert.sh
```

This restores the original `applications.menu`, stock QML files, and resets `dconf` launcher grid settings.

---

## 🏗️ Architecture

```
taidi-app/
├── bin/
│   └── taidi               # Python 3 CLI & folder structure generator
├── qml/
│   ├── LauncherGrid.qml    # 5x7 grid, quick-move sheet, edit mode toolbar
│   └── LauncherFolder.qml  # Folder view with '+ Apps' manager overlay
├── scripts/
│   ├── install.sh          # On-device installer
│   ├── uninstall.sh        # On-device uninstaller & stock restore
│   └── deploy_remote.sh    # Host-to-device SSH deployer
├── LICENSE                 # MIT License
└── README.md
```

---

## 📜 License

MIT License. Copyright (c) 2026 tsaknorris.
All Sailfish OS / Lipstick original components copyright (c) Jolla Ltd & Open Mobile Platform LLC.
