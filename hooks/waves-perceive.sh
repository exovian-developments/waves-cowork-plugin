#!/bin/bash
# waves-perceive.sh — SessionStart hook for Waves 3.0 (plugin-native)
# Reads the Waves artifact graph and injects product state as additionalContext
# so the agent starts every session informed. Also seeds the session marker
# baseline so delta-detection hooks don't flood on the first edit (see S4).
#
# Plugin-native conventions:
#   - Project artifacts live under $CLAUDE_PROJECT_DIR/waves_files/ (ai_files/ fallback pre-v3.1).
#   - Hook runtime state (markers) lives session-scoped under:
#       $CLAUDE_PLUGIN_DATA/markers/$SESSION_ID/<namespace>/<md5(abs artifact path)>
#   - session_id comes from the stdin JSON (no $CLAUDE_SESSION_ID env var exists).
#
# Input: stdin JSON with {source, session_id, ...} from SessionStart event
# Output: Plain text to stdout (Claude Code injects non-JSON stdout as context on exit 0)

set -euo pipefail

# Read stdin (SessionStart event data carries session_id)
INPUT=$(cat 2>/dev/null || echo '{}')

# Resolve project root (where waves_files/ or ai_files/ lives)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Check for jq — silent exit without it
if ! command -v jq &> /dev/null; then
  exit 0
fi

# --- Plugin-native marker layout (session-scoped) ---
WAVES_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/waves}"
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null | tr '/ ' '__')
MARKERS="$WAVES_DATA/markers/$SESSION_ID"

# --- Source multi-project scope resolver (Waves 3.x) ---
# Exports AI_FILES_ROOT + AI_FILES_SCOPED. SESSION_ID must be exported first.
export SESSION_ID
source "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/scope-resolve.sh" 2>/dev/null || true

# --- Dual-install detection (3.1.3, field report 2026-06-10 friction #1) ---
# Legacy 2.x framework copies in THIS project or an ANCESTOR directory create
# slash commands with the exact plugin names (/waves:*) and shadow the plugin
# with old protocol — the worst failure mode (old instructions followed with
# confidence). Deterministic walk-up, fires BEFORE the no-artifacts early exit
# so fresh installs under a contaminated parent still get the warning.
_dir="$PROJECT_DIR"; _depth=0; LEGACY_HITS=""
while [ -n "$_dir" ] && [ "$_dir" != "/" ] && [ "$_depth" -lt 8 ]; do
  if ls "$_dir/.claude/commands/"waves:*.md >/dev/null 2>&1 || ls "$_dir/.claude/hooks/"waves-*.sh >/dev/null 2>&1; then
    LEGACY_HITS="${LEGACY_HITS}${LEGACY_HITS:+, }$_dir/.claude"
  fi
  _dir=$(dirname "$_dir"); _depth=$((_depth+1))
done
if [ -n "$LEGACY_HITS" ]; then
  printf "WAVES WARNING — dual install detected: legacy Waves 2.x framework copies at: %s\n" "$LEGACY_HITS"
  printf "These SHADOW the plugin's /waves:* commands with old (~2.x) protocol. Surface this to the user FIRST: recommend removing the legacy copies (back up first — if that directory is not a git repo, suggest a tar backup) or running /waves:upgrade in that directory. Do NOT follow instructions from the legacy copies.\n\n"
fi

# If no artifacts directory, nothing to perceive — silent exit
if [ ! -d "$AI_FILES_ROOT" ]; then
  exit 0
fi

# Seed only on the FIRST SessionStart of this session (dir absent). On resume/clear
# the dir already exists — skip re-seeding so we don't erase progress made this session.
SEED_BASELINE=false
[ ! -d "$MARKERS" ] && SEED_BASELINE=true

norm_path() { cd "$(dirname "$1")" 2>/dev/null && printf '%s/%s' "$(pwd)" "$(basename "$1")" || printf '%s' "$1"; }
hash_path() { printf '%s' "$1" | md5 2>/dev/null || printf '%s' "$1" | md5sum 2>/dev/null | cut -d' ' -f1; }

