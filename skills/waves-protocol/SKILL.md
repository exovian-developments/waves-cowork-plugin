---
name: waves-protocol
description: >
  This skill should be used when the user asks to "initialize a project",
  "create a manifest", "create rules", "create a logbook", "update a manifest",
  "analyze project structure", "track development progress", "create a roadmap",
  "update roadmap", "analyze feasibility", "run feasibility analysis",
  "create a foundation", "create a blueprint", "product blueprint",
  or needs guidance on structured context for AI agents.
  Also triggers for "waves", "project context", "coding rules",
  "development logbook", "ticket resolution", "user preferences", "roadmap",
  "product roadmap", "phase planning", "feasibility", "monte carlo",
  "bayesian analysis", "product foundation", "product blueprint",
  "product lifecycle", or any workflow involving project manifests,
  standards, product planning, or multi-session continuity.
version: 1.3.1
---

# waves Protocol

A structured context protocol for AI agents that provides interactive commands and JSON schemas to manage project context, coding rules, and development logbooks.

## Core Concepts

**Two types of context:**
- **Global Context** — Project manifests, coding rules, user preferences (read at session start)
- **Focused Context** — Development logbooks for tickets/tasks with objectives and progress tracking

**Schema authoring contract (product_rule #13 — every field is born compliant):** Each JSON schema field carries two layers:
- `description` = **WHAT** the field represents (for the reader)
- `$comment` = **HOW** to fill it. For every capped prose field, the `$comment` follows the **STOP + REDIRECT + bad→good** standard (product_rule #12):
  - **STOP:** one unit per field — if the value lists with `+` / `y`/`and` / an em-dash / a colon-list / two verbs, it is multi-concern; split it.
  - **REDIRECT:** what is forbidden here → which field/artifact it belongs in instead. A prohibition without a destination does not suppress content, it relocates it to invented fields.
  - **bad: → good:** one concrete rewrite pair (a one-line example does not inoculate against real verbosity).

**Schemas stay OPEN (design_principle #11):** never `additionalProperties:false`. Validate known fields strictly (type, maxLength, required); let extras pass — a recurring invented field is *signal* for the corpus miner, not an error.

**ROOT `$comment` carries the CANONICAL SHAPE:** the allowed top-level keys + the line *"an undeclared sibling field is the signal you are writing in the wrong artifact."* Mid-flight adopters read the root, not the `$defs`.

Worked example: the root `$comment` of `references/product_blueprint_schema.json`.

## Project Types Supported

| Type | Manifest | Rules/Standards | Logbook |
|------|----------|----------------|---------|
| **Software** | `project_manifest.json` | `project_rules.json` | `logbook_software_schema.json` |
| **Academic** | `research_manifest.json` | `project_standards.json` | `logbook_general_schema.json` |
| **Creative** | `creative_manifest.json` | `project_standards.json` | `logbook_general_schema.json` |
| **Business** | `business_manifest.json` | `project_standards.json` | `logbook_general_schema.json` |
| **General** | `general_manifest.json` | `project_standards.json` | `logbook_general_schema.json` |

## File Structure

After setup, a project will have:
```
project/
├── waves_files/
│   ├── schemas/                    # JSON schemas (reference)
│   ├── user_pref.json              # User preferences
│   ├── project_manifest.json       # Project analysis
│   ├── project_rules.json          # Coding rules
│   ├── feasibility.json            # Feasibility analysis (one per project)
│   ├── foundation.json             # Product foundation
│   ├── blueprint.json              # Product blueprint
│   └── waves/
│       ├── sub-zero/
│       │   ├── roadmap.json
│       │   └── logbooks/
│       ├── w0/
│       │   ├── roadmap.json
│       │   └── logbooks/
│       ├── w1/
│       │   ├── roadmap.json
│       │   └── logbooks/
│       │       └── <slug>/                    # one directory per logbook
│       │           ├── logbook.json           # the logbook itself (fixed name)
│       │           ├── integrity-audit.json   # A6 (logbook-create)
│       │           ├── correctness-postplan.json   # A7 (logbook-create)
│       │           ├── correctness-postimpl.json   # Step 9.8 (objectives-implement)
│       │           └── resolution.md        # resolution-create
│       └── wN/
│           ├── roadmap.json
│           └── logbooks/
│               └── <slug>/ ...
└── CLAUDE.md                       # Updated with preferences reference
```

## Directory-per-logbook convention (design_principle #11)

Artifacts co-locate by unit of work: **one directory per logbook holds the logbook and all its analyses**, so the directory IS the unit of intelligence the corpus miner navigates. This replaces the old scattered split (`logbooks/X.json` + a sibling `audits/logbook-X.json` + `resolutions/X.md`).

- **Directory:** `waves_files/waves/<wave>/logbooks/<slug>/`, where `<slug>` is the logbook's basename without `.json` (e.g. `phase_1`, `L03-2-867-installer-core`).
- **Fixed filenames** inside the directory — every path derives from the logbook name with zero guessing:
  - `logbook.json` — the logbook (always this name, not `<slug>.json`).
  - `integrity-audit.json` — logbook-create Step A6, which runs in two stages so **"audited" implies "valid"**: (1) a deterministic schema validator that BLOCKS on hard `type`/`required`/`maxLength` failures (extras pass — schemas are OPEN, design_principle #11), then (2) the semantic integrity reviewer subagent. Report validates against `integrity_audit_schema`.
  - `correctness-postplan.json` — post-plan gate (Step A7); `correctness_gate_schema` with `boundary: post_plan`.
  - `correctness-postimpl.json` — post-impl gate (objectives-implement Step 9.8); `correctness_gate_schema` with `boundary: post_impl`.
  - `resolution.md` — resolution-create output; `ticket_resolution_schema`.
- **Transition:** commands READ both layouts (the old flat `logbooks/X.json` and the new `<slug>/`) until `migrate_v2_to_v3` relocates existing artifacts; they WRITE only the new layout. Forward-only.

## Correctness gate reviewers — input isolation (4 lenses)

The gates dispatch parallel reads-only reviewers, each paired with an inline verifier B (classifies `confirmed | smoke | unverifiable | gold`, never vetoes): **3 at post-plan** (`waves-correctness-reviewer`, `waves-silent-failure-hunter`, `waves-cross-consistency-reviewer`) and **4 at post-impl** (plus `waves-coverage-gap-analyzer` — diff paths no test exercises; it only exists where tests exist). Two structural rules, encoded from a cross-agent defect report (Diamond PR 503: an author-coupled review missed 8 real findings an isolated external review caught):

- **Input isolation is a guarantee of the dispatching command:** reviewer prompts are built ONLY from the artifact + its requirements (diff/plan, changed files, file tree, `test_cases`, test corpus). FORBIDDEN: the author's reasoning, implementation narrative, commit-message justifications, prior reviews' conclusions, the author's transcript. The reviewers also defensively discard author rationale if it leaks (their `Input contract` section).
- **Anti-refilter rule:** B's verdicts are authoritative external signal — the main agent may not discard or downgrade a `confirmed`/`gold` finding by re-reasoning from its own framing; the only dissent channel is a documented `correctness_gate_override` in `resolved_decisions`. A fallen lens marks the gate `degraded`, never silently passes.

## Corpus mining — second-order metacognition (design_principle #11)

Once every analysis persists and co-locates (above), the framework can read its own corpus and improve from it. `/waves:corpus-mine` is that organ: on demand, it walks every logbook's analyses across waves/projects and emits `corpus-insights.json` — recurring findings, most-violated rules, most-omitted edge_cases, **emergent fields** (invented fields that recur = officialization candidates; `parent_main_id` was the first), and **field-fill quality** (declared prose fields chronically over-filled/multi-concern → `$comment` rewrite). The corpus is heterogeneous (mixed flat/dir layouts, v2/v3 snapshots — product_decision #23): the walker reads **defensively** (a missing v3 field means "predates the field", never a violation). Every insight is A→B-verified (design_principle #7) and routing to rules/schema/reviewers is **suggest-only** — the command writes nothing but `corpus-insights.json` and never edits a governed artifact (human-in-the-loop). Detail in FRAMEWORK.md §24; the spec is the manual run at `waves_files/waves/w6/audits/corpus-insights-comment-quality.md`.

## diverged_work — lightweight divergent work (design_principle #11, w6 Phase 6)

Small work that surfaces mid-flight (during **design** OR **testing**) and diverges from the current thread has nowhere to live but a `recent_context` note — invisible to the corpus miner. `/waves:diverged-work-create` gives it a mineable home: the lightweight sibling of a logbook (schema `diverged_work_schema.json`) — one `title`, `trigger_context`, a closed `scope`, a `completion_guide`, and **one** `verification`. **No** main/secondary decomposition, **no** orthogonality review. **When to use it vs a logbook:** if the work is one concern with a bounded scope and a single deterministic check, it is a diverged_work; if it needs multiple dimensions or an unbounded blast radius, it is a logbook. That judgment is not yours to assert — an adversarial auditor tries to **refute** three gates (single_dimension / closed_scope / self_verifiable) and sets `disposition`: **executable** (all gates pass → the object IS the subagent prompt, run it now + its verification) or **promoted** (any gate refuted, or doubt → the object IS the seed for `/waves:logbook-create`). Doubt always resolves to `promoted` — the anti-fragmentation rail. The auditor (A) assigns; the main agent (B) re-judges (`reviewer_verdict`, A→B, design_principle #7). Lineage `diverged_work[promoted] → logbook → resolution` is traced by the corpus miner. Detail in FRAMEWORK.md §25.

## Usage telemetry — the behavioral sensor (design_principle #11, w6 Phase 7)

The corpus miner reads the OUTPUT (artifacts); usage telemetry reads the BEHAVIOR (what gets invoked) — two complementary sensors. Captured zero-token by `waves-telemetry.sh` (a bash hook on PreToolUse[Skill]/PreToolUse[Agent]/PostToolUse[Skill] + the enforcement hooks self-logging their firing/blocks), SILENT and ALWAYS exit 0 (a telemetry failure never breaks a command), opt-out via `.claude/waves-telemetry-off`, local-first (no server). MULTI-LOG by type (dp#11): `commands.jsonl`/`hooks.jsonl`/`subagents.jsonl` under `$CLAUDE_PLUGIN_DATA/telemetry/`, schema `usage_event_schema.json` `{ts,name,event,session,scope,thread,inv}`. Two-level correlation **thread ⊇ inv**: `inv` = one command invocation + its child events (footprint, good-vs-broken); `thread` = the work-unit served (logbook/diverged_work/blueprint) — which makes the telemetry thread the SAME node as the artifact lineage. `/waves:usage` renders the heat map (frequency/jewels, recency, friction, block-rate, maturation trend, per-invocation footprint) with zero LLM tokens; `--analyze` crosses with `corpus-insights.json` to weight findings by usage. The data model was grounded by a simulate-before-building exercise (FINDINGS.md), not inferred. **v1 capture (verified vs the Claude Code hook API):** command invocations (UserPromptSubmit + PreToolUse[Skill], defensive name read), subagent spawns, and hook fired/blocked all capture live. RESERVED (designed, not yet live): per-command good-vs-broken outcomes (no PostToolUse for Skill) and the `thread` column (no `active-thread` writer wired yet — forward-compatible, inert). Detail in FRAMEWORK.md §26.

## Cost telemetry — the economic sensor (design_principle #13, w6 Phase 8)

The THIRD sensor: the corpus miner reads OUTPUT, usage telemetry reads BEHAVIOR, this reads ECONOMICS — what each unit of work costs in tokens and frozen USD, to project costs for companies (USD/person). Granularity = **primary objective**. An ODOMETER hook (`waves-cost.sh`, a sibling of the metacognition hook — separate process, so zero interference with the gate by construction) fires on each primary-completion: it accumulates `message.usage` by model across the session transcript + the subagents' transcripts (`<session>/subagents/*.jsonl`), subtracts the per-logbook checkpoint, attributes the delta to the just-closed primary, and FREEZES the USD with `pricing.json` + the current `waves_version`. The result is a **co-located `cost.json`** (location = semantics, dp#11): per-primary `{tokens cache-vs-normal, frozen usd}` that SUM to the logbook total; a single-total file for a `diverged_work`. The four token types matter — `cache_read` bills ~0.1×, so a naive total×price overstates ~10×. USD is frozen (a per-release snapshot), so `/waves:cost` reports it as captured — never recomputed. Robust to mid-primary compaction (the transcript persists). `/waves:cost` renders the business report (per logbook / roadmap / project, + the release-over-release efficiency curve by `waves_version`); `--cross` multiplies cost × the Phase 7 heat-map frequency = **USD/person/month**. Silent/exit-0/opt-out, local-first. Detail in FRAMEWORK.md §27.

## Foundational write-time coverage — closing the inversion (design_principle #7, w6 Phase 9)

Extends design_principle #7 (every analyst A is followed by an independent verifier B) to the **foundational** write paths it was never retrofitted onto. The verification layer (dp#8) covers logbooks and code; the highest-blast-radius artifacts — **blueprint, roadmap, foundation, resolution** — carried ZERO write-time adversarial verification (the coverage *inversion*: the most impactful artifacts had the least checking). The artifact is authored by the main agent; the adversarial review is **delegated to fresh subagents to remove author bias**; the verifier **classifies, never vetoes** — the main agent decides with both A and B.

Two surfaces, one A→B pattern:
- **Hook** `waves-foundational-audit.sh` (`PostToolUse[Edit|Write]`) covers **blueprint + roadmap**, branching by filename and keying on the **write path** (multi-project: a blueprint at `projects/<name>/waves_files/` is audited identically). It is a **distinct axis from `waves-blueprint-impact.sh`, not a fusion** — blueprint-impact projects the downstream CASCADE; foundational-audit checks INTERNAL COHERENCE (orphan principle↔rule, capability↔flow coverage, contradictory decisions, phase↔capability traceability, dependency cycles, born-compliance/`$comment` fill-quality). Both may fire on one blueprint edit. Reuses the metacognition A→B scaffolding verbatim (the `metacognition-pending` gate marker, shared cooldown, `META_MODEL`, scope-resolve); net-new = only the branched check list.
- **In-command** covers **foundation + resolution** (no stable PostToolUse trigger). `/waves:foundation-create` Step 7.5 audits the essential/important/desired re-classification vs the feasibility evidence; `/waves:resolution-create` Step 2.5 runs a no-fabrication audit (each claim `supported`/`unsupported`/`overstated` vs achieved objectives + audit reports). resolution runs **last** — lowest-frequency path, highest-trust artifact.

**Fill-quality (product_rule #12)** at creation is realized *inside* these checks (flag thin/boilerplate `$comment` on new prose), not as a separate step. **The `project_manifest.json` is EXCLUDED by design** — it is a derived, low-trust map whose risk is *staleness*, not mis-writing; its net is freshness (w6 Phase 10), not write-time consistency. Do not add it here. Detail in FRAMEWORK.md §28.

## Manifest freshness — the commit-boundary semantic-index sync (capability #8, w6 Phase 10)

The manifest is a DERIVED map; its risk is **staleness**, not mis-writing (this is the OTHER axis from the §28 foundational coverage — freshness, not consistency). The manual `/waves:manifest-update` went unused for months (product_decision #26), so a non-blocking `PostToolUse[Bash]` hook (`waves-manifest-freshness.sh`) keeps it fresh at the commit boundary. It runs a **zero-token deterministic pre-filter**: the manifest maps CODE only, so a commit touching ONLY `waves_files/` / docs / lockfiles early-exits at zero cost; a code diff emits `additionalContext` DELEGATING a graduated analysis to the agent (metacognition delegation pattern — the hook stays deterministic, the spend is proportional and visible, NOT a new hook class).

The delegated analysis (Flow C of `/waves:manifest-update`) recovers INTENT from the **Waves artifact co-committed in the same diff** (logbook / roadmap / diverged_work), not the commit message — the why travels in the diff. It classifies magnitude (cosmetic → no-op; structural → update the section; new-capability → deep analyzer pass reusing manifest-create scoped to changed files) with a budget proportional to impact. Two entry points: Flow C (automatic, primary) vs the manual full re-scan Flows A/B (fallback for first-sync / drift recovery).

The net-new prerequisite was **`relations[]`** in all 3 manifest schemas — a directed edge `{from, to, kind, why}` capturing the blast-radius couplings grep cannot see (feature↔endpoint↔flag, subagent↔tool↔governance). `kind` is OPEN; `why` is required (the consequence is the point). This graph is the substrate the cost sensor (cost-per-component), corpus miner (findings-per-region), and correctness layer all read. Detail in FRAMEWORK.md §29.

## Command Flow

```
project-init
  → manifest-create
    → rules-create
      → feasibility-analyze
        → foundation-create
          → blueprint-create
            → roadmap-create
              → logbook-create
                → logbook-update
                  → resolution-create

(roadmap-update operates in parallel with logbook-update to track phase progress)

Product lifecycle: feasibility (CAN WE?) → foundation (WHAT DID WE LEARN?)
  → blueprint (WHAT/WHY) → roadmap (WHEN/ORDER) → logbook (HOW)
```

Each command is an orchestrator that dispatches to specialized agents for heavy analysis work. The main thread stays lean — it handles user interaction and file writing while agents do the deep reading/analysis.

Roadmap commands integrate at the product-level orchestration layer, sitting above logbook commands which handle detailed milestone implementation.

## Agent Dispatch Pattern

When a command needs analysis, use the Task tool to launch the appropriate agent:
1. Prepare a clear input prompt with project_root, relevant context, and what to analyze.
2. Launch the agent via Task tool.
3. Receive structured JSON results.
4. Present findings to the user.
5. Write output files based on user approval.

**Critical principle:** Always dispatch analysis work to agents. Never do deep code scanning or multi-file analysis in the main thread. This preserves context for long work sessions.

## Schemas Reference

All JSON schemas are in `references/`:
- `user_pref_schema.json` — User interaction preferences
- `software_manifest_schema.json` — Software project structure
- `general_manifest_schema.json` — Non-software project structure
- `project_rules_schema.json` — Coding rules and patterns
- `project_standards_schema.json` — Standards for general projects
- `feasibility_analysis_schema.json` — Pre-blueprint feasibility with Monte Carlo and Bayesian
- `product_foundation_schema.json` — Compacted feasibility into validated facts
- `product_blueprint_schema.json` — Complete product definition
- `company_blueprint_schema.json` — Multi-product company strategy
- `logbook_roadmap_schema.json` — Product-level roadmap with phases and milestones
- `logbook_software_schema.json` — Development logbook with code refs
- `logbook_general_schema.json` — Task logbook with doc refs
- `ticket_resolution_schema.json` — Ticket closure summary
- `change_manifest_schema.json` — Change detection for manifest updates
- `integrity_audit_schema.json` — logbook-create A6 integrity audit report
- `correctness_gate_schema.json` — post-plan / post-impl correctness gate report (one schema, `boundary` field)
- `corpus_insights_schema.json` — corpus-mine output: A→B-verified, suggest-only insights across the corpus
- `diverged_work_schema.json` — diverged-work-create output: a lightweight divergent-work unit with a 3-gate audit → disposition executable|promoted
- `usage_event_schema.json` — one usage-telemetry event line (commands/hooks/subagents.jsonl); the behavioral sensor, thread ⊇ inv correlation
- `cost_schema.json` — co-located cost.json: per-primary tokens (cache vs normal) + frozen USD summing to the logbook total; the economic sensor
- `pricing.json` — configurable model×token-type rate table the odometer applies to freeze USD (referenced by cost.json's pricing_ref)

Read the appropriate schema before generating any JSON file to ensure compliance.

## Roadmap Hierarchy

The waves protocol organizes product planning in three levels:

```
BLUEPRINT (WHY + WHAT)
  ├── Project vision and goals
  ├── Feature categories
  └── Strategic objectives

    ↓ (informs)

ROADMAP (WHEN + ORDER)
  ├── Phases (3-5 ideal, max 7)
  ├── Milestones with acceptance criteria
  ├── Phase dependencies and sequencing
  └── Strategic decisions and open questions

    ↓ (spawns)

LOGBOOK (HOW + DETAIL)
  ├── Objective breakdown (per milestone)
  ├── Implementation progress
  ├── Technical decisions and code references
  └── Completion guide and recommendations
```

**Key distinctions:**

| Aspect | Blueprint | Roadmap | Logbook |
|--------|-----------|---------|---------|
| **Scope** | Product-wide | Phase-wide | Milestone-specific |
| **Detail** | Business & vision | Strategy & sequencing | Implementation & code |
| **Audience** | Stakeholders | Product team | Dev team |
| **File Type** | manifest.json | waves/*/roadmap.json | waves/*/logbooks/*.json |
| **Update Frequency** | Once/project | Weekly/monthly | Per work session |

**Relationship:**
1. The **blueprint** (manifest) defines "what we're building and why"
2. The **roadmap** plans "when and in what order"
3. The **logbook** tracks "how we're building it"

Roadmaps spawn logbooks — each milestone in a roadmap can have a corresponding logbook that contains detailed implementation progress. Use `logbook_ref` field in milestone to link them.

## Rule Creation Criteria

All rules must meet ALL criteria (from schema `$comment`):
1. Promotes project-wide consistency
2. Improves code clarity, structure, maintainability
3. No contradictions with existing rules
4. Establishes implementation patterns (not tool config)
5. Context-independent (applicable without special knowledge)
6. YAGNI compliant (current needs, not hypothetical)

## Logbook Conventions

- **IDs:** Integer starting at 1, immutable once created
- **Timestamps:** UTC ISO 8601, `created_at` immutable
- **Context limit:** 20 recent entries, auto-compacts to history_summary
- **History limit:** 10 summaries max
- **Status values:** `not_started`, `active`, `blocked`, `achieved`, `abandoned`
- **`achieved` is conditional (design_principle #8):** for every NEW primary, status `achieved` requires that all entries in `verification_demonstrations` have `verdict='pass'`. Historical primaries are grandfathered (forward-only).

## Verification Layer (design_principle #8 — Waves 3.0+)

> **Demonstration over declaration.** A primary outcome is marked `achieved` only when there is observable executable evidence that verifies it does what it declared. LLM self-declaration alone is no longer a valid completion contract.

**Field:** `main_objective.verification_demonstrations` (array, minItems=1) — present on logbook_software_schema.json and logbook_general_schema.json. Each entry: `{type, target, expected, command_or_method, verdict, verified_at, evidence}`.

**Taxonomy (10 types):**
- Software-leaning: `unit_test`, `integration_test`
- Agentic / cross-format: `sandbox_execution`, `schema_validation`, `behavior_check`
- Cross-cutting: `release_verification`, `state_change_verification`, `external_observation`, `documentation_consistency`, `adversarial_review`

**Protocol (logbook-create A4.5 + A4.6, both unconditional fresh subagents):**
1. **A4.5 verification-designer** proposes type-aware demonstrations per primary based on `scope.files` extensions + content keywords.
2. **A4.6 feasibility-checker** verifies local deps deterministically (`command -v`, `gh auth status`, etc.). If `missing_deps` are detected, A4 inserts provisioning secondaries BEFORE implementation — blocks "paper demonstrations" by construction.

Detail lives in `commands/logbook-create.md` Phase 4 w4 section. SKILL.md only orients to the concept.

**Project-type rules of thumb (lens dispatch at Phase 3 w4 / objectives-implement Step 7.5):**
- Software primaries → `unit_test` + `integration_test` (test-critic lens).
- Agentic primaries (`.md` commands, `.sh` hooks, `.json` schemas) → `sandbox_execution` + `behavior_check` + `schema_validation` (behavior-critic lens).
- General primaries → `external_observation` + `documentation_consistency` + `adversarial_review` (evidence-critic, OPT-IN via verification rule).

**Forward-only contract (blueprint decision #15):** historical logbooks without the field continue to validate. New logbooks must populate it via A4.5+A4.6. There is no retroactive re-audit.

**Governance:** the `verification` category in `project_rules.json` (universal, available for all project types) holds tunable thresholds — stub-check floors, evidence-critic opt-ins, feasibility-checker strictness per type.

## Multi-project Path Resolution (Waves 3.x)

> Parent repo's `waves_files/` holds company-level governance. Real products live at sibling `projects/<name>/`, each with its own `waves_files/` for its own waves artifacts. `--project <name>` flag selects which child the command operates on. Commands resolve their working path through this helper.

**Path semantics** (design_principle #9):

- `waves_files/` at repo root = waves artifacts of the PARENT (company / meta-project blueprint, rules, manifest, roadmaps).
- `projects/<name>/` at repo root = a real product (own code, own git typically, own resources).
- `projects/<name>/waves_files/` = waves artifacts of that product specifically.

The folder `waves_files/` only ever contains waves artifacts. The folder `projects/` only ever contains products. Mixing them (placing products inside `waves_files/`) breaks the semantic contract — humans read paths and expect them to mean what they say.

**Mode detection:** filesystem inference, no state field.

- If `projects/` exists at repo root with at least one subdirectory → repo is in multi-project mode.
- Otherwise → repo is in single-project mode (legacy / default).

**Path resolution rule** (apply at the top of any command that reads or writes Waves artifacts):

1. Parse `--project <name>` from the command arguments.
2. **If flag is present:**
   - Set `base_path = projects/<name>/waves_files/`.
   - Validate that `projects/<name>/` exists. If it does not, ABORT with:
     ```
     ❌ Project scope '<name>' not found at projects/<name>/.
        Run /waves:projects to list available scopes, or /waves:project-add <name> to create it.
     ```
   - If `projects/<name>/` exists but `projects/<name>/waves_files/` does not, the scope was created externally (cloned product repo). The command must `mkdir -p` the `waves_files/` and proceed — the child product simply hasn't been initialized with waves artifacts yet.
3. **If flag is absent:**
   - Set `base_path = waves_files/` (parent / company root; identical to pre-3.x behavior in single-project repos).
4. Use `base_path` for all subsequent artifact reads/writes within the command (logbooks, manifest, rules, roadmap, etc.).

**Three structural patterns supported** (same physical layout, different git policy):

| Pattern | `.gitignore /projects/` in parent? | Each child has own `.git/`? |
|---------|------------------------------------|------------------------------|
| **Monorepo** (e.g., Exobase) | No — projects are part of parent's git | No — single git for everything |
| **Workspace-parent** (e.g., QAT) | No — projects are part of parent's git | No — but the parent repo is the user's working repo, NOT the target product's repo |
| **Ecosystem of independent gits** (e.g., Exovian holding) | Yes — single line `/projects/` | Yes — each child is a real cloned product repo |

Same Waves code handles all three. The user's `.gitignore` policy + how children get into `projects/` (mkdir vs git clone) determines the pattern.

**Standalone child sessions:** a user can `cd projects/<name>/` and open Claude Code there. From that vantage point the child is just a normal Waves project — its `waves_files/` is the root, its blueprint can optionally declare `parent_blueprint: ../../waves_files/blueprint.json` to inherit company governance via the tree-blueprint mechanism. No `--project` flag needed at child level.

**Backwards compatibility:** commands invoked without `--project` in any existing single-project repo behave exactly as before 3.x. The flag is purely additive.

**Commands that accept `--project`** (apply the helper above): `blueprint-create`, `logbook-create`, `logbook-update`, `objectives-implement`, `roadmap-create`, `roadmap-update`, `rules-create`, `rules-update`, `manifest-create`, `manifest-update`, `resolution-create`, `corpus-mine`, `diverged-work-create`, `cost`.

**Commands that do NOT accept `--project`** (operate at root or plugin level only): `project-init`, `feasibility-analyze`, `foundation-create`, `upgrade`, `version`, `migrate-from-v2-to-v3`, `projects`, `project-add`, `project-remove`, `migrate-to-projects`.

Detail and edge cases live in the `/waves:projects` command family. SKILL.md only carries the canonical helper spec referenced by every consumer command.

## Root-only Prerequisite Validation (Waves 3.x)

> Prerequisite artifacts are validated at root ONLY, regardless of multi-project mode. Scopes inherit root governance and do not need their own copies.

**What "prerequisite" means:** the minimum set of artifacts a command needs to operate — `user_pref.json`, `project_manifest.json`, `project_rules.json`, plus any blueprint or roadmap the command depends on (e.g., `blueprint-create` requires a foundation, `logbook-create` requires a blueprint and an active roadmap).

**Rule:** every prereq existence check reads from `waves_files/<artifact>` directly (the parent's waves_files), never from `projects/<name>/waves_files/<artifact>` (the child's). Whether the user passed `--project <name>` does NOT affect prereq check paths.

**Scope inheritance:** a child product at `projects/<name>/` operates correctly without owning a blueprint, roadmap, manifest, or rules of its own — it inherits everything from the parent's `waves_files/`. Scoped artifacts (when the child does declare its own) ADD on top of parent governance, they do not REPLACE the prereq check itself.

**Error messages:** when a root prereq is missing in multi-project mode, the abort message points to root setup, NEVER to a per-scope path. Example: "Run /waves:project-init at root first — multi-project scopes inherit root prerequisites."

**Relation to the Multi-project Path Resolution helper:** the `base_path` returned by that helper applies to WORK artifacts (logbooks the command will write, scoped rules/manifest/blueprint when the child owns them), NOT to prerequisite existence checks. Prereqs are parent-only by design.

**Why this matters:** corporate / external repos (e.g., a contractor working inside a client repo where they cannot make Waves visible at the top level) only need root setup once to operate N scoped child products. Without root-only inheritance, every child would require its own prereq files, defeating the purpose of multi-project mode.

## Analysis Principle

> "99.9% of software projects have bad practices. ALWAYS find at least 1-5 critical issues. Do not assume the code is perfect."

This principle applies to all analysis agents. Be constructive, not critical.

## User Questions Convention

All questions to the user include option `0. I don't know (auto-detect)` so the user is never blocked if they don't have the answer.

## Cloning Remote Repos

When the user provides a GitHub URL instead of a local folder:
1. Clone the repo to a temporary working directory
2. Run the requested analysis on the cloned repo
3. Save output files (manifest, rules, etc.) to the user's workspace folder
4. Inform the user where the files were saved
