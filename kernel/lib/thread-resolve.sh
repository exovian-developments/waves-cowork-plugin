#!/bin/bash
# thread-resolve.sh — Waves work-thread resolver (w6 Phase 7)
#
# Resolves the current WORK-THREAD and exports THREAD — the COARSE half of the
# two-level correlation thread ⊇ inv (see usage_event_schema.json). A thread is
# the work-unit being served: a logbook slug, a diverged_work slug, or a top
# artifact ('blueprint'/'roadmap') for work serving them directly. It spans many
# invocations across many sessions (a logbook is created in one session,
# implemented in another, audited, resolved) — which is what lets /waves:usage
# assemble complete runs and attribute artifact modifications to their cause.
#
# DRY (REGLA-0 #3): mirrors scope-resolve.sh's marker contract EXACTLY — same
# $CLAUDE_PLUGIN_DATA/markers/$SESSION_ID/ dir, same "<cwd_md5>=<value>" line
# format, same SESSION_ID caller contract — but a SEPARATE marker file
# (active-thread) so it NEVER reads or writes active-scope. The two markers
# coexist; resolving one cannot corrupt the other.
#
# Caller contract: export SESSION_ID before sourcing (identical to
# scope-resolve.sh). Each product sources its own kernel copy:
#   source <kernel>/lib/thread-resolve.sh
#
# Fallback discipline: marker missing OR malformed OR no line for this cwd →
# THREAD stays empty. An empty thread is VALID (a one-off command whose thread is
# the artifact it produces, e.g. blueprint-create) — never an error.
#
# Re-source safety: idempotent. Recomputes from current env + cwd each source.

THREAD="${THREAD:-}"

if [ -n "${CLAUDE_PLUGIN_DATA:-}" ] && [ -n "${SESSION_ID:-}" ]; then
  _waves_thread_marker="${CLAUDE_PLUGIN_DATA}/markers/${SESSION_ID}/active-thread"
  if [ -f "$_waves_thread_marker" ] && [ -r "$_waves_thread_marker" ]; then
    _waves_cwd_hash=$(printf '%s' "$PWD" | { md5 -q 2>/dev/null || md5sum | awk '{print $1}'; })
    _waves_thread=$(grep -E "^${_waves_cwd_hash}=" "$_waves_thread_marker" 2>/dev/null | head -1 | cut -d= -f2)
    [ -n "$_waves_thread" ] && THREAD="$_waves_thread"
    unset _waves_cwd_hash _waves_thread
  fi
  unset _waves_thread_marker
fi

export THREAD
