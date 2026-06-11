#!/bin/bash
# waves-gate.sh — PreToolUse hook for Waves 3.1 (thin wrapper, w6 Phase 13)
#
# The graduated-enforcement DECISION logic lives in the kernel
# (plugin/kernel/bin/waves-gate-eval — extracted verbatim in w6 Phase 13).
# This wrapper owns the Claude Code surface only: stdin JSON parse, session
# marker layout, scope resolution, telemetry self-log, and exit-code relay.
#
# Input: stdin JSON with {session_id, tool_name, tool_input} from PreToolUse
# Output: JSON with {additionalContext} or exit 2 to block (relayed from kernel)

set -euo pipefail

# Read stdin (PreToolUse event data)
INPUT=$(cat)

# Resolve project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Check for jq
if ! command -v jq &> /dev/null; then
  echo '{}'
  exit 0
fi

# --- Plugin-native marker layout (session-scoped) ---
WAVES_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/waves}"
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null | tr '/ ' '__')
MARKERS="$WAVES_DATA/markers/$SESSION_ID"

# --- Source multi-project scope resolver (kernel rail via shim) ---
# Exports AI_FILES_ROOT (prereqs always root) + AI_FILES_SCOPED (work scope-aware).
# SESSION_ID must be exported BEFORE sourcing — helper reads it for marker lookup.
export SESSION_ID

# --- Usage telemetry self-log (w6 Phase 7) — fired now, blocked on exit 2 ---
# Bulletproof: never alters this hook's exit code or aborts it (telemetry is
# subordinate to enforcement). One EXIT trap captures every exit-2 path.
__waves_tlm() { bash "${CLAUDE_PLUGIN_ROOT}/hooks/waves-telemetry.sh" emit hooks waves-gate "$1" 2>/dev/null || true; }
__waves_tlm fired
trap '__waves_rc=$?; [ "$__waves_rc" -eq 2 ] 2>/dev/null && __waves_tlm blocked; true' EXIT

source "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/scope-resolve.sh" 2>/dev/null || true

# --- Extract tool info ---
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# --- Delegate the decision to the kernel rail, relay output + exit code ---
KERNEL_BIN="${CLAUDE_PLUGIN_ROOT}/kernel/bin/waves-gate-eval"
if [ ! -f "$KERNEL_BIN" ]; then
  # Kernel missing (broken install) — fail open with a visible note, never block silently
  echo '{}'
  exit 0
fi

set +e
bash "$KERNEL_BIN" \
  --tool "$TOOL_NAME" \
  --file "$FILE_PATH" \
  --command "$COMMAND" \
  --artifacts-root "$AI_FILES_ROOT" \
  --artifacts-scoped "$AI_FILES_SCOPED" \
  --markers "$MARKERS" \
  --project-dir "$PROJECT_DIR"
RC=$?
set -e
exit "$RC"
