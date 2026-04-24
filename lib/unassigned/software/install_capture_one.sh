#!/bin/bash
# Install or update Capture One to the latest version
# Executed by Fleet as root

set -uo pipefail

XML_URL="https://www.captureone.com/update/capture-one-mac.xml"
APP_PATH="/Applications/Capture One.app"
TEMP_DIR=$(mktemp -d)
DMG_PATH="$TEMP_DIR/CaptureOne.dmg"
MOUNT_POINT="$TEMP_DIR/CaptureOneMount"

trap 'hdiutil detach "$MOUNT_POINT" -force -quiet 2>/dev/null; rm -rf "$TEMP_DIR"' EXIT

echo "[INFO] Checking for Capture One updates..."

XML_CONTENT=$(curl -sSL --fail --max-time 30 "$XML_URL") || {
    echo "[ERROR] Failed to fetch update manifest"
    exit 1
}

LATEST_VERSION=$(echo "$XML_CONTENT" | grep -A 5 "<item>" | grep "<title>" | head -n 1 | sed -E 's/.*<title>(.*)<\/title>.*/\1/')
DOWNLOAD_URL=$(echo "$XML_CONTENT" | grep -oE 'url="https://[^"]+\.dmg"' | head -n 1 | cut -d'"' -f2)

if [ -z "$LATEST_VERSION" ] || [ -z "$DOWNLOAD_URL" ]; then
    echo "[ERROR] Unable to parse version or URL from manifest"
    exit 1
fi

echo "[INFO] Online version: $LATEST_VERSION"

if [ -d "$APP_PATH" ]; then
    INSTALLED_VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
    echo "[INFO] Installed version: $INSTALLED_VERSION"
    
    if [ "$INSTALLED_VERSION" = "$LATEST_VERSION" ]; then
        echo "[INFO] Already up to date. Exiting."
        exit 0
    fi
    echo "[INFO] New version available, upgrading..."
else
    echo "[INFO] Capture One not installed, performing fresh install..."
fi

echo "[INFO] Downloading version $LATEST_VERSION..."
curl -sSL --fail --max-time 1800 "$DOWNLOAD_URL" -o "$DMG_PATH" || {
    echo "[ERROR] Download failed"
    exit 1
}

echo "[INFO] Mounting DMG..."
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse -quiet || {
    echo "[ERROR] Failed to mount DMG"
    exit 1
}

echo "[INFO] Installing..."
pkill -x "Capture One" 2>/dev/null || true
sleep 2

if [ -d "$APP_PATH" ]; then
    rm -rf "$APP_PATH"
fi

cp -R "$MOUNT_POINT/Capture One.app" "/Applications/" || {
    echo "[ERROR] Copy failed"
    exit 1
}

if [ -d "$APP_PATH" ]; then
    NEW_INSTALLED=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
    echo "[INFO] Installation complete. Version: $NEW_INSTALLED"
    exit 0
else
    echo "[ERROR] Installation verification failed"
    exit 1
fi