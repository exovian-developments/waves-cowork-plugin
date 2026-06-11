#!/bin/bash
# waves-foundational-audit.sh — PostToolUse hook for Waves 3.0 (plugin-native)
# Adversarial coverage for the FOUNDATIONAL write paths (w6 Phase 9).
#
# Closes the coverage inversion (blueprint product_decision #25, capability
# important #7): the highest-blast-radius artifacts — blueprint and roadmap —
# carried ZERO write-time adversarial verification while logbooks/code carry
# 2-4 A->B layers. This extends design_principle #7 ("every analyst A is
# followed by an independent verifier B") to the foundational write paths it was
# never retrofitted onto.
#
# DISTINCT AXIS from waves-blueprint-impact.sh — NOT a fusion (roadmap decision
# #20 / product_decision #25). blueprint-impact owns the CASCADE axis (downstream
# impact projection when the blueprint changes). THIS hook owns the INTERNAL
# COHERENCE axis (is the artifact self-consistent and born-compliant AT WRITE
# time). Both may fire on a blueprint edit — they ask different questions.
# Specialization beats fusion (dp). foundation + resolution are the sibling
# write paths, audited IN-COMMAND (Phase 9 Primary 2), not here — they have no
# stable PostToolUse trigger. manifest is EXCLUDED by design (a derived low-trust
# map; its discipline is freshness — w6 Phase 10 — not write-time consistency).
#
# Multi-project by construction: the case-match keys on the WRITE PATH (any path
# ending in blueprint.json / product_blueprint.json / roadmap.json), NOT a
# literal repo-root path — so a blueprint at projects/<name>/waves_files/ is audited
# identically (capability #9, blueprint tree).
#
# Reuses the metacognition A->B scaffolding verbatim (DRY, project_rule #3):
# two-stage flow, META_MODEL resolution, the metacognition-pending gate marker,
# the metacognition-cooldown suppression, scope-resolve. The ONLY net-new content
# is the internal-coherence CHECK LIST, branched by artifact type.
#
# Input: stdin JSON {session_id, tool_name, tool_input, tool_response} (PostToolUse)
# Output: JSON {additionalContext} for the A->B coherence audit, '{}' otherwise.

set -euo pipefail

# Read stdin
INPUT=$(cat)

# Extract file path
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# --- Branch by filename: only foundational artifacts on a governed write path ---
case "$FILE" in
  */blueprint.json|*/product_blueprint.json)
    ARTIFACT="blueprint"
    ;;
  */roadmap.json)
    ARTIFACT="roadmap"
    ;;
  *)
    echo '{}'
    exit 0
    ;;
esac

# Quick exit: file gone or jq unavailable
if [ ! -f "$FILE" ]; then echo '{}'; exit 0; fi
if ! command -v jq &> /dev/null; then echo '{}'; exit 0; fi

# --- Plugin-native marker layout (session-scoped) ---
WAVES_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/waves}"
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null | tr '/ ' '__')
export SESSION_ID
source "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/scope-resolve.sh" 2>/dev/null || true
MARKERS="$WAVES_DATA/markers/$SESSION_ID"
mkdir -p "$MARKERS" 2>/dev/null

