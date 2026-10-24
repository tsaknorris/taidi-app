#!/bin/sh
# TAIDI APP - Local Installer for Sailfish OS
# Installs Taidi QML launcher modifications and the CLI management tool.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="$HOME/lipstick_backup"
LAUNCHER_DIR="/usr/share/lipstick-jolla-home-qt5/launcher"
BIN_DIR="$HOME/.local/bin"

echo "=== TAIDI APP Installer ==="

# 1. Ensure backup directory exists and backup original files if not yet done
mkdir -p "$BACKUP_DIR/config_lipstick" "$BACKUP_DIR/usr_launcher"
if [ ! -f "$BACKUP_DIR/usr_launcher/LauncherGrid.qml" ]; then
    echo "[1/5] Creating safety backup in $BACKUP_DIR..."
    cp -a "$LAUNCHER_DIR"/*.qml "$BACKUP_DIR/usr_launcher/" 2>/dev/null || true
    cp -a "$LAUNCHER_DIR"/*.qml "$BACKUP_DIR/" 2>/dev/null || true
    cp -a ~/.config/lipstick/applications.menu "$BACKUP_DIR/config_lipstick/" 2>/dev/null || true
    cp -a ~/.config/lipstick/applications.menu "$BACKUP_DIR/" 2>/dev/null || true
    dconf dump /desktop/sailfish/experimental/ > "$BACKUP_DIR/dconf_experimental.dump" 2>/dev/null || true
fi

# 2. Install QML files into Lipstick launcher
echo "[2/5] Installing QML launcher components (requires root)..."
TMP_DIR="/tmp/taidi_install_$$"
mkdir -p "$TMP_DIR"
cp "$SCRIPT_DIR/qml/LauncherGrid.qml" "$SCRIPT_DIR/qml/LauncherFolder.qml" "$TMP_DIR/"

cat << 'EOF' > "$TMP_DIR/apply_root.sh"
#!/bin/sh
set -e
LAUNCHER_DIR="/usr/share/lipstick-jolla-home-qt5/launcher"
TMP="$1"
cp -f "$TMP/LauncherGrid.qml" "$LAUNCHER_DIR/LauncherGrid.qml"
cp -f "$TMP/LauncherFolder.qml" "$LAUNCHER_DIR/LauncherFolder.qml"
chown root:root "$LAUNCHER_DIR/LauncherGrid.qml" "$LAUNCHER_DIR/LauncherFolder.qml"
chmod 644 "$LAUNCHER_DIR/LauncherGrid.qml" "$LAUNCHER_DIR/LauncherFolder.qml"
EOF
chmod +x "$TMP_DIR/apply_root.sh"

if [ "$(id -u)" = "0" ]; then
    "$TMP_DIR/apply_root.sh" "$TMP_DIR"
else
    devel-su -c /bin/sh "$TMP_DIR/apply_root.sh" "$TMP_DIR"
fi
rm -rf "$TMP_DIR"

# 3. Install CLI tool
echo "[3/5] Installing CLI tool 'taidi' to $BIN_DIR/taidi..."
mkdir -p "$BIN_DIR"
cp -f "$SCRIPT_DIR/bin/taidi" "$BIN_DIR/taidi"
chmod +x "$BIN_DIR/taidi"

# 4. Set compact 5x7 grid in dconf
echo "[4/5] Configuring 5x7 compact grid..."
dconf write /desktop/sailfish/experimental/launcher_columns_portrait 5
dconf write /desktop/sailfish/experimental/launcher_rows_portrait 7
dconf write /desktop/sailfish/experimental/launcher_columns_landscape 7
dconf write /desktop/sailfish/experimental/launcher_rows_landscape 4

# 5. Restart Lipstick
echo "[5/5] Restarting Lipstick..."
(sleep 1 && mcetool --set-display-state=on 2>/dev/null || true) &
systemctl --user restart lipstick

echo ""
echo "=== Installation complete! ==="
echo "Taidi App is now active. Open your app grid to see the compact layout and folder tools."
