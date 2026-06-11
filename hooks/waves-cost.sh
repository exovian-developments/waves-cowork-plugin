#!/bin/bash
# waves-cost.sh — Waves cost telemetry odometer (w6 Phase 8, the ECONOMIC sensor)
#
# The THIRD self-instrumentation sensor (design_principle #13): the corpus miner
# reads OUTPUT, usage telemetry reads BEHAVIOR, this reads ECONOMICS — what each
# primary objective costs in tokens and frozen USD.
#
# SIBLING hook, NOT a modification of waves-metacognition.sh. It fires on the same
# PostToolUse[Edit|Write] event and detects primary-completion the same way (a
# per-logbook achieved-count marker), but as a SEPARATE process — so it can NEVER
# alter the metacognition gate's exit code or stdout (the non-interference
# criterion is satisfied by construction, not by discipline).
#
# Odometer model: on each primary close, accumulate token usage (by model) across
# the session transcript + the subagents' transcripts, subtract the per-logbook
# checkpoint, attribute the DELTA to the just-closed primary, FREEZE the USD with
# pricing.json + the current waves_version, and write/update the co-located
# cost.json. Robust to mid-primary compaction: the transcript JSONL persists
# across compactions under one session id, so the accumulated total never resets.
#
# INVARIANT: silent + ALWAYS exit 0. Opt-out: .claude/waves-telemetry-off.
# Input: stdin JSON {session_id, transcript_path?, tool_input.file_path, ...}.

# No `set -e` — nothing here may abort or affect the caller.

