---
description: Continuously implement logbook objectives with business-aware code generation, automatic auditing, real-time logbook updates, and context-window-aware session management.
---

# Command: /waves:objectives-implement

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.

You are executing the waves implement command. Follow these instructions exactly.

## Multi-project scope

Apply the **Multi-project Path Resolution** helper from `plugin/skills/waves-protocol/SKILL.md` before any other step:

- Parse `--project <name>` from the command arguments.
- If present: set `base_path = projects/<name>/waves_files/` and validate that projects/<name>/ exists (abort with a "scope not found" error if it does not).
- If absent: set `base_path = waves_files/` (backwards-compatible default — identical to pre-3.x single-project behavior).

Use `base_path` for every `waves_files/...` reference in the steps below. When the steps say `waves_files/<artifact>` they mean `<base_path><artifact>` in multi-project mode.

When `--project` is present, also write the **session marker** via bash BEFORE any artifact operation — this is what makes the active scope visible to hooks (`plugin/hooks/_lib/scope-resolve.sh`) when they fire on subsequent Edit/Write:

```bash
mkdir -p "${CLAUDE_PLUGIN_DATA}/markers/${CLAUDE_SESSION_ID:-default}"
printf '%s=%s\n' "$(printf '%s' "$PWD" | { md5 -q 2>/dev/null || md5sum | awk '{print $1}'; })" "<scope_name>" \
  > "${CLAUDE_PLUGIN_DATA}/markers/${CLAUDE_SESSION_ID:-default}/active-scope"
```

Idempotent (overwrite-safe). The marker maps `<cwd_md5>=<scope_name>` so a session that traverses multiple cwds keeps one line per cwd. When `--project` is absent, **do not write** the marker — hooks fall back to root naturally.

## Your Role

