#!/bin/bash
# run-precommit-cases.sh — integration cases for the waves-pre-commit backstop.
#
# Real git repos in a sandbox, real `git commit` runs, hook installed via
# waves-pre-commit-install. Schemas: a minimal roadmap schema written into the
# sandbox (the kernel takes --schemas as input — fixtures must not depend on
# the plugin's schema files, per self-containment).
#
# Cases:
#   1. malformed-blocks      — staged artifact with broken JSON → commit blocked
#   2. invalid-new-blocks    — staged roadmap introducing a NEW schema error → blocked
#   3. valid-passes          — clean artifact commit → proceeds
#   4. legacy-tolerated      — file ALREADY invalid at HEAD, edit adds no new
#                              error → warning, commit proceeds (delta semantics)
#   5. foreign-hook-chained  — pre-existing pre-commit keeps running (and its
#                              failure still blocks), waves backstop added
#   6. no-artifacts-noop     — commit touching only code → hook silent
#
# Exit: 0 = all cases pass; 1 = a case failed (named on stderr).

set -uo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)"
INSTALL="$BIN_DIR/waves-pre-commit-install"

FAILURES=0
fail() { echo "FAIL [$1]: $2" >&2; FAILURES=$((FAILURES+1)); }
ok()   { echo "ok   [$1]"; }

SANDBOX=$(mktemp -d /tmp/waves-precommit-cases.XXXXXX)
trap 'rm -rf "$SANDBOX"' EXIT

# Minimal roadmap schema: product required; decisions[].decision capped at 40 chars
SCHEMAS="$SANDBOX/schemas"
mkdir -p "$SCHEMAS"
cat > "$SCHEMAS/logbook_roadmap_schema.json" <<'EOF'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["product"],
  "properties": {
    "product": {"type": "object"},
    "decisions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {"decision": {"type": "string", "maxLength": 40}}
      }
    }
  }
}
EOF

new_repo() {
  local dir="$1"
  mkdir -p "$dir/ai_files/waves/w1"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email fixture@waves.test
  git -C "$dir" config user.name "Waves Fixture"
  echo init > "$dir/seed.txt"
  git -C "$dir" add -A && git -C "$dir" commit -qm seed
  bash "$INSTALL" --schemas "$SCHEMAS" --repo "$dir" >/dev/null
}

# ============ Case 1: malformed JSON blocks ============
R="$SANDBOX/c1"; new_repo "$R"
printf '{ broken json' > "$R/ai_files/waves/w1/roadmap.json"
git -C "$R" add -A
if git -C "$R" commit -qm bad >/dev/null 2>&1; then
  fail malformed-blocks "commit proceeded with malformed JSON"
else
  ok malformed-blocks
fi

# ============ Case 2: NEW schema error blocks ============
R="$SANDBOX/c2"; new_repo "$R"
printf '{"product": {}, "decisions": []}\n' > "$R/ai_files/waves/w1/roadmap.json"
git -C "$R" add -A && git -C "$R" commit -qm valid-base
jq '.decisions += [{"decision": "this decision text is way past the forty char cap of the fixture schema"}]' \
  "$R/ai_files/waves/w1/roadmap.json" > "$R/t" && mv "$R/t" "$R/ai_files/waves/w1/roadmap.json"
git -C "$R" add -A
if git -C "$R" commit -qm overcap >/dev/null 2>&1; then
  fail invalid-new-blocks "commit proceeded with a NEW schema error"
else
  ok invalid-new-blocks
fi

# ============ Case 3: valid artifact passes ============
R="$SANDBOX/c3"; new_repo "$R"
printf '{"product": {"status": "active"}, "decisions": [{"decision": "short and valid"}]}\n' \
  > "$R/ai_files/waves/w1/roadmap.json"
git -C "$R" add -A
if git -C "$R" commit -qm good >/dev/null 2>&1; then
  ok valid-passes
else
  fail valid-passes "valid commit was blocked"
fi

# ============ Case 4: legacy errors tolerated (delta semantics) ============
R="$SANDBOX/c4"; new_repo "$R"
# Seed HEAD with an ALREADY-invalid roadmap, bypassing the hook (simulates
# legacy content committed before the backstop existed).
printf '{"product": {}, "decisions": [{"decision": "legacy entry already over the cap from before the backstop existed"}]}\n' \
  > "$R/ai_files/waves/w1/roadmap.json"
