#!/bin/bash
# waves-rules-audit-injector.sh — PostToolUse hook (Layer C, injection phase), plugin-native
#
# Runs after every Edit/Write. Two responsibilities:
#
# 1. INJECT: scan waves_files/waves/*/audits/*.json (ai_files/ fallback) for status=completed_pending_injection
#    and surface the violations to the main agent via additionalContext. Mark them
#    as 'injected' so they don't re-fire.
#
# 2. RE-AUDIT TRIGGER: if the agent just edited a file that's in scope_files of a
#    previously-injected audit (which means: agent is presumably correcting it),
#    dispatch a re-audit subagent prompt. Cooldown prevents bursty re-triggers.
#
# Plugin-native: cooldown marker session-scoped under $CLAUDE_PLUGIN_DATA/markers/$SESSION_ID/.
# NON-BLOCKING. Output is always {} or {additionalContext}, never a non-zero exit.

set -euo pipefail

INPUT=$(cat)
EDITED_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"


# Need jq
command -v jq &>/dev/null || { echo '{}'; exit 0; }

# --- Plugin-native marker layout (session-scoped) ---
WAVES_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/waves}"
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null | tr '/ ' '__')
export SESSION_ID
source "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/scope-resolve.sh" 2>/dev/null || true
MARKERS="$WAVES_DATA/markers/$SESSION_ID"
mkdir -p "$MARKERS" 2>/dev/null

# Find all audit files
AUDIT_FILES=()
while IFS= read -r f; do
  AUDIT_FILES+=("$f")
done < <(find "$AI_FILES_SCOPED"/waves -path "*/audits/*.json" -type f 2>/dev/null)

