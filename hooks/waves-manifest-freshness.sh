#!/bin/bash
# waves-manifest-freshness.sh — PostToolUse[Bash] hook for Waves 3.0 (w6 Phase 10)
# Keeps the project manifest (the semantic index) FRESH automatically at the
# COMMIT boundary (blueprint capability important #8, product_decision #26).
#
# The manual /waves:manifest-update is invisible in practice (owner: unused after
# months) — a DERIVED map nobody refreshes silently rots, producing false
# downstream findings and an invisible blast-radius. DISTINCT from w6 Phase 9
# (waves-foundational-audit.sh): that is adversarial CONSISTENCY at write time;
# this is FRESHNESS at the commit boundary. The manifest's risk is staleness,
# not being mis-written.
#
# NON-BLOCKING by construction: this is PostToolUse (the commit already ran) and
# it only ever emits additionalContext or '{}'. It NEVER exits 2, NEVER writes a
# gate-pending marker. The commit always proceeds.
#
# TWO deterministic stages, ZERO LLM tokens in the hook itself:
#   1. Trigger + SHA-resolve (S2): match `git commit`, read HEAD's changed files
#      (reuses the doc-sync `git show --name-only` pattern).
#   2. Zero-token pre-filter (S3): the manifest maps CODE only. If the commit
#      touches ONLY waves_files/ or ai_files/ (Waves artifacts), docs (*.md), or lockfiles, it
#      early-exits with ZERO tokens — no analysis. Only a diff that touches real
#      CODE emits additionalContext DELEGATING the graduated, intent-aware
#      magnitude analysis to the main agent (same delegation pattern as
#      waves-metacognition.sh — the hook stays deterministic; the token spend is
#      the agent's and visible; NOT a new hook class).
#
# INVARIANT: silent + ALWAYS exit 0. Opt-out: .claude/waves-manifest-freshness-off.
# Input: stdin JSON {session_id, tool_name, tool_input.command, ...} (PostToolUse).

# No `set -e` — nothing here may abort or affect the caller. Defensive throughout.

INPUT=$(cat 2>/dev/null) || exit 0

# Extract the bash command that just ran
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && { echo '{}'; exit 0; }

# --- S2: trigger on the boundaries where code LANDS (w6 Phase 14, sec 5) ---
# Not just `git commit`: a PR-branch workflow crosses the boundary at merge/pull
# (field finding: pcc_local merges never fired Flow C). Also tolerate `git -C`.
FIRST_LINE=$(printf '%s' "$COMMAND" | head -1)
if ! printf '%s' "$FIRST_LINE" | grep -qE '(^|[[:space:]]|&&|;)(git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?(commit|merge|pull)([[:space:]]|$)|gh[[:space:]]+pr[[:space:]]+merge)'; then
  echo '{}'; exit 0
fi
# Skip a dry-run commit (no SHA is produced)
if printf '%s' "$FIRST_LINE" | grep -qE 'git[[:space:]]+commit[[:space:]].*--dry-run'; then
  echo '{}'; exit 0
fi

command -v jq >/dev/null 2>&1 || { echo '{}'; exit 0; }
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Opt-out marker (dedicated — freshness is not telemetry)
[ -f "$PROJECT_DIR/.claude/waves-manifest-freshness-off" ] && { echo '{}'; exit 0; }

# --- Multi-project scope resolver (find the manifest under the active scope) ---
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null | tr '/ ' '__')
export SESSION_ID
source "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/scope-resolve.sh" 2>/dev/null || true

# --- Resolve the REPO where the commit actually landed (w6 Phase 14, sec 5) ---
# Root cause (a): reading HEAD of $CLAUDE_PROJECT_DIR is blind to CHILD repos
# under projects/* with their own git. Resolution order: explicit `git -C
# <path>` in the command > the hook payload's cwd > PROJECT_DIR; then walk to
# the repo toplevel. Root cause (c): the md5(cwd) scope marker is NOT used for
# locating the manifest anymore — the resolved repo root is.
GITC=$(printf '%s' "$FIRST_LINE" | sed -n 's/.*git[[:space:]]\{1,\}-C[[:space:]]\{1,\}\([^[:space:]]\{1,\}\).*/\1/p')
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
REPO_HINT="${GITC:-${HOOK_CWD:-$PROJECT_DIR}}"
REPO_ROOT=$(git -C "$REPO_HINT" rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$REPO_ROOT" ] && REPO_ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$REPO_ROOT" ] && { echo '{}'; exit 0; }

# --- SHA-resolve: HEAD of the RESOLVED repo. First-parent diff covers merge
# commits too (git show --name-only is empty on merges).
RESOLVED=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "")
[ -z "$RESOLVED" ] && { echo '{}'; exit 0; }
CHANGED=$(git -C "$REPO_ROOT" diff --name-only "${RESOLVED}^1" "$RESOLVED" 2>/dev/null | grep -v '^$' || true)
[ -z "$CHANGED" ] && CHANGED=$(git -C "$REPO_ROOT" show --name-only --format="" "$RESOLVED" 2>/dev/null | grep -v '^$' || echo "")
[ -z "$CHANGED" ] && { echo '{}'; exit 0; }

