#!/bin/bash
# run-gate-parser-cases.sh — command-normalization cases for waves-gate-eval
# (w6 Phase 14, secondary 4; field report exobase_med_corpus finding #3).
#
# The first-word extractor used to see 'VERSION=$(jq ...)' as the command
# 'VERSION=...' — a pure read blocked under metacognition-pending. The
# normalizer strips leading VAR=token assignments and an opening $( before
# matching, WITHOUT loosening the mutant path.
#
# Cases (direct against the kernel bin — wrapper plumbing already covered by
# run-regression-cases.sh):
#   1. assignment-subshell-read  — VERSION=$(jq -r '.v' f.json) under pending → allowed
#   2. assignment-mutant-blocks  — X=1 rm -rf /tmp/x under pending → still blocked
#   3. plain-read-still-allowed  — jq . f.json under pending → allowed (no regression)
#   4. normal-mode-assignment    — ENV=prod jq . f.json, full artifacts → allowed
#                                  SILENTLY ({}): normalized read-only hits the
#                                  whitelist before the artifact checks
#
# Exit: 0 = all pass; 1 = a case failed.

set -uo pipefail

BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/waves-gate-eval"

FAILURES=0
fail() { echo "FAIL [$1]: $2" >&2; FAILURES=$((FAILURES+1)); }
ok()   { echo "ok   [$1]"; }

SANDBOX=$(mktemp -d /tmp/waves-gate-parser.XXXXXX)
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/waves_files/waves/w1/logbooks" "$SANDBOX/markers"
echo '{"meta":{}}' > "$SANDBOX/waves_files/blueprint.json"
echo '{}' > "$SANDBOX/waves_files/waves/w1/roadmap.json"
echo '{}' > "$SANDBOX/waves_files/waves/w1/logbooks/t.json"

run_gate() { # $1 command, $2 with-pending (yes/no)
  if [ "$2" = "yes" ]; then date > "$SANDBOX/markers/metacognition-pending"; else rm -f "$SANDBOX/markers/metacognition-pending"; fi
  bash "$BIN" --tool Bash --command "$1" \
    --artifacts-root "$SANDBOX/waves_files" --artifacts-scoped "$SANDBOX/waves_files" \
    --markers "$SANDBOX/markers" --project-dir "$SANDBOX"
}

# 1
run_gate "VERSION=\$(jq -r '.v' f.json)" yes >/dev/null 2>&1
[ $? -eq 0 ] && ok assignment-subshell-read || fail assignment-subshell-read "blocked a pure read"

# 2
run_gate "X=1 rm -rf /tmp/x" yes >/dev/null 2>&1
[ $? -eq 2 ] && ok assignment-mutant-blocks || fail assignment-mutant-blocks "mutant slipped through"

# 3
run_gate "jq . f.json" yes >/dev/null 2>&1
[ $? -eq 0 ] && ok plain-read-still-allowed || fail plain-read-still-allowed "regression on plain jq"

# 4 (normal mode: artifacts complete → allow with reminder)
OUT=$(run_gate "ENV=prod jq . f.json" no 2>/dev/null); RC=$?
if [ $RC -eq 0 ] && [ "$OUT" = "{}" ]; then
  ok normal-mode-assignment
else
  fail normal-mode-assignment "rc=$RC out=$OUT"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "run-gate-parser-cases: $FAILURES case(s) failed" >&2
  exit 1
fi
echo "run-gate-parser-cases: all 4 cases passed"