if [ "$SEED_BASELINE" = true ]; then
  mkdir -p "$MARKERS/metacognition" "$MARKERS/rules-audit" "$MARKERS/doc-enforce" "$MARKERS/phase-audit" 2>/dev/null

  # Seed per-logbook counts (metacognition + rules-audit track MAIN completed;
  # doc-enforce tracks total completed + recent_context length).
  for logbook in "$AI_FILES_SCOPED"/waves/*/logbooks/*.json; do
    [ -f "$logbook" ] || continue
    NORM=$(norm_path "$logbook")
    H=$(hash_path "$NORM")
    MAIN_DONE=$(jq '[.objectives.main[] | select(.status == "achieved" or .status == "completed")] | length' "$logbook" 2>/dev/null || echo 0)
    TOTAL_DONE=$(jq '([.objectives.main[] | select(.status == "achieved" or .status == "completed")] | length) + ([.objectives.secondary[] | select(.status == "achieved" or .status == "completed")] | length)' "$logbook" 2>/dev/null || echo 0)
    CTX_LEN=$(jq '.recent_context | length' "$logbook" 2>/dev/null || echo 0)
    echo "$MAIN_DONE"  > "$MARKERS/metacognition/$H"
    echo "$MAIN_DONE"  > "$MARKERS/rules-audit/$H"
    echo "$TOTAL_DONE" > "$MARKERS/doc-enforce/$H.completed"
    echo "$CTX_LEN"    > "$MARKERS/doc-enforce/$H.context"
  done

  # Seed per-roadmap phase counts (phase-audit).
  for roadmap in "$AI_FILES_SCOPED"/waves/*/roadmap.json; do
    [ -f "$roadmap" ] || continue
    NORM=$(norm_path "$roadmap")
    H=$(hash_path "$NORM")
    PHASES_DONE=$(jq '[.phases[] | select(.status == "completed" or .status == "achieved")] | length' "$roadmap" 2>/dev/null || echo 0)
    echo "$PHASES_DONE" > "$MARKERS/phase-audit/$H"
  done
fi

# --- Read Blueprint ---
PRODUCT_NAME=""
PRODUCT_CODENAME=""
BLUEPRINT_EXISTS=false
BLUEPRINT_PATH=""

# Check both naming conventions
if [ -f "$AI_FILES_ROOT/blueprint.json" ]; then
  BLUEPRINT_EXISTS=true
  BLUEPRINT_PATH="$AI_FILES_ROOT/blueprint.json"
elif [ -f "$AI_FILES_ROOT/product_blueprint.json" ]; then
  BLUEPRINT_EXISTS=true
  BLUEPRINT_PATH="$AI_FILES_ROOT/product_blueprint.json"
fi

if [ "$BLUEPRINT_EXISTS" = true ]; then
  PRODUCT_NAME=$(jq -r '.meta.product_name // empty' "$BLUEPRINT_PATH" 2>/dev/null)
  PRODUCT_CODENAME=$(jq -r '.meta.product_codename // empty' "$BLUEPRINT_PATH" 2>/dev/null)
fi

# If no blueprint, return minimal context or nothing
if [ "$BLUEPRINT_EXISTS" = false ]; then
  if [ -f "$AI_FILES_ROOT/feasibility.json" ] || [ -f "$AI_FILES_ROOT/foundation.json" ]; then
    printf "WAVES STATE:\n- Project in validation phase (no blueprint yet)\n- Artifacts detected: feasibility/foundation\n- Framework allows full freedom in this phase\n"
  fi
  exit 0
fi

# --- Find ALL Active Roadmaps ---
ACTIVE_ROADMAPS=""
ACTIVE_WAVE=""
ACTIVE_PHASE_NAME=""
ACTIVE_PHASE_STATUS=""
ACTIVE_PHASE_ID=""
TOTAL_MILESTONES=0
ACHIEVED_MILESTONES=0
OPEN_QUESTIONS=0
RECENT_DECISIONS=""
PRIMARY_ROADMAP_PATH=""