# --- S3: ZERO-TOKEN deterministic pre-filter. The manifest maps CODE only. ---
# A path is manifest-IRRELEVANT (non-code) when it is a Waves artifact, docs, or
# a lockfile. If EVERY changed path is non-code, early-exit with zero tokens —
# a commit without code changes needs no manifest update. Only CODE proceeds.
CODE_FILES=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    waves_files/*|*/waves_files/*|ai_files/*|*/ai_files/*) continue ;;  # Waves artifacts — not code
    *.md|*.markdown|*.txt|*.rst) continue ;;                     # docs
    *.lock|*-lock.json|*.lock.json|go.sum|*.sum) continue ;;     # lockfiles (deps pinned, not source)
    .gitignore|.gitattributes|LICENSE|LICENSE.*|*/LICENSE) continue ;;
    .claude/*|*/.claude/*) continue ;;                           # Claude config — not product code
    *) CODE_FILES="${CODE_FILES}${CODE_FILES:+$'\n'}$f" ;;       # everything else = code
  esac
done <<< "$CHANGED"

# All changes were non-code → the manifest cannot have drifted. Zero tokens.
if [ -z "$CODE_FILES" ]; then
  echo '{}'; exit 0
fi

# --- structural+ : a code diff exists. DELEGATE the graduated analysis. ---
# The hook stays deterministic; the LLM spend is the agent's, visible and
# proportional (cosmetic -> no-op; structural -> layer update; new-capability ->
# deep). The WHY of the change is read from the Waves artifact co-committed in
# the SAME diff (logbook/roadmap/diverged_work), NOT the commit message.

# Locate the manifest to refresh: the RESOLVED repo's own first (covers child
# repos regardless of scope markers), then the classic scope fallbacks.
MANIFEST=""
for m in "$REPO_ROOT/waves_files/project_manifest.json" "$REPO_ROOT/ai_files/project_manifest.json" \
         "$AI_FILES_SCOPED/project_manifest.json" "$AI_FILES_ROOT/project_manifest.json"; do
  [ -f "$m" ] && MANIFEST="$m" && break
done

# Identify any Waves artifact co-committed in this same diff (the INTENT source)
ARTIFACTS_IN_DIFF=$(printf '%s' "$CHANGED" | grep -E '(^|/)(waves_files|ai_files)/.*(logbooks/.*\.json|roadmap\.json|diverged_work/.*\.json)$' || echo "")

# Read metacognition model from user_pref.json (default: opus) — same convention
META_MODEL="opus"
for pref in "$AI_FILES_ROOT/user_pref.json" "user_pref.json"; do
  if [ -f "$pref" ]; then
    CONFIGURED_MODEL=$(jq -r '.agent_config.metacognition_model // empty' "$pref" 2>/dev/null)
    [ -n "$CONFIGURED_MODEL" ] && META_MODEL="$CONFIGURED_MODEL"
    break
  fi
done

# Find the blueprint (degrade target when no co-committed artifact gives intent)
BP=""
for bp in "$AI_FILES_SCOPED/blueprint.json" "$AI_FILES_SCOPED/product_blueprint.json" \
          "$AI_FILES_ROOT/blueprint.json" "$AI_FILES_ROOT/product_blueprint.json"; do
  [ -f "$bp" ] && BP="$bp" && break
done

CODE_LIST=$(printf '%s' "$CODE_FILES" | sed 's/^/  - /')
ART_LINE=${ARTIFACTS_IN_DIFF:+$(printf '%s' "$ARTIFACTS_IN_DIFF" | sed 's/^/  - /')}

MSG="MANIFEST FRESHNESS — commit ${RESOLVED:0:8} changed CODE. Refresh the semantic index so it does not rot (NON-BLOCKING — the commit already landed; this is a nudge, not a gate).\n\nThis is the FRESHNESS sensor (capability #8, distinct from the Phase 9 adversarial-consistency hook). The manifest's reason to exist is the blast-radius GRAPH (the relations[] field) — couplings grep cannot see. Run a GRADUATED analysis with a budget PROPORTIONAL to the change; do not over-analyze cosmetics.\n\nManifest to refresh: ${MANIFEST:-<none found — run /waves:manifest-create first>}\n\nCode files changed in this commit:\n$CODE_LIST\n\nINTENT (the WHY) — read it from the Waves artifact co-committed in THIS diff, NOT the commit message:\n${ART_LINE:-  (no Waves artifact in this commit — degrade to the active logbook, else infer from the diff + the blueprint: ${BP:-none})}\n\nSTEPS (delegate the heavy reading to a subagent if the diff is large; model=$META_MODEL):\n1. Read the INTENT source above to learn WHY the code changed.\n2. Classify MAGNITUDE (proportional budget):\n   - cosmetic (a rename, a margin, one field) -> NO-OP. Do nothing to the manifest.\n   - structural (a new module / dependency / layer) -> update the affected section (modules / architecture_identified / platform_info) and any relations[] edge the change creates or breaks.\n   - new blueprint CAPABILITY (a websocket, an encrypted store, a new integration) -> DEEP: reuse the manifest-create analyzers scoped to the changed files; compute the new technologies AND the blast-radius relations[] edges (the couplings grep cannot see). See /waves:manifest-update.\n3. Write the manifest PROPORTIONALLY (only what changed). The relations[] graph is the highest-value output — add edges the new code introduces.\n\nIf you judge the change cosmetic, say so in one line and make no manifest edit (that is the correct outcome — freshness, not churn)."

jq -n --arg ctx "$MSG" '{"additionalContext": $ctx}'
exit 0
