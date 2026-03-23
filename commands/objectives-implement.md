---
description: Continuously implement logbook objectives with business-aware code generation, automatic auditing, real-time logbook updates, and context-window-aware session management.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Command: objectives-implement $ARGUMENTS

You are executing the implementation command. Follow these instructions exactly.

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

## Step -1: Prerequisites Check

1. Check if `ai_files/user_pref.json` exists
   - IF NOT EXISTS → Show error, EXIT

2. Read `user_pref.json`:
   - Extract `preferred_language`
   - Extract `project_type`

3. IF `project_type !== "software"`:
   ```
   ⚠️ This command is only available for software projects.

   Your project is configured as: [project_type]

   To change this, reinitialize the project.
   ```
   → EXIT

4. Check if `ai_files/project_manifest.json` exists
   - IF NOT EXISTS → Show error, EXIT

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
  logbook-create [filename]

Example:
  logbook-create TICKET-123.json
```
→ EXIT

**IF logbooks exist:**

Display available logbooks with status summary, showing which wave each belongs to:

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

Read user input and load corresponding logbook.

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
└─────┴────────────────────────────────────────────────┴─────────────┘
```

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
     resolution-create [logbook]

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
     - Identify which **capability**, **user_flow**, **system_flow**, or **view** relates to the current objective
     - Extract: description, $comment, is_essential flag, acceptance_criteria, related design_principles and product_rules
     - Store as `business_context`
   - IF NOT EXISTS: Set `business_context = null`, continue normally

   **Why this matters:** The agent must understand WHAT the business wants to achieve, not just WHAT code to write. Essential capabilities are revenue-critical — implementation must be thorough and aligned with the blueprint's intent.

4. **Load additional product context files:**
   - Search for `ai_files/technical_guide.md` → Extract relevant sections
   - Search for `ai_files/feasibility.json` → Extract relevant context
   - Load the roadmap from the SAME wave as the selected logbook: if the logbook is at `ai_files/waves/w1/logbooks/X.json`, read `ai_files/waves/w1/roadmap.json` → Extract current phase context, milestone status, and decisions
   - For each file NOT found: Skip silently.

5. **Parse completion guide:**
   - Extract file references and rule references

6. **Build context object**

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
2. **Read applicable project rules** to ensure compliance during writing
3. **If business_context exists**, keep the business intent in mind:
   - Code should fulfill the capability's acceptance_criteria
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
   - **Business-impact findings**: anything that could affect a capability's behavior
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
```

→ Go to Step 9

### Step 8B: Non-Compliant (Retry Loop)

IF `audit_response.compliant === false`:

```
⚠️ Audit found issues:

  [For each finding in audit_response.findings:]
  [❌ if error, ⚡ if warning, ℹ️ if info] [Rule #N] [file]:[line]
     [finding.issue]
```

**CRITICAL: Implement → Audit → Fix Loop**

IF retry_count < 3:
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
- Offer to re-run: "Run objectives-implement [logbook] when ready"
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

For each category in implementation_findings, create context entries:

| Finding Type | Context Entry Format |
|--------------|---------------------|
| `discoveries` | "Discovery: [description]. Impact: [impact]" |
| `plan_deviations` | "Plan change: [original] → [actual]. Reason: [reason]" |
| `new_decisions` | "Decision: [decision]. Reasoning: [reasoning]" |
| `impediments_found` | "Impediment: [description]. Resolution: [resolution]" |
| `ambiguities_consulted` | "Clarified: [question] → [answer]" |

### Step 9.3: Insert Business-Impact Findings into recent_context (CRITICAL)

**For each finding that could affect a business capability, insert a dedicated recent_context entry.** These entries persist across sessions.

**Insert a business-impact entry when:**
- A code change affects the behavior of a capability from the blueprint
- A dependency was upgraded/added that could affect system stability
- An architecture pattern was deviated from, creating a new precedent
- A bug or edge case was discovered that could affect user-facing behavior
- A performance characteristic was found that could affect user experience

**Format:**
```json
{
  "id": [next_id],
  "created_at": "[now UTC]",
  "content": "⚡ BUSINESS IMPACT: [description]. Capability: [name]. Essential: [yes/no]. Files: [files]. Action needed: [none/monitor/review/fix in next session]."
}
```

### Step 9.4: Handle New Objectives Suggested (Autonomous)

IF `implementation_findings.new_objectives_suggested` is not empty:
- **Add automatically** as `not_started` secondary objectives
- Do NOT ask user for approval (follows autonomy principle)
- Note in recent_context

### Step 9.5: Store Recommendations

IF `implementation_findings.recommendations` is not empty:
Add to logbook's `recommendations` array.

### Step 9.6: Create Comprehensive Context Entry

```
Implemented [objective.id]: [objective.content].
Files: [+created] [-modified].
[If business_context:] Business alignment: [capability name] ([essential/non-essential]).
[If discoveries:] Discovered: [key discovery].
[If deviations:] Deviated: [main deviation reason].
Audit: [status].
```

### Step 9.7: Save and Show Progress

Save the updated logbook.

```
  ✓ Objective [id] marked as achieved
  [✓ Main objective #[N] completed! (if applicable)]
  ✓ [N] context entries added
  ✓ Logbook saved

📊 Progress for Main #[N]:
  [achieved]/[total] secondary objectives done
  [progress bar ████░░░░░░ X%]
```

## Step 10: Continuous Implementation Loop (AUTO-CONTINUE)

**The agent does NOT ask the user whether to continue.** It automatically proceeds to the next objective.

### Stop Conditions (check after EVERY objective completion):

1. **Context window exhaustion:** If remaining context ≤ 7% of total session capacity → stop, go to Final Summary
2. **All objectives completed:** No more `not_started` or `active` secondary objectives remain
3. **Blocking impediment:** An impediment prevents further implementation

### Auto-Continue Logic:

**IF more objectives AND context > 7% AND no blocking impediment:**
```
🔄 Auto-continuing to next objective...

🎯 Next: [next_objective.id]: [next_objective.content]
```
- Set `current_objective` to next objective
- Reset retry_count = 0
- Go to Step 4

**IF context ≤ 7%:**
```
⏸️ Context window reaching limit. Saving progress and stopping.
```
→ Go to Final Summary

**IF all done:**
```
🎉 All objectives complete! Consider running: resolution-create [logbook]
```
→ Go to Final Summary

**IF blocking impediment:**
```
🔴 Blocking impediment: [description]. Progress saved.
```
→ Go to Final Summary

## Final Summary

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

[If objectives remain:]
🎯 Next pending: [next_objective.id]: [content]

💡 Continue in next session:
  objectives-implement [filename]
```

END OF COMMAND
