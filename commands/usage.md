---
description: Render the Waves usage heat map from local telemetry — frequency/jewels, recency/cold spots, friction, hook block-rate, the maturation trend, per-invocation footprint, and good-vs-broken outcomes. Zero-LLM bash aggregation; --analyze crosses with corpus-mine to weight findings by usage.
allowed-tools: Read, Bash, Glob
---

# Command: /waves:usage — the behavioral sensor (heat map)

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.

You are rendering the Waves usage heat map. This is the read side of the BEHAVIORAL sensor (w6 Phase 7) that complements the corpus miner: `/waves:corpus-mine` reads the OUTPUT (artifacts produced); this reads the BEHAVIOR (what gets invoked). It aggregates the append-only telemetry logs (`waves-telemetry.sh` writes them — `commands.jsonl` / `hooks.jsonl` / `subagents.jsonl`, schema `usage_event_schema.json`) with **zero LLM tokens** — pure bash/jq counting — and renders the intelligences the simulate-before-building exercise validated (`waves_files/waves/w6/sandbox/telemetry-prototype/FINDINGS.md`). Local-first, no server (out_of_scope #2).

## What it reads vs writes

- **READS (only):** `$CLAUDE_PLUGIN_DATA/telemetry/*.jsonl` (+ `waves_files/corpus-insights.json` in `--analyze` mode). Never edits them.
- **WRITES:** nothing. It renders to the terminal. (Telemetry is append-only and owned by the capture hook.)

## Step 0: Language

Read `waves_files/user_pref.json` → `user_profile.preferred_language`. Render all output in that language. If absent, default to English.

## Step 0.5: Parse arguments

- `--analyze` → also run the corpus cross (Step 3). Default off (heat map only).
- `--project <name>` → not needed: telemetry already tags each event with its `scope` (resolved at capture time). The render groups/filters by the `scope` field instead.

## Step 1: Locate telemetry (degrade gracefully)

```bash
TLM="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/waves}/telemetry"
```

If `$TLM` is absent OR all three logs are empty/missing, print a clear message and exit cleanly (NOT an error):

```
📊 No usage data yet.
Telemetry is captured silently as you use Waves commands. Run a few commands and
check back. (Opt-out: touch .claude/waves-telemetry-off.)
```

→ EXIT. Require `jq`; if absent, say so and exit cleanly.

## Step 2: Aggregate the seven intelligences (zero-LLM)

All seven are bash/jq counts over the three logs. Compute each; skip any whose source log is empty (degrade per-intelligence, never error).

1. **Frequency / jewels** — `commands.jsonl`, `event=="invoked"`, count by `name`, descending. The top is the heat map's hot end; a command invoked 50× weights a bug in it far above one in a cold command.
   ```bash
   jq -r 'select(.event=="invoked")|.name' "$TLM/commands.jsonl" | sort | uniq -c | sort -rn
   ```
2. **Recency / cold spots** — last `ts` per command; flag commands not invoked in > 40 days as cold (candidates to retire or fix). Compare `max(ts)` per name against now.
3. **Friction** — the same command `invoked` two+ times in one `session`, grouped by `name`+`session`. A high repeat count is a proxy for "a command users fight with" (per-command success is not captured in v1 — see intelligence 7 — so this is repetition, not confirmed retry-without-success).
4. **Hook block-rate** — `hooks.jsonl`: per `name`, `blocked / fired`. A gate that never blocks may be dead weight; one that always blocks may be miscalibrated.
   ```bash
   jq -r '.name+" "+.event' "$TLM/hooks.jsonl" | sort | uniq -c
   ```
5. **Maturation trend** — block-rate over time: bucket `hooks.jsonl` events by week (`ts` prefix) and show the block-rate per bucket. A falling gate block-rate as a project matures is the GOLD signal the exercise surfaced (the project learned the rails).
6. **Per-invocation footprint** — group every log by `inv`: subagents spawned per invocation, hooks fired per invocation, % of invocations that hit a block. Answers "which command is expensive" and "which gate earns its keep" — physically uncomputable without `inv` (the exercise's first improvement).
   ```bash
   # join across logs on inv, then per command: avg subs, avg hooks, %blocked
   ```
7. **Good-vs-broken — RESERVED, not available in v1.** This needed per-command `completed`/`aborted` (the exercise's second improvement), but Claude Code does not fire PostToolUse for the Skill tool, so per-command outcome cannot be captured today (verified, claude-code-guide). Do NOT fabricate it from other signals. It activates when a turn-level completion mechanism lands; until then, intelligence 3 (friction/repetition) is the only proxy. State this plainly in the render rather than showing an empty or invented table.

Use real package-qualified names in the render (#6) — `name` is already stored that way.

## Step 3: Corpus cross (`--analyze` only)

If `--analyze` was passed and `waves_files/corpus-insights.json` exists (run `/waves:corpus-mine` first if not), weight each corpus finding by usage frequency: a `most_violated_rule` or `field_fill_quality` insight whose subject lives in a HOT command/artifact matters more than the same insight in a cold one. Join the corpus finding's `sources`/`subject` against the Step-2 frequency map and re-rank: `confirmed`/`gold` findings on hot paths first. This is where the two sensors combine — "a bug in a command used 50× outweighs the same bug in a cold one." Render the re-ranked list; change nothing (suggest-only, like corpus-mine).

## Step 4: Render the heat map

Render, in the user's language, a compact terminal report:

- **Heat map** (frequency, hottest first) — the jewels at the top, cold spots flagged.
- **Block-rate + maturation trend** — per hook, with the trend arrow if enough history.
- **Per-invocation footprint** — per command: subs/run, hooks/run, %blocked.
- **Friction** — commands repeated within a session.
- **Good-vs-broken** — note it as RESERVED (not captured in v1; see intelligence 7), not an empty table.
- (`--analyze`) the usage-weighted corpus findings.

Degrade gracefully: render only the sections whose source log had data; never fail because one log is empty. If the `thread` column is uniformly empty (no work-thread writer wired yet), say so rather than implying cross-session runs were assembled. State plainly that nothing was changed and that telemetry is local-only and opt-out-able. End with the totals (events per log, distinct sessions, date range).
