#!/bin/bash
# waves-doc-enforce.sh — PostToolUse hook for Waves 3.0 (plugin-native)
# Ensures recent_context is updated when logbook objectives are completed.
#
# Only processes edits to logbook files (*/logbooks/*.json).
# For 99% of edits (non-logbook files), exits in <1ms.
#
# Uses a session-scoped marker to track the last known completed count.
# If completed count increased but recent_context didn't grow,
# documentation is missing. The baseline is seeded by waves-perceive.sh at
# SessionStart, so the first edit of a session doesn't false-fire.
#
# Plugin-native marker: $CLAUDE_PLUGIN_DATA/markers/$SESSION_ID/doc-enforce/<md5(abs path)>
#
# Input: stdin JSON with {session_id, tool_name, tool_input, tool_response} from PostToolUse
# Output: JSON with {additionalContext} if documentation is missing, empty otherwise

set -euo pipefail

# Read stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.content // empty' 2>/dev/null)

# Quick exit: not a logbook file → ignore (<1ms)
if [[ "$FILE" != *"/logbooks/"*.json ]]; then
  echo '{}'
  exit 0
fi

# Quick exit: file doesn't exist
if [ ! -f "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Check for jq
if ! command -v jq &> /dev/null; then
  echo '{}'
  exit 0
fi

# Count objectives with status "achieved" or "completed" (main + secondary)
COMPLETED=$(jq '([.objectives.main[] | select(.status == "achieved" or .status == "completed")] | length) + ([.objectives.secondary[] | select(.status == "achieved" or .status == "completed")] | length)' "$FILE" 2>/dev/null || echo 0)

# Count recent_context entries
CONTEXT_ENTRIES=$(jq '.recent_context | length' "$FILE" 2>/dev/null || echo 0)

# --- Plugin-native marker (session-scoped, absolute-path hash) ---
WAVES_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/waves}"
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null | tr '/ ' '__')
MARKER_DIR="$WAVES_DATA/markers/$SESSION_ID/doc-enforce"
mkdir -p "$MARKER_DIR" 2>/dev/null
NORM_FILE=$(cd "$(dirname "$FILE")" 2>/dev/null && echo "$(pwd)/$(basename "$FILE")" || echo "$FILE")
FILE_HASH=$(printf '%s' "$NORM_FILE" | md5 2>/dev/null || printf '%s' "$NORM_FILE" | md5sum 2>/dev/null | cut -d' ' -f1)
MARKER_FILE="$MARKER_DIR/$FILE_HASH"

LAST_COMPLETED=$(cat "$MARKER_FILE.completed" 2>/dev/null || echo 0)
LAST_CONTEXT=$(cat "$MARKER_FILE.context" 2>/dev/null || echo 0)

# Update markers
echo "$COMPLETED" > "$MARKER_FILE.completed"
echo "$CONTEXT_ENTRIES" > "$MARKER_FILE.context"

# If completed count grew but context count didn't, documentation is missing
if [ "$COMPLETED" -gt "$LAST_COMPLETED" ] && [ "$CONTEXT_ENTRIES" -le "$LAST_CONTEXT" ]; then
  MSG="ENFORCEMENT: You marked objectives as completed but did not add a recent_context entry. Every group of completed objectives MUST have its context documented — it is the foundation for future projections and session continuity. Add a recent_context entry describing what was done and what was learned."
  jq -n --arg ctx "$MSG" '{"additionalContext": $ctx}'
  exit 0
fi

echo '{}'
exit 0
