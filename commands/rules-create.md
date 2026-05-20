---
description: Extract coding rules/standards from the project codebase (software) or guide the user through defining standards (general projects).
---

# Command: /waves:rules-create

You are executing the waves rules creation command. Follow these instructions exactly.

## Your Role

You are the main orchestrator for project rules/standards creation. For software projects, you analyze existing code to extract patterns and conventions. For general projects, you guide the user through defining standards.

## Step -1: Prerequisites Check (CRITICAL)

1. Check if `ai_files/user_pref.json` exists.
   - IF NOT EXISTS → Display: "⚠️ Missing configuration! Run /waves:project-init first." → EXIT COMMAND

2. Read `ai_files/user_pref.json`:
   - Extract `user_profile.preferred_language` → Use for all interactions
   - Extract `project_context.project_type` → Determines main flow

3. IF `project_type === "software"` OR `project_type === "agentic"`:
   - Check `ai_files/project_manifest.json` exists
   - IF NOT EXISTS → Display: "⚠️ Run /waves:manifest-create first." → EXIT COMMAND

4. Check if rules file already exists:
   - Software / Agentic → `ai_files/project_rules.json`
   - General → `ai_files/project_standards.json`
   - IF EXISTS → Ask: "Rules already exist. Overwrite / Merge / Cancel?"

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Command Explanation

Display in user's language:
```
📘 Command: /waves:rules-create

[If software]:
I'll analyze the existing code to identify patterns,
conventions, and also detect potential antipatterns.

[If general]:
I'll guide you to define the standards you need
for your project.

Continue? (Yes/No)
```

IF No → Exit.

## Step 1: Fork by Project Type

- IF `project_type === "software"` → Go to **Flow A**
- IF `project_type === "general"` → Go to **Flow B**
- IF `project_type === "agentic"` → Go to **Flow C**

---

## Flow A: Software — Layer-Based Analysis

### Step A1: Read Project Manifest

1. Read `ai_files/project_manifest.json`
2. Extract: `primary_language`, `framework`, `architecture_patterns_by_layer`, `modules`, `features`
3. Show project context summary and ask which layer to analyze:

```
📊 Project context (from manifest):

Language: [language]
Framework: [framework]
Type: [frontend/backend/fullstack]

Detected layers:
[List layers from manifest]

Which layer to analyze?

1. architecture
2. presentation_layer
3. data_layer
4. api_layer
5. naming_conventions
6. testing
7. infra
8. All layers (full analysis)

Choose 1-8:
```

### Step A2: Invoke Analysis Subagents (in parallel)

For each selected layer, invoke these 3 subagents IN PARALLEL:

**Subagent 1: pattern-extractor** (read from `subagents/22-pattern-extractor.md`)
- Analyzes code in the layer for consistent patterns (3+ occurrences)
- Returns: List of detected patterns

**Subagent 2: convention-detector** (read from `subagents/23-convention-detector.md`)
- Analyzes naming and structural conventions
- Returns: Conventions with consistency percentages

**Subagent 3: antipattern-detector** (read from `subagents/24-antipattern-detector.md`)
- Analyzes code for known antipatterns (educational, constructive tone)
- Returns: Antipatterns with explanations and suggestions

Display progress:
```
🔍 Analyzing layer: [layer]

[✅] Pattern Extractor — [count] patterns identified
[✅] Convention Detector — [count] conventions detected
[⏳] Antipattern Detector — Analyzing...
```

### Step A3: Validate Against Criteria

Use the **criteria-validator** subagent (read from `subagents/25-criteria-validator.md`).

Each pattern/convention must meet ALL criteria from the schema:
- Promotes project-wide consistency
- Improves maintainability
- No contradictions with other rules
- Establishes implementation patterns (not tool config)
- Context-independent
- YAGNI compliant

### Step A4: Present Findings

Display in user's language:
```
📋 Analysis completed for: [layer]

═══════════════════════════════════════
✅ PATTERNS IDENTIFIED ([count] proposed rules)
═══════════════════════════════════════

[For each rule: section, description (max 280 chars)]

═══════════════════════════════════════
⚠️ ANTIPATTERNS DETECTED (Educational)
═══════════════════════════════════════

[For each antipattern: severity, location, problem, suggestion]

Options:
1. Save all proposed rules
2. Review and select individually
3. Analyze another layer
4. See more antipattern details
```

### Step A5: Generate Rules File

Read `ai_files/schemas/project_rules_schema.json` for structure reference.

Generate `ai_files/project_rules.json` with:
- Project info from manifest
- Validated rules organized by section
- IDs starting at 1, incrementing
- `created_at` timestamps in UTC ISO 8601
- Descriptions max 280 characters
- `scope` for each rule: "ecosystem" if the rule applies across all projects in the organization (shared conventions, architecture patterns, naming), "local" if it only applies to this project. Ask the user when uncertain. Within each section, list ecosystem rules first, then local.

Validate the generated file against the schema.

### Step A6: Success Message

