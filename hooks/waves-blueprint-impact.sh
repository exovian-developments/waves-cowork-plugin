#!/bin/bash
# waves-blueprint-impact.sh — PostToolUse hook for Waves 3.0 (plugin-native)
# Triggers impact projection when the product blueprint is modified.
#
# This is the MOST IMPORTANT metacognition trigger.
# When the blueprint changes, everything downstream is potentially affected.
#
# Detects: edit to waves_files/ (or ai_files/) blueprint.json / product_blueprint.json
# Action: injects additionalContext prompting the agent to project cascading impacts
#
# Plugin-native: pending marker session-scoped under $CLAUDE_PLUGIN_DATA/markers/$SESSION_ID/.
# NOTE (P2/S8): verifier B (adversarial verification of projected impacts) is added in
# Phase 2 secondary S8; this file currently carries the plumbing migration only.
# This is the exact process that failed with the ECC false projection — the verifier
# B is what would have caught it.
#
# Input: stdin JSON with {session_id, tool_name, tool_input, tool_response} from PostToolUse
# Output: JSON with {additionalContext} for impact projection prompt

set -euo pipefail

# Read stdin
INPUT=$(cat)

# Extract file path
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Quick exit: not a blueprint file
case "$FILE" in
  */blueprint.json|*/product_blueprint.json)
    # Proceed — this is a blueprint
    ;;
  *)
    echo '{}'
    exit 0
    ;;
esac

# Resolve project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"


# --- Plugin-native marker layout (session-scoped) ---
WAVES_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/waves}"
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null | tr '/ ' '__')
export SESSION_ID
source "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/scope-resolve.sh" 2>/dev/null || true
MARKERS="$WAVES_DATA/markers/$SESSION_ID"
mkdir -p "$MARKERS" 2>/dev/null

