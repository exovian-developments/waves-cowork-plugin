---
description: Render the Waves cost report from the co-located cost.json files — token cost (cache vs normal) and frozen USD per primary objective, summed per logbook, per roadmap, and per project; crosses with the usage heat map to project USD per person per month. Zero-LLM bash aggregation.
allowed-tools: Read, Bash, Glob
---

# Command: /waves:cost — the economic sensor (cost report)

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.

You are rendering the Waves cost report. This is the read side of the THIRD self-instrumentation sensor (w6 Phase 8, design_principle #13): the corpus miner reads OUTPUT, usage telemetry reads BEHAVIOR, this reads ECONOMICS — what each unit of work cost in tokens and money. It aggregates the `cost.json` files the odometer (`waves-cost.sh`) writes co-located in each logbook's directory, with **zero LLM tokens** — pure bash/jq summation — and applies no new pricing (the USD was already frozen at capture, per release). Local-first.

## What it reads vs writes

- **READS (only):** the `cost.json` files across `waves_files/waves/*/` (+ the usage telemetry logs in `--cross` mode). Never edits them.
- **WRITES:** nothing. It renders to the terminal. The cost figures are immutable snapshots (USD frozen at capture with the then-current `waves_version` + `pricing_ref`).

## Step 0: Language

Read `waves_files/user_pref.json` → `user_profile.preferred_language`. Render all output in that language. If absent, default to English.

## Step 0.5: Parse arguments

- `--cross` → also project USD/person/month by crossing cost with the Phase 7 usage heat map (Step 3). Default off (cost report only).
- `--project <name>` → aggregate only that scope (cost.json files under `projects/<name>/waves_files/...`). Default: the current scope.

## Step 1: Discover the cost snapshots (degrade gracefully)

Glob, tolerating both layouts (the corpus is heterogeneous, product_decision #23):
- directory-per-logbook: `waves_files/waves/*/logbooks/*/cost.json`
- flat layout: `waves_files/waves/*/logbooks/*.cost.json`
- diverged_work: `waves_files/waves/*/diverged_work/*/cost.json`

If none exist, print a clear message and exit cleanly (NOT an error):

```
💰 No cost data yet.
Cost is captured silently as primary objectives complete (the odometer writes a
co-located cost.json). Implement a logbook objective and check back.
(Opt-out: touch .claude/waves-telemetry-off.)
```

→ EXIT. Require `jq`; if absent, say so and exit cleanly.

## Step 2: Aggregate (zero-LLM)

Each `cost.json` already carries its own `total` (tokens cache-vs-normal + frozen `usd`) and a `per_primary` breakdown — the odometer did the per-objective math. So aggregation is pure summation, no recompute:

1. **Per logbook** — read each `cost.json`'s `total`. This IS the cost of that logbook (creation → implementation). Show the per-primary breakdown when asked.
   ```bash
   for f in $(glob); do jq -c '{file: input_filename, wv: .waves_version, usd: .total.usd, tokens: .total.tokens}' "$f"; done
   ```
2. **Per roadmap (wave)** — sum the logbook totals within one `waves/<wN>/`. "What did wave N cost."
3. **Per project** — sum across all waves. "What has Waves cost on this project."
4. **By waves_version** — group totals by `waves_version`. This is the release-over-release efficiency curve: *"the same logbook cost fewer tokens in 3.1 than 3.0"* — the optimization compass and the sales line. Surface tokens (the framework-efficiency fact, isolated from pricing) alongside USD.
5. **Cost concentration** — rank primaries/logbooks by `usd` (or tokens) descending: which objective burned the most. This is where to point optimization — and what to consider trimming (cost surface with no value).

Sum the four token types separately (the cache-vs-normal split is already in each total). Never recompute USD — it is frozen; report it as captured. Use real package-qualified names (#6).

## Step 3: Cross with usage (`--cross` only)

Cost answers "what does one operation cost"; the Phase 7 heat map (`commands.jsonl`) answers "how often is it invoked". Multiply:

```
cost-per-operation (this sensor)  ×  frequency (Phase 7 heat map)  =  USD per person per month
```

Read the per-command invocation counts from `$CLAUDE_PLUGIN_DATA/telemetry/commands.jsonl` (the Phase 7 sensor) and the per-logbook/per-command cost from Step 2, and project: for a team running N logbooks/month at the measured average cost, the USD/person/month. State the assumptions (which averages, what period) plainly — this is the business projection a buyer needs, not a precise invoice. If the usage logs are empty, say the projection needs usage data first (`/waves:usage`).

## Step 4: Render the cost report

Render, in the user's language, a compact terminal report — the "vacation receipt" framing, high-level not granular:

- **Per project total** — "Waves has cost $X (Y tokens) on this project."
- **Per roadmap (wave)** — one line each.
- **Per logbook** — one line each (creation → implementation), with the per-primary breakdown available on request.
- **Release-over-release** — totals grouped by `waves_version`, so the efficiency trend is visible.
- **Cost concentration** — the top few costliest objectives/logbooks (where to optimize).
- (`--cross`) the USD/person/month projection.

Degrade gracefully: render only the sections backed by data; never fail because a `cost.json` is missing or a wave has none. State plainly that nothing was changed and that the USD is a frozen per-release snapshot (not recomputed). End with the totals (logbooks costed, date range, waves_versions seen).