git -C "$R" add -A && git -C "$R" commit -q --no-verify -m legacy-base
# Edit that does NOT add a new error (touches product only)
jq '.product.status = "active"' "$R/ai_files/waves/w1/roadmap.json" > "$R/t" && mv "$R/t" "$R/ai_files/waves/w1/roadmap.json"
git -C "$R" add -A
OUT=$(git -C "$R" commit -m tolerated 2>&1); RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'pre-existing schema errors'; then
  ok legacy-tolerated
elif [ "$RC" -eq 0 ]; then
  fail legacy-tolerated "commit passed but the legacy warning was not emitted"
else
  fail legacy-tolerated "commit blocked on pre-existing legacy errors"
fi

# ============ Case 5: foreign hook chained ============
R="$SANDBOX/c5"
mkdir -p "$R/ai_files/waves/w1"
git -C "$R" init -q -b main
git -C "$R" config user.email fixture@waves.test
git -C "$R" config user.name "Waves Fixture"
echo init > "$R/seed.txt"
git -C "$R" add -A && git -C "$R" commit -qm seed
# Foreign hook that rejects commits containing the word FORBIDDEN in staged
# files. NOTE: path built from $R explicitly — `git -C dir rev-parse --git-dir`
# prints a RELATIVE .git, which would resolve against the RUNNER's cwd (this
# exact mistake once wrote a fixture hook into the host repo's .git/hooks).
mkdir -p "$R/.git/hooks"
cat > "$R/.git/hooks/pre-commit" <<'EOF'
#!/bin/bash
git diff --cached | grep -q 'FORBIDDENWORD' && { echo "foreign hook: blocked" >&2; exit 1; }
exit 0
EOF
chmod +x "$R/.git/hooks/pre-commit"
bash "$INSTALL" --schemas "$SCHEMAS" --repo "$R" >/dev/null
# 5a: foreign hook still blocks what it always blocked
echo "FORBIDDENWORD" > "$R/code.txt"
git -C "$R" add -A
if git -C "$R" commit -qm foreign-blocked >/dev/null 2>&1; then
  fail foreign-hook-chained "foreign hook no longer blocks after install"
else
  # 5b: waves backstop also active in the same chained hook
  git -C "$R" reset -q
  printf '{ also broken' > "$R/ai_files/waves/w1/roadmap.json"
  git -C "$R" add ai_files
  if git -C "$R" commit -qm waves-blocked >/dev/null 2>&1; then
    fail foreign-hook-chained "waves backstop inactive in chained hook"
  else
    ok foreign-hook-chained
  fi
fi

# ============ Case 6: code-only commit is a no-op ============
R="$SANDBOX/c6"; new_repo "$R"
echo "code" > "$R/main.dart"
git -C "$R" add -A
if git -C "$R" commit -qm code-only >/dev/null 2>&1; then
  ok no-artifacts-noop
else
  fail no-artifacts-noop "code-only commit was blocked"
fi

# ============ Case 7: linked worktree (audit repro) ============
# Found by the adversarial Step-7 audit of primary 3: installing via
# `--git-dir` wrote the hook to the per-worktree dir, where git never reads
# hooks → backstop silently inert. Install from INSIDE the worktree must land
# in the common hooks dir and actually block.
R="$SANDBOX/c7"; new_repo "$R"
git -C "$R" worktree add -q "$SANDBOX/c7-wt" -b wt-branch
mkdir -p "$SANDBOX/c7-wt/ai_files/waves/w1"
bash "$INSTALL" --schemas "$SCHEMAS" --repo "$SANDBOX/c7-wt" >/dev/null
printf '{ broken in worktree' > "$SANDBOX/c7-wt/ai_files/waves/w1/roadmap.json"
git -C "$SANDBOX/c7-wt" add -A
if git -C "$SANDBOX/c7-wt" commit -qm wt-bad >/dev/null 2>&1; then
  fail worktree-install "commit from a linked worktree proceeded with malformed JSON (hook inert)"
else
  ok worktree-install
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "run-precommit-cases: $FAILURES case(s) failed" >&2
  exit 1
fi
echo "run-precommit-cases: all 7 cases passed"