# --- Cooldown suppression (field report 2026-06-10, friction #3) ---
# Applying the fixes that the CURRENT metacognition round produced re-edits the
# blueprint and re-armed the pending marker in a loop. Honor the shared
# metacognition-cooldown (touched when the gate clears) with a 5-minute grace
# window: blueprint writes inside it are treated as applying the round's own
# findings, not as a new change to project.
COOLDOWN_FILE="$MARKERS/metacognition-cooldown"
if [ -f "$COOLDOWN_FILE" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    COOLDOWN_AGE=$(( $(date +%s) - $(stat -f %m "$COOLDOWN_FILE") ))
  else
    COOLDOWN_AGE=$(( $(date +%s) - $(stat -c %Y "$COOLDOWN_FILE") ))
  fi
  if [ "$COOLDOWN_AGE" -lt 300 ]; then
    echo '{}'
    exit 0
  fi
fi

# Build context about what roadmaps and logbooks exist
ROADMAP_LIST=""
LOGBOOK_LIST=""

for roadmap in "$AI_FILES_SCOPED"/waves/*/roadmap.json; do
  [ -f "$roadmap" ] || continue
  WAVE=$(echo "$roadmap" | sed 's|.*/waves/\([^/]*\)/roadmap.json|\1|')
  ROADMAP_LIST="$ROADMAP_LIST\n- $WAVE: $roadmap"
done

for logbook in "$AI_FILES_SCOPED"/waves/*/logbooks/*.json; do
  [ -f "$logbook" ] || continue
  LOGBOOK_LIST="$LOGBOOK_LIST\n- $logbook"
done

# Read metacognition model from user_pref.json (default: opus)
META_MODEL="opus"
for pref in "$AI_FILES_ROOT/user_pref.json" "user_pref.json"; do
  if [ -f "$pref" ]; then
    CONFIGURED_MODEL=$(jq -r '.agent_config.metacognition_model // empty' "$pref" 2>/dev/null)
    [ -n "$CONFIGURED_MODEL" ] && META_MODEL="$CONFIGURED_MODEL"
    break
  fi
done

# Write pending marker — gate blocks until delegation
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$MARKERS/metacognition-pending"

# Build clean path lists for the subagent (one per line with - prefix)
ROADMAPS_PATHS=$(echo -e "$ROADMAP_LIST" | grep -v '^$')
LOGBOOKS_PATHS=$(echo -e "$LOGBOOK_LIST" | grep -v '^$')

MSG="METACOGNITION — Blueprint changed. BLOCKED until you delegate.\n\nThis is a TWO-STAGE adversarial flow: analyst A projects impacts, verifier B checks each one against the real files (this is the exact process that produced the ECC false projection — B is the barrier that catches it).\n\n1. Spawn background Agent A (run_in_background=true, model=$META_MODEL) with the ANALYST PROMPT below — COPY IT EXACTLY.\n2. When A returns, persist A's raw output to $WAVES_DATA/blueprint-impact/$SESSION_ID/ (timestamped .json), then spawn verifier B (run_in_background=true, model=$META_MODEL) with the VERIFIER PROMPT below, pasting A's full output into it.\n3. Present BOTH A's raw analysis AND B's classification to the user; then write to any waves_files/ (or ai_files/) artifact — this clears the gate.\n\nANALYST PROMPT (A) — copy as-is:\nYou are an expert advisor. The product BLUEPRINT was just modified — this is the most important artifact in the project. Everything downstream derives from it.\n\nRead ALL these files:\n$FILE\n$ROADMAPS_PATHS\n$LOGBOOKS_PATHS\n\nNow step back and assess the cascading impact. Share your honest observations:\n\n- Has any work already done or planned become invalid because of this change? Roadmap phases targeting changed capabilities, logbook objectives that no longer match, decisions that are now contradicted?\n- Does this change create gaps? New capabilities without a plan to build them, new flows without logbook objectives, new dependencies that the phase ordering doesn't reflect?\n- Does this change open opportunities? Can phases be simplified or eliminated? Is planned work now unnecessary? Is there a faster path to what the product promises?\n- SERENDIPITY: does this change reveal something unexpected about the product direction? A pivot opportunity, a market insight, a simplification that nobody saw coming? Does this change make the product directly applicable to an operational problem in another area or business vertical — not speculatively, but with concrete and relevant impact?\n\nBe specific — reference capability IDs, phase numbers, objective IDs. Share observations conversationally. If you genuinely see no impact, just say so briefly. Under 400 words.\n\n---\n\nVERIFIER PROMPT (B) — copy as-is, pasting A's full returned text where marked:\nYou are an independent, skeptical verifier with MINIMAL context by design. Another analyst (A) projected the blueprint-change impacts below. Your job is to verify and classify each projected impact — NOT to expand it, NOT to filter it out.\n\nA's analysis:\n<<< PASTE A's FULL OUTPUT HERE >>>\n\nApply TWO lenses to every projected impact:\n1) TECHNICAL — use grep/Read against the real files (roadmaps, logbooks, code) to confirm or refute each claim. Does the phase/objective/dependency A names actually exist and actually depend on the changed capability? Words like 'planned', 'should', 'likely' are red flags — check them. Cite file:line.\n2) VALUE — is this a real cascading impact or speculative overengineering? Apply KISS/YAGNI. A big proposed phase that does not land is smoke.\n\nClassify EACH impact as exactly one: confirmed (verified against files) / smoke (refuted, OR speculation that doesn't land) / unverifiable (you lack context — say so honestly) / gold (confirmed AND high independent value). Do NOT drop any item. Output a compact list: impact → class → one-line reason citing the file:line you checked. Under 300 words.\n\n---\n\nDECISION DISCIPLINE: present BOTH A's raw analysis and B's classification to the user. Decide with full context — smoke → discard or re-evaluate; unverifiable → your own judgment; confirmed/gold → safe to surface/act. NEVER let an unverified impact drive a change to roadmap, blueprint, or logbook."

jq -n --arg ctx "$MSG" '{"additionalContext": $ctx}'
