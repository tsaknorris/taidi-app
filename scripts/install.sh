#!/bin/sh
# TAIDI APP - Installer for Sailfish OS
# Uses unified diff patches to avoid overwriting or distributing proprietary system files.
# Features automatic dry-run preflight check and auto-rollback on failure.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHER_DIR="/usr/share/lipstick-jolla-home-qt5/launcher"
PATCHER="python3 $SCRIPT_DIR/scripts/patcher.py"

# Resolve non-root target user and their home directory
if [ "$(id -u)" = "0" ]; then
    TARGET_USER="${SUDO_USER:-defaultuser}"
else
    TARGET_USER="$USER"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
BACKUP_DIR="$TARGET_HOME/lipstick_backup"

echo "=== TAIDI APP Installer ==="
echo "Target user: $TARGET_USER ($TARGET_HOME)"

# Require root for modifying /usr/share system files
if [ "$(id -u)" != "0" ]; then
    echo "Root privileges required to patch launcher components."
    echo "Re-running with devel-su..."
    exec devel-su /bin/sh "$0" "$@"
fi

# 1. Verify required files exist
if [ ! -f "$LAUNCHER_DIR/LauncherGrid.qml" ] || [ ! -f "$LAUNCHER_DIR/LauncherFolder.qml" ]; then
    echo "Error: Sailfish OS lipstick launcher files not found in $LAUNCHER_DIR!"
    exit 1
fi

# 2. Safety backups (.taidi_orig and ~/lipstick_backup)
echo "[1/5] Checking safety backups..."
mkdir -p "$BACKUP_DIR/usr_launcher" "$BACKUP_DIR/config_lipstick"
if [ ! -f "$LAUNCHER_DIR/LauncherGrid.qml.taidi_orig" ]; then
    cp -p "$LAUNCHER_DIR/LauncherGrid.qml" "$LAUNCHER_DIR/LauncherGrid.qml.taidi_orig"
    cp -p "$LAUNCHER_DIR/LauncherFolder.qml" "$LAUNCHER_DIR/LauncherFolder.qml.taidi_orig"
fi
if [ ! -f "$BACKUP_DIR/usr_launcher/LauncherGrid.qml" ]; then
    cp -p "$LAUNCHER_DIR/LauncherGrid.qml.taidi_orig" "$BACKUP_DIR/usr_launcher/LauncherGrid.qml"
    cp -p "$LAUNCHER_DIR/LauncherFolder.qml.taidi_orig" "$BACKUP_DIR/usr_launcher/LauncherFolder.qml"
fi
if [ -f "$TARGET_HOME/.config/lipstick/applications.menu" ] && [ ! -f "$BACKUP_DIR/config_lipstick/applications.menu" ]; then
    cp -p "$TARGET_HOME/.config/lipstick/applications.menu" "$BACKUP_DIR/config_lipstick/applications.menu"
fi

# 3. Dry-run preflight checks
echo "[2/5] Testing patches against your device's system files..."
if ! $PATCHER --dry-run "$LAUNCHER_DIR/LauncherGrid.qml" "$SCRIPT_DIR/patches/LauncherGrid.patch"; then
    echo "Error: LauncherGrid.patch does not match your system file! Aborting to prevent breakage."
    exit 1
fi
if ! $PATCHER --dry-run "$LAUNCHER_DIR/LauncherFolder.qml" "$SCRIPT_DIR/patches/LauncherFolder.patch"; then
    echo "Error: LauncherFolder.patch does not match your system file! Aborting to prevent breakage."
    exit 1
fi

# 4. Apply patches
echo "[3/5] Applying patches..."
$PATCHER "$LAUNCHER_DIR/LauncherGrid.qml" "$SCRIPT_DIR/patches/LauncherGrid.patch"
$PATCHER "$LAUNCHER_DIR/LauncherFolder.qml" "$SCRIPT_DIR/patches/LauncherFolder.patch"

# 5. Install CLI tool
echo "[4/5] Installing CLI tool 'taidi'..."
mkdir -p "$TARGET_HOME/.local/bin"
cp -f "$SCRIPT_DIR/bin/taidi" "$TARGET_HOME/.local/bin/taidi"
chmod +x "$TARGET_HOME/.local/bin/taidi"
chown "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.local/bin/taidi"
# Also install to /usr/local/bin for global terminal access
mkdir -p /usr/local/bin
cp -f "$SCRIPT_DIR/bin/taidi" /usr/local/bin/taidi
chmod +x /usr/local/bin/taidi

# 6. Configure compact 5x7 grid in user's dconf
su - "$TARGET_USER" -c "
dconf write /desktop/sailfish/experimental/launcher_columns_portrait 5
dconf write /desktop/sailfish/experimental/launcher_rows_portrait 7
dconf write /desktop/sailfish/experimental/launcher_columns_landscape 7
dconf write /desktop/sailfish/experimental/launcher_rows_landscape 4
"

# 7. Restart Lipstick with auto-rollback guard
echo "[5/5] Restarting Lipstick and validating runtime..."
su - "$TARGET_USER" -c "(sleep 1 && mcetool --set-display-state=on 2>/dev/null || true) & systemctl --user restart lipstick"

# Healthcheck loop (up to 8 seconds)
LIPSTICK_HEALTHY=0
for i in 1 2 3 4 5 6 7 8; do
    sleep 1
    if su - "$TARGET_USER" -c "systemctl --user is-active lipstick" 2>/dev/null | grep -q "^active"; then
        LIPSTICK_HEALTHY=1
        break
    fi
done

if [ "$LIPSTICK_HEALTHY" != "1" ]; then
    echo "WARNING: Lipstick failed to start cleanly! Rolling back patches..."
    $PATCHER -R "$LAUNCHER_DIR/LauncherGrid.qml" "$SCRIPT_DIR/patches/LauncherGrid.patch" 2>/dev/null || cp -f "$LAUNCHER_DIR/LauncherGrid.qml.taidi_orig" "$LAUNCHER_DIR/LauncherGrid.qml"
    $PATCHER -R "$LAUNCHER_DIR/LauncherFolder.qml" "$SCRIPT_DIR/patches/LauncherFolder.patch" 2>/dev/null || cp -f "$LAUNCHER_DIR/LauncherFolder.qml.taidi_orig" "$LAUNCHER_DIR/LauncherFolder.qml"
    su - "$TARGET_USER" -c "systemctl --user restart lipstick"
    echo "Rollback completed. System restored safely."
    exit 1
fi

echo ""
echo "=== Taidi App installed successfully! ==="
echo "Launcher grid is now 5x7 and folder tools are active."
