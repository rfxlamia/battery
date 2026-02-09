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

# Restrict file creation permissions to owner-only
umask 077

EVENT_TYPE="${1:-unknown}"
SESSION_ID="${CLAUDE_SESSION_ID:-$(uuidgen)}"
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
EVENTS_DIR="$HOME/.battery"
EVENTS_FILE="$EVENTS_DIR/events.jsonl"

# Ensure events directory exists with restrictive permissions
mkdir -p "$EVENTS_DIR"
chmod 700 "$EVENTS_DIR"

# Get ISO 8601 timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Refuse to write to a symlink
if [[ -L "$EVENTS_FILE" ]]; then
    echo "battery-hook: refusing to write to symlink at $EVENTS_FILE" >&2
    exit 1
fi

# Build JSON event with proper escaping via printf
# Escape backslashes and double quotes in all variable fields
escape_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/}"
    s="${s//$'\r'/}"
    printf '%s' "$s"
}

SAFE_EVENT=$(escape_json "$EVENT_TYPE")
SAFE_SID=$(escape_json "$SESSION_ID")
SAFE_TOOL=$(escape_json "$TOOL_NAME")

if [[ -n "$SAFE_TOOL" ]]; then
    EVENT_JSON="{\"event\":\"$SAFE_EVENT\",\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SAFE_SID\",\"tool\":\"$SAFE_TOOL\"}"
else
    EVENT_JSON="{\"event\":\"$SAFE_EVENT\",\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SAFE_SID\"}"
fi

# Append to events file
echo "$EVENT_JSON" >> "$EVENTS_FILE"

# Rotate: keep only last 1000 events
if [[ $(wc -l < "$EVENTS_FILE") -gt 1000 ]]; then
    tail -500 "$EVENTS_FILE" > "$EVENTS_FILE.tmp"
    mv "$EVENTS_FILE.tmp" "$EVENTS_FILE"
fi
