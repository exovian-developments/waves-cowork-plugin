#!/bin/bash
# waves-dart-analyze.sh — PostToolUse hook for Waves 3.0 (plugin-native)
# Runs dart analyze on .dart files after each edit.
#
# Only processes .dart files. For all other files, exits in <1ms.
# No marker state — purely reactive to the edited file, so plugin migration
# requires no path changes (reads tool_input.file_path from stdin).
#
# Input: stdin JSON with {tool_name, tool_input, tool_response} from PostToolUse
# Output: JSON with {additionalContext} if analysis finds issues, empty otherwise

set -euo pipefail

# Read stdin
INPUT=$(cat)

# Extract file path
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Quick exit: not a .dart file
if [[ "$FILE" != *.dart ]]; then
  echo '{}'
  exit 0
fi

# Quick exit: dart not available
if ! command -v dart &> /dev/null; then
  echo '{}'
  exit 0
fi

# Run dart analyze on the specific file
ANALYSIS=$(dart analyze "$FILE" 2>&1) || true

# Check if there are any issues (errors or warnings)
ISSUE_COUNT=$(echo "$ANALYSIS" | grep -cE '^\s*(error|warning|info)\s' 2>/dev/null || echo 0)

if [ "$ISSUE_COUNT" -gt 0 ]; then
  # Extract just the issue lines (not the summary)
  ISSUES=$(echo "$ANALYSIS" | grep -E '^\s*(error|warning|info)\s' | head -10)
  MSG="dart analyze encontró $ISSUE_COUNT problemas en $FILE:\n$ISSUES"
  jq -n --arg ctx "$MSG" '{"additionalContext": $ctx}'
  exit 0
fi

echo '{}'
exit 0
