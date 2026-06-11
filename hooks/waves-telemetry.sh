#!/bin/bash
# waves-telemetry.sh — Waves usage telemetry capture (w6 Phase 7)
#
# The BEHAVIORAL sensor that complements the corpus miner's OUTPUT sensor:
# the miner reads the artifacts produced; this reads what gets INVOKED.
# Zero-token, append-only, MULTI-LOG by type (design_principle #11 navigability):
#   $CLAUDE_PLUGIN_DATA/telemetry/commands.jsonl   (event: invoked — completed/aborted reserved, not emitted in v1)
#   $CLAUDE_PLUGIN_DATA/telemetry/hooks.jsonl       (event: fired|blocked)
#   $CLAUDE_PLUGIN_DATA/telemetry/subagents.jsonl   (event: spawned)
# Every line validates against usage_event_schema.json:
#   {ts, name, event, session, scope, thread, inv}
#
# INVARIANT: silent + ALWAYS exit 0. A telemetry failure must NEVER break the
# Waves command/hook that triggered it. Opt-out: touch .claude/waves-telemetry-off.
#
# Two modes:
#   1. HOOK mode (no args, reads stdin JSON) — registered in hooks.json on
#      UserPromptSubmit/UserPromptExpansion (a slash-command was typed),
#      PreToolUse[Skill] (a command invoked programmatically), and
#      PreToolUse[Agent] (a subagent spawned). Derives kind/name/event from the event.
#   2. EMIT mode (`waves-telemetry.sh emit <kind> <name> <event>`) — called by
#      the existing waves-*.sh hooks to self-log their own firing/blocking.
#
# thread + inv (the two-level correlation thread ⊇ inv) are read from env when
# present (Phase 7 P2 sets them via thread-resolve.sh); empty here is valid.

# NOTE: no `set -e` on purpose — nothing in this script may abort its caller.

# --- Resolve plugin data dir + project dir ---
WAVES_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/waves}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# --- Opt-out: a single marker file disables all telemetry ---
if [ -f "$PROJECT_DIR/.claude/waves-telemetry-off" ]; then
  exit 0
fi

# --- jq is required for safe JSON build/parse; absent → no-op (never fail) ---
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

TELEMETRY_DIR="$WAVES_DATA/telemetry"

# _emit <kind> <name> <event> — append one schema-valid line to <kind>.jsonl.
# Reads SESSION_ID, SCOPE, THREAD, INV from env (any may be empty). Never fails.
_emit() {
  local kind="$1" name="$2" event="$3"
  [ -n "$kind" ] && [ -n "$name" ] && [ -n "$event" ] || return 0
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || return 0
  mkdir -p "$TELEMETRY_DIR" 2>/dev/null || return 0
  local line
  line=$(jq -nc \
    --arg ts "$ts" \
    --arg name "$name" \
    --arg event "$event" \
    --arg session "${SESSION_ID:-}" \
    --arg scope "${SCOPE:-root}" \
    --arg thread "${THREAD:-}" \
    --arg inv "${INV:-}" \
    '{ts:$ts, name:$name, event:$event, session:$session, scope:$scope, thread:$thread, inv:$inv}' \
    2>/dev/null) || return 0
  printf '%s\n' "$line" >> "$TELEMETRY_DIR/${kind}.jsonl" 2>/dev/null || return 0
  return 0
}

# --- Resolve the active scope label (root | <child product name>) ---
# Reuse scope-resolve.sh (DRY) to get AI_FILES_ROOT/SCOPED, then derive the label.
_resolve_scope() {
  export SESSION_ID
  # shellcheck disable=SC1091
  source "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/scope-resolve.sh" 2>/dev/null || true
  if [ -n "${AI_FILES_SCOPED:-}" ] && [ "${AI_FILES_SCOPED:-}" != "${AI_FILES_ROOT:-}" ]; then
    SCOPE=$(basename "$(dirname "$AI_FILES_SCOPED")" 2>/dev/null)
  else
    SCOPE="root"
  fi
  # Phase 7 P2 sets THREAD/INV via thread-resolve.sh when available; safe if absent.
  if [ -f "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/thread-resolve.sh" ]; then
    # shellcheck disable=SC1091
    source "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/thread-resolve.sh" 2>/dev/null || true
  fi
}

