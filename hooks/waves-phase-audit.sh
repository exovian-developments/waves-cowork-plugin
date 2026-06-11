#!/bin/bash
# waves-phase-audit.sh — PostToolUse hook for Waves 3.0 (plugin-native)
# Triggers strategic audit when a roadmap phase is completed.
#
# Detects: edit to */roadmap.json where a phase status changed to "completed"/"achieved"
# Action: injects additionalContext prompting comprehensive strategic analysis
#
# Plugin-native: markers session-scoped under $CLAUDE_PLUGIN_DATA/markers/$SESSION_ID/.
# Hash uses `printf '%s' | md5` (matches the baseline seeded by waves-perceive.sh — S4).
# NOTE (P2/S9): verifier B (adversarial verification of readiness claims) is added in
# Phase 2 secondary S9; this file currently carries the plumbing migration only.
#
# Input: stdin JSON with {session_id, tool_name, tool_input, tool_response} from PostToolUse
# Output: JSON with {additionalContext} for strategic audit prompt

set -euo pipefail

# Read stdin
INPUT=$(cat)

# Extract file path
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Quick exit: not a roadmap file
if [[ "$FILE" != */roadmap.json ]]; then
  echo '{}'
  exit 0
fi

# Quick exit: file doesn't exist
if [ ! -f "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Check for jq
if ! command -v jq &> /dev/null; then
  echo '{}'
  exit 0
fi

# --- Plugin-native marker layout (session-scoped) ---
WAVES_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/waves}"
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null | tr '/ ' '__')
MARKERS="$WAVES_DATA/markers/$SESSION_ID"
export SESSION_ID
source "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/scope-resolve.sh" 2>/dev/null || true

# Count completed phases
PHASES_COMPLETED=$(jq '[.phases[] | select(.status == "completed" or .status == "achieved")] | length' "$FILE" 2>/dev/null || echo 0)

# Normalize file path to match perceive's seeded hash (absolute path, printf-based md5)
NORM_FILE=$(cd "$(dirname "$FILE")" 2>/dev/null && echo "$(pwd)/$(basename "$FILE")" || echo "$FILE")
MARKER_DIR="$MARKERS/phase-audit"
mkdir -p "$MARKER_DIR" 2>/dev/null
MARKER_FILE="$MARKER_DIR/$(printf '%s' "$NORM_FILE" | md5 2>/dev/null || printf '%s' "$NORM_FILE" | md5sum 2>/dev/null | cut -d' ' -f1)"
LAST_COUNT=$(cat "$MARKER_FILE" 2>/dev/null || echo 0)

# Update marker
echo "$PHASES_COMPLETED" > "$MARKER_FILE"

