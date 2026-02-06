#!/usr/bin/env bash
#
# Quick dev cycle: kill → build → bundle → relaunch
# Usage: ./Scripts/dev.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Kill running instance
pkill -x Battery 2>/dev/null && sleep 0.3 || true

# Build
echo "Building..."
cd "$PROJECT_DIR"
swift build 2>&1 | tail -1

# Bundle
bash "$SCRIPT_DIR/bundle.sh" debug

# Launch
echo "Launching..."
open "$PROJECT_DIR/Battery.app"