WAVES_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/waves}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Opt-out + jq guard (same discipline as usage telemetry)
[ -f "$PROJECT_DIR/.claude/waves-telemetry-off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat 2>/dev/null) || exit 0
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only act on a logbook or diverged_work artifact write
case "$FILE" in
  */logbooks/*.json) UNIT="logbook" ;;
  */diverged_work/*/diverged_work.json) UNIT="diverged_work" ;;
  *) exit 0 ;;
esac
[ -f "$FILE" ] || exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null | tr '/ ' '__')

# --- Detect primary-completion (same counter+marker idea as waves-metacognition.sh) ---
ACHIEVED=$(jq '[.objectives.main[]? | select(.status=="achieved" or .status=="completed")] | length' "$FILE" 2>/dev/null || echo 0)
# diverged_work has no primaries; treat its disposition write as a single close.
[ "$UNIT" = "diverged_work" ] && ACHIEVED=1

NORM=$(cd "$(dirname "$FILE")" 2>/dev/null && printf '%s/%s' "$(pwd)" "$(basename "$FILE")" || printf '%s' "$FILE")
KEY=$(printf '%s' "$NORM" | { md5 -q 2>/dev/null || md5sum 2>/dev/null | cut -d' ' -f1; })
CKDIR="$WAVES_DATA/cost/$SESSION_ID"; mkdir -p "$CKDIR" 2>/dev/null || exit 0
COUNT_MARK="$CKDIR/$KEY.count"          # last achieved-count we costed
ACC_MARK="$CKDIR/$KEY.acc"              # last accumulated tokens-by-model (the odometer reading)
LAST_COUNT=$(cat "$COUNT_MARK" 2>/dev/null || echo 0)

# Nothing newly completed → record the reading and exit (keeps the odometer warm)
if [ "$ACHIEVED" -le "$LAST_COUNT" ]; then exit 0; fi

# --- Resolve transcripts: main session + its subagents. Prefer transcript_path,
# fall back to CLAUDE_PROJECT_DIR + session_id (verified robust, Phase-7 lesson). ---
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  ENC=$(printf '%s' "$PROJECT_DIR" | sed 's#/#-#g')
  TRANSCRIPT="$HOME/.claude/projects/$ENC/$SESSION_ID.jsonl"
fi
[ -f "$TRANSCRIPT" ] || exit 0
SUBDIR="$(dirname "$TRANSCRIPT")/$SESSION_ID/subagents"

# --- Accumulate tokens by model across the transcript + subagent transcripts ---
ACC=$(cat "$TRANSCRIPT" "$SUBDIR"/*.jsonl 2>/dev/null | jq -s '
  [ .[] | select(.message.usage) | {
      m: (.message.model // "unknown"),
      input: (.message.usage.input_tokens // 0),
      output: (.message.usage.output_tokens // 0),
      cache_creation: (.message.usage.cache_creation_input_tokens // 0),
      cache_read: (.message.usage.cache_read_input_tokens // 0)
    } ]
  | group_by(.m)
  | map({ key: .[0].m, value: {
      input: (map(.input)|add), output: (map(.output)|add),
      cache_creation: (map(.cache_creation)|add), cache_read: (map(.cache_read)|add) } })
  | from_entries
' 2>/dev/null)
[ -n "$ACC" ] || exit 0

PREV_ACC=$(cat "$ACC_MARK" 2>/dev/null || echo '{}')

# --- DELTA (by model) = ACC - PREV_ACC. This is the cost of the just-closed primary. ---
PRICING="${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/pricing.json"
[ -f "$PRICING" ] || PRICING=/dev/null
WAVES_VERSION=$(jq -r '.version // "unknown"' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null || echo unknown)
PRICING_REF=$(jq -r '("pricing.json@" + (.version // "unknown"))' "$PRICING" 2>/dev/null || echo "pricing.json@unknown")
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)

# Real objective id of the just-closed primary — NOT the achieved-COUNT (robust to
# non-contiguous ids / out-of-order completion). The achieved list is document order.
REAL_PID=$(jq -r --argjson n "$ACHIEVED" '([.objectives.main[]? | select(.status=="achieved" or .status=="completed")][$n-1].id) // $n' "$FILE" 2>/dev/null)
[ -n "$REAL_PID" ] && [ "$REAL_PID" != "null" ] || REAL_PID="$ACHIEVED"

# Compute delta tokens (summed across models) + frozen USD (per-model rates), in jq.
ENTRY=$(jq -n \
  --argjson acc "$ACC" --argjson prev "$PREV_ACC" \
  --slurpfile pr "$PRICING" \
  --arg pid "$REAL_PID" '
  ($pr[0] // {models:{}, default_model:"unknown"}) as $price |
  ($price.models // {}) as $rates |
  ($acc | keys) as $models |
  # per-model delta
  # max(0, acc - prev) per field: a TRUNCATING compaction (acc < prev) yields 0, never a negative delta.
  ( [ $models[] | . as $m |
      { ($m): {
        input: ([(($acc[$m].input // 0) - ($prev[$m].input // 0)), 0] | max),
        output: ([(($acc[$m].output // 0) - ($prev[$m].output // 0)), 0] | max),
        cache_creation: ([(($acc[$m].cache_creation // 0) - ($prev[$m].cache_creation // 0)), 0] | max),
        cache_read: ([(($acc[$m].cache_read // 0) - ($prev[$m].cache_read // 0)), 0] | max) } } ]
    | add // {} ) as $delta |
  # summed tokens across models (the high-level number stored)
  { input: ([$delta[].input]|add // 0), output: ([$delta[].output]|add // 0),
    cache_creation: ([$delta[].cache_creation]|add // 0), cache_read: ([$delta[].cache_read]|add // 0) } as $tok |
  # frozen USD: per-model rate x per-model delta, summed. null if no pricing.
  ( if ($rates|length)==0 then null else
      ( [ $delta | to_entries[] | .key as $m | .value as $d |
          ($rates[$m] // $rates[$price.default_model] // {input:0,output:0,cache_creation:0,cache_read:0}) as $r |
          ($d.input/1000000*$r.input + $d.output/1000000*$r.output
           + $d.cache_creation/1000000*$r.cache_creation + $d.cache_read/1000000*$r.cache_read) ]
        | add // 0 | .*10000 | round / 10000 )
    end ) as $usd |
  { primary_id: ($pid|tonumber), tokens: $tok, usd: $usd }
' 2>/dev/null)
[ -n "$ENTRY" ] || exit 0

# --- Co-located cost.json path (location = semantics, dp#11) ---
DIR=$(dirname "$FILE"); BASE=$(basename "$FILE")
if [ "$BASE" = "logbook.json" ] || [ "$UNIT" = "diverged_work" ]; then
  COST="$DIR/cost.json"                       # directory-per-unit layout
else
  COST="$DIR/${BASE%.json}.cost.json"         # flat layout — sibling of the logbook
fi

# Label from the just-closed primary's content
LABEL=$(jq -r --argjson n "$ACHIEVED" '([.objectives.main[]? | select(.status=="achieved" or .status=="completed")] | .[$n-1].content) // ""' "$FILE" 2>/dev/null | cut -c1-90)

# --- Write/update cost.json: replace the entry for this primary_id, recompute total ---
EXISTING=$(cat "$COST" 2>/dev/null || echo '{}')
printf '%s' "$EXISTING" | jq \
  --argjson entry "$ENTRY" --arg label "$LABEL" --arg ts "$TS" \
  --arg wv "$WAVES_VERSION" --arg pref "$PRICING_REF" --arg unit "$UNIT" '
  ($entry + {label:$label}) as $e |
  ( (.per_primary // []) | map(select(.primary_id != $e.primary_id)) + (if $unit=="diverged_work" then [] else [$e] end)
    | sort_by(.primary_id) ) as $pp |
  ( if $unit=="diverged_work" then $e.tokens else
      { input: ([$pp[].tokens.input]|add // 0), output: ([$pp[].tokens.output]|add // 0),
        cache_creation: ([$pp[].tokens.cache_creation]|add // 0), cache_read: ([$pp[].tokens.cache_read]|add // 0) }
    end ) as $tt |
  ( if $unit=="diverged_work" then $e.usd
    elif ([$pp[].usd] | map(select(.!=null)) | length) == ($pp|length) then ([$pp[].usd]|add)
    else null end ) as $tu |
  {
    generated_at: $ts, waves_version: $wv, currency: "USD", pricing_ref: $pref,
    per_primary: $pp, total: { tokens: $tt, usd: $tu }
  }
' > "$COST.tmp" 2>/dev/null && mv "$COST.tmp" "$COST" 2>/dev/null

# --- Advance the odometer checkpoint ---
printf '%s' "$ACC" > "$ACC_MARK" 2>/dev/null
printf '%s' "$ACHIEVED" > "$COUNT_MARK" 2>/dev/null

exit 0