# If count increased, a phase was just completed
if [ "$PHASES_COMPLETED" -gt "$LAST_COUNT" ]; then
  # Get the wave name from path
  WAVE=$(echo "$FILE" | sed 's|.*/waves/\([^/]*\)/roadmap.json|\1|')

  # Resolve project root
  PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"


  # Write pending marker — gate blocks until delegation
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$MARKERS/metacognition-pending"

  # Read metacognition model from user_pref.json (default: opus)
  META_MODEL="opus"
  for pref in "$AI_FILES_ROOT/user_pref.json" "user_pref.json"; do
    if [ -f "$pref" ]; then
      CONFIGURED_MODEL=$(jq -r '.agent_config.metacognition_model // empty' "$pref" 2>/dev/null)
      [ -n "$CONFIGURED_MODEL" ] && META_MODEL="$CONFIGURED_MODEL"
      break
    fi
  done

  # Find blueprint
  BP=""
  for bp in "$AI_FILES_ROOT/blueprint.json" "$AI_FILES_ROOT/product_blueprint.json"; do
    [ -f "$bp" ] && BP="$bp" && break
  done

  # ALL roadmaps (not just this wave — other waves may be affected)
  ALL_ROADMAPS=""
  for rm in "$AI_FILES_SCOPED"/waves/*/roadmap.json; do
    [ -f "$rm" ] || continue
    ALL_ROADMAPS="$ALL_ROADMAPS\n- $rm"
  done
  ROADMAPS_PATHS=$(echo -e "$ALL_ROADMAPS" | grep -v '^$')

  # ALL logbooks (not just this wave)
  ALL_LOGBOOKS=""
  for lb in "$AI_FILES_SCOPED"/waves/*/logbooks/*.json; do
    [ -f "$lb" ] || continue
    ALL_LOGBOOKS="$ALL_LOGBOOKS\n- $lb"
  done
  LOGBOOKS_PATHS=$(echo -e "$ALL_LOGBOOKS" | grep -v '^$')

  MSG="METACOGNITION — Phase completed in $WAVE. BLOCKED until you delegate.\n\nThis is a TWO-STAGE adversarial flow: analyst A audits readiness, verifier B checks A's claims against the real files.\n\n1. Spawn background Agent A (run_in_background=true, model=$META_MODEL) with the ANALYST PROMPT below — COPY IT EXACTLY.\n2. When A returns, persist A's raw output to $WAVES_DATA/phase-audit/$SESSION_ID/ (timestamped .json), then spawn verifier B (run_in_background=true, model=$META_MODEL) with the VERIFIER PROMPT below, pasting A's full output into it.\n3. Present BOTH A's raw analysis AND B's classification to the user; then write to any waves_files/ (or ai_files/) artifact — this clears the gate.\n\nANALYST PROMPT (A) — copy as-is:\nYou are an expert advisor. A roadmap phase was just completed in $WAVE. The team is about to start the next phase — your job is to ensure it starts on solid ground.\n\nRead ALL these files:\n${BP:-blueprint not found}\n$ROADMAPS_PATHS\n$LOGBOOKS_PATHS\n\nNow step back and assess readiness. Share your honest observations:\n\n- Is the next phase ready to start? Does the project have everything it needs — infrastructure, accounts, APIs, design assets, legal requirements? Are there decisions from the completed phase that must be resolved first? Were logbook objectives abandoned that the next phase depends on?\n- How aligned is the progress with the blueprint? Which capabilities advanced? Are any falling behind or diverging from the original design? Is the product hypothesis still supported by the direction of implementation?\n- Are there opportunities? Can upcoming phases be reordered to enable parallel work? Did this phase produce something reusable — a pattern, tool, or approach that saves effort later? Is there a faster path to validating the hypothesis?\n- SERENDIPITY: did this phase reveal something unexpected? A capability that's more valuable than planned, a simplification nobody anticipated, a market insight that emerged from implementation? Does what was built in this phase directly solve an operational problem in another area or business vertical that the team hasn't considered — not speculatively, but with concrete and relevant impact?\n\nBe specific — reference capability IDs, phase numbers, objective IDs. Share observations conversationally. If you genuinely see nothing noteworthy, just say so briefly. Under 400 words.\n\n---\n\nVERIFIER PROMPT (B) — copy as-is, pasting A's full returned text where marked:\nYou are an independent, skeptical verifier with MINIMAL context by design. Another analyst (A) produced the readiness audit below. Your job is to verify and classify each claim — NOT to expand it, NOT to filter it out.\n\nA's analysis:\n<<< PASTE A's FULL OUTPUT HERE >>>\n\nApply TWO lenses to every claim:\n1) TECHNICAL — use grep/Read against the real files (roadmap, logbooks, code) to confirm or refute each readiness gap or alignment claim. Does the dependency/prerequisite/abandoned-objective A names actually exist in the files? Words like 'planned', 'should', 'likely' are red flags — check them. Cite file:line.\n2) VALUE — is this a real readiness concern or process overengineering? Apply KISS/YAGNI. A heavyweight gate that does not land is smoke.\n\nClassify EACH claim as exactly one: confirmed (verified against files) / smoke (refuted, OR overengineering that doesn't land) / unverifiable (you lack context — say so honestly) / gold (confirmed AND high independent value). Do NOT drop any item. Output a compact list: claim → class → one-line reason citing the file:line you checked. Under 300 words.\n\n---\n\nDECISION DISCIPLINE: present BOTH A's raw analysis and B's classification to the user. Decide with full context — smoke → discard or re-evaluate; unverifiable → your own judgment; confirmed/gold → safe to surface/act. NEVER let an unverified claim drive a change to roadmap, blueprint, or logbook."

  jq -n --arg ctx "$MSG" '{"additionalContext": $ctx}'
  exit 0
fi

echo '{}'
exit 0
