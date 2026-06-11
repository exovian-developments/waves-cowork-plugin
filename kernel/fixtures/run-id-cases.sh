#!/bin/bash
# run-id-cases.sh — merge-safe ID generation + renumbering cases (w6 Phase 13).
#
# Cases:
#   1. max-plus-one-gaps   — the id expression used by hooks must yield max+1,
#                            not length+1, on a decisions array with gaps
#                            (deletions); [1,2,29] → next id 30, never 4
#   2. max-plus-one-empty  — empty array → next id 1
#   3. collision-renumber  — waves-merge replay: A and B created the same id
#                            with different content → both survive, renumbered
#                            deterministically (covered end-to-end with real
#                            git in run-merge-cases.sh case 4; here the driver
#                            is exercised directly with no git context → the
#                            deterministic tie→ours fallback applies)
#
# Exit: 0 = all pass; 1 = a case failed.

set -uo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)"

FAILURES=0
fail() { echo "FAIL [$1]: $2" >&2; FAILURES=$((FAILURES+1)); }
ok()   { echo "ok   [$1]"; }

SANDBOX=$(mktemp -d /tmp/waves-id-cases.XXXXXX)
trap 'rm -rf "$SANDBOX"' EXIT

# The exact id expression the hooks use (waves-metacognition.sh)
ID_EXPR='(.decisions | map(.id) | map(select(type=="number")) | max // 0) + 1'

# ============ Case 1: gaps after deletions ============
NEXT=$(echo '{"decisions": [{"id":1},{"id":2},{"id":29}]}' | jq "$ID_EXPR")
if [ "$NEXT" = "30" ]; then ok max-plus-one-gaps; else fail max-plus-one-gaps "next=$NEXT (length+1 would have collided at 4)"; fi

# ============ Case 2: empty array ============
NEXT=$(echo '{"decisions": []}' | jq "$ID_EXPR")
if [ "$NEXT" = "1" ]; then ok max-plus-one-empty; else fail max-plus-one-empty "next=$NEXT"; fi

# ============ Case 3: collision renumber via direct driver replay ============
echo '{"decisions": [{"id": 29, "decision": "base"}]}' > "$SANDBOX/O.json"
echo '{"decisions": [{"id": 29, "decision": "base"}, {"id": 30, "decision": "A created"}]}' > "$SANDBOX/A.json"
echo '{"decisions": [{"id": 29, "decision": "base"}, {"id": 30, "decision": "B created"}]}' > "$SANDBOX/B.json"
if bash "$BIN_DIR/waves-merge" "$SANDBOX/O.json" "$SANDBOX/A.json" "$SANDBOX/B.json" >/dev/null 2>&1; then
  N=$(jq '.decisions | length' "$SANDBOX/A.json")
  IDS=$(jq -c '[.decisions[].id] | sort' "$SANDBOX/A.json")
  # No git context → winner=a (deterministic fallback) → B (treated older… no:
  # winner=a means OURS newer → theirs keeps id, ours renumbered)
  KEEP30=$(jq -r '.decisions[] | select(.id == 30) | .decision' "$SANDBOX/A.json")
  REN31=$(jq -r '.decisions[] | select(.id == 31) | .decision' "$SANDBOX/A.json")
  if [ "$N" = "3" ] && [ "$IDS" = "[29,30,31]" ] && [ "$KEEP30" = "B created" ] && [ "$REN31" = "A created" ]; then
    ok collision-renumber
  else
    fail collision-renumber "n=$N ids=$IDS id30=$KEEP30 id31=$REN31"
  fi
else
  fail collision-renumber "driver exited non-zero"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "run-id-cases: $FAILURES case(s) failed" >&2
  exit 1
fi
echo "run-id-cases: all 3 cases passed"