You are the orchestrator AND executor for code implementation with compliance verification. You will:
1. Help user select a logbook and starting objective
2. Load governance context from the logbook (populated by logbook-create A1.4 via blueprint chain walk) to understand WHAT the business needs
3. Implement code directly in the main agent (full context needed), aligned with both coding rules (project_rules.json) and business governance (governance_context)
4. Audit compliance by spawning a fresh adversarial subagent (independence needed — see Step 7)
5. Verify substance via a second adversarial dispatch — type-aware critic A paired with inline verifier B (see Step 7.5, design_principle #7 + #8)
6. Update the logbook immediately after each objective (status + recent_context)
7. **Auto-continue** to the next objective without asking — loop until context window reaches 7% remaining

**CONTINUOUS EXECUTION:** Once the user selects a logbook and starting point, the agent implements objectives in sequence without stopping for approval. It only stops when: context window ≤ 7%, all objectives done, or a blocking impediment is found.

**GOVERNANCE AWARENESS:** The agent reads `logbook.governance_context` (populated by logbook-create A1.4) to understand which matched capabilities, flows, design_principles, product_rules, out_of_scope items, decisions, and success_metrics relate to each objective. Capabilities flagged `is_essential: true` get extra thoroughness. Business-impact findings are recorded in recent_context for cross-session continuity.

**IMPORTANT — implementation vs verification are opposite forces:**

- **Implementation stays in the main agent.** Writing correct code needs full context (project rules, manifest, resolved decisions, prior objectives, governance context). A subagent with stripped context would contradict conventions. Steps 5 and 8 (retry fixes) are main-agent work.
- **Compliance audit delegates to a FRESH subagent (Step 7).** The implementer cannot audit its own code without bias — the same principle that produced design_principle #7 / product_rule #9 of the blueprint (verifier A→B pattern). Independence is structural, not aspirational.
- **Substance critic delegates to TWO FRESH subagents (Step 7.5: A → inline B).** Step 7 catches RULE violations; Step 7.5 catches SUBSTANCE failures (circular asserts, non-branching hooks, declared-but-unimplemented behavior). The two layers verify orthogonal concerns. A produces type-aware findings; B classifies (confirmed/smoke/unverifiable/gold) with double lens (technical + value) and never vetoes. Main agent decides with full context.

At the per-secondary granularity, the meaningful jump is structural independence (fresh A); the deeper A→B audit at primary completion fires via the Layer C hook (`waves-rules-audit.sh`).

## Step -1: Prerequisites Check (CRITICAL)

**Multi-project note (root-only validation):** prerequisite artifacts (`user_pref.json`, `project_manifest.json`, `project_rules.json`, plus any required blueprint/roadmap) are validated at root (`waves_files/<artifact>`) regardless of whether the `--project <name>` flag is set. Scopes inherit root prerequisites. If a root prerequisite is missing in multi-project mode, abort with a message pointing to root setup (e.g., "Run /waves:project-init at root first — multi-project scopes inherit root prerequisites.") — NEVER to a per-scope path. The `base_path` from the Multi-project scope helper applies to WORK artifacts (logbooks, scoped rules/manifest/blueprint), not to prerequisite existence checks.

1. Check if `waves_files/user_pref.json` exists
   - IF NOT EXISTS → Show error, suggest `/waves:project-init`, EXIT

2. Read `user_pref.json`:
   - Extract `user_profile.preferred_language`
   - Extract `project_context.project_type`

3. IF `project_type !== "software"` AND `project_type !== "agentic"`:
   ```
   ⚠️ This command is only available for software and agentic projects.

   Your project is configured as: [project_type]

   General projects use /waves:logbook-update with the 'audit' token instead.

   To change project type, run:
   /waves:project-init
   ```
   → EXIT

   **Why agentic projects qualify:** the "code" of an agentic project is markdown skill files, JSON hook configurations, and prompt files. The 4 defense layers (A inline rules + B banner + C post-impl audit + D logbook integrity audit) and the orthogonality reviewer operate on diff vs rules, which works the same regardless of whether the diff is Dart code or a skill markdown file. Logbook scope.files for an agentic project points to skill/hook/config files; scope.rules references categories from project_rules.json (which for agentic typically includes orchestration, prompt_engineering, tool_use, governance, etc.).

4. Check if `waves_files/project_manifest.json` exists
   - IF NOT EXISTS → Show error, suggest `/waves:manifest-create`, EXIT

5. Check if `waves_files/project_rules.json` exists
   - IF NOT EXISTS → Show warning (will proceed without rules validation)

**From this point, use the user's preferred language.**

## Step 0: Parse Parameter

Check if a logbook filename was provided as parameter.

IF parameter provided:
- Store as `logbook_param`
- Go to Step 1.1

IF no parameter:
- Go to Step 1.2

## Step 1: Logbook Selection

### Step 1.1: Validate Provided Logbook

Search for `[logbook_param]` in BOTH layouts (directory-per-logbook convention + transition tolerance): the new directory layout `waves_files/waves/*/logbooks/[slug]/logbook.json` (where `[slug]` is `[logbook_param]` without `.json`) AND the old flat layout `waves_files/waves/*/logbooks/[logbook_param]`. Load whichever is found.

IF EXISTS:
- Load the logbook (from `<slug>/logbook.json` if new layout, else the flat file)
- Go to Step 2

IF NOT EXISTS:
```
⚠️ Logbook not found: [logbook_param]
```
→ Go to Step 1.2

### Step 1.2: List Available Logbooks

Scan `waves_files/waves/*/logbooks/` for logbooks in BOTH layouts: new-layout `*/logbooks/<slug>/logbook.json` (the logbook is the inner `logbook.json`; its name is the `<slug>` directory) AND old-layout flat `*/logbooks/*.json`. Until `migrate_v2_to_v3` (w6 Phase 4) relocates everything, both coexist.

**IF no logbooks found:**
```
📂 No logbooks found in waves_files/waves/*/logbooks/

A logbook defines your task objectives and guides implementation.

To create one, run:
  /waves:logbook-create [filename]

Example:
  /waves:logbook-create TICKET-123.json
```
→ EXIT

**IF logbooks exist:**

For each logbook, read and extract:
- ticket.title
- Count of main objectives
- Count of active/not_started objectives
- Last modified date (from file system)
- Which wave the logbook belongs to (from its path)

Display:
```
📚 Available logbooks:

  #  Wave  Logbook                    Last Modified    Objectives
  ──────────────────────────────────────────────────────────────────────────
  1  w1    TICKET-123.json            2 hours ago      3 main (1 active)
  2  w1    feature-auth.json          1 day ago        2 main (2 pending)
  3  w2    bug-fix-login.json         3 days ago       1 main (✅ done)

Options:
  [1-N]  Select by number
  [name] Type filename
  [c]    Create new logbook
  [q]    Quit

Choose:
```

### Step 1.3: Handle Selection

Read user input.

**IF number 1-N:**
- Load corresponding logbook
- Go to Step 2

**IF filename string:**
- Validate exists in `waves_files/waves/*/logbooks/`
- IF exists → Load and go to Step 2
- IF not → Show error, repeat Step 1.2

**IF "c" or "create":**
```
To create a new logbook, run:
  /waves:logbook-create [filename]

Example:
  /waves:logbook-create TICKET-456.json
```
→ EXIT

**IF "q" or "quit":**
→ EXIT

## Step 2: Display Logbook Status

Load the selected logbook and display:

```
📋 Logbook: [ticket.title]
   File: waves_files/waves/[wN]/logbooks/[filename]

🎯 Main Objectives:
┌────┬────────────────────────────────────────────────┬─────────────┐
│ #  │ Content                                        │ Status      │
├────┼────────────────────────────────────────────────┼─────────────┤
│ 1  │ [main_objective.content truncated to 40ch]     │ [icon] [status] │
│ 2  │ [main_objective.content truncated to 40ch]     │ [icon] [status] │
└────┴────────────────────────────────────────────────┴─────────────┘
```

Find the first main objective that is `active` or has `not_started` secondary objectives.

Display its secondary objectives:
```
📝 Secondary Objectives for Main #[N]:
┌─────┬────────────────────────────────────────────────┬─────────────┐
│ ID  │ Content                                        │ Status      │
├─────┼────────────────────────────────────────────────┼─────────────┤
│ 1.1 │ [secondary.content truncated]                  │ [icon] [status] │
│ 1.2 │ [secondary.content truncated]                  │ [icon] [status] │
│ 1.3 │ [secondary.content truncated]                  │ [icon] [status] │
└─────┴────────────────────────────────────────────────┴─────────────┘
```

**Status icons:**
- ⚪ not_started
- 🟡 active
- 🔴 blocked
- 🟢 achieved
- ⚫ abandoned

## Step 3: Select Objective

```
🎯 Which objective do you want to implement?

Options:
  [1.1, 1.2, ...] Select secondary objective by ID
  [auto]          Choose next logical objective for me
  [q]             Quit

Choose:
```

**IF "auto":**
1. Find first secondary objective with status `not_started` or `active`
2. If none in current main, check next main objective
3. If all done:
   ```
   ✅ All objectives are completed!

   Consider running:
     /waves:resolution-create [logbook]

   to generate a resolution summary.
   ```
   → EXIT

**IF specific ID (e.g., "1.2"):**
- Validate ID exists in logbook
- Load that objective

**IF "q":**
→ EXIT

Store selected objective as `current_objective`.

## Step 4: Prepare Implementation Context

Display:
```
🔍 Preparing implementation context...
```

1. **Load project manifest:**
   - Read `waves_files/project_manifest.json`
   - Extract relevant layers, patterns, tech stack

2. **Load project rules:**
   - Read `waves_files/project_rules.json` (if exists)
   - Filter rules that apply to `current_objective.scope.rules`
   - If no rules file, set `applicable_rules = []`

3. **Load governance context (CRITICAL for business alignment — NEW Waves 3.x flow).**

   The logbook itself carries a `governance_context` field populated by `logbook-create` Step 4 (chain walk + jq extraction). It is the compact extracted subset of the blueprint chain (scope → product → company) that impacts this logbook's direction. Loading it does NOT require re-reading any blueprint file from disk.

   - Read `current_logbook.governance_context`.
   - IF the field exists with non-empty arrays: store as `governance_context` for Step 5 banner consumption.
   - IF the field exists but all arrays are empty: this logbook had no matching blueprint capabilities (greenfield ticket OR blueprint missing at creation time). Set `governance_context = null`. Banner is skipped.
   - IF the field is absent entirely (logbook created with pre-3.x logbook-create): fallback — read `waves_files/blueprint.json` directly using the OLD pattern (read full + extract matched capability) and synthesize a minimal governance_context object in-memory. This fallback exists for backwards compatibility with logbooks created before the governance_context field was introduced. Forward-only: do NOT write the synthesized object back to the logbook (logbook-update is the right place to regenerate it).

   **Why this matters:** governance_context drives the Step 5 Governance banner. It carries matched capabilities (with `is_essential` + `acceptance_criteria`), governing design_principles (the WHY behind coding rules), applicable product_rules (business behavior, distinct from coding rules), out_of_scope reminders (STOP signals), related flows, relevant decisions, success_metrics, and — for autonomous_entity blueprints — the entity identity. Reading these together with project_rules.json is what keeps implementation aligned to BOTH the blueprint (business) and the code (engineering).

   `is_essential: true` capabilities flag the work as revenue-critical — extra thoroughness, edge case coverage, robust error paths.

4. **Load additional product context files (if not already loaded in logbook creation):**
   - Search for `waves_files/technical_guide.md` → Extract relevant sections
   - Search for `waves_files/feasibility.json` → Extract relevant buyer personas, essential capabilities
   - Load the roadmap from the SAME wave as the selected logbook: if the logbook is at `waves_files/waves/w1/logbooks/X.json`, read `waves_files/waves/w1/roadmap.json` → Extract current phase context, milestone status, and decisions
   - For each file NOT found: Skip silently. Do NOT stop or error.

5. **Parse completion guide:**
   - For each item in `current_objective.completion_guide`:
     - If references file:line → Add to `reference_files`
     - If references rule # → Ensure rule is in `applicable_rules`

6. **Build context object:**
```json
{
  "objective": {
    "id": "[current_objective.id]",
    "content": "[current_objective.content]",
    "completion_guide": ["..."]
  },
  "governance_context": {
    "blueprint_chain": [...],
    "matched_capabilities": [{level, id, capability, is_essential, acceptance_criteria}],
    "related_flows": [...],
    "governing_design_principles": [...],
    "applicable_product_rules": [...],
    "out_of_scope_reminders": [...],
    "relevant_decisions": [...],
    "success_metrics": [...],
    "autonomous_entity_identity": null
  },
  "rules": [...applicable_rules...],
  "manifest_summary": {
    "framework": "[from manifest]",
    "patterns": ["..."],
    "relevant_layers": ["..."]
  },
  "reference_files": [
    { "path": "...", "purpose": "..." }
  ]
}
```

Display:
```
  ✓ Project manifest loaded
  ✓ [N] applicable rules identified
  ✓ [M] reference files identified
  ✓ Completion guide parsed
  [If governance_context has matched_capabilities:]
  ✓ Governance context: [N matched capabilities, M design_principles, K product_rules] across [chain length] blueprint(s)
  [If not found:]
  ○ governance_context absent or empty in logbook (proceeding without Governance banner)
```

## Step 5: Implement Code Directly

### Sibling primaries banner (mandatory when logbook has 2+ main objectives)

When the logbook has more than one main objective, the work is decomposed into orthogonal dimensions (per the `orthogonality_review` resolved decision in Step A2.5 of `logbook-create`). Before any code, print:

```
═══ Decomposition context ═══
Implementing primary [N] of [TOTAL]:
  • Primary 1: "[content]" — [DONE | DEFERRED]
  • Primary 2 (THIS): "[content]"
  • Primary 3: "[content]" — [DEFERRED]

This objective addresses ONE dimension. Do NOT anticipate work that belongs to deferred primaries. Do NOT modify scope.files of primaries marked DONE except where strictly necessary for this primary's success.
═══════════════════════════════════
```

Build the list dynamically from `logbook.objectives.main` ordered by id. For each sibling, derive the state:
- DONE if status is `achieved` or `completed`
- THIS if it is `current_objective`
- DEFERRED otherwise

If the logbook has only one main objective, **skip this banner entirely** — there is no decomposition to scope around.

### Governance banner (mandatory when logbook has governance_context)

Before the Rules-in-scope banner, if the logbook has a `governance_context` field with any non-empty array, print the governance subset extracted by `logbook-create` Step 4 (chain walk + jq extraction). This is the business-direction alignment layer — separate from and orthogonal to coding rules. Reading governance + rules together is what keeps implementation aligned both to the blueprint (capabilities, flows, principles, business rules, out-of-scope, decisions) and to the code (project_rules.json).

If `governance_context` is absent or all arrays are empty, skip this banner entirely (no blueprint chain matched the ticket — unusual but valid for greenfield work).

```
═══ Governance context for this objective ═══

📋 Matched capabilities (this primary serves):
  [for each entry in governance_context.matched_capabilities]
  [<level>] #<id> [ESSENTIAL or NON-ESSENTIAL]: <capability>
    Acceptance: <each acceptance_criteria item, one per line, indented>
    (If acceptance_criteria is empty, omit the Acceptance subline.)

🧭 Design principles (the WHY behind the coding rules below):
  [for each entry in governance_context.governing_design_principles]
  [<level>] #<id>: <principle>

🚧 Product rules (business behavior — distinct from coding rules):
  [for each entry in governance_context.applicable_product_rules]
  [<level>] #<id> (applies to: <applies_to>): <rule>

⛔ Out of scope reminders (do NOT do):
  [for each entry in governance_context.out_of_scope_reminders]
  [<level>] #<id>: <statement>

🔄 Related flows (where this code fits in user journey):
  [for each entry in governance_context.related_flows]
  [<level>] <type> #<id> "<name>": <entry_point> → <termination>

📜 Relevant historical decisions:
  [for each entry in governance_context.relevant_decisions]
  [<level>] #<id> (impact: <impact_on or "—">): <decision>

📈 Success metrics tied to matched capabilities:
  [for each entry in governance_context.success_metrics]
  [<level>] #<id> <metric>: <success_signal>

[If governance_context.autonomous_entity_identity is non-null:]
🤖 Autonomous entity identity (load-bearing for agentic implementations):
  [<level>] Identity: <identity, abbreviated to ~200 chars>
  [<level>] Voice: <voice, abbreviated>
  [<level>] Operation modes: <operation_modes, abbreviated>
  [<level>] Operational limits: <operational_limits — print VERBATIM, no truncation; these are hard guardrails>
═══════════════════════════════════════════
```

Omit any section whose array is empty. Skip empty sections entirely — do not print "📜 Relevant historical decisions: (none)" if the array is empty; the absence of the section signals nothing matched.

This banner is **not optional** when governance_context exists. Skipping it is the most common cause of implementation drift from blueprint intent: implementer follows coding rules letter-perfect but breaks acceptance_criteria, ignores out_of_scope items, or contradicts product_rules — all because the business layer wasn't physically present in context.

### Rules-in-scope banner (mandatory)

Before doing ANY implementation work, print the full text of every rule that applies to this objective. The IDs alone are insufficient — rules are not constraints if they are not present in the active context.

For the current objective, look up `current_objective.scope.rules` (for main objectives) or the parent main's `scope.rules` (for secondary objectives). For each rule ID, look up the full text in `project_rules.json` and print:

```
═══ Rules in scope for this objective ═══
#3 [<category>, <scope>]: <full rule description>
#7 [<category>, <scope>]: <full rule description>
#12 [<category>, <scope>]: <full rule description>
═══════════════════════════════════════════
```

If `scope.rules` is empty for this objective, print:
```
═══ Rules in scope for this objective ═══
(no rules in scope — apply framework defaults + YAGNI)
═══════════════════════════════════════════
```

This banner is **not optional**. Skipping it is the single biggest reason rules drift in frontend code where the implementation context is dense and rule violations are not caught by AST or tests. The banner makes the constraints physically present at the moment of writing code.

### Implementation

Display:
```
🤖 Starting implementation...

Objective: [current_objective.content]
[If governance_context has matched_capabilities:]
Business context: [capability/flow name] — [business_intent summary]
[If is_essential:] ⚠️ ESSENTIAL CAPABILITY — revenue-critical implementation
```

**Execute the implementation directly (no subagents).** Using the context from Step 4:

1. **Read all reference files** from the completion guide
2. **Treat every rule in the banner as a hard constraint.** Each line of code you write must comply with all rules in scope. If a rule seems to conflict with a completion_guide step, stop and surface the conflict instead of silently choosing one.
3. **If governance_context has matched_capabilities**, keep the business intent in mind:
   - Code should fulfill the capability's acceptance_criteria, not just the technical objective
   - For essential capabilities: be thorough, cover edge cases, ensure robustness
   - Apply blueprint's design_principles alongside project_rules
4. **Implement the code** following:
   - Project manifest patterns and conventions
   - Applicable rules from `project_rules.json`
   - Completion guide steps as implementation checklist
   - Resolved decisions from the logbook
5. **Track changes** as you implement:
   - Files created (+) and modified (-)
   - Patterns applied
   - Any discoveries, deviations, or impediments found
   - **Business-impact findings**: anything that could affect a capability's behavior (essential or not)
6. **Run `dart analyze`** (or equivalent for the project) to verify no errors

Store the implementation results as `change_manifest`:
```json
{
  "changes": [{"file": "...", "action": "created|modified", "lines": N}],
  "patterns_applied": ["..."],
  "implementation_findings": {
    "discoveries": [],
    "plan_deviations": [],
    "new_decisions": [],
    "impediments_found": [],
    "ambiguities_consulted": [],
    "new_objectives_suggested": [],
    "recommendations": []
  }
}
```

Go to Step 6

## Step 6: Show Implementation Summary

```
✅ Implementation complete!

📄 Changes:
  [For each change in response.changes:]
  [+/-] [file] ([action], [lines] lines)

📋 Patterns applied:
  [For each pattern in change_manifest.patterns_applied:]
  • [pattern]

🔍 Auditing compliance with project rules...
```

## Step 7: Audit Compliance (fresh adversarial subagent — A)

The implementer (main agent) cannot audit its own code without bias. **Delegate the rule-compliance audit to a FRESH subagent with minimal context by design** — same principle as the verifier pattern A→B (blueprint design_principle #7 / product_rule #9), applied to in-flow per-secondary audits.

### Spawn the auditor subagent

Spawn an Agent with `run_in_background=false` (blocking — the result conditions Step 8) using the model from `agent_config.metacognition_model` in user_pref.json (default: `opus`). Do NOT pass the main agent's accumulated context; pass only what is needed for an independent audit:

- Current objective id and content.
- The list of files created/modified in this objective (`change_manifest.changes`).
- The **full text** of each applicable rule (from `project_rules.json`), with its category and scope — IDs alone are insufficient.
- One-line manifest summary of the layer/pattern the objective touches.

### Adversarial subagent prompt (copy as-is, fill the placeholders)

```
You are a code rules auditor with MINIMAL context by design. Another agent (the implementer) just wrote the code below. Your job is to verify rule compliance INDEPENDENTLY — not to confirm the implementer's choices.

Objective: <objective.content> (id: <objective.id>)
Files changed: <list of paths from change_manifest.changes>
Applicable rules (full text):
  - Rule #<id> [<category>, <scope>]: <full text>
  - ...
Manifest layer: <one-line summary>

Your job:
1. Read each changed file from disk (Read tool).
2. For each rule, evaluate compliance. Flag a violation ONLY when you can cite (a) the exact rule text and (b) the exact file:line in the current code.
3. Classify severity:
   - error: rule violation that must be fixed.
   - warning: potential issue, review recommended.
   - info: observation, no action needed.

Return ONLY a JSON object of this exact shape (no prose):
{
  "compliant": true|false,
  "rules_checked": [<rule_ids>],
  "rules_skipped": [{"id": <id>, "reason": "<why not applicable to these files>"}],
  "findings": [
    {"severity": "error|warning|info", "rule_id": <id>, "file": "<path>", "line": <int or 0 for range>, "issue": "<concise description with citation>"}
  ]
}

Constraints:
- High confidence only. Do not flag stylistic preferences not encoded in the rules.
- No speculation. If you cannot cite file:line, omit the finding.
- Do not modify any file.
```

Receive the JSON as `audit_response` and proceed to Step 8. If the subagent fails (returns non-JSON or errors), record a warning and proceed treating it as `compliant: true` with `rules_skipped` noting the failure — the Layer C hook will still audit at primary completion.

## Step 8: Handle Audit Result

### Step 8A: Compliant

IF `audit_response.compliant === true`:

```
✅ Audit passed!

Rules verified:
  [For each rule_id in audit_response.rules_checked:]
  ✓ Rule #[id]: [rule.content summary]

  [If rules_skipped:]
  ○ Rule #[id]: Skipped - [reason]
```

→ Go to Step 9

### Step 8B: Non-Compliant (Retry)

IF `audit_response.compliant === false`:

```
⚠️ Audit found issues:

  [For each finding in audit_response.findings:]
  [❌ if error, ⚡ if warning, ℹ️ if info] [Rule #N] [file]:[line]
     [finding.issue]
```

**IF retry_count < 3:**
```
🔄 Attempting automatic fix... (Attempt [retry_count + 1]/3)
```

Fix the audit findings directly:
- Read each file with findings
- Apply fixes for each error-level finding
- Re-run `dart analyze` to verify
- Update `change_manifest` with the fixes

Increment retry_count, go back to Step 6.

### Step 8C: Max Retries Exceeded

IF retry_count >= 3:

```
⚠️ Could not achieve full compliance after 3 attempts.

Remaining issues:
  [List remaining error-level findings]

Options:
  1) Accept with issues (will note in logbook)
  2) Open files for manual fix
  3) Abort (no changes to logbook)

Choose [1-3]:
```

**IF "1":**
- Proceed to Step 9 with note about issues

**IF "2":**
- List files that need fixes
- Instruct user to fix manually
- Offer to re-run audit after: "Run /waves:implement [logbook] when ready"
- EXIT

**IF "3":**
- EXIT without updating logbook

## Step 7.5: Adversarial critic dispatch (type-aware A → inline verifier B)

The rules audit at Step 7 verifies **compliance** (does the code respect project rules?). It does not verify **substance** — whether tests are meaningful, whether hooks actually branch, whether documentation aligns with implementation. Step 7.5 closes that gap with a second adversarial subagent dispatch that fires AFTER Step 8 confirms rule compliance and BEFORE Step 9 marks the objective achieved.

This step aterriza design_principle #8 (Demonstration over declaration) on the adversarial-judgment layer that complements the deterministic stub-check hook (`waves-stub-check.sh`). Stub-check catches cheap, infallible classes of fakeness (empty bodies, TODO markers); the critic catches the subtle classes that require domain judgment (circular asserts, non-branching hooks, declared-but-unimplemented behavior).

The critic is paired with an inline verifier B per blueprint design_principle #7 / product_rule #9: B applies a double lens (technical via grep/Read + value via overengineering/KISS check) and **classifies** findings as `confirmed | smoke | unverifiable | gold` — it never vetoes. The main agent receives BOTH raw A and B classification and decides what to do.

### Step 7.5.1: Critic spawn (A — fresh subagent, type-aware prompt)

Spawn an Agent with `run_in_background=false` (blocking — the result conditions main agent's decision below) using the model from `agent_config.metacognition_model` in user_pref.json (default: `opus`). Read `project_type` from `waves_files/user_pref.json` `project_context.project_type` to select the lens.

**Inputs (paths, not content — subagent reads from disk):**
- Current objective id + content
- Files changed (`change_manifest.changes`)
- Acceptance criteria from the matched blueprint capability/flow (if available from Step 4 `governance_context`)
- One-line manifest summary of the layer touched

**Adversarial subagent prompt (branches by project_type):**

```
You are a code critic with MINIMAL context by design. Another agent (the implementer) just wrote the code below. Your job is to verify SUBSTANCE — not rule compliance (the rules auditor already ran). Detect the classes of fakeness that pass static checks but undermine the work:

Objective: <objective.content> (id: <objective.id>)
Files changed: <list of paths>
Acceptance criteria (from blueprint): <ACs from governance_context.matched_capabilities[0].acceptance_criteria, or "none extracted">
Manifest layer: <one-line>

IF project_type == software (test-critic lens):
  Detect these 4 anti-patterns:
  (a) circular_assert — assert that compares setup data to itself (e.g. setup: var x = 5; test: expect(x, equals(5))). The assertion verifies the literal value the test author wrote, not behavior.
  (b) mock_on_mock — a test mocks the same dependency it just mocked in a different layer (the test never reaches real code).
  (c) trivially_true — expect(true), expect(1, equals(1)), assert(2 + 2 == 4). Always passes by definition.
  (d) missing_ac_coverage — objective declares acceptance criteria (e.g. "X throws Y on missing id") but no test covers that branch.

IF project_type == agentic (behavior-critic lens):
  Detect these 4 anti-patterns:
  (a) non_branching_hook — bash hook with no meaningful if/case/while; reduces to "emit {}; exit 0" regardless of input.
  (b) single_write_command — slash command whose entire flow ends in one Write tool call with no branching, validation, or analysis.
  (c) prompt_no_constraints — subagent prompt that does not declare output schema, validation rules, or constraints on findings.
  (d) description_vs_substance — header/description declares behavior X but the implementation does Y (e.g. command claims "validates X" but only emits a fixed message).

IF project_type == general (evidence-critic lens, OPT-IN):
  Only run if project_rules.json .rules.verification[] contains a rule with keyword 'evidence-critic' or 'general-critic-opt-in'. Otherwise return {findings: []} immediately.
  Detect 2 anti-patterns:
  (a) unsupported_declaration — claim without cited source/document/observation.
  (b) jump_to_conclusion — conclusion stated without prior visible observation.

For each detected anti-pattern, produce a finding with structural citation.

Return ONLY a JSON object of this exact shape (no prose):
{
  "lens": "test-critic" | "behavior-critic" | "evidence-critic",
  "findings": [
    {
      "id": <int starting at 1>,
      "severity": "error" | "warning" | "info",
      "category": "<one of the anti-pattern names above>",
      "location": { "file": "<path>", "line": <int or 0 for file-level> },
      "message": "<concise explanation citing the specific code or content>",
      "suggested_action": "<short textual suggestion — do NOT prescribe exact code edits>"
    }
  ]
}

Constraints:
- High confidence only. Cite file:line.
- No speculation. If you cannot cite, omit.
- Do not modify any file.
```

Receive the JSON as `critic_response`. If the subagent fails (non-JSON or errors), record a warning and proceed treating it as `findings: []` with a skip note — the Layer C hook at primary completion still runs.

### Step 7.5.2: Verifier B (inline, second fresh subagent)

Immediately after A returns, spawn a second Agent (`run_in_background=false`) for verification. Inline pattern per blueprint decision #14 (w3) — no materialized agent file. Same model as A.

**Inputs (minimal):**
- A's raw `critic_response` JSON (verbatim)
- The objective content (one line)
- Paths of files changed (for B to grep/Read evidence)
- The acceptance criteria (if any)

**Verifier B prompt:**

```
You are a verifier B with MINIMAL context by design. A critic (A) just produced findings about another agent's code. Your job is NOT to confirm A's findings — it is to CLASSIFY each one independently using two lenses, and never veto. The main agent will make the final decision with both A's raw output and your classification.

A's raw output (verbatim):
<critic_response JSON>

Objective: <one line>
Files: <paths>
Acceptance criteria: <ACs or "none">

For each finding in A's output, apply BOTH lenses:

LENS 1 — Technical (evidence):
  Use Read and Grep on the cited file:line. Does the cited code actually exhibit the anti-pattern? Cite what you saw (snippet or line).

LENS 2 — Value (overengineering/KISS):
  Even if technically correct, does the finding describe a real problem or an over-elaborated expectation? A circular_assert in a fixture file is intentional; a non_branching_hook for a no-op task is fine; a missing_ac_coverage on an objective with no ACs is moot.

Classify each finding into EXACTLY one of:
  - confirmed  — technical lens supports AND value lens says it's a real problem worth fixing.
  - smoke      — at least one lens says no (no evidence, or trivial/over-elaborated). Main agent should re-evaluate.
  - unverifiable — cannot confirm without external context the verifier does not have.
  - gold       — valuable insight beyond the finding's original scope (e.g. surfaces a broader issue worth noting).

Return ONLY a JSON object of this exact shape (no prose):
{
  "classifications": [
    {
      "finding_id": <int — must match an id from A's findings>,
      "verdict": "confirmed" | "smoke" | "unverifiable" | "gold",
      "technical_lens": "<one-line — what you saw via grep/Read>",
      "value_lens": "<one-line — KISS/overengineering judgment>",
      "rationale": "<one paragraph combining both lenses>"
    }
  ]
}

Constraints:
- NEVER modify a file.
- NEVER veto a finding by omitting it — classify EVERY finding A produced (even if smoke or unverifiable).
- The main agent receives BOTH A's raw output and your classifications.
```

Receive `verifier_b_response`. If B fails, treat all A findings as `unverifiable` and proceed.

### Step 7.5.3: Main agent decision tree

The main agent now has BOTH `critic_response` (raw A) AND `verifier_b_response` (B classifications). It decides with full context:

| Dominant B verdict | Main agent action |
|--------------------|-------------------|
| **confirmed** or **gold** | Proceed to Step 9. Gold findings are logged in the logbook as discoveries (do NOT block achievement). |
| **smoke** | Re-evaluate. Two options: (1) loop back to Step 5 with a new approach addressing the substance gap; (2) document override in `resolved_decisions` with `method: "critic_smoke_override"` and a reasoning paragraph. The override path is for cases where the main agent's full context contradicts B's minimal-context classification — proceed with documentation. |
| **unverifiable** | Main agent judgment with full context — proceed to Step 9 with a `recent_context` note documenting the uncertainty. |

**"Dominant" means the verdict with the most findings.** If A produced zero findings, treat as `confirmed` (nothing to verify).

**Anti-refilter rule:** B's classifications are authoritative external signal. The main agent must NOT discard or downgrade a `confirmed`/`gold` finding by re-reasoning from its own implementation framing — the only dissent channel is the documented override in `resolved_decisions` (`critic_smoke_override` applies ONLY to `smoke` verdicts; there is no override that silently drops a `confirmed` finding).

**Failure cases:**
- A fails (non-JSON, timeout): warning + treat as `findings: []` with skip note. Proceed to Step 9. Layer C hook at primary completion catches what Step 7.5 missed.
- B fails: treat all A findings as `unverifiable`. Proceed with main agent judgment.
- Both fail: skip Step 7.5 entirely. Layer C is the backstop.

### Step 7.5.4: Display the critic summary

```
🎭 Substance critic complete (lens: [test-critic | behavior-critic | evidence-critic]):

  A findings: [N]
  B classifications: confirmed=[X], smoke=[Y], unverifiable=[Z], gold=[W]

  [If dominant == confirmed:]
  ✅ Substance verified. Proceeding to Step 9.
  [If dominant == smoke:]
  ⚠️ Critic findings did not survive verifier B (mostly smoke). [If looping:] Looping back to Step 5 with new approach. [If overriding:] Override documented in resolved_decisions.
  [If dominant == unverifiable:]
  ℹ️ Critic findings unverifiable. Proceeding with main agent judgment + uncertainty note.
  [If dominant == gold:]
  ⭐ Gold findings logged as discoveries: [list]. Proceeding to Step 9.
```

Then proceed to Step 9 (or loop back to Step 5 per the smoke branch).

## Step 9: Update Logbook Immediately (CRITICAL — after EVERY objective)

**This step is mandatory after each objective completion.** The logbook must be updated in real-time so that if the session ends unexpectedly, progress is preserved.

**Use the Edit/Write TOOLS for every logbook status change — never bash/jq/python.** The framework's sensors are PostToolUse[Edit|Write] hooks: metacognition triggers, the Layer C rules audit, doc-enforce, and the COST ODOMETER (the per-primary cost.json) all detect completion by watching these tool events. A status flip applied through a bash script is INVISIBLE to all of them — the logbook looks updated but no [AUTO] roadmap note lands, no audit fires, and the primary's cost is silently never recorded (field bug, 2026-06-11). Large structural artifact edits via scripts are fine for OTHER files; the logbook's `status` transitions must go through Edit.

```
📋 Updating logbook...
```

### Step 9.1: Update Objective Status (FIRST — before anything else)

1. Set `current_objective.status = "achieved"`
2. Set `current_objective.completed_at = "[now UTC]"`
3. **Check main objective progress:**
   - Count achieved secondary objectives for the parent main objective
   - IF all secondary objectives for this main are `achieved`:
     - Set `main_objective.status = "achieved"`
     - Set `main_objective.completed_at = "[now UTC]"`
4. **Save logbook immediately** — don't wait for findings processing

### Step 9.2: Process Implementation Findings

Extract valuable context from `change_manifest.implementation_findings`:

For each category in implementation_findings, create context entries:

| Finding Type | Context Entry Format |
|--------------|---------------------|
| `discoveries` | "Discovery: [description]. Impact: [impact]" |
| `plan_deviations` | "Plan change: [original] → [actual]. Reason: [reason]" |
| `new_decisions` | "Decision: [decision]. Reasoning: [reasoning]" |
| `impediments_found` | "Impediment: [description]. Resolution: [resolution]" |
| `ambiguities_consulted` | "Clarified: [question] → [answer]" |

### Step 9.3: Insert Business-Impact Findings into recent_context (CRITICAL)

**For each finding that could affect a business capability, insert a dedicated recent_context entry.** These entries are designed to persist across sessions and help future agents understand code-level decisions that have business consequences.

**Insert a business-impact entry when:**
- A code change affects the behavior of a capability from the blueprint (essential or not)
- A dependency was upgraded/added that could affect system stability
- An architecture pattern was deviated from, creating a new precedent
- A bug or edge case was discovered that could affect user-facing behavior
- A performance characteristic was found that could affect user experience

**Format for business-impact recent_context entries:**
```json
{
  "id": [next_id],
  "created_at": "[now UTC]",
  "content": "⚡ BUSINESS IMPACT: [concise description of what happened and why it matters]. Capability: [capability name or 'general']. Essential: [yes/no]. Files: [affected files]. Action needed: [none/monitor/review/fix in next session]."
}
```

**Examples:**
```
⚡ BUSINESS IMPACT: ProductService.getById() now includes soft-deleted products in query — this could show unavailable products to buyers. Capability: product-catalog. Essential: yes. Files: src/services/ProductService.ts:45. Action needed: fix in next session.
```
```
⚡ BUSINESS IMPACT: Added retry logic to PaymentGateway.charge() with 3 attempts and exponential backoff. Capability: checkout-flow. Essential: yes. Files: src/services/PaymentGateway.ts. Action needed: none (improvement).
```

### Step 9.4: Handle New Objectives Suggested (Autonomous)

IF `implementation_findings.new_objectives_suggested` is not empty:
- **Add automatically** as `not_started` secondary objectives in the logbook
- Do NOT ask user for approval (follows autonomy principle)
- Note in recent_context: "Added [N] follow-up objectives from implementation of [objective.id]: [brief list]"

### Step 9.5: Store Recommendations

IF `implementation_findings.recommendations` is not empty:
Add to logbook's `recommendations` array (create if doesn't exist).

### Step 9.6: Create Comprehensive Context Entry

Build a context entry summarizing the implementation:

```
Implemented [objective.id]: [objective.content].
Files: [+created] [-modified].
[If governance_context.matched_capabilities not empty:] Business alignment: [first matched capability + level] ([essential/non-essential]).
[If discoveries:] Discovered: [key discovery].
[If deviations:] Deviated: [main deviation reason].
[If impediments resolved:] Resolved: [impediment].
[If new objectives added:] Added [N] follow-up objectives.
Audit: [status].
```

### Step 9.7: Save and Show Progress

Save the updated logbook.

```
  ✓ Objective [id] marked as achieved
  [✓ Main objective #[N] completed! (if applicable)]
  ✓ [N] context entries added
  [✓ [M] follow-up objectives added (if any)]
  ✓ Logbook saved

📊 Progress for Main #[N]:
  [achieved]/[total] secondary objectives done
  [progress bar ████░░░░░░ X%]
```

## Step 9.8: Post-implementation Correctness Gate (runs ONCE, when the logbook completes)

This is the **non-negotiable safety net** of the adversarial correctness layer (design_principle #10, product_rule #11). The per-secondary checks (Step 7 compliance, Step 7.5 substance) are minimal-context and see each objective in isolation — they are structurally blind to **relational runtime correctness**: bugs that live BETWEEN objectives and between the new code and its siblings (concurrency, stale state, cross-handler invariants). Step 9.8 reviews the **integrated diff against the assembled system** with FULL context, once, before the logbook is declared done. It is the complement of the post-plan gate (`logbook-create` Step A7): A7 catches problems on the plan (cheap); 9.8 catches what survived into the code (the net).

### When it runs

Trigger: **all secondary objectives are `achieved`** (the "all objectives completed" branch of Step 10), BEFORE the `resolution-create` suggestion. Runs once per logbook completion. Skip with a one-line note only if the whole logbook was doc-only/config-only (no code diff). Configurable via verification rule (`correctness_gate.post_impl`: `auto` (default) | `always` | `off`).

### Build the integrated diff

Compute the **cumulative** diff this logbook produced — NOT per-secondary. Use `git diff` of the working tree against the state before the first objective (the base SHA recorded at implementation start, or the merge-base of the working branch); if no base was recorded, reconstruct it from the union of every `change_manifest.files_created` + `files_modified` across the logbook's objectives. The reviewers must see the changes TOGETHER, as they now sit in the assembled codebase.

### Dispatch the 4 reviewers in PARALLEL (full-context, reads-only) + verifier B

Spawn all four with `run_in_background: true` (model from `agent_config.metacognition_model`, default `opus`). The first three are the same native reviewers as `logbook-create` Step A7; the fourth runs at THIS boundary only (post-plan has no tests to analyze):

1. **waves-correctness-reviewer** — runtime correctness of the integrated code vs the real APIs it now calls.
2. **waves-silent-failure-hunter** — failure paths in the assembled diff that fail without signal / leave stale state / skip rollback.
3. **waves-cross-consistency-reviewer** — does the merged code preserve the invariants its sibling handlers enforce across the whole change? (the Diamond #829/#830 class, now caught in the code if it slipped the plan).
4. **waves-coverage-gap-analyzer** — which paths of the diff does NO test exercise? (untested branches, mock-killed branches, untested error paths, single-element loop coverage). Pass it additionally the repo's test corpus locations.

**Failure branch (a fallen lens must not be swallowed):** if any reviewer fails, times out, or returns non-JSON, the gate is NOT complete — record `"degraded": true` plus the fallen reviewer's name in `fallen_reviewers` inside `audit.correctness_postimpl` (both fields are declared in the `gate_result` schema), surface it in the Display, and do NOT declare the gate passed on the surviving lenses alone. A gate that silently reports 3-of-4 coverage as full coverage reintroduces the exact blind spot this step exists to close.

**If the verifier B falls** (not a reviewer A): treat all of that lens's A findings as `unverifiable` (same rule as Step 7.5) AND mark the gate degraded — an unclassified lens is an incomplete lens; the anti-refilter rule cannot operate without B's verdicts.

**A degraded gate holds the logbook open:** do NOT suggest `resolution-create` while the gate is degraded. Append a `recent_context` entry `"Post-impl gate DEGRADED — [reviewer] fell; re-run pending"` and either re-run the fallen lens(es) until the gate completes, or close anyway ONLY with a documented `resolved_decisions` entry (`method: "correctness_gate_override"`) stating why the surviving coverage suffices. Objective statuses set at Step 9.1 stay (the work was done); what the degraded gate blocks is the COMPLETION claim of the logbook, not the per-objective record.

Pass each: the **integrated diff**, the assembled codebase (read widely), and the logbook's declared `test_cases`. Each reviewer must also **check coverage**: for every `edge_case: true` row declared in the logbook, is that behavior actually implemented in the diff? An unimplemented declared edge case is a finding.

### Reviewer input contract (structural isolation — a guarantee of THIS command, not a caller convention)

A review invoked by the author, briefed with the author's framing, is not a review — the reviewer inherits the author's blind spots and reasons from the author's conclusion instead of from the code. Build every reviewer prompt **only** from the ALLOWED list. Everything in FORBIDDEN must be withheld even when it seems helpful.

**ALLOWED inputs (the artifact + the contract):**

- The integrated diff (computed above).
- The full content of every changed file (pass paths; the reviewer reads from disk).
- The file tree / assembled codebase (the reviewer reads widely).
- The logbook's declared objectives and `test_cases` — the intended behavior, i.e. the contract.
- The repo's test corpus (test directories/files and how they run) — required input for the coverage-gap analysis.

**FORBIDDEN inputs (the author's framing):**

- The implementing agent's reasoning, chain-of-thought, or "design rationale".
- The implementation narrative ("why I did it this way") and commit-message justifications framed as truth.
- Any prior review's or gate's conclusions (Step 7/7.5 results, earlier 9.8 passes) — each pass re-derives independently.
- The author agent's session/transcript content in any form.

**Reviewer prompt skeleton (copy as-is, fill ONLY the placeholders):**

```
You are the <reviewer agent name>. POST-IMPL correctness gate. Re-derive every judgement from the artifact below; if any author rationale, narrative, or prior review conclusion reaches you anyway, DISCARD it and judge only the code.

Integrated diff:
<the git diff>

Changed files (read their full content from disk): <paths>
Behavior contract (the logbook's declared objectives + test_cases): <JSON>
Test corpus (where the repo's tests live / how they run): <paths or "none found">

If you cannot read the diff or the changed files, do NOT return empty findings (that reads as "clean") — return your axis JSON with summary "unreadable_input: <what failed>" so the dispatcher treats this lens as fallen, not as clean.

Review per your single axis, reading the assembled codebase widely. Return ONLY your axis JSON (no prose).
```

The isolation guarantee belongs to this command: if information outside ALLOWED would reach the prompt, remove it before dispatch. (The reviewer agents also defensively discard author rationale per their own Input contract section — but the dispatcher must not leak it in the first place.)

Each reviewer A → inline verifier B (reads the cited evidence, classifies `confirmed | smoke | unverifiable | gold`, double lens technical+value, never vetoes).

### Act on the findings (before resolution-create)

**Anti-refilter rule (non-negotiable):** B's verdicts are authoritative external signal. The main agent must NOT discard, downgrade, or re-classify a `confirmed`/`gold` finding by re-reasoning from its own implementation framing ("I know why I wrote it that way, so this doesn't apply") — that re-filtering is exactly the author bias the isolated review exists to break. The ONLY dissent channel is `resolved_decisions` with `method: "correctness_gate_override"` citing code evidence, never the implementation narrative.

- **`confirmed`/`gold`, critical/high** — fix the CODE now (go back to Step 5 logic for the affected files), then re-run the relevant reviewer on the fix. Trust contract level 1-2; document a genuine disagreement in `resolved_decisions` with `method: "correctness_gate_override"`.
- **medium/low confirmed** — fix if cheap; else log in `recent_context` as a known gap with `Action needed`.
- All gate outcomes → a `recent_context` entry: `"Post-impl correctness gate: [N] confirmed (fixed), [M] smoke. Coverage: [k]/[t] declared edge_case rows implemented. Reviewers that ran: [only the lenses that actually returned]. [If degraded: 'DEGRADED — [lens] fell.']"` — never name a fallen lens as having run.
- **Persist the report (directory-per-logbook convention):** write the gate's findings + verifier-B classifications to `waves_files/waves/[wN]/logbooks/[slug]/correctness-postimpl.json`, which validates against `correctness_gate_schema` with `boundary: post_impl` — co-located in the logbook's own directory (`[slug]` = logbook basename without `.json`). Then populate the `audit.correctness_postimpl` gate_result, branching on the gate state: complete run → `{ "ran": true, "report_file": "<that path>", "summary": { "confirmed": <N>, "smoke": <M> }, "completed_at": "<UTC>" }`; degraded run → the same object PLUS `"degraded": true, "fallen_reviewers": ["<lens>", ...]` (`ran: true` means "the gate executed"; `degraded: true` means "it executed incomplete" — both fields are declared in the schema). The `recent_context` entry above stays a SHORT summary — the full findings live in the file (no inline prose dump; design_principle #11 + DRY).

### Relationship to Step 7.5 (no overlap)

Step 7.5 stays exactly as-is: minimal-context, per-secondary, substance/compliance axis, runs inside each objective. Step 9.8 is its complement: full-context, integrated, correctness axis, runs once at the end. Different axis, scope, and timing — they do not duplicate (product_rule #10/#11).

### Display

```
🛡️ Post-implementation correctness gate ([ran | degraded: [reviewer] fell | skipped: no code diff]):
  [one line per lens — a lens that ran:]
  [lens name]:        [N] findings ([c] confirmed)
  [a lens that fell:]
  [lens name]:        FELL ([failure reason]) — no counts; gate degraded
  edge_case coverage: [k]/[t] declared rows implemented
  → [k] confirmed findings fixed before resolution.
  [If degraded:] → resolution-create BLOCKED until the fallen lens re-runs or an override is documented.
```

## Step 10: Continuous Implementation Loop (AUTO-CONTINUE)

**The agent does NOT ask the user whether to continue.** It automatically proceeds to the next objective until one of these conditions is met:

### Stop Conditions (check after EVERY objective completion):

1. **Context window exhaustion:** If the remaining context window is ≤ 7% of the total session capacity (e.g., ≤ 14,000 tokens for a 200,000-token session), the agent MUST stop and go to Final Summary. This preserves enough context to save the logbook cleanly.

2. **All objectives completed:** No more `not_started` or `active` secondary objectives remain.

3. **Blocking impediment:** An impediment was found that prevents further implementation (e.g., missing dependency, broken build that can't be auto-fixed).

### Auto-Continue Logic:

**IF more objectives exist AND context window > 7% AND no blocking impediment:**
```
🔄 Auto-continuing to next objective...

🎯 Next: [next_objective.id]: [next_objective.content]
[If governance_context.matched_capabilities not empty:] Business context: [first matched capability]
```
- Set `current_objective` to next objective
- Reset retry_count = 0
- Go to Step 4 (context will be partially reloaded — manifest and rules are already in memory, only new reference files need reading)

**IF context window ≤ 7%:**
```
⏸️ Context window reaching limit (~[remaining]% remaining).
Saving progress and stopping to preserve session integrity.
```
→ Go to Final Summary

**IF all objectives completed:**
→ **First run Step 9.8 (Post-implementation Correctness Gate)** on the integrated diff and resolve any confirmed critical/high findings. Then:
```
🎉 All objectives for this logbook are complete!

Consider running:
  /waves:resolution-create [logbook]

to generate a resolution summary for your ticket.
```
→ Go to Final Summary

**IF blocking impediment:**
```
🔴 Blocking impediment detected:
  [impediment description]

Progress saved. Resume with:
  /waves:objectives-implement [logbook]
```
→ Go to Final Summary

## Final Summary

**MANDATORY: Before showing the summary, update the roadmap.**

Find the roadmap for the same wave as this logbook (`waves_files/waves/[wN]/roadmap.json`).
Add a `decisions` entry recording the session outcome:

```json
{
  "id": [next_id],
  "created_at": "[now UTC]",
  "decision": "[AUTO] Session ended for [logbook]: [X] objectives completed this session, [Y]/[Z] total. Stop reason: [reason]. Next pending: [objective description or 'none']."
}
```

If ALL objectives in the logbook are complete, also check if the associated milestone in the roadmap should be updated to "completed".

Then show the summary:

```
✅ Implementation session complete!

📊 Session summary:
  • Objectives completed: [count this session]
  • Files created: [count]
  • Files modified: [count]
  • Audit attempts: [count] ([passed]/[total])
  • Business-impact entries: [count]
  • Stop reason: [all done | context limit | impediment]

📋 Logbook: waves_files/waves/[wN]/logbooks/[filename]
📋 Roadmap updated: waves_files/waves/[wN]/roadmap.json

[If objectives remain:]
🎯 Next pending objective: [next_objective.id]: [content]

💡 Continue in next session:
  /waves:objectives-implement [filename]
```

---

## Subagents

This command uses TWO subagent dispatches per secondary objective:

1. **Rules audit (A) at Step 7** — one fresh subagent verifies compliance with project_rules.json. Implementer cannot audit its own code without bias.

2. **Substance critic (A→B) at Step 7.5** — two fresh subagent spawns: (a) type-aware critic detects substance anti-patterns (circular asserts / non-branching hooks / unsupported declarations); (b) inline verifier B applies double lens (technical + value) and classifies findings as confirmed/smoke/unverifiable/gold without vetoing. Main agent receives both A raw + B classifications and decides.

The two dispatches verify ORTHOGONAL concerns: Step 7 verifies COMPLIANCE (rule violations); Step 7.5 verifies SUBSTANCE (real code behind the surface). Compliance can pass while substance fails — that is the gap Step 7.5 closes.

Once per logbook completion, a THIRD dispatch runs at **Step 9.8 — Post-implementation Correctness Gate**: the 4 gate reviewers (waves-correctness-reviewer / waves-silent-failure-hunter / waves-cross-consistency-reviewer / waves-coverage-gap-analyzer) in parallel, full-context, each paired with verifier B, over the INTEGRATED diff. Steps 7/7.5 are minimal-context and per-secondary (compliance + substance); Step 9.8 is full-context and integrated (relational runtime correctness) — a third orthogonal axis, not a repeat (design_principle #10, product_rule #11). It is the safety net for bugs that live between objectives and between new code and its siblings.

Implementation (Step 5), audit-finding decisions, and retry fixes (Step 8) remain in the main agent because writing/fixing code needs the full accumulated context. The audit/critic dispatches delegate because they need independence from the implementer. This is the verifier-pattern principle (design_principle #7 / product_rule #9) applied to in-flow per-secondary verification; Layer C (`waves-rules-audit.sh` hook) provides the deeper A→B audit at primary completion.

---

## Error Handling

| Error | Action |
|-------|--------|
| Logbook not found | Show available logbooks |
| No objectives available | Suggest resolution-create |
| Implementer fails | Offer retry/skip/quit |
| Auditor fails | Skip audit with warning |
| Max retries | Offer accept/manual/abort |

END OF COMMAND
