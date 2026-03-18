#!/usr/bin/env bash
set -euo pipefail

# Verifies that the Battery GNOME extension and core service are both installed correctly.
# Exits non-zero with a clear message if any check fails.

EXTENSION_UUID="battery@allthingsclaude.local"
EXTENSION_DIR="$HOME/.local/share/gnome-shell/extensions/$EXTENSION_UUID"

echo "Checking Battery GNOME extension install..."

# Check extension files are present
if ! test -f "$EXTENSION_DIR/extension.js"; then
  echo "FAIL: extension.js not found in $EXTENSION_DIR"
  echo "      Run ./install-local.sh to install the extension."
  exit 1
fi

# Check extension is known to GNOME
if ! gnome-extensions info "$EXTENSION_UUID" > /dev/null 2>&1; then
  echo "FAIL: Extension $EXTENSION_UUID is not known to GNOME Shell."
  echo "      Try: gnome-extensions enable $EXTENSION_UUID"
  echo "      Then reload GNOME Shell (Alt+F2 → r on X11, or log out/in on Wayland)."
  exit 1
fi

echo "  ✓ Extension files installed"

# Check core service is running
if ! systemctl --user --quiet is-active battery-core.service; then
  echo "FAIL: battery-core.service is not active."
  echo "      The extension will show 'Battery Stale' without the core service running."
  echo "      Start it with: systemctl --user start battery-core.service"
  exit 1
fi

echo "  ✓ battery-core.service is active"
echo ""
echo "Battery GNOME extension is correctly installed and running."
