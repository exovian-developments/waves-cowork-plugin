---
description: Continuously implement logbook objectives with business-aware code generation, automatic auditing, real-time logbook updates, and context-window-aware session management.
---

# Command: /waves:objectives-implement

You are executing the waves implement command. Follow these instructions exactly.

## Your Role

You are the orchestrator AND executor for code implementation with compliance verification. You will:
1. Help user select a logbook and starting objective
2. Load business context from blueprint to understand WHAT the business needs
3. Implement code directly (no subagents), aligned with both technical rules and business intent
4. Audit compliance with project rules directly (no subagents)
5. Update the logbook immediately after each objective (status + recent_context)
6. **Auto-continue** to the next objective without asking — loop until context window reaches 7% remaining

**CONTINUOUS EXECUTION:** Once the user selects a logbook and starting point, the agent implements objectives in sequence without stopping for approval. It only stops when: context window ≤ 7%, all objectives done, or a blocking impediment is found.

**BUSINESS AWARENESS:** The agent reads the blueprint to understand which capability, flow, or view each objective serves. Essential capabilities get extra thoroughness. Business-impact findings are recorded in recent_context for cross-session continuity.

**IMPORTANT: Do NOT delegate implementation or auditing to subagents. Execute all steps directly in the main agent to preserve full context (project rules, manifest, resolved decisions, prior objectives, business context). Subagents lose accumulated context and can produce code that contradicts project conventions.**

## Step -1: Prerequisites Check (CRITICAL)

1. Check if `ai_files/user_pref.json` exists
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

4. Check if `ai_files/project_manifest.json` exists
   - IF NOT EXISTS → Show error, suggest `/waves:manifest-create`, EXIT

5. Check if `ai_files/project_rules.json` exists
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

Search for `[logbook_param]` in `ai_files/waves/*/logbooks/`.

IF EXISTS:
- Load the logbook
- Go to Step 2

IF NOT EXISTS:
```
⚠️ Logbook not found: [logbook_param]
```
→ Go to Step 1.2

### Step 1.2: List Available Logbooks

Scan `ai_files/waves/*/logbooks/` directories for `.json` files.

**IF no logbooks found:**
```
📂 No logbooks found in ai_files/waves/*/logbooks/

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
- Validate exists in `ai_files/waves/*/logbooks/`
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
   File: ai_files/waves/[wN]/logbooks/[filename]

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
   - Read `ai_files/project_manifest.json`
   - Extract relevant layers, patterns, tech stack

2. **Load project rules:**
   - Read `ai_files/project_rules.json` (if exists)
   - Filter rules that apply to `current_objective.scope.rules`
   - If no rules file, set `applicable_rules = []`

3. **Load product blueprint (CRITICAL for business alignment):**
   - Search for `ai_files/blueprint.json`
   - IF EXISTS:
     - Read the full blueprint
     - Identify which **capability**, **user_flow**, **system_flow**, or **view** relates to the current objective (match by name, description, or scope files overlap)
     - Extract for the matched element:
       - `description` and `$comment` (what it does and why)
       - `is_essential` flag (if true, this is revenue-critical — extra care needed)
       - `acceptance_criteria` (what "done" looks like from business perspective)
       - Related `design_principles` and `product_rules`
     - Store as `business_context`
   - IF NOT EXISTS: Set `business_context = null`, continue normally

   **Why this matters:** The agent must understand WHAT the business wants to achieve, not just WHAT code to write. A capability marked `is_essential: true` means the business cannot generate revenue without it — implementation must be thorough and aligned with the blueprint's intent.

4. **Load additional product context files (if not already loaded in logbook creation):**
   - Search for `ai_files/technical_guide.md` → Extract relevant sections
   - Search for `ai_files/feasibility.json` → Extract relevant buyer personas, essential capabilities
   - Load the roadmap from the SAME wave as the selected logbook: if the logbook is at `ai_files/waves/w1/logbooks/X.json`, read `ai_files/waves/w1/roadmap.json` → Extract current phase context, milestone status, and decisions
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
  "business_context": {
    "related_capability": "[capability name or null]",
    "is_essential": true|false,
    "business_intent": "[what the business wants to achieve]",
    "acceptance_criteria": ["..."],
    "design_principles": ["..."]
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
  [If business_context found:]
  ✓ Business context: [capability/flow name] (essential: yes/no)
  [If not found:]
  ○ Product blueprint not found (proceeding without business context)
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
[If business_context exists:]
Business context: [capability/flow name] — [business_intent summary]
[If is_essential:] ⚠️ ESSENTIAL CAPABILITY — revenue-critical implementation
```

**Execute the implementation directly (no subagents).** Using the context from Step 4:

1. **Read all reference files** from the completion guide
2. **Treat every rule in the banner as a hard constraint.** Each line of code you write must comply with all rules in scope. If a rule seems to conflict with a completion_guide step, stop and surface the conflict instead of silently choosing one.
3. **If business_context exists**, keep the business intent in mind:
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

## Step 7: Audit Compliance Directly

**Execute the audit directly (no subagents).** For each file in `change_manifest.changes`:

1. **Read the file** that was created or modified
2. **Check against each applicable rule** from Step 4:
   - Verify naming conventions (CSN-*)
   - Verify architecture patterns (ARCH-*)
   - Verify domain rules (DOM-*)
   - Verify Dart best practices (DART-*)
   - Verify any project-specific rules
3. **Record findings** with severity:
   - `error`: Rule violation that must be fixed
   - `warning`: Potential issue, review recommended
   - `info`: Observation, no action needed
4. **Build audit response:**
```json
{
  "compliant": true|false,
  "rules_checked": ["rule_ids"],
  "rules_skipped": [{"id": "...", "reason": "..."}],
  "findings": [
    {"severity": "error|warning|info", "rule_id": "...", "file": "...", "line": N, "issue": "..."}
  ]
}
```

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

## Step 9: Update Logbook Immediately (CRITICAL — after EVERY objective)

**This step is mandatory after each objective completion.** The logbook must be updated in real-time so that if the session ends unexpectedly, progress is preserved.

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
[If business_context:] Business alignment: [capability name] ([essential/non-essential]).
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
[If business_context:] Business context: [capability/flow name]
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

Find the roadmap for the same wave as this logbook (`ai_files/waves/[wN]/roadmap.json`).
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

📋 Logbook: ai_files/waves/[wN]/logbooks/[filename]
📋 Roadmap updated: ai_files/waves/[wN]/roadmap.json

[If objectives remain:]
🎯 Next pending objective: [next_objective.id]: [content]

💡 Continue in next session:
  /waves:objectives-implement [filename]
```

---

## Subagents

This command does NOT use subagents. All steps (implementation, auditing, retry fixes) are executed directly by the main agent to preserve full context and avoid deviations from project conventions and resolved decisions.

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
