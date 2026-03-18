#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.local/share/battery/core"
UNIT_DIR="$HOME/.config/systemd/user"

cd "$SCRIPT_DIR"
npm ci
npm run build

mkdir -p "$TARGET_DIR" "$UNIT_DIR"

cp package.json package-lock.json "$TARGET_DIR"/
rm -rf "$TARGET_DIR/dist"
cp -r dist "$TARGET_DIR"/

npm ci --omit=dev --prefix "$TARGET_DIR"

NODE_BIN="$(command -v node)"
if [[ -z "$NODE_BIN" ]]; then
  echo "Failed to locate node in PATH."
  exit 1
fi

cat > "$TARGET_DIR/run-battery-core.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$NODE_BIN" "$TARGET_DIR/dist/main.js" --loop
EOF
chmod +x "$TARGET_DIR/run-battery-core.sh"

cp systemd/battery-core.service "$UNIT_DIR"/battery-core.service

systemctl --user daemon-reload
systemctl --user enable --now battery-core.service

echo "Installed Battery core to $TARGET_DIR"
echo "battery-core.service is enabled and started."