```
✅ Project rules created!

📁 File: ai_files/project_rules.json
📊 Rules generated: [count]

By section:
[List sections with rule counts]

⚠️ Antipatterns identified: [count]
(Review the report to improve code quality)

🎯 Next steps:

To analyze more layers:
/waves:rules-create [layer]

To update rules after code changes:
/waves:rules-update

To start working:
/waves:logbook-create
```

---

## Flow B: General Projects — User-Guided Standards

### Step B1: Show Suggestions

Based on manifest type, show relevant standard suggestions:
- Academic: citation format, document structure, tables/figures, file naming
- Creative: file specs, color palette, typography, asset naming
- Business: processes, communication, KPIs, templates
- General: file organization, naming, workflows, documentation

Frame as "ideas" not requirements.

### Step B2: Open Question

```
📝 What standards or rules do you want to define for your project?

Describe freely what you need. I can help you structure it afterwards.

[Show example response relevant to project type]
```

### Step B3: Structure User Input

Use the **standards-structurer** subagent (read from `subagents/26-standards-structurer.md`).

Parse free-form input into structured categories. Show the structured result for confirmation.

If user wants changes → iterate.

### Step B4: Generate Standards File

Generate `ai_files/project_standards.json` with structured standards.

### Step B5: Success Message

```
✅ Project standards created!

📁 File: ai_files/project_standards.json
📊 Categories defined: [count]

[List categories]

🎯 Next step:

To update standards later:
/waves:rules-update

To start working:
/waves:logbook-create
```

---

## Flow C: Agentic — Default Categories + User Refinement

Agentic projects rarely have a code corpus to scan for patterns (the "code" is markdown skills, JSON hook configs, and prompt files). This flow proposes a set of rule categories tuned to **Claude Code agentic primitives** (roles, skills, tools, hooks, state contracts, pipelines, gates, budgets) plus a universal `governing_principles` anchor, and lets the user accept, edit, or extend them. Since `project_rules_schema` sets `unevaluatedProperties: true` for `type=agentic`, the user may also declare **custom categories** beyond the defaults if the domain needs them.

### Step C1: Show Default Categories

Display in user's language:
```
📘 I'll propose default rule categories tuned to Claude Code agentic primitives.
Your project_rules_schema is open for type=agentic — you can accept these,
remove the ones that don't apply, or add custom categories.

Universal (available for any project type, anchors the org governance chain):
  1. governing_principles  — Trans-layer rules (SRP→KISS→YAGNI→OCP→DRY, RESILIENCE, PLACEMENT)

Agentic-native (aligned to Claude Code primitives):
  2. role_design           — Who acts: responsibility, tools_authorized/forbidden, count_pattern, separation of powers
  3. skills_management     — Composition units: markdown_with_frontmatter, versioning, granularity, embedded prompts
  4. tool_use              — Tool selection policy: CLI vs MCP, model selection, prompt caching
  5. hooks_lifecycle       — Hook design: PreToolUse=enforcement, PostToolUse=audit, message clarity
  6. state_contracts       — Persistent state: single-writer-per-file, partitioning, volatility, schema_ref
  7. pipeline_design       — State machine: granular states, stuck_threshold per stage, agent-driven cascade
  8. governance            — Approval gates + audit + scope + observability policy (ApprovalDecision envelope)
  9. budget_and_concurrency— Cost/concurrency: reactive throttling, daily_max_usd, OWNER_INTENSIVE_MODE

Would you like to (a) accept all 9 default categories, (b) edit the list (add/remove/add-custom), or (c) start from scratch?
```

### Step C2: Iterate Per-Category Rule Definition

For each accepted category, ask the user to provide 2-5 concrete rules. The agent helps phrase each rule per the `project_rules_schema.json` shape (`id`, `description`, `scope: ecosystem|local`, `created_at`, max 280 chars). Examples derived from the exobase_med_corpus pilot:

- **governing_principles** (typically `scope: ecosystem`):
  - "REGLA-0: Apply SRP → KISS → YAGNI → OCP → DRY before writing code or design."
  - "REGLA-RESILIENCE: Extract to a shared package early when reusable + cheap."
  - "REGLA-PLACEMENT: Reusable features live in starter kits / ecosystem / isolated packages, not in product code."

- **role_design**:
  - "AGT-ROLE-001: Each subagent has ONE responsibility. If it declares >2 `writes_to` paths from distinct domains, redesign."
  - "AGT-ROLE-002: Separation of powers — who decides ≠ who executes ≠ who signs."
  - "AGT-ROLE-003: No heartbeats. State transition granularity is the only liveness signal; an external verifier observes by cron."
  - "AGT-ROLE-004: Deterministic roles (no reasoning) MUST be Bash workers, not Claude subagents. `tools_authorized` excludes `claude_*`."

- **skills_management**:
  - "AGT-SKILL-001: Skills materialize under `skills/` as markdown_with_frontmatter (Claude Code style). No JSON, no embedded code."
  - "AGT-SKILL-002: `versioning_required: true` when skills produce persistent data — output records skill version for retroactive invalidation."
  - "AGT-SKILL-003: One skill per (source × stage). Extend by composition, not by accretion."

