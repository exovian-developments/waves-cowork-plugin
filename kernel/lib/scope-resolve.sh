#!/bin/bash
# scope-resolve.sh — Waves multi-project scope resolver (shared helper)
#
# Sourced by hook wrappers to resolve the active project scope from a
# per-session marker file. Exports two path variables consumers use to read
# the Waves artifacts directory (waves_files/ canonical, ai_files/ fallback):
#
#   AI_FILES_ROOT   — the parent's artifacts dir, resolved dual (parent's waves artifacts:
#                     blueprint, root rules, manifest, schemas). Root-only
#                     validation per Phase 2 w5: prereq checks always read from
#                     here regardless of --project flag.
#   AI_FILES_SCOPED — work artifacts (logbooks, scoped rules/manifest/blueprint
#                     when the child product owns them). Equals ROOT in single-
#                     project mode OR when marker absent. Equals
#                     "$PROJECT_DIR/projects/<scope>/ai_files" when marker
#                     resolves to an existing child product dir at
#                     "$PROJECT_DIR/projects/<scope>/".
#
# Path semantics (design_principle #9): products live at /projects/<name>/;
# their waves artifacts live at /projects/<name>/ai_files/. Never the inverse.
#
# Caller contract: before sourcing, the caller MUST have exported $SESSION_ID
# (the session identifier of the host runtime; Claude Code passes it via stdin
# JSON to each hook event). Convention:
#   SESSION_ID=$(... resolve from host input ...)
#   export SESSION_ID
# Then: source <kernel>/lib/scope-resolve.sh (each product sources its own copy)
#
# If $SESSION_ID is unset/empty when this script runs, marker lookup is skipped
# and AI_FILES_SCOPED falls back to AI_FILES_ROOT (single-project behavior).
#
# Marker contract (decision #5 w5 roadmap):
#   Path:   $CLAUDE_PLUGIN_DATA/markers/$SESSION_ID/active-scope
#   Format: one or more lines, each "<cwd_md5>=<scope_name>" (md5 of $PWD as
#           seen at source time). Multi-line supports sessions traversing
#           multiple cwds; only the line matching current cwd is consulted.
#
# Fallback discipline: marker missing OR malformed OR scope dir absent →
# AI_FILES_SCOPED == AI_FILES_ROOT. Never errors — hooks must remain
# backwards-compatible with single-project mode (pre-3.x).
#
# Re-source safety: idempotent. Each source recomputes from current env + cwd.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Dual resolution (w6 Phase 13, waves_files rename): waves_files/ is the
# canonical artifacts directory; ai_files/ is the pre-v3.1 fallback so
# unmigrated projects keep working unchanged. Both present = a migration left
# half-done → prefer waves_files/ and warn (never silently read from both).
# Neither present → return the canonical path (consumers check -d themselves,
# exactly as they did pre-rename). This function is the ONLY place the
# directory name is decided — every consumer inherits it.
_waves_resolve_dir() {
  if [ -d "$1/waves_files" ]; then
    if [ -d "$1/ai_files" ]; then
      echo "waves: both waves_files/ and ai_files/ exist under $1 — using waves_files/; run 'waves upgrade' to finish the migration" >&2
    fi
    printf '%s' "$1/waves_files"
  elif [ -d "$1/ai_files" ]; then
    printf '%s' "$1/ai_files"
  else
    printf '%s' "$1/waves_files"
  fi
}

AI_FILES_ROOT=$(_waves_resolve_dir "$PROJECT_DIR")
AI_FILES_SCOPED="$AI_FILES_ROOT"

if [ -n "${CLAUDE_PLUGIN_DATA:-}" ] && [ -n "${SESSION_ID:-}" ]; then
  _waves_marker="${CLAUDE_PLUGIN_DATA}/markers/${SESSION_ID}/active-scope"
  if [ -f "$_waves_marker" ] && [ -r "$_waves_marker" ]; then
    _waves_cwd_hash=$(printf '%s' "$PWD" | { md5 -q 2>/dev/null || md5sum | awk '{print $1}'; })
    _waves_scope=$(grep -E "^${_waves_cwd_hash}=" "$_waves_marker" 2>/dev/null | head -1 | cut -d= -f2)
    if [ -n "$_waves_scope" ] && [ -d "${PROJECT_DIR}/projects/${_waves_scope}" ]; then
      AI_FILES_SCOPED=$(_waves_resolve_dir "${PROJECT_DIR}/projects/${_waves_scope}")
    fi
    unset _waves_cwd_hash _waves_scope
  fi
  unset _waves_marker
fi

export AI_FILES_ROOT AI_FILES_SCOPED