# --- inv: the FINE correlation (thread ⊇ inv). One command invocation and every
# event it triggers share one inv. Pure-bash fallback (b) from FINDINGS.md: a
# session-scoped pointer file OPENED on the command's 'invoked' event and read by
# its child events. There is no per-command completion event (Claude Code does
# not fire PostToolUse for Skill), so the pointer is not cleared — the next
# invocation simply overwrites it. No dependency on any undocumented payload id.
_inv_file() { printf '%s/markers/%s/active-inv' "$WAVES_DATA" "${SESSION_ID:-default}"; }
_read_inv() { local f; f=$(_inv_file); if [ -r "$f" ]; then INV=$(cat "$f" 2>/dev/null) || INV=""; else INV=""; fi; export INV; }
_write_inv() { local f; f=$(_inv_file); mkdir -p "$(dirname "$f")" 2>/dev/null || return 0; printf '%s' "$1" > "$f" 2>/dev/null || true; }

# --- EMIT mode: self-log from an existing hook ---
# Usage: waves-telemetry.sh emit <kind> <name> <event>
# The caller already exported SESSION_ID (sibling-hook convention). A hook firing
# is a CHILD of the current command invocation, so it inherits the active inv.
if [ "${1:-}" = "emit" ]; then
  SESSION_ID="${SESSION_ID:-}"
  _resolve_scope
  _read_inv
  _emit "${2:-}" "${3:-}" "${4:-}"
  exit 0
fi

# --- HOOK mode: read the tool/prompt event from stdin ---
#
# DEFENSIVE CAPTURE (mirrors the corpus miner's heterogeneous-read discipline,
# product_decision #23): the EXACT Claude Code stdin field names are not fully
# guaranteed across versions, so we never bet on a single path. A command's
# invocation is captured TWO ways that together cover both paths a slash-command
# can take, and the command NAME is read from any plausible field:
#   - UserPromptSubmit  → the user TYPED a /command (the common path). We parse
#     the leading /token from the prompt text, robust to field renames.
#   - PreToolUse[Skill] → Claude invoked a skill programmatically. Name read
#     defensively from skill_name // name // command // skill.
# PostToolUse does NOT fire for the Skill tool (verified, claude-code-guide), so
# there is no reliable per-command completion event — `completed`/`aborted`
# (good-vs-broken) and a clean inv-close are NOT captured in v1. inv is opened on
# each invocation and overwritten by the next (the documented fallback-b model).
INPUT=$(cat 2>/dev/null) || exit 0
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
HOOK_EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null | tr '/ ' '__')
_resolve_scope

# _open_inv <name> — start a new invocation for a command and emit 'invoked'.
_open_inv() {
  INV="${SESSION_ID}-$(date +%s 2>/dev/null)-$$"; export INV
  _write_inv "$INV"
  _emit "commands" "$1" "invoked"
}

# Prompt-level command capture. Accept BOTH candidate event names (the exact one
# is version-dependent — UserPromptSubmit / UserPromptExpansion), since
# registering an event that never fires is harmless but missing the real one
# loses the common path. command_name is the expansion field; .prompt is parsed
# for a leading /token (robust to any field renaming).
if [ "$HOOK_EVENT" = "UserPromptSubmit" ] || [ "$HOOK_EVENT" = "UserPromptExpansion" ]; then
  CMD_NAME=$(printf '%s' "$INPUT" | jq -r '.command_name // empty' 2>/dev/null)
  if [ -z "$CMD_NAME" ]; then
    PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
    CMD_NAME=$(printf '%s' "$PROMPT" | grep -oE '^/[A-Za-z0-9:_-]+' | head -1 | sed 's#^/##')
  fi
  CMD_NAME=$(printf '%s' "$CMD_NAME" | sed 's#^/##')
  [ -n "$CMD_NAME" ] && _open_inv "$CMD_NAME"
  exit 0
fi

case "$TOOL_NAME" in
  Skill)
    # Claude invoked a skill programmatically (user-typed slash-commands come via
    # UserPromptSubmit above). Name from any plausible field (defensive).
    CMD_NAME=$(printf '%s' "$INPUT" | jq -r '(.tool_input.skill_name // .tool_input.name // .tool_input.command // .tool_input.skill // empty)' 2>/dev/null)
    [ -n "$CMD_NAME" ] && _open_inv "$CMD_NAME"
    ;;
  Agent)
    # A subagent was spawned — a CHILD of the current invocation, inherits its inv.
    _read_inv
    SUB_NAME=$(printf '%s' "$INPUT" | jq -r '(.tool_input.subagent_type // .tool_input.description // "subagent")' 2>/dev/null)
    [ -n "$SUB_NAME" ] && _emit "subagents" "$SUB_NAME" "spawned"
    ;;
esac

exit 0