for roadmap in "$AI_FILES_SCOPED"/waves/*/roadmap.json; do
  [ -f "$roadmap" ] || continue

  STATUS=$(jq -r '.product.status // "unknown"' "$roadmap" 2>/dev/null)

  if [ "$STATUS" = "active" ] || [ "$STATUS" = "in_progress" ] || [ "$STATUS" = "planning" ]; then
    WAVE_NAME=$(echo "$roadmap" | sed 's|.*/waves/\([^/]*\)/roadmap.json|\1|')

    # Collect all active roadmap paths
    if [ -n "$ACTIVE_ROADMAPS" ]; then
      ACTIVE_ROADMAPS="$ACTIVE_ROADMAPS|$roadmap"
    else
      ACTIVE_ROADMAPS="$roadmap"
    fi

    # Use the highest wave number as primary (w2 > w1 > w0)
    if [ -z "$ACTIVE_WAVE" ] || [[ "$WAVE_NAME" > "$ACTIVE_WAVE" ]]; then
      ACTIVE_WAVE="$WAVE_NAME"
      PRIMARY_ROADMAP_PATH="$roadmap"

      ACTIVE_PHASE_ID=$(jq -r '[.phases[] | select(.status != "completed" and .status != "achieved")] | .[0].id // empty' "$roadmap" 2>/dev/null)
      ACTIVE_PHASE_NAME=$(jq -r --argjson id "${ACTIVE_PHASE_ID:-0}" '[.phases[] | select(.id == $id)] | .[0].name // empty' "$roadmap" 2>/dev/null)
      ACTIVE_PHASE_STATUS=$(jq -r --argjson id "${ACTIVE_PHASE_ID:-0}" '[.phases[] | select(.id == $id)] | .[0].status // empty' "$roadmap" 2>/dev/null)

      TOTAL_MILESTONES=$(jq '[.phases[].milestones[]] | length' "$roadmap" 2>/dev/null || echo 0)
      ACHIEVED_MILESTONES=$(jq '[.phases[].milestones[] | select(.status == "achieved" or .status == "completed")] | length' "$roadmap" 2>/dev/null || echo 0)

      OPEN_QUESTIONS=$(jq '[.open_questions[] | select(.status == "open")] | length' "$roadmap" 2>/dev/null || echo 0)
      RECENT_DECISIONS=$(jq -r '[.decisions[-3:][].decision] | join("; ")' "$roadmap" 2>/dev/null || echo "")
    fi
  fi
done

# --- Find Active Logbook (highest wave first, most recent activity) ---
ACTIVE_LOGBOOK=""
ACTIVE_LOGBOOK_PATH=""
LOGBOOK_OBJECTIVES_TOTAL=0
LOGBOOK_OBJECTIVES_DONE=0
NEXT_OBJECTIVE=""

