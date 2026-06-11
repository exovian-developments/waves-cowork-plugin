#!/bin/bash
# run-resolve-cases.sh — dual artifacts-directory resolution cases (w6 Phase 13).
#
# Exercises lib/scope-resolve.sh's _waves_resolve_dir through a real source of
# the lib (the same path every hook takes), across the three project states:
#   1. migrated      — waves_files/ only → resolves waves_files/
#   2. legacy        — ai_files/ only → resolves ai_files/ (fallback, no warning)
#   3. half-migrated — BOTH present → resolves waves_files/ + actionable warning
#   4. neither       — no artifacts dir → canonical waves_files/ path (consumers
#                      check -d themselves; same no-artifacts behavior as before)
#
# Exit: 0 = all pass; 1 = a case failed.

set -uo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/scope-resolve.sh"

FAILURES=0
fail() { echo "FAIL [$1]: $2" >&2; FAILURES=$((FAILURES+1)); }
ok()   { echo "ok   [$1]"; }

SANDBOX=$(mktemp -d /tmp/waves-resolve-cases.XXXXXX)
trap 'rm -rf "$SANDBOX"' EXIT

# resolve <project-dir> → prints AI_FILES_ROOT after sourcing the lib (stderr passes through)
resolve() {
  CLAUDE_PROJECT_DIR="$1" bash -c "source '$LIB'; printf '%s' \"\$AI_FILES_ROOT\""
}

# ============ Case 1: migrated ============
P="$SANDBOX/migrated"; mkdir -p "$P/waves_files"
R=$(resolve "$P" 2>/dev/null)
[ "$R" = "$P/waves_files" ] && ok migrated || fail migrated "resolved=$R"

# ============ Case 2: legacy fallback, quiet ============
P="$SANDBOX/legacy"; mkdir -p "$P/ai_files"
ERR=$(resolve "$P" 2>&1 >/dev/null)
R=$(resolve "$P" 2>/dev/null)
if [ "$R" = "$P/ai_files" ] && [ -z "$ERR" ]; then
  ok legacy-fallback
else
  fail legacy-fallback "resolved=$R stderr='$ERR'"
fi

# ============ Case 3: half-migrated prefers canonical + warns ============
P="$SANDBOX/half"; mkdir -p "$P/waves_files" "$P/ai_files"
ERR=$(resolve "$P" 2>&1 >/dev/null)
R=$(resolve "$P" 2>/dev/null)
if [ "$R" = "$P/waves_files" ] && printf '%s' "$ERR" | grep -q 'waves upgrade'; then
  ok half-migrated-warns
else
  fail half-migrated-warns "resolved=$R stderr='$ERR'"
fi

# ============ Case 4: neither → canonical path, consumers check -d ============
P="$SANDBOX/none"; mkdir -p "$P"
R=$(resolve "$P" 2>/dev/null)
[ "$R" = "$P/waves_files" ] && ok neither-canonical || fail neither-canonical "resolved=$R"

if [ "$FAILURES" -gt 0 ]; then
  echo "run-resolve-cases: $FAILURES case(s) failed" >&2
  exit 1
fi
echo "run-resolve-cases: all 4 cases passed"
