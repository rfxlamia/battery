#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/battery/core"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

cd "$SCRIPT_DIR"
npm install
npm run build

mkdir -p "$TARGET_DIR" "$UNIT_DIR"

cp package.json package-lock.json "$TARGET_DIR"/
rm -rf "$TARGET_DIR/dist"
cp -r dist "$TARGET_DIR"/

npm ci --omit=dev --prefix "$TARGET_DIR"

cp systemd/battery-core.service "$UNIT_DIR"/battery-core.service

systemctl --user daemon-reload
systemctl --user enable --now battery-core.service

echo "Installed Battery core to $TARGET_DIR"
echo "battery-core.service is enabled and started."
