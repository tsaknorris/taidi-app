#!/bin/sh
# TAIDI APP - Uninstaller / Restore Script
# Restores original stock Lipstick QML components, dconf settings, and launcher menu.
set -e

BACKUP_DIR="$HOME/lipstick_backup"
LAUNCHER_DIR="/usr/share/lipstick-jolla-home-qt5/launcher"
CONFIG_DIR="$HOME/.config/lipstick"

echo "=== TAIDI APP Uninstaller ==="

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory $BACKUP_DIR not found!"
    exit 1
fi

# 1. Restore applications.menu if backup exists
if [ -f "$BACKUP_DIR/config_lipstick/applications.menu" ]; then
    echo "[1/4] Restoring original applications.menu..."
    cp -f "$BACKUP_DIR/config_lipstick/applications.menu" "$CONFIG_DIR/applications.menu"
fi

# 2. Restore stock QML files
echo "[2/4] Restoring original QML launcher components..."
TMP_DIR="/tmp/taidi_uninstall_$$"
mkdir -p "$TMP_DIR"

cat << 'EOF' > "$TMP_DIR/restore_root.sh"
#!/bin/sh
set -e
BACKUP_DIR="$HOME/lipstick_backup"
LAUNCHER_DIR="/usr/share/lipstick-jolla-home-qt5/launcher"
if [ -d "$BACKUP_DIR/usr_launcher" ]; then
    cp -f "$BACKUP_DIR/usr_launcher/"*.qml "$LAUNCHER_DIR/"
    chown root:root "$LAUNCHER_DIR/"*.qml
    chmod 644 "$LAUNCHER_DIR/"*.qml
fi
EOF
chmod +x "$TMP_DIR/restore_root.sh"

if [ "$(id -u)" = "0" ]; then
    "$TMP_DIR/restore_root.sh"
else
    devel-su -c /bin/sh "$TMP_DIR/restore_root.sh"
fi
rm -rf "$TMP_DIR"

# 3. Reset dconf experimental settings
echo "[3/4] Resetting dconf grid settings..."
dconf reset -f /desktop/sailfish/experimental/
if [ -s "$BACKUP_DIR/dconf_experimental.dump" ]; then
    dconf load /desktop/sailfish/experimental/ < "$BACKUP_DIR/dconf_experimental.dump"
fi

# 4. Restart Lipstick
echo "[4/4] Restarting Lipstick..."
(sleep 1 && mcetool --set-display-state=on 2>/dev/null || true) &
systemctl --user restart lipstick

echo ""
echo "=== Restoration complete! ==="
echo "Stock Sailfish OS launcher restored."
