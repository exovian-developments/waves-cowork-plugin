#!/bin/bash
# waves-stub-check.sh — PostToolUse hook for Waves 3.1 (thin wrapper, w6 Phase 13)
#
# The stub-detection CHECKERS live in the kernel
# (plugin/kernel/bin/waves-stub-check — extracted verbatim in w6 Phase 13).
# This wrapper owns the Claude Code surface only: stdin JSON parse, project_type
# resolution from project_rules.json (+ WAVES_PROJECT_TYPE override), telemetry
# self-log, and exit-code relay.
#
# Exit codes (Claude Code hook contract):
#   0 = clean (no stub detected, o file ignorado por extensión)
#   2 = stub detectado (blocking — Claude Code surface STDERR al user)
#   1 = hook error interno

set -euo pipefail

# --- Stdin payload + extracción del archivo ---
INPUT=$(cat)
TOOL_FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Fail-safe: sin file, sin trabajo
if [ -z "$TOOL_FILE" ] || [ ! -f "$TOOL_FILE" ]; then
  exit 0
fi

# Check jq disponible (fail-safe)
if ! command -v jq &> /dev/null; then
  exit 0
fi

# --- Resolver project_root ---
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT=$(git -C "$(dirname "$TOOL_FILE")" rev-parse --show-toplevel 2>/dev/null || pwd)
fi

# --- Source multi-project scope resolver (kernel rail via shim) ---
# No SESSION_ID set here → helper falls back to root for SCOPED (this hook only
# needs ROOT for the project_type prereq read; behavior identical to pre-3.x).
CLAUDE_PROJECT_DIR="$PROJECT_ROOT" source "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/scope-resolve.sh" 2>/dev/null || true

# --- Usage telemetry self-log (w6 Phase 7) — fired = a real stub check ---
# Bulletproof: never alters this hook's exit code or aborts it. One EXIT trap
# captures every exit-2 path from the kernel checkers. Placed after we have a
# file to evaluate so "fired" means stub-check actually ran, not every Edit/Write.
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null | tr '/ ' '__'); export SESSION_ID
__waves_tlm() { bash "${CLAUDE_PLUGIN_ROOT}/hooks/waves-telemetry.sh" emit hooks waves-stub-check "$1" 2>/dev/null || true; }
__waves_tlm fired
trap '__waves_rc=$?; [ "$__waves_rc" -eq 2 ] 2>/dev/null && __waves_tlm blocked; true' EXIT

# --- Resolver PROJECT_TYPE ---
# Source-of-truth: plugin/skills/waves-protocol/references/project_rules_schema.json
# .properties.type.enum = [frontend, backend, fullstack, agentic]
# Prereq read → AI_FILES_ROOT (root-only validation per Phase 2 w5).
PROJECT_TYPE=""
if [ -f "$AI_FILES_ROOT/project_rules.json" ]; then
  PROJECT_TYPE=$(jq -r '.type // empty' "$AI_FILES_ROOT/project_rules.json" 2>/dev/null || echo "")
fi
PROJECT_TYPE="${WAVES_PROJECT_TYPE:-$PROJECT_TYPE}"

# --- Delegate the checkers to the kernel rail, relay output + exit code ---
KERNEL_BIN="${CLAUDE_PLUGIN_ROOT}/kernel/bin/waves-stub-check"
if [ ! -f "$KERNEL_BIN" ]; then
  # Kernel missing (broken install) — fail open, never block on a missing binary
  exit 0
fi

set +e
bash "$KERNEL_BIN" --file "$TOOL_FILE" --type "$PROJECT_TYPE"
RC=$?
set -e
exit "$RC"