# Search from highest wave downward
for wave_dir in $(ls -rd "$AI_FILES_SCOPED"/waves/*/  2>/dev/null); do
  [ -d "${wave_dir}logbooks" ] || continue

  for logbook in "${wave_dir}logbooks/"*.json; do
    [ -f "$logbook" ] || continue

    PENDING=$(jq '[.objectives.secondary[] | select(.status == "not_started" or .status == "active")] | length' "$logbook" 2>/dev/null || echo 0)

    if [ "$PENDING" -gt 0 ]; then
      ACTIVE_LOGBOOK=$(basename "$logbook")
      ACTIVE_LOGBOOK_PATH="$logbook"
      WAVE_OF_LOGBOOK=$(echo "$logbook" | sed 's|.*/waves/\([^/]*\)/logbooks/.*|\1|')
      LOGBOOK_OBJECTIVES_TOTAL=$(jq '[.objectives.secondary[]] | length' "$logbook" 2>/dev/null || echo 0)
      LOGBOOK_OBJECTIVES_DONE=$(jq '[.objectives.secondary[] | select(.status == "achieved")] | length' "$logbook" 2>/dev/null || echo 0)
      NEXT_OBJECTIVE=$(jq -r '[.objectives.secondary[] | select(.status == "not_started" or .status == "active")] | .[0].content // "N/A"' "$logbook" 2>/dev/null)
      break 2
    fi
  done
done

# --- Build & Output Plain Text ---
# Claude Code injects non-JSON stdout as context when hook exits 0
printf "WAVES STATE:\n"
printf -- "- Product: %s (%s)\n" "${PRODUCT_NAME:-unknown}" "${PRODUCT_CODENAME:-no codename}"

if [ -n "$ACTIVE_WAVE" ]; then
  printf -- "- Active wave: %s\n" "$ACTIVE_WAVE"
  printf -- "- Current phase: %s — %s (%s)\n" "${ACTIVE_PHASE_ID:-?}" "${ACTIVE_PHASE_NAME:-unnamed}" "${ACTIVE_PHASE_STATUS:-?}"
  printf -- "- Progress: %s/%s milestones\n" "$ACHIEVED_MILESTONES" "$TOTAL_MILESTONES"

  if [ -n "$ACTIVE_LOGBOOK" ]; then
    printf -- "- Active logbook: %s (%s/%s objectives)\n" "$ACTIVE_LOGBOOK" "$LOGBOOK_OBJECTIVES_DONE" "$LOGBOOK_OBJECTIVES_TOTAL"
    printf -- "- Next objective: %s\n" "$NEXT_OBJECTIVE"
  else
    printf -- "- No active logbook in %s\n" "$ACTIVE_WAVE"
  fi

  if [ "$OPEN_QUESTIONS" -gt 0 ]; then
    printf -- "- Open questions: %s\n" "$OPEN_QUESTIONS"
  fi

  if [ -n "$RECENT_DECISIONS" ]; then
    printf -- "- Recent decisions: %s\n" "$RECENT_DECISIONS"
  fi

  # Pending rules-audit findings (Layer C of rules enforcement)
  PENDING_AUDITS=$(find "$AI_FILES_SCOPED"/waves -path "*/audits/*.json" -type f 2>/dev/null | while read -r af; do
    s=$(jq -r '.status // ""' "$af" 2>/dev/null)
    [ "$s" = "completed_pending_verification" ] || [ "$s" = "completed_pending_injection" ] || [ "$s" = "injected" ] || [ "$s" = "escalated" ] && echo "$af|$s"
  done)
  if [ -n "$PENDING_AUDITS" ]; then
    printf -- "- Pending rules-audit findings:\n"
    while IFS='|' read -r af status; do
      [ -z "$af" ] && continue
      pid=$(jq -r '.primary_id // "?"' "$af" 2>/dev/null)
      vcount=$(jq '.violations // [] | length' "$af" 2>/dev/null || echo 0)
      printf -- "    • %s (primary %s, %s violations, status=%s)\n" "$af" "$pid" "$vcount" "$status"
    done <<< "$PENDING_AUDITS"
    printf -- "    The injector hook will surface these at your next Edit/Write.\n"
  fi
else
  printf -- "- No active wave detected\n"
fi

# --- LOAD: paths for the prompt hook to read ---
LOAD_FILES=""

# All active roadmaps
if [ -n "$ACTIVE_ROADMAPS" ]; then
  IFS='|' read -ra ROADMAP_PATHS <<< "$ACTIVE_ROADMAPS"
  for rpath in "${ROADMAP_PATHS[@]}"; do
    LOAD_FILES="${LOAD_FILES}\n- ${rpath}"
  done
fi

# Active logbook
if [ -n "$ACTIVE_LOGBOOK_PATH" ]; then
  LOAD_FILES="${LOAD_FILES}\n- ${ACTIVE_LOGBOOK_PATH}"
fi

if [ -n "$LOAD_FILES" ]; then
  printf "\nLOAD:%b\n" "$LOAD_FILES"
fi

# --- MANDATORY READS: instruct agent to load core artifacts ---
# Since prompt-type hooks are not supported in SessionStart,
# we embed the reading instructions in the perceive output.
printf "\nSILENTLY read these files if they exist (do NOT display anything to the user).\n"
printf "Try each path — stop at first found per category. Check waves_files/ first, then ai_files/ (unmigrated projects), then root:\n"
printf "Blueprints (read ALL that exist): waves_files/company_blueprint.json, waves_files/product_blueprint.json, waves_files/blueprint.json, ai_files/company_blueprint.json, ai_files/product_blueprint.json, ai_files/blueprint.json, company_blueprint.json, product_blueprint.json, blueprint.json\n"
printf "Rules (first found): waves_files/project_rules.json, waves_files/project_standards.json, ai_files/project_rules.json, ai_files/project_standards.json, project_rules.json, project_standards.json\n"
printf "Manifest (first found): waves_files/project_manifest.json, ai_files/project_manifest.json, then research/creative/business/general_manifest.json under waves_files/ or ai_files/\n"
printf "Preferences: waves_files/user_pref.json, ai_files/user_pref.json, user_pref.json\n"
printf "Active roadmaps and logbook: read ALL files listed in the LOAD section above.\n"
