#!/bin/sh
# TAIDI APP - Remote Deployment over SSH
# Deploys Taidi App files to a Sailfish OS device over SSH and runs installer.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

DEVICE_IP="${JOLLA_IP:-$1}"
DEVICE_USER="${JOLLA_USER:-defaultuser}"

if [ -z "$DEVICE_IP" ]; then
    printf "Enter Jolla device IP address [192.168.2.15]: "
    read -r input_ip
    DEVICE_IP="${input_ip:-192.168.2.15}"
fi

echo "Connecting to $DEVICE_USER@$DEVICE_IP..."

REMOTE_TMP="/home/$DEVICE_USER/taidi_deploy_tmp"

ssh -o StrictHostKeyChecking=no "$DEVICE_USER@$DEVICE_IP" "mkdir -p $REMOTE_TMP/patches $REMOTE_TMP/bin $REMOTE_TMP/scripts"
scp -o StrictHostKeyChecking=no "$SCRIPT_DIR/patches/"*.patch "$DEVICE_USER@$DEVICE_IP:$REMOTE_TMP/patches/"
scp -o StrictHostKeyChecking=no "$SCRIPT_DIR/bin/"* "$DEVICE_USER@$DEVICE_IP:$REMOTE_TMP/bin/"
scp -o StrictHostKeyChecking=no "$SCRIPT_DIR/scripts/"*.py "$SCRIPT_DIR/scripts/"*.sh "$DEVICE_USER@$DEVICE_IP:$REMOTE_TMP/scripts/"

echo "Running installer on device..."
ssh -t -o StrictHostKeyChecking=no "$DEVICE_USER@$DEVICE_IP" "chmod +x $REMOTE_TMP/scripts/*.sh $REMOTE_TMP/scripts/*.py $REMOTE_TMP/bin/* && $REMOTE_TMP/scripts/install.sh && rm -rf $REMOTE_TMP"

echo "Remote deployment completed successfully!"
