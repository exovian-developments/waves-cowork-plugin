#!/bin/bash
# run-merge-cases.sh — integration cases for the waves-merge git merge-driver.
#
# Builds a real git repo in a sandbox, wires .gitattributes + [merge "waves"],
# creates diverging branches with controlled commit dates, runs REAL `git merge`
# and asserts the merged artifact. Exercises the full driver contract
# (%O %A %B %P expansion), not just the jq function.
#
# Cases:
#   1. distinct-fields      — A edits .vision, B appends a decision → both land
#   2. union-by-id          — A adds decision id=30, B adds id=31 → both present
#   3. lww-collision        — A and B edit the same field; newer commit wins
#                             THAT field; other fields from both sides intact
#   4. create-collision     — A and B both create id=30 with different content →
#                             both survive, newer side renumbered to max+1
#   5. non-artifact-fallback— a .txt routed to the driver → git merge-file
#                             markers appear (visible degradation)
#
# Exit: 0 = all cases pass; 1 = a case failed (named on stderr).

set -uo pipefail

KERNEL_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/waves-merge"
[ -f "$KERNEL_BIN" ] || { echo "run-merge-cases: kernel bin not found at $KERNEL_BIN" >&2; exit 1; }

FAILURES=0
fail() { echo "FAIL [$1]: $2" >&2; FAILURES=$((FAILURES+1)); }
ok()   { echo "ok   [$1]"; }

# new_repo <dir> — git repo with the waves driver wired
new_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email fixture@waves.test
  git -C "$dir" config user.name "Waves Fixture"
  git -C "$dir" config merge.waves.name "Waves artifact merge"
  git -C "$dir" config merge.waves.driver "bash $KERNEL_BIN %O %A %B %P"
  printf '*.json merge=waves\nroutes.txt merge=waves\n' > "$dir/.gitattributes"
  git -C "$dir" add .gitattributes
  git -C "$dir" commit -qm "wire driver"
}

# commit_dated <dir> <date> <msg> — commit all with a controlled date
commit_dated() {
  local dir="$1" date="$2" msg="$3"
  git -C "$dir" add -A
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" git -C "$dir" commit -qm "$msg"
}

SANDBOX=$(mktemp -d /tmp/waves-merge-cases.XXXXXX)
trap 'rm -rf "$SANDBOX"' EXIT

# ============ Case 1: distinct fields ============
R="$SANDBOX/c1"; new_repo "$R"
cat > "$R/art.json" <<'EOF'
{"vision": "old vision", "decisions": [{"id": 1, "decision": "base"}]}
EOF
commit_dated "$R" "2026-06-01T10:00:00Z" base
git -C "$R" checkout -qb side
jq '.decisions += [{"id": 2, "decision": "from B"}]' "$R/art.json" > "$R/t" && mv "$R/t" "$R/art.json"
commit_dated "$R" "2026-06-02T10:00:00Z" b-change
git -C "$R" checkout -q main
jq '.vision = "new vision"' "$R/art.json" > "$R/t" && mv "$R/t" "$R/art.json"
commit_dated "$R" "2026-06-03T10:00:00Z" a-change
if git -C "$R" merge -q --no-edit side >/dev/null 2>&1; then
  V=$(jq -r '.vision' "$R/art.json"); N=$(jq '.decisions | length' "$R/art.json")
  if [ "$V" = "new vision" ] && [ "$N" = "2" ] && ! grep -q '<<<<<<<' "$R/art.json"; then
    ok distinct-fields
  else
    fail distinct-fields "vision=$V decisions=$N"
  fi
else
  fail distinct-fields "git merge exited non-zero"
fi

# ============ Case 2: union by id ============
R="$SANDBOX/c2"; new_repo "$R"
cat > "$R/art.json" <<'EOF'
{"decisions": [{"id": 29, "decision": "base"}]}
EOF
commit_dated "$R" "2026-06-01T10:00:00Z" base
git -C "$R" checkout -qb side
jq '.decisions += [{"id": 31, "decision": "B new"}]' "$R/art.json" > "$R/t" && mv "$R/t" "$R/art.json"
commit_dated "$R" "2026-06-02T10:00:00Z" b-add
git -C "$R" checkout -q main
jq '.decisions += [{"id": 30, "decision": "A new"}]' "$R/art.json" > "$R/t" && mv "$R/t" "$R/art.json"
commit_dated "$R" "2026-06-03T10:00:00Z" a-add
if git -C "$R" merge -q --no-edit side >/dev/null 2>&1; then
  IDS=$(jq -c '[.decisions[].id] | sort' "$R/art.json")
  if [ "$IDS" = "[29,30,31]" ]; then ok union-by-id; else fail union-by-id "ids=$IDS"; fi
else
  fail union-by-id "git merge exited non-zero"
fi

