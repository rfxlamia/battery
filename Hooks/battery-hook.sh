#!/usr/bin/env bash
#
# Battery - Claude Code Hook Script
#
# This hook writes session events to ~/.battery/events.jsonl
# so the Battery menu bar app can detect active coding sessions.
#
# Installation:
#   Add to your Claude Code hooks configuration:
#
#   "hooks": {
#     "SessionStart": [{ "command": "/path/to/battery-hook.sh SessionStart" }],
#     "SessionEnd":   [{ "command": "/path/to/battery-hook.sh SessionEnd" }],
#     "PostToolUse":  [{ "command": "/path/to/battery-hook.sh PostToolUse" }],
#     "Stop":         [{ "command": "/path/to/battery-hook.sh Stop" }]
#   }

set -euo pipefail

EVENT_TYPE="${1:-unknown}"
SESSION_ID="${CLAUDE_SESSION_ID:-$(uuidgen)}"
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
EVENTS_DIR="$HOME/.battery"
EVENTS_FILE="$EVENTS_DIR/events.jsonl"

# Ensure events directory exists
mkdir -p "$EVENTS_DIR"

# Get ISO 8601 timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build JSON event
if [[ -n "$TOOL_NAME" ]]; then
    EVENT_JSON="{\"event\":\"$EVENT_TYPE\",\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\",\"tool\":\"$TOOL_NAME\"}"
else
    EVENT_JSON="{\"event\":\"$EVENT_TYPE\",\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\"}"
fi

# Append to events file
echo "$EVENT_JSON" >> "$EVENTS_FILE"

# Rotate: keep only last 1000 events
if [[ $(wc -l < "$EVENTS_FILE") -gt 1000 ]]; then
    tail -500 "$EVENTS_FILE" > "$EVENTS_FILE.tmp"
    mv "$EVENTS_FILE.tmp" "$EVENTS_FILE"
fi
