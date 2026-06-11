#!/bin/bash
# run-regression-cases.sh — known-input regression runner for the extracted rails.
#
# Runs a fixed set of representative cases (block paths AND pass paths) against
# the gate and stub-check surfaces, and prints one JSON row per case:
#   {"rail": "...", "case": "...", "exit": N, "stdout_sha": "...", "stderr_sha": "..."}
#
# Usage:
#   run-regression-cases.sh <gate-script> <stubcheck-script>
#
# The same runner is used to capture the PRE-extraction baseline (pointing at the
# original hooks) and the POST-extraction state (pointing at the wrappers); the
# A→B no-regression matrix (phase 13 primary 5) diffs the two outputs.
#
# Self-contained: builds its own sandbox project under a mktemp dir, sets the
# CLAUDE_* env the hooks expect, never touches the host project.

set -u

GATE="${1:?usage: run-regression-cases.sh <gate-script> <stubcheck-script>}"
STUB="${2:?usage: run-regression-cases.sh <gate-script> <stubcheck-script>}"

SANDBOX=$(mktemp -d /tmp/waves-regression.XXXXXX)
trap 'rm -rf "$SANDBOX"' EXIT

# --- Sandbox project WITH full artifacts (blueprint + roadmap + logbook) ---
FULL="$SANDBOX/full"
mkdir -p "$FULL/ai_files/waves/w1/logbooks"
echo '{"meta":{"product_name":"fixture"}}' > "$FULL/ai_files/blueprint.json"
echo '{"product":{"status":"active"},"phases":[]}' > "$FULL/ai_files/waves/w1/roadmap.json"
echo '{"objectives":{"main":[],"secondary":[]}}' > "$FULL/ai_files/waves/w1/logbooks/t.json"

# --- Sandbox project WITHOUT artifacts at all ---
BARE="$SANDBOX/bare"
mkdir -p "$BARE"

# --- Sandbox data dir (markers) ---
DATA="$SANDBOX/data"
mkdir -p "$DATA"

# Normalize before hashing: the sandbox path changes per run (mktemp), so any
# output embedding it would produce non-comparable hashes between the baseline
# run and the post-extraction run. SANDBOX is replaced by a literal token.
sha() { sed "s|$SANDBOX|SANDBOX|g" | shasum -a 256 2>/dev/null | cut -c1-12; }

# run_case <rail> <case-name> <script> <project-dir> <stdin-json>
run_case() {
  local rail="$1" name="$2" script="$3" project="$4" stdin_json="$5"
  local out err rc
  out=$(printf '%s' "$stdin_json" | CLAUDE_PROJECT_DIR="$project" CLAUDE_PLUGIN_DATA="$DATA" \
        CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT must be set}" \
        bash "$script" 2>"$SANDBOX/err.txt")
  rc=$?
  err=$(cat "$SANDBOX/err.txt" 2>/dev/null)
  printf '{"rail":"%s","case":"%s","exit":%d,"stdout_sha":"%s","stderr_sha":"%s"}\n' \
    "$rail" "$name" "$rc" \
    "$(printf '%s' "$out" | sha)" "$(printf '%s' "$err" | sha)"
}

# ============ GATE cases ============
SID="regression-fixture"

# G1: Edit to ai_files/ → whitelisted, {} exit 0
run_case gate edit-aifiles-whitelist "$GATE" "$FULL" \
  "{\"session_id\":\"$SID\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$FULL/ai_files/waves/w1/roadmap.json\"}}"

# G2: Edit to code with full artifacts → allowed + classification reminder, exit 0
run_case gate edit-code-reminder "$GATE" "$FULL" \
  "{\"session_id\":\"$SID\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$FULL/src/main.dart\"}}"

# G3: read-only Bash (git status) → {} exit 0
run_case gate bash-readonly "$GATE" "$FULL" \
  "{\"session_id\":\"$SID\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git status\"}}"

# G4: mutating Bash with full artifacts → allowed + reminder, exit 0
run_case gate bash-mutating-reminder "$GATE" "$FULL" \
  "{\"session_id\":\"$SID\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"npm install leftpad\"}}"

# G5: no ai_files at all → {} exit 0 (shaping phase)
run_case gate no-artifacts-allow "$GATE" "$BARE" \
  "{\"session_id\":\"$SID\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$BARE/src/main.dart\"}}"

# G6: blueprint present but NO roadmap → BLOCK exit 2
NORDMAP="$SANDBOX/nordmap"
mkdir -p "$NORDMAP/ai_files"
echo '{"meta":{}}' > "$NORDMAP/ai_files/blueprint.json"
run_case gate blueprint-no-roadmap-block "$GATE" "$NORDMAP" \
  "{\"session_id\":\"$SID\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$NORDMAP/src/main.dart\"}}"

# G7: metacognition-pending marker + code Edit → BLOCK exit 2
PEND_SID="regression-pending"
mkdir -p "$DATA/markers/$PEND_SID"
date -u +%Y-%m-%dT%H:%M:%SZ > "$DATA/markers/$PEND_SID/metacognition-pending"
run_case gate pending-blocks-code-edit "$GATE" "$FULL" \
  "{\"session_id\":\"$PEND_SID\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$FULL/src/main.dart\"}}"

