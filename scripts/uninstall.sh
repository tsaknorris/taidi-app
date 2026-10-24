#!/bin/sh
# TAIDI APP - Uninstaller / Restore Script
# Reverts QML patches, resets dconf settings, and leaves system in stock state.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHER_DIR="/usr/share/lipstick-jolla-home-qt5/launcher"
PATCHER="python3 $SCRIPT_DIR/scripts/patcher.py"

# Resolve target non-root user
if [ "$(id -u)" = "0" ]; then
    TARGET_USER="${SUDO_USER:-defaultuser}"
else
    TARGET_USER="$USER"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
BACKUP_DIR="$TARGET_HOME/lipstick_backup"

echo "=== TAIDI APP Uninstaller ==="
echo "Target user: $TARGET_USER ($TARGET_HOME)"

if [ "$(id -u)" != "0" ]; then
    echo "Root privileges required to revert launcher components."
    echo "Re-running with devel-su..."
    exec devel-su /bin/sh "$0" "$@"
fi

# 1. Revert QML patches or restore .taidi_orig
echo "[1/4] Reverting QML patches..."
if [ -f "$SCRIPT_DIR/patches/LauncherGrid.patch" ]; then
    if ! $PATCHER -R "$LAUNCHER_DIR/LauncherGrid.qml" "$SCRIPT_DIR/patches/LauncherGrid.patch" 2>/dev/null; then
        if [ -f "$LAUNCHER_DIR/LauncherGrid.qml.taidi_orig" ]; then
            echo "Patch revert failed or already clean, restoring .taidi_orig backup..."
            cp -f "$LAUNCHER_DIR/LauncherGrid.qml.taidi_orig" "$LAUNCHER_DIR/LauncherGrid.qml"
        fi
    fi
fi

if [ -f "$SCRIPT_DIR/patches/LauncherFolder.patch" ]; then
    if ! $PATCHER -R "$LAUNCHER_DIR/LauncherFolder.qml" "$SCRIPT_DIR/patches/LauncherFolder.patch" 2>/dev/null; then
        if [ -f "$LAUNCHER_DIR/LauncherFolder.qml.taidi_orig" ]; then
            echo "Patch revert failed or already clean, restoring .taidi_orig backup..."
            cp -f "$LAUNCHER_DIR/LauncherFolder.qml.taidi_orig" "$LAUNCHER_DIR/LauncherFolder.qml"
        fi
    fi
fi

# Clean up temporary backup copies in launcher dir
rm -f "$LAUNCHER_DIR/LauncherGrid.qml.taidi_orig" "$LAUNCHER_DIR/LauncherFolder.qml.taidi_orig"

# 2. Reset experimental dconf grid settings
echo "[2/4] Resetting dconf grid settings..."
su - "$TARGET_USER" -c "dconf reset -f /desktop/sailfish/experimental/"

# 3. Optionally restore applications.menu if backup exists
if [ -f "$BACKUP_DIR/config_lipstick/applications.menu" ]; then
    echo "[3/4] Restoring original applications.menu from backup..."
    cp -f "$BACKUP_DIR/config_lipstick/applications.menu" "$TARGET_HOME/.config/lipstick/applications.menu"
    chown "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config/lipstick/applications.menu"
else
    echo "[3/4] Keeping current menu structure (no stock backup found)."
fi

# 4. Remove global CLI
rm -f /usr/local/bin/taidi

# 5. Restart Lipstick and dependent session boosters (Camera, Browser, Email)
echo "[4/4] Restarting Lipstick..."
su - "$TARGET_USER" -c "(sleep 1 && mcetool --set-display-state=on 2>/dev/null || true) & systemctl --user restart lipstick && systemctl --user start user-session.target post-user-session.target"

echo ""
echo "=== Taidi App uninstalled successfully! ==="
echo "Stock Sailfish OS launcher restored."