# --- Cooldown suppression (DRY: shares the metacognition-cooldown marker) ---
# After any A->B delegation clears the gate, waves-gate.sh touches this marker.
# Honor it so the foundational audit does not storm on the mechanical roadmap
# decision-append that objectives-implement performs right after a logbook write.
COOLDOWN_FILE="$MARKERS/metacognition-cooldown"
if [ -f "$COOLDOWN_FILE" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    COOLDOWN_AGE=$(( $(date +%s) - $(stat -f %m "$COOLDOWN_FILE") ))
  else
    COOLDOWN_AGE=$(( $(date +%s) - $(stat -c %Y "$COOLDOWN_FILE") ))
  fi
  if [ "$COOLDOWN_AGE" -lt 60 ]; then
    echo '{}'
    exit 0
  fi
fi

# --- Resolve the coherence-audit reading set (branch by artifact) ---
# blueprint  -> audit the blueprint itself + project_rules.json (orphan checks)
# roadmap    -> audit the roadmap itself + the blueprint (phase<->capability)
BP=""
for bp in "$AI_FILES_SCOPED/blueprint.json" "$AI_FILES_SCOPED/product_blueprint.json" \
          "$AI_FILES_ROOT/blueprint.json" "$AI_FILES_ROOT/product_blueprint.json"; do
  [ -f "$bp" ] && BP="$bp" && break
done
RULES=""
for r in "$AI_FILES_SCOPED/project_rules.json" "$AI_FILES_ROOT/project_rules.json"; do
  [ -f "$r" ] && RULES="$r" && break
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

# --- Build the artifact-specific CHECK LIST (the only net-new content) ---
if [ "$ARTIFACT" = "blueprint" ]; then
  READ_SET="$FILE${RULES:+$'\n'$RULES}"
  CHECKS="- ORPHAN principle<->rule: does every product_rule trace to a design_principle (and is no design_principle left with zero rules/capabilities exercising it)? Cross-check against ${RULES:-the project rules}.\n- CAPABILITY<->FLOW coverage: does every essential_capability have at least one essential_flow_or_view that exercises it, and does every flow map back to a capability? Flag capabilities with no flow and flows with no capability.\n- CONTRADICTORY product_decisions: are any two product_decisions mutually exclusive or does a later decision silently reverse an earlier one without superseding it?\n- INTERNAL traceability: do recent_context / history entries reference capability, decision and principle IDs that actually exist?\n- BORN-COMPLIANCE / fill-quality (product_rule #12): are the \$comment / description fields on NEW or EDITED prose substantive (the WHY, the STOP/REDIRECT, a bad->good), not placeholder or empty? Flag thin or boilerplate \$comment."
else
  READ_SET="$FILE${BP:+$'\n'$BP}"
  CHECKS="- PHASE<->CAPABILITY traceability (the Golden Rule): does every phase trace to a blueprint capability in ${BP:-the blueprint}? Flag any phase that builds something with no capability backing it (scope creep) and any essential capability with no phase delivering it (gap).\n- DEPENDENCY CYCLES: do the phases' depends_on form a DAG? Flag any cycle or a phase depending on a later-numbered phase that also depends back.\n- CONTRADICTORY decisions: do any two roadmap decisions conflict, or does a decision contradict a blueprint product_decision?\n- MILESTONE coherence: are milestones inside each phase consistent with the phase description (no milestone that belongs to a different phase)?\n- BORN-COMPLIANCE / fill-quality (product_rule #12): are NEW or EDITED decision/description prose substantive (the WHY and context), not placeholder? Flag the mechanical [AUTO] notes only if they are the ONLY content of a phase that claims completion."
fi

# Write pending marker — reuse the gate's marker so enforcement is real (the
# gate blocks Edit/Write/Bash on code until the agent delegates the A->B and
# then writes to a waves_files/ (or ai_files/) artifact, which clears it).
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$MARKERS/metacognition-pending"

MSG="FOUNDATIONAL AUDIT — The $ARTIFACT (a high-blast-radius foundational artifact) was just written. BLOCKED until you delegate.\n\nThis closes the coverage inversion (product_decision #25): foundational artifacts get the SAME write-time A->B that logbooks/code already get (design_principle #7). This is the INTERNAL-COHERENCE axis — distinct from waves-blueprint-impact.sh, which projects downstream CASCADE. Do both when both fire.\n\nThis is a TWO-STAGE adversarial flow: analyst A audits coherence, verifier B checks A. The artifact was authored by you (the main agent); the adversarial review is DELEGATED to subagents to remove author bias.\n\n1. Spawn background Agent A (run_in_background=true, model=$META_MODEL) with the ANALYST PROMPT below — COPY IT EXACTLY.\n2. When A returns, persist A's raw output to $WAVES_DATA/foundational-audit/$SESSION_ID/ (timestamped .json), then spawn verifier B (run_in_background=true, model=$META_MODEL) with the VERIFIER PROMPT below, pasting A's full output into it.\n3. Present BOTH A's raw findings AND B's classification to the user; then write to any waves_files/ (or ai_files/) artifact — this clears the gate.\n\nANALYST PROMPT (A) — copy as-is:\nYou are a coherence auditor for a Waves $ARTIFACT, with MINIMAL context by design. The $ARTIFACT was just written/edited and you must verify it is INTERNALLY CONSISTENT and born-compliant — NOT confirm the author's choices.\n\nRead these files:\n$READ_SET\n\nRun this checklist, citing the exact field/id/line for every finding:\n$CHECKS\n\nFlag a problem ONLY when you can cite the exact location (capability id, decision id, phase id, rule id, field path). Do not flag style not encoded in the schema. If the artifact is clean, say so briefly. Under 350 words.\n\n---\n\nVERIFIER PROMPT (B) — copy as-is, pasting A's full returned text where marked:\nYou are an independent, skeptical verifier with MINIMAL context by design. Auditor A produced the coherence findings below. Your job is to verify and classify each finding — NOT to expand it, NOT to filter it out.\n\nA's findings:\n<<< PASTE A's FULL OUTPUT HERE >>>\n\nApply TWO lenses to every finding:\n1) TECHNICAL — use grep/Read against the real $ARTIFACT (and the blueprint/rules it references) to confirm or refute each claim. Does the orphan/cycle/contradiction/gap A names actually exist? Cite file:line.\n2) VALUE — is this a real coherence defect or pedantry? Apply KISS/YAGNI. A 'missing flow' for a capability that is intentionally infrastructural is not a defect.\n\nClassify EACH finding as exactly one: confirmed (verified against files) / smoke (refuted, OR pedantic) / unverifiable (you lack context — say so) / gold (confirmed AND high-impact, e.g. a contradiction that would mislead every downstream artifact). Do NOT drop any finding. Output a compact list: finding -> class -> one-line reason citing the file:line you checked. Under 300 words.\n\n---\n\nDECISION DISCIPLINE: present BOTH A's raw findings and B's classification to the user. Decide with full context — smoke -> discard; unverifiable -> your judgment; confirmed/gold -> fix the $ARTIFACT before building on it. NEVER let an unverified finding drive a change to the blueprint, roadmap, or any logbook."

jq -n --arg ctx "$MSG" '{"additionalContext": $ctx}'
exit 0