- **tool_use**:
  - "AGT-TOOL-001: CLI default over MCP when possible — CLI doesn't consume Claude tokens, MCP does."
  - "AGT-TOOL-002: MCP only when real-time Claude reasoning is required on the output."
  - "AGT-TOOL-003: Cheapest model that suffices — Haiku for parsing/validation, Sonnet for standard reasoning, Opus only when Sonnet under-delivers."
  - "AGT-TOOL-004: Prompt caching mandatory for context reused across invocations of the same skill (rules, schemas, examples)."

- **hooks_lifecycle**:
  - "AGT-HOOK-001: PreToolUse when enforcing (reject write), PostToolUse when logging/auditing. Never the inverse."
  - "AGT-HOOK-002: Hooks do NOT mutate project state contracts. They validate, log, or redirect."
  - "AGT-HOOK-003: Hooks that reject must emit clear `reason` + `how_to_unblock` (see waves-gate.sh)."

- **state_contracts**:
  - "AGT-STATE-001: Single-writer-per-file. Each state file has exactly ONE `writer_role`; the rest read only."
  - "AGT-STATE-002: Explicit partitioning — `singleton` | `by_<dimension>`. Anti-collision by construction, no locks."
  - "AGT-STATE-003: Volatility declared — `stable` | `volatile` | `ephemeral`."
  - "AGT-STATE-004: Schema-validated. Every state contract has a `schema_ref`."

- **pipeline_design**:
  - "AGT-PIPE-001: Granular states as a resilience primitive. Every transition is an atomic write to the state contract."
  - "AGT-PIPE-002: `stuck_threshold_seconds` declared per stage (fetching ≠ parsing ≠ indexing)."
  - "AGT-PIPE-003: Agent-driven cascade. No stage 'waits'; it finishes, writes, and the next role observes the state change."
  - "AGT-PIPE-004: Verifier cron ≤ shortest stuck_threshold."

- **governance** (gates + audit + observability policy):
  - "AGT-GOV-001: Critical operations (INSERT to DB, send_external, modify_persistent) require an `approval_gate` with auditor sign-off."
  - "AGT-GOV-002: Graduated gates — `auto_approve_when` free condition + `fallback: human_approval | block | log_only`. Never binary without escalation."
  - "AGT-GOV-003: `ApprovalDecision { verdict, reason, evidence_refs[] }` is the canonical envelope of every auditor."
  - "AGT-GOV-004: `log_level: decisions_full` for regulated domains; `audit_critical_decisions: true`."

- **budget_and_concurrency**:
  - "AGT-BUDGET-001: Reactive throttling, not preventive. Start with an ambitious target; lower only when measurable signals show contention."
  - "AGT-BUDGET-002: `daily_max_usd` declared per project. Orchestrator monitors and escalates to owner near limit."
  - "AGT-BUDGET-003: When ambient Max plan usage > 70% weekly, lower `claude_subagent_concurrent_target` automatically."
  - "AGT-BUDGET-004: `OWNER_INTENSIVE_MODE` env var drops project to minimal footprint — owner's human work is priority."

For each rule entered, the agent records `scope: "local"` by default unless the user explicitly says it applies ecosystem-wide.

**Reminder for custom categories:** since `type=agentic` sets `unevaluatedProperties: true` on the rules object in `project_rules_schema`, you may propose categories beyond the 9 defaults if your domain warrants it (e.g. `medical_compliance`, `pii_handling`, `multi_tenant_isolation`). The schema will validate them as bucket arrays of standard rule objects. KISS reminder: prefer fitting rules into existing categories when the fit is reasonable — only add a custom category when you have ≥3 rules that genuinely don't belong elsewhere.

### Step C3: Generate Rules File

Build the JSON populating `rules: { [category]: [array_of_rules] }`. Within each section, ecosystem rules go first, then local. Validate against `project_rules_schema.json`. Save to `ai_files/project_rules.json` (same path as software — the type is inferred from project_type in user_pref and persisted in the `type` field of the file as `"agentic"`).

### Step C4: Success Message

```
✅ Project rules created!

📁 File: ai_files/project_rules.json
📊 Categories defined: [count] ([N] defaults + [M] custom)
📊 Total rules: [count]

Categories:
  [For each category:] • [name] ([N] rules — ecosystem [E] / local [L])

🎯 Next step:

These rules will be referenced from logbook objectives' scope.rules
and surfaced in the implementer banner during /waves:objectives-implement.

To update rules later:
/waves:rules-update

To start working:
/waves:logbook-create
```

---

## Subagents Reference

| Subagent | File | Flow |
|----------|------|------|
| pattern-extractor | `subagents/22-pattern-extractor.md` | A |
| convention-detector | `subagents/23-convention-detector.md` | A |
| antipattern-detector | `subagents/24-antipattern-detector.md` | A |
| criteria-validator | `subagents/25-criteria-validator.md` | A |
| standards-structurer | `subagents/26-standards-structurer.md` | B |

END OF COMMAND
