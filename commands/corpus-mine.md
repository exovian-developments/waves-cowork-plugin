---
description: Mine the Waves artifact corpus — read every logbook's analyses across waves/projects, surface recurring findings, most-violated rules, most-omitted edge_cases, emergent fields, and chronically mis-filled fields, then emit corpus-insights.json with A->B-verified, suggest-only recommendations.
allowed-tools: Read, Bash, Glob, Grep, Write, Agent
---

# Command: /waves:corpus-mine — Second-order metacognition (corpus miner)

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.

You are executing the Waves corpus miner. This is the second-order metacognition of the framework (design_principle #11): the framework learns from its own use by READING its corpus, not by re-deriving it. It walks the persisted analyses every logbook leaves behind (integrity-audit, correctness-postplan, correctness-postimpl), aggregates them across waves and projects, and emits `corpus-insights.json` — recurring findings, most-violated rules, most-omitted edge_case classes, and EMERGENT FIELDS (invented fields that recur = officialization candidates). Every finding is verified by an independent verifier (A->B, design_principle #7) and the feedback to rules/schemas/reviewers is **suggested only — this command NEVER auto-edits a governed artifact** (human-in-the-loop).

## What it reads vs what it writes

- **READS (only):** the corpus — logbooks and their co-located analyses across `waves_files/waves/*/`. The corpus is an immutable historical record (product_decision #23); this command treats it as read-only.
- **WRITES (only):** `corpus-insights.json` (a new artifact, schema `corpus_insights_schema.json`). It writes NOTHING else — it does not touch `project_rules.json`, schemas, command files, or any logbook.

## Critical constraint — the corpus is HETEROGENEOUS (read defensively)

Logbooks are immutable snapshots of the schema at their moment (product_decision #23), so the corpus mixes:
- **Layouts:** the legacy flat layout (`logbooks/X.json`, with siblings under `audits/` and `resolutions/`) AND the v3 directory-per-logbook layout (`logbooks/X/logbook.json` + `logbooks/X/integrity-audit.json` + `logbooks/X/correctness-postplan.json` + `logbooks/X/correctness-postimpl.json` + `logbooks/X/resolution.md`).
- **Schema versions:** v2-shaped logbooks (flat secondary list, no `parent_main_id`, legacy `audit.is_already_audited`) coexist with v3-shaped ones (`parent_main_id`, `audit.integrity`/`correctness_postplan`/`correctness_postimpl`).

**The rule:** a missing v3 field means "this snapshot predates the field", NEVER "violation". Heterogeneity is the FEATURE that lets the miner SEE the schema's evolution — it is not an error to normalize away. A logbook that fails to parse as JSON is reported as a pre-existing broken artifact; it is never edited or guessed at.

## Step 0: Language

Read `waves_files/user_pref.json` (or `user_pref.json`) → `user_profile.preferred_language` (default English). Conduct all interaction in that language.

## Step 0.5: Parse arguments

- `--project <name>` (optional): mine a single scope at `projects/<name>/waves_files/` instead of the root. Same helper as the other commands (see `plugin/skills/waves-protocol/SKILL.md` Multi-project Path Resolution). Absent → mine the root `waves_files/` corpus.
- `--out <path>` (optional): output path. Default `waves_files/corpus-insights.json` (or `projects/<name>/waves_files/corpus-insights.json` in `--project` mode).
- No other flags. This command never mutates the corpus, so it needs no `--dry-run`.

Set `corpus_root` = the resolved `waves_files/` and `out_path` accordingly.

## Step 1: Discover the corpus (defensive walk)

Glob every wave's logbooks under `corpus_root/waves/*/logbooks/`, tolerating BOTH layouts. For each wave directory:

1. **Flat layout** — every `logbooks/*.json` file that is a logbook (not a directory). Its co-located analyses live under sibling `waves/<wN>/audits/` and `waves/<wN>/resolutions/`.
2. **Directory-per-logbook layout** — every `logbooks/<slug>/logbook.json`. Its analyses are co-located in the same directory.
3. A `<slug>` migrated to a directory takes precedence — if both `logbooks/<slug>.json` and `logbooks/<slug>/` exist (mid-migration), read the directory and skip the flat file (idempotent, no double-count).
4. **diverged_work artifacts** (w6 Phase 6) — glob `corpus_root/waves/*/diverged_work/<slug>/diverged_work.json` (a directory parallel to `logbooks/`, schema `diverged_work_schema.json`). Most waves have NONE — an absent `diverged_work/` directory is "predates the artifact" (product_decision #23), never a finding. Read each with the same defensive contract below. A diverged_work is a lightweight unit that surfaced mid-flight; its embedded `audit` (the 3-gate disposition record) is itself a mineable analysis.

**Discover analyses by GLOB, not by a closed name-list.** The corpus's filenames are themselves open-ended (the framework's own thesis — design_principle #11), so do NOT probe three hard-coded names. Glob `audits/*.json` (flat) and `<slug>/*.json` (dir) and the `resolutions/`/`<slug>/*.md` files, then **classify each by filename pattern**:

| Pattern | Class |
|---|---|
| `logbook-<slug>.json` (flat) / `integrity-audit.json` (dir) | `integrity` |
| `correctness-postplan*` / `correctness-postimpl*` | `correctness_postplan` / `correctness_postimpl` |
| `*-resolution.md` (flat) / `resolution.md` (dir) | `resolution` |
| `diverged_work.json` (under `waves/<wN>/diverged_work/<slug>/`) | `diverged_work` |
| anything else (e.g. `metacognition-*`, `primary-*`) | **`other` — recorded + counted + surfaced as an EMERGENT-ARTIFACT signal** |

The `other` bucket is cheap and turns a blind spot into a finding: a recurring undeclared analysis FAMILY (`metacognition-*`, `primary-*`) is the file-level analogue of an emergent field — exactly what the miner exists to surface. Correctness/resolution analyses are absent for logbooks predating w6 Phase 3 — that is "predates the file", never fabricate them.

Reuse the dual-layout discovery + precedence + idempotency of `plugin/commands/migrate-from-v2-to-v3.md` (REGLA-0 #3) — but NOT its closed 3-name mapping; widen classification per the table above. Read every artifact with the **defensive contract**:

- Parse each JSON. On parse failure (analysis OR logbook), record it in `broken_artifacts` (path + reason) and continue — never edit, never guess. An unparseable logbook is skipped but must NOT abort discovery of its separately-parseable siblings.
- A field absent from a snapshot is "predates the field", not a finding. Only the analyses' OWN findings (what the integrity/correctness reviewers already recorded) are mined — the miner does not re-audit the logbooks.
- Validate nothing destructively; the miner is a reader.

## Step 2: Build the parseable index

From the discovered analyses, build an in-memory index that the extractions (Step 3) consume. Key it by the three axes the corpus is mined on, and keep every entry traceable to its source snapshot:

```
index = {
  "by_category":   { "<finding category>": [ {source, severity, message_excerpt}, ... ] },
  "by_rule":       { "<rule_id>": [ {source, severity, message_excerpt}, ... ] },
  "by_edge_case":  { "<edge_case class>": [ {source, expected_present: bool}, ... ] },
  "observed_keys_by_artifact_type": { "<artifact type>": { "<observed key>": <count across artifacts of that type> } },
  "other_analyses": { "<unclassified filename pattern>": [ {source}, ... ] },
  "diverged_work": [ {source, disposition, refuted_gates: ["<gate name>", ...], reviewer_verdict, promoted_lineage: "<logbook source path or null>"}, ... ],
  "artifacts_seen": { "integrity": <int>, "correctness_postplan": <int>, "correctness_postimpl": <int>, "diverged_work": <int>, "other": <int>, "logbooks_total": <int>, "logbooks_with_analyses": <int> },
  "broken_artifacts": [ {path, reason}, ... ]
}
```

Where each `source` is the snapshot path (e.g. `conversational_engine_ba` `waves_files/waves/w3/logbooks/phase_2/integrity-audit.json`) so every later insight is traceable back to the artifact that produced it.

- `observed_keys_by_artifact_type` feeds `emergent_field` detection (Step 3): record, per artifact type (logbook / integrity-audit / correctness-* / blueprint / roadmap), the set of keys actually present and how often. This is the OBSERVED half; Step 3 diffs it against the DECLARED half (the schema's `properties`).
- `artifacts_seen` separates `logbooks_total` from `logbooks_with_analyses` so the reader sees the DENOMINATOR — waves that predate the analysis files (e.g. w1/w2 of an older corpus) contribute logbooks but zero findings; without the gap visible, "rule X violated 3×" reads as "rare" when 4 of 8 waves were never scanned at all.
- `diverged_work` indexes each diverged unit by its `audit`: the `disposition` (executable/promoted), which `gates` were `refuted`, and the `reviewer_verdict`. This is a behavioral signal the logbook analyses cannot give — a gate that refutes often (e.g. `closed_scope` failing repeatedly → frequent `promoted`) means divergent work is consistently bigger than captured, feeding `recurring_finding`/`field_fill_quality` the same way. **Lineage** (`diverged_work[promoted] → logbook → resolution`): the DW file is written before its logbook exists, so the link is forward and BEST-EFFORT — set `promoted_lineage` to a logbook source path only when a logbook in the corpus plausibly originated from this DW — a logbook that back-references this DW's path, or whose ticket title matches this DW's `title` (the seed carried by `/waves:diverged-work-create` Step 5B). Logbooks carry no guaranteed structured pointer to their seed DW, so this is a TITLE/path match, not a field lookup; when no match, leave it `null` and surface the promoted DW standalone. Never fabricate a link (the defensive contract; product_decision #23).

Keep the index to exactly what Step 3's extractions need — no speculative aggregates (REGLA-0 #3). Use real package names in any example (#6), never the short conversational names.

## Step 3: Extractions (analyst A)

From the index, the main agent acts as **analyst A** and extracts exactly the five insight kinds the corpus is mined for. The prior MANUAL run is the spec — `waves_files/waves/w6/audits/corpus-insights-comment-quality.md` already ran these extractions by hand over 23 projects; automate THOSE, do not invent new metrics (REGLA-0 #3):

1. **recurring_finding** — the same integrity/correctness issue (by category + message similarity) appearing across multiple logbooks. Rank by `occurrences`.
2. **most_violated_rule** — `rule_id`s that the integrity/correctness analyses flag most across the corpus. Rank by `occurrences`. Note: legacy integrity findings embed the rule ref inside the `message` prose (e.g. "missing 'Apply rule #3'"), not a structured field — so `by_rule` is best-effort (parse refs out of `message`); `by_category` is clean.
3. **omitted_edge_case** — `edge_case` classes most often left with empty `expected` (the forcing-function gap design_principle #10 targets), counted across logbooks. (New extraction — no manual-run precedent yet, so its first output is the least-validated of the four; keep but mark it as such.)
4. **emergent_field** — fields PRESENT in an artifact but NOT in its schema's declared `properties`, RECURRING across many same-type artifacts. "Undeclared" is only meaningful against a baseline: load the canonical schemas (`${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/*_schema.json`), extract each artifact type's declared keys (recursively, incl. `$defs`), and diff `observed_keys_by_artifact_type` (Step 2) against them. Recurrence (not schema-closure — schemas are OPEN) discriminates signal from noise (design_principle #11). Officialization candidates: `parent_main_id` was the first (now official); `ui_requirements`, `provider_api` are the manual run's standing candidates. The `other_analyses` bucket (Step 1) is the file-level version of this — a recurring undeclared analysis family is an emergent ARTIFACT, surface it the same way.
5. **field_fill_quality** — a DECLARED prose field chronically mis-filled across the corpus: over its `maxLength`, or multi-concern (value carries `+` / `y`/`and` / an em-dash / a colon-list / two verbs — the STOP signal of product_rule #12). `subject` is the `artifact.field` path (e.g. `product_decision.decision`, `main_objective.content`); `observation` cites the overflow ratio + the multi-concern markers seen. This is the manual run's HIGHEST-leverage extraction (corpus-insights-comment-quality.md patterns P1/P2/P3): it keys on a schema FIELD and a structural symptom, NOT a `rule_id` (that is `most_violated_rule`) and NOT a correctness issue (that is `recurring_finding`). It routes to a `$comment` rewrite (`suggested_routing.target: schema`), the distinct remediation that makes it its own kind.

Each extracted insight carries its `subject`, `occurrences`, `sources` (snapshot paths — real package-qualified, #6), and A's `observation`. Hold them as analyst-A findings; they are NOT final until verifier B classifies them (Step 4).

## Step 4: Independent verification (verifier B — A->B pattern, design_principle #7)

Analyst A (the miner) cannot judge its own findings without bias. Delegate classification to a **fresh, independent verifier B** — the same A->B contract as `plugin/commands/rules-create.md` and the correctness gates (reuse it, do not invent another — REGLA-0 #3). Apply rule #5 strictly: **B is an explorer — it READS the corpus and CLASSIFIES; it never edits any file.**

Spawn an Agent (`run_in_background=false`) with the model from `agent_config.metacognition_model` in user_pref.json (default `opus`). Pass it ONLY: the list of A's insights (kind, subject, occurrences, sources, observation) and read access to the cited source paths. The verifier prompt:

```
You are verifier B with minimal context by design. Analyst A (the corpus miner) proposes the insights below. Your job is to CLASSIFY each — never to veto, never to edit any file. Apply two lenses:
  - technical: open the cited sources (Read). Do the occurrences actually exist and recur as claimed?
  - value: is this signal worth surfacing, or is it pedantic/over-eager noise?
Classify each insight as exactly one of:
  - confirmed: grounded in the sources and worth acting on.
  - smoke: likely noise, over-eager, or not actually recurring.
  - unverifiable: cannot decide from the corpus available.
  - gold: high-value pattern A may have undersold.
Return ONLY JSON: {"classifications": [{"id": <A insight id>, "classification": "confirmed|smoke|unverifiable|gold", "note": "<one line, optional>"}]}
Do not modify any file. Cite a source path when you downgrade to smoke.
```

Attach B's `classification` to each insight. A's raw `observation` is preserved regardless of B's verdict (B classifies, does not filter — design_principle #7).

## Step 5: Emit corpus-insights.json + suggested routing (NEVER auto-edit)

Assemble the report and write it to `out_path` (default `waves_files/corpus-insights.json`), validating against `corpus_insights_schema.json` (`${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/corpus_insights_schema.json`):

1. `generated_at`, `corpus_scope`, `model`, `corpus_summary` (the counts from Step 1), `broken_artifacts` (pre-existing parse failures — reported, NEVER fixed; product_decision #23).
2. `findings[]` — every insight with its `kind`, `subject`, `occurrences`, `sources`, `observation`, B's `classification`, and a `suggested_routing` (`target`: rules-update / schema / reviewer-prompt / none; `suggestion`: the concrete recommendation).
3. **The routing is SUGGEST-ONLY.** This command writes ONLY `corpus-insights.json`. It does NOT edit `project_rules.json`, any schema, any command, or any logbook. Applying a suggestion is a separate, human-initiated `/waves:rules-update` (or schema/reviewer) task — the human-in-the-loop contract (rule #1: in analysis, present proposals and wait; do not act). A `confirmed`/`gold` insight is a strong suggestion, never an automatic change.

Validate the written file; if it fails the schema, fix the report shape (not the corpus) and re-write.

## Crossing with usage telemetry (`/waves:usage --analyze`)

This miner reads the OUTPUT (artifacts produced); `/waves:usage` (w6 Phase 7) reads the BEHAVIOR (what gets invoked). They are complementary sensors. `corpus-insights.json` is the join target: `/waves:usage --analyze` weights each finding here by how HOT its subject is — a `most_violated_rule` or `field_fill_quality` insight whose subject lives in a command/artifact invoked 50× outranks the same insight on a cold path. The cross lives in `/waves:usage` (it owns the telemetry read); this miner just emits findings with stable `subject`/`sources` so the join is possible. The miner itself never reads telemetry — separation of concerns (REGLA-0 #3).

## Step 6: Summary

Present, in the user's language: counts mined (logbooks_total vs logbooks_with_analyses — surface the DENOMINATOR so waves that predate the analysis files do not distort how rare/common a finding looks; each analysis type incl. the `other` bucket; broken_artifacts), and the findings grouped by B's classification (confirmed / gold first, smoke last), each with its `subject`, `occurrences`, and `suggested_routing`. State plainly that nothing was changed — `corpus-insights.json` is a proposal the user can act on via `/waves:rules-update` or a schema/reviewer edit. End by pointing to the output path.
