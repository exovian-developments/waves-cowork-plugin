#!/bin/bash
# run-freshness-cases.sh — coverage cases for waves-manifest-freshness.sh
# (w6 Phase 14, secondary 5; pcc_local field finding: Flow C fired for NOBODY).
#
# Requires CLAUDE_PLUGIN_ROOT (the hook sources scope-resolve + reads user_pref
# conventions). Real git repos in a sandbox.
#
# Cases:
#   1. child-repo-commit  — commit in projects/<child>/ (own git) with code:
#                           the hook must resolve THE CHILD repo (via payload
#                           cwd) and find the child's manifest → delegation fires
#   2. merge-boundary     — `git merge` landing code → delegation fires
#   3. artifacts-only     — commit touching only waves_files/ → silent {}
#   4. git-dash-C         — `git -C <child> commit` from the root cwd → child resolved
#
# Exit: 0 = all pass; 1 = a case failed.

set -uo pipefail
: "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT must be set}"
HOOK="${CLAUDE_PLUGIN_ROOT}/hooks/waves-manifest-freshness.sh"

FAILURES=0
fail() { echo "FAIL [$1]: $2" >&2; FAILURES=$((FAILURES+1)); }
ok()   { echo "ok   [$1]"; }

SANDBOX=$(mktemp -d /tmp/waves-freshness-cases.XXXXXX)
trap 'rm -rf "$SANDBOX"' EXIT

mk_repo() { # $1 dir — repo with a manifest + base commit
  mkdir -p "$1/waves_files"
  git -C "$1" init -q -b main 2>/dev/null || { mkdir -p "$1"; git -C "$1" init -q -b main; }
  git -C "$1" config user.email f@t && git -C "$1" config user.name F
  echo '{"project":{"name":"t"}}' > "$1/waves_files/project_manifest.json"
  echo base > "$1/seed.txt"
  git -C "$1" add -A && git -C "$1" commit -qm base
}

run_hook() { # $1 command, $2 cwd, $3 project_dir → stdout
  python3 - "$1" "$2" <<'PY' | CLAUDE_PROJECT_DIR="$3" CLAUDE_PLUGIN_DATA="$SANDBOX/data" bash "$HOOK" 2>/dev/null
import json, sys
print(json.dumps({"session_id":"fx","tool_name":"Bash","cwd":sys.argv[2],"tool_input":{"command":sys.argv[1]}}))
PY
}

ROOT="$SANDBOX/root"; mkdir -p "$ROOT/projects"
mk_repo "$ROOT"
CHILD="$ROOT/projects/childproj"; mkdir -p "$CHILD"
mk_repo "$CHILD"

# ============ Case 1: commit in the CHILD repo (cwd = child) ============
echo 'void main(){}' > "$CHILD/app.dart"
git -C "$CHILD" add -A && git -C "$CHILD" commit -qm code
OUT=$(run_hook "git commit -m code" "$CHILD" "$ROOT")
if printf '%s' "$OUT" | jq -e '.additionalContext' >/dev/null 2>&1 && \
   printf '%s' "$OUT" | jq -r '.additionalContext' | grep -q "childproj/waves_files/project_manifest.json"; then
  ok child-repo-commit
else
  fail child-repo-commit "no disparó o no localizó el manifest del hijo"
fi

# ============ Case 2: merge boundary lands code ============
R="$SANDBOX/m"; mk_repo "$R"
git -C "$R" checkout -qb feature
echo 'code' > "$R/lib.dart" && git -C "$R" add -A && git -C "$R" commit -qm feat
git -C "$R" checkout -q main
git -C "$R" merge -q --no-ff --no-edit feature
OUT=$(run_hook "git merge --no-ff feature" "$R" "$R")
if printf '%s' "$OUT" | jq -e '.additionalContext' >/dev/null 2>&1; then
  ok merge-boundary
else
  fail merge-boundary "merge con código no disparó"
fi

# ============ Case 3: artifacts-only commit is silent ============
R="$SANDBOX/a"; mk_repo "$R"
echo '{"x":1}' > "$R/waves_files/extra.json"
git -C "$R" add -A && git -C "$R" commit -qm artifacts
OUT=$(run_hook "git commit -m artifacts" "$R" "$R")
[ "$OUT" = "{}" ] && ok artifacts-only-silent || fail artifacts-only-silent "out=$OUT"

# ============ Case 4: git -C <child> from the ROOT cwd ============
echo 'more code' > "$CHILD/app2.dart"
git -C "$CHILD" add -A && git -C "$CHILD" commit -qm code2
OUT=$(run_hook "git -C $CHILD commit -m code2" "$ROOT" "$ROOT")
if printf '%s' "$OUT" | jq -e '.additionalContext' >/dev/null 2>&1 && \
   printf '%s' "$OUT" | jq -r '.additionalContext' | grep -q "childproj"; then
  ok git-dash-C
else
  fail git-dash-C "no resolvió el repo del -C"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "run-freshness-cases: $FAILURES case(s) failed" >&2
  exit 1
fi
echo "run-freshness-cases: all 4 cases passed"