[ ${#AUDIT_FILES[@]} -eq 0 ] && { echo '{}'; exit 0; }

# Skip self-edits to audit files (the subagent writing its result triggers PostToolUse;
# don't bounce on that)
if [[ "$EDITED_FILE" == *"/audits/"*.json ]]; then
  echo '{}'
  exit 0
fi

# Don't fire during cooldown
COOLDOWN_FILE="$MARKERS/rules-audit-cooldown"
IN_COOLDOWN=false
if [ -f "$COOLDOWN_FILE" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    AGE=$(( $(date +%s) - $(stat -f %m "$COOLDOWN_FILE") ))
  else
    AGE=$(( $(date +%s) - $(stat -c %Y "$COOLDOWN_FILE") ))
  fi
  [ "$AGE" -lt 60 ] && IN_COOLDOWN=true
fi

# Normalize edited file to relative path for scope.files comparison
NORM_EDITED=""
if [ -n "$EDITED_FILE" ] && [ -e "$EDITED_FILE" ]; then
  NORM_EDITED=$(cd "$(dirname "$EDITED_FILE")" 2>/dev/null && echo "$(pwd)/$(basename "$EDITED_FILE")" || echo "$EDITED_FILE")
  # Strip the project dir prefix to get relative path
  REL_EDITED="${NORM_EDITED#$PROJECT_DIR/}"
else
  REL_EDITED=""
fi

INJECTIONS=()
REAUDIT_TRIGGERS=()
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

for AUDIT_FILE in "${AUDIT_FILES[@]}"; do
  STATUS=$(jq -r '.status // ""' "$AUDIT_FILE" 2>/dev/null)

  case "$STATUS" in
    completed_pending_injection)
      # Build a digest of violations to inject
      PRIMARY_ID=$(jq -r '.primary_id // "?"' "$AUDIT_FILE" 2>/dev/null)
      PRIMARY_CONTENT=$(jq -r '.primary_content // ""' "$AUDIT_FILE" 2>/dev/null)
      VIOLATIONS_COUNT=$(jq '.violations | length' "$AUDIT_FILE" 2>/dev/null || echo 0)

      if [ "$VIOLATIONS_COUNT" -eq 0 ]; then
        # No violations — mark as closed_resolved and skip injection
        jq --arg ts "$TIMESTAMP" '.status = "closed_resolved" | .resolved_at = $ts' "$AUDIT_FILE" > "${AUDIT_FILE}.tmp" \
          && mv "${AUDIT_FILE}.tmp" "$AUDIT_FILE"
        continue
      fi

      # Format the violations digest
      DIGEST=$(jq -r --arg pid "$PRIMARY_ID" --arg pcontent "$PRIMARY_CONTENT" '
        "Primary " + $pid + " (\"" + $pcontent + "\") — " + (.violations | length | tostring) + " rule violation(s):\n\n" +
        ([.violations[] |
          "  • [Level " + (.level | tostring) + " | verifier: " + (.classification // "unverified") + "] Rule #" + (.rule_id | tostring) + " — " + .file + ":" + (.line | tostring) + "\n" +
          "    Rule: " + .rule_text + "\n" +
          "    Evidence: " + .evidence + "\n" +
          "    Suggested fix: " + .suggested_fix + "\n" +
          "    Reasoning: " + .reasoning
        ] | join("\n\n"))
      ' "$AUDIT_FILE" 2>/dev/null)

      INJECTIONS+=("$DIGEST")

      # Mark as injected
      jq --arg ts "$TIMESTAMP" '.status = "injected" | .injected_at = $ts' "$AUDIT_FILE" > "${AUDIT_FILE}.tmp" \
        && mv "${AUDIT_FILE}.tmp" "$AUDIT_FILE"
      ;;

    injected|awaiting_resolution)
      # If the agent edited a file in this audit's scope_files AND we're not in cooldown,
      # the agent is presumably correcting → trigger a re-audit.
      [ "$IN_COOLDOWN" = true ] && continue
      [ -z "$REL_EDITED" ] && continue

      IS_IN_SCOPE=$(jq -r --arg f "$REL_EDITED" '[.scope_files[]? | select(. == $f or . == ($f + " (new)"))] | length' "$AUDIT_FILE" 2>/dev/null || echo 0)
      [ "$IS_IN_SCOPE" -eq 0 ] && continue

      # The audit file shape carries enough info to dispatch a re-audit
      PRIMARY_ID=$(jq -r '.primary_id // "?"' "$AUDIT_FILE" 2>/dev/null)
      PRIMARY_CONTENT=$(jq -r '.primary_content // ""' "$AUDIT_FILE" 2>/dev/null)
      ITERATION=$(jq '.iterations // 1' "$AUDIT_FILE" 2>/dev/null)
      NEXT_ITER=$((ITERATION + 1))

      if [ "$NEXT_ITER" -gt 3 ]; then
        # Cap reached on this re-audit attempt
        jq --arg ts "$TIMESTAMP" '.status = "escalated" | .iterations = 4 | .escalate_to_user = true | .escalated_at = $ts | .message = "Cap of 3 audit iterations reached on re-audit. Manual review required."' \
          "$AUDIT_FILE" > "${AUDIT_FILE}.tmp" && mv "${AUDIT_FILE}.tmp" "$AUDIT_FILE"
        REAUDIT_TRIGGERS+=("ESCALATED|$AUDIT_FILE|$PRIMARY_ID|$PRIMARY_CONTENT")
        continue
      fi

      # Mark for re-audit (running) — subagent will overwrite with new findings
      jq --arg ts "$TIMESTAMP" --argjson iter "$NEXT_ITER" \
        '.status = "running" | .iterations = $iter | .reaudit_started_at = $ts | del(.violations, .completed_at, .injected_at)' \
        "$AUDIT_FILE" > "${AUDIT_FILE}.tmp" && mv "${AUDIT_FILE}.tmp" "$AUDIT_FILE"

      REAUDIT_TRIGGERS+=("REAUDIT|$AUDIT_FILE|$PRIMARY_ID|$PRIMARY_CONTENT|$NEXT_ITER")

      # Set cooldown to prevent bursty re-trigger from sequential edits
      touch "$COOLDOWN_FILE"
      IN_COOLDOWN=true
      ;;
  esac
done

# Build aggregated message
[ ${#INJECTIONS[@]} -eq 0 ] && [ ${#REAUDIT_TRIGGERS[@]} -eq 0 ] && { echo '{}'; exit 0; }

MSG=""

if [ ${#INJECTIONS[@]} -gt 0 ]; then
  MSG="${MSG}RULES AUDIT FINDINGS — Action required.

These violations were reported by auditor A and verified+classified by verifier B (A→B pattern). Each carries a verifier classification — respect it first, then the impact level:

  - verifier=smoke: likely false positive or pedantic. Do NOT auto-fix; note and move on unless you independently disagree.
  - verifier=unverifiable: B lacked context. Use your own judgment.
  - verifier=confirmed/gold: real. Then apply the Waves trust contract by level:
      • Level 1-2: auto-fix silently or with brief documentation. No user approval needed.
      • Level 3-5: STOP. Surface to the user with your analysis. Do not auto-fix.

When you finish editing the scope files, the injector will automatically dispatch a re-audit. Iteration cap is 3.

"
  for d in "${INJECTIONS[@]}"; do
    MSG="${MSG}${d}

---

"
  done
fi

if [ ${#REAUDIT_TRIGGERS[@]} -gt 0 ]; then
  for t in "${REAUDIT_TRIGGERS[@]}"; do
    IFS='|' read -r KIND AFILE PID PCONTENT NITER <<<"$t"
    if [ "$KIND" = "ESCALATED" ]; then
      MSG="${MSG}RULES AUDIT ESCALATED — Primary $PID (\"$PCONTENT\"). Audit cap of 3 iterations reached. Stop auto-correction. Read $AFILE, summarize the persistent violations to the user, and request guidance.

"
    else
      MSG="${MSG}RULES AUDIT RE-AUDIT — Primary $PID (\"$PCONTENT\"), iteration $NITER of 3. You just edited a file in scope. Spawn a background subagent (model=opus, run_in_background=true) to re-audit. Use the same prompt format as the initial audit; the audit file at $AFILE has the updated iteration. Continue normally — the result will surface at your next Edit/Write.

"
    fi
  done
fi

jq -n --arg ctx "$MSG" '{additionalContext: $ctx}'
exit 0