# G8: metacognition-pending + read-only Bash → allowed exit 0
date -u +%Y-%m-%dT%H:%M:%SZ > "$DATA/markers/$PEND_SID/metacognition-pending"
run_case gate pending-allows-readonly-bash "$GATE" "$FULL" \
  "{\"session_id\":\"$PEND_SID\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls -la\"}}"

# ============ STUB-CHECK cases ============
# Files live inside the sandbox; type forced via WAVES_PROJECT_TYPE override.

# S1: agentic .md with a [TBD] placeholder → exit 2
printf '# Doc\n\nContent with [TBD] marker.\n' > "$SANDBOX/stub.md"
out=$(printf '{"session_id":"%s","tool_input":{"file_path":"%s"}}' "$SID" "$SANDBOX/stub.md" | \
  WAVES_PROJECT_TYPE=agentic CLAUDE_PROJECT_DIR="$FULL" CLAUDE_PLUGIN_DATA="$DATA" bash "$STUB" 2>"$SANDBOX/err.txt"); rc=$?
printf '{"rail":"stub-check","case":"agentic-md-tbd-block","exit":%d,"stdout_sha":"%s","stderr_sha":"%s"}\n' \
  "$rc" "$(printf '%s' "$out" | sha)" "$(cat "$SANDBOX/err.txt" | sha)"

# S2: agentic clean .md → exit 0
printf '# Doc\n\nReal content, no placeholders here.\n' > "$SANDBOX/clean.md"
out=$(printf '{"session_id":"%s","tool_input":{"file_path":"%s"}}' "$SID" "$SANDBOX/clean.md" | \
  WAVES_PROJECT_TYPE=agentic CLAUDE_PROJECT_DIR="$FULL" CLAUDE_PLUGIN_DATA="$DATA" bash "$STUB" 2>"$SANDBOX/err.txt"); rc=$?
printf '{"rail":"stub-check","case":"agentic-md-clean-pass","exit":%d,"stdout_sha":"%s","stderr_sha":"%s"}\n' \
  "$rc" "$(printf '%s' "$out" | sha)" "$(cat "$SANDBOX/err.txt" | sha)"

# S3: agentic .sh comment-only → exit 2
printf '#!/bin/bash\n# only comments\nexit 0\n' > "$SANDBOX/stub.sh"
out=$(printf '{"session_id":"%s","tool_input":{"file_path":"%s"}}' "$SID" "$SANDBOX/stub.sh" | \
  WAVES_PROJECT_TYPE=agentic CLAUDE_PROJECT_DIR="$FULL" CLAUDE_PLUGIN_DATA="$DATA" bash "$STUB" 2>"$SANDBOX/err.txt"); rc=$?
printf '{"rail":"stub-check","case":"agentic-sh-empty-block","exit":%d,"stdout_sha":"%s","stderr_sha":"%s"}\n' \
  "$rc" "$(printf '%s' "$out" | sha)" "$(cat "$SANDBOX/err.txt" | sha)"

# S4: agentic .json schema metadata without properties → exit 2
printf '{"title":"x","type":"object"}\n' > "$SANDBOX/stub.json"
out=$(printf '{"session_id":"%s","tool_input":{"file_path":"%s"}}' "$SID" "$SANDBOX/stub.json" | \
  WAVES_PROJECT_TYPE=agentic CLAUDE_PROJECT_DIR="$FULL" CLAUDE_PLUGIN_DATA="$DATA" bash "$STUB" 2>"$SANDBOX/err.txt"); rc=$?
printf '{"rail":"stub-check","case":"agentic-json-noprops-block","exit":%d,"stdout_sha":"%s","stderr_sha":"%s"}\n' \
  "$rc" "$(printf '%s' "$out" | sha)" "$(cat "$SANDBOX/err.txt" | sha)"

# S5: software .dart with TODO marker → exit 2
printf 'void main() {\n  // body\n  var x = 1; // TODO: fix\n}\n' > "$SANDBOX/stub.dart"
out=$(printf '{"session_id":"%s","tool_input":{"file_path":"%s"}}' "$SID" "$SANDBOX/stub.dart" | \
  WAVES_PROJECT_TYPE=backend CLAUDE_PROJECT_DIR="$FULL" CLAUDE_PLUGIN_DATA="$DATA" bash "$STUB" 2>"$SANDBOX/err.txt"); rc=$?
printf '{"rail":"stub-check","case":"software-dart-todo-block","exit":%d,"stdout_sha":"%s","stderr_sha":"%s"}\n' \
  "$rc" "$(printf '%s' "$out" | sha)" "$(cat "$SANDBOX/err.txt" | sha)"

# S6: unmatched extension → exit 0 ignored
printf 'whatever\n' > "$SANDBOX/file.xyz"
out=$(printf '{"session_id":"%s","tool_input":{"file_path":"%s"}}' "$SID" "$SANDBOX/file.xyz" | \
  WAVES_PROJECT_TYPE=agentic CLAUDE_PROJECT_DIR="$FULL" CLAUDE_PLUGIN_DATA="$DATA" bash "$STUB" 2>"$SANDBOX/err.txt"); rc=$?
printf '{"rail":"stub-check","case":"unmatched-ext-pass","exit":%d,"stdout_sha":"%s","stderr_sha":"%s"}\n' \
  "$rc" "$(printf '%s' "$out" | sha)" "$(cat "$SANDBOX/err.txt" | sha)"