# ============ Case 3: LWW collision (theirs newer) ============
R="$SANDBOX/c3"; new_repo "$R"
cat > "$R/art.json" <<'EOF'
{"product": {"status": "planning", "name": "keepme"}, "vision": "v"}
EOF
commit_dated "$R" "2026-06-01T10:00:00Z" base
git -C "$R" checkout -qb side
jq '.product.status = "active" | .vision = "B vision"' "$R/art.json" > "$R/t" && mv "$R/t" "$R/art.json"
commit_dated "$R" "2026-06-05T10:00:00Z" b-newer
git -C "$R" checkout -q main
jq '.product.status = "paused"' "$R/art.json" > "$R/t" && mv "$R/t" "$R/art.json"
commit_dated "$R" "2026-06-02T10:00:00Z" a-older
if git -C "$R" merge -q --no-edit side >/dev/null 2>&1; then
  S=$(jq -r '.product.status' "$R/art.json"); NAME=$(jq -r '.product.name' "$R/art.json"); V=$(jq -r '.vision' "$R/art.json")
  # theirs (side) is newer → status=active; vision only changed on B → B's; name untouched
  if [ "$S" = "active" ] && [ "$NAME" = "keepme" ] && [ "$V" = "B vision" ]; then
    ok lww-collision
  else
    fail lww-collision "status=$S name=$NAME vision=$V"
  fi
else
  fail lww-collision "git merge exited non-zero"
fi

# ============ Case 4: create-collision → renumber ============
R="$SANDBOX/c4"; new_repo "$R"
cat > "$R/art.json" <<'EOF'
{"decisions": [{"id": 29, "decision": "base"}]}
EOF
commit_dated "$R" "2026-06-01T10:00:00Z" base
git -C "$R" checkout -qb side
jq '.decisions += [{"id": 30, "decision": "B created"}]' "$R/art.json" > "$R/t" && mv "$R/t" "$R/art.json"
commit_dated "$R" "2026-06-05T10:00:00Z" b-newer
git -C "$R" checkout -q main
jq '.decisions += [{"id": 30, "decision": "A created"}]' "$R/art.json" > "$R/t" && mv "$R/t" "$R/art.json"
commit_dated "$R" "2026-06-02T10:00:00Z" a-older
if git -C "$R" merge -q --no-edit side >/dev/null 2>&1; then
  N=$(jq '.decisions | length' "$R/art.json")
  IDS=$(jq -c '[.decisions[].id] | sort' "$R/art.json")
  KEEP30=$(jq -r '.decisions[] | select(.id == 30) | .decision' "$R/art.json")
  REN=$(jq -r '.decisions[] | select(.id == 31) | .decision' "$R/art.json")
  # theirs (B) is newer → A (older) keeps id 30; B renumbered to 31. Zero loss.
  if [ "$N" = "3" ] && [ "$IDS" = "[29,30,31]" ] && [ "$KEEP30" = "A created" ] && [ "$REN" = "B created" ]; then
    ok create-collision
  else
    fail create-collision "n=$N ids=$IDS id30=$KEEP30 id31=$REN"
  fi
else
  fail create-collision "git merge exited non-zero"
fi

# ============ Case 5: non-artifact fallback ============
R="$SANDBOX/c5"; new_repo "$R"
printf 'line1\nline2\nline3\n' > "$R/routes.txt"
commit_dated "$R" "2026-06-01T10:00:00Z" base
git -C "$R" checkout -qb side
printf 'line1\nB-version\nline3\n' > "$R/routes.txt"
commit_dated "$R" "2026-06-02T10:00:00Z" b-edit
git -C "$R" checkout -q main
printf 'line1\nA-version\nline3\n' > "$R/routes.txt"
commit_dated "$R" "2026-06-03T10:00:00Z" a-edit
if git -C "$R" merge -q --no-edit side >/dev/null 2>&1; then
  fail non-artifact-fallback "merge reported clean on a real text conflict"
else
  if grep -q '<<<<<<<' "$R/routes.txt"; then
    ok non-artifact-fallback
  else
    fail non-artifact-fallback "no conflict markers after fallback"
  fi
fi

# ============ Case 6: string-array concurrent appends (audit repro) ============
# Found by the adversarial Step-7 audit of primary 2: per-field LWW on id-less
# arrays silently dropped the losing side's additions. Set-union must keep both.
R="$SANDBOX/c6"; new_repo "$R"
cat > "$R/art.json" <<'EOF'
{"acceptance_criteria": ["criterion one"]}
EOF
commit_dated "$R" "2026-06-01T10:00:00Z" base
git -C "$R" checkout -qb side
jq '.acceptance_criteria += ["added by B"]' "$R/art.json" > "$R/t" && mv "$R/t" "$R/art.json"
commit_dated "$R" "2026-06-05T10:00:00Z" b-newer
git -C "$R" checkout -q main
jq '.acceptance_criteria += ["added by A"]' "$R/art.json" > "$R/t" && mv "$R/t" "$R/art.json"
commit_dated "$R" "2026-06-02T10:00:00Z" a-older
if git -C "$R" merge -q --no-edit side >/dev/null 2>&1; then
  ARR=$(jq -c '.acceptance_criteria | sort' "$R/art.json")
  if [ "$ARR" = '["added by A","added by B","criterion one"]' ]; then
    ok string-array-union
  else
    fail string-array-union "arr=$ARR (an addition was silently lost)"
  fi
else
  fail string-array-union "git merge exited non-zero"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "run-merge-cases: $FAILURES case(s) failed" >&2
  exit 1
fi
echo "run-merge-cases: all 6 cases passed"
