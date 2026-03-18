#!/usr/bin/env bash
set -euo pipefail

# Installs the Battery GNOME extension locally.
# Note: This installs only the extension layer.
# The Battery core service must be installed and running separately.
# See README.md for full setup instructions.

TARGET="$HOME/.local/share/gnome-shell/extensions/battery@allthingsclaude.local"
mkdir -p "$TARGET"
cp metadata.json extension.js stylesheet.css "$TARGET"/
cp -r lib "$TARGET"/
gnome-extensions enable battery@allthingsclaude.local
echo "Installed to $TARGET"
echo "If GNOME Shell is running, press Alt+F2, type 'r', and press Enter to reload (X11 only)."
echo "On Wayland, log out and log back in."
