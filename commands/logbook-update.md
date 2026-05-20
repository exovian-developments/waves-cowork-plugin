---
description: Update an existing logbook with progress entries, objective status changes, new objectives, and reminders. Includes automatic history compaction.
---

# Command: /waves:logbook-update

You are executing the waves logbook update command. Follow these instructions exactly.

## Your Role

You are the main orchestrator for logbook updates. You will help users track progress, update objective statuses, add new objectives discovered during work, and manage reminders.

## Step -1: Prerequisites Check (CRITICAL)

Check if `ai_files/user_pref.json` exists.

IF NOT EXISTS:
```
⚠️ Missing configuration!

Please run first:
/waves:project-init
```
→ EXIT COMMAND

IF EXISTS:
1. Read `ai_files/user_pref.json`
2. Extract `user_profile.preferred_language` → Use for all interactions
3. Extract `project_context.project_type` → For schema validation

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Parameter Check and Logbook Selection

The command accepts up to two arguments: `[filename] [instruction]`. Both are optional.

Parse `$ARGUMENTS` as `<filename> <rest_of_string>`:
- `filename`: first whitespace-delimited token. Optional.
- `instruction`: everything after the first token. Optional. Free-form natural language OR one of the reserved tokens listed below.

### Reserved instruction tokens (deterministic, no LLM interpretation)

| Token | Meaning |
|---|---|
| `audit` | Skip the operations menu entirely. Go directly to the schema migration check, then to STEP AUDIT. Used when the user only wants to verify integrity of an existing logbook without modifying content. |
| (empty) | Open the operations menu (current behavior). |

### Free-form instruction (interpreted)

If `instruction` is non-empty and not a reserved token, treat it as a natural-language description of operations to perform. Map to operations 1-4 (Add Progress, Update Objective Status, Add New Objective, Add Reminder). Multiple operations can be chained in one instruction.

**Plan-before-execute is mandatory** for free-form instructions. Show the interpreted plan and wait for confirmation before applying:

```
📋 Interpretación de tu instrucción:

1. Operation [N]: [name]
   → [concrete action with the parameters inferred]
2. Operation [M]: [name]
   → [concrete action]

Después: STEP AUDIT (siempre).

¿Procedo? (Yes/No/Adjust)
```

If `Adjust` → ask the user for clarifications, re-build the plan.
If `No` → fall back to the operations menu (Step 3).
If `Yes` → execute the plan in order, then proceed to STEP AUDIT.

For ambiguities the agent cannot resolve confidently (e.g. "marca completado" without specifying which objective), STOP and ask the user to disambiguate before showing the plan.

### Loading the logbook

**IF `filename` provided:**
1. Search for file in `ai_files/waves/*/logbooks/[filename].json`
2. IF NOT EXISTS → Error: "Logbook not found: [filename]"
3. IF EXISTS → Load logbook, note which wave it belongs to, continue to schema migration.

**IF `filename` NOT provided:**
1. Show tip:
```
💡 TIP: You can run faster with:
   /waves:logbook-update TICKET-123 [instruction]

   Examples:
   /waves:logbook-update TICKET-123 audit
   /waves:logbook-update TICKET-123 "marca objetivo 3 completado"
```

2. List available logbooks from all waves `ai_files/waves/*/logbooks/*.json`, grouped by wave:
```
📚 Available logbooks:

Wave w1:
1. [filename1].json (updated [time ago])
2. [filename2].json (updated [time ago])

Wave w0:
3. [filename3].json (updated [time ago])

Choose 1-[N] or type the filename:
```

3. User selects → Load logbook.

### Step 0.5: Schema Migration (soft, automatic)

After loading the logbook and before any other step, normalize the JSON to the current schema by adding any required fields that are missing. This is a **soft migration**: it only adds, never modifies existing values.

Concrete actions for this version:
- If `audit` is missing entirely, add `audit: { "is_already_audited": false }`. This applies to logbooks created before Waves 2.2.0.

If migration applied any changes, persist the logbook immediately (atomic write) before proceeding. Append a `recent_context` entry: `"Schema migration applied: <list of fields added>"` so the trail is auditable.

If no migration was needed, skip silently.

In future versions, additional required fields are added here following the same pattern (one short check per field).

## Step 1: Check Due Reminders

Read `future_reminders` array from loaded logbook.

FOR EACH reminder WHERE `when <= now`:
```
⏰ Pending reminder:
"[reminder.content]"
(Created: [reminder.created_at])

Mark as seen? (Yes/No)
```

IF "Yes" → Remove from array

## Step 2: Show Current Status

Display logbook summary:

```
📋 Logbook: [ticket.title]

🎯 Main Objectives:
┌────┬─────────────────────────────────────────────┬─────────────┐
│ ID │ Content                                     │ Status      │
├────┼─────────────────────────────────────────────┼─────────────┤
│ 1  │ [objective.content truncated...]            │ [icon] [status] │
│ 2  │ [objective.content truncated...]            │ [icon] [status] │
└────┴─────────────────────────────────────────────┴─────────────┘

📝 Secondary Objectives (active/pending):
┌────┬─────────────────────────────────────────────┬─────────────┐
│ 1  │ [objective.content truncated...]            │ [icon] [status] │
│ 2  │ [objective.content truncated...]            │ [icon] [status] │
│ 3  │ [objective.content truncated...]            │ [icon] [status] │
└────┴─────────────────────────────────────────────┴─────────────┘

📊 Recent context: [count]/20 entries
📜 Compacted history: [count]/10 entries
```

**Status Icons:**
- ⚪ not_started
- 🟡 active
- 🔴 blocked
- 🟢 achieved
- ⚫ abandoned

## Step 3: Select Operation

**Skip this step entirely if:**
- The user invoked the command with the reserved token `audit` → go directly to STEP SAVE then STEP AUDIT.
- The user invoked the command with a free-form instruction that was interpreted and confirmed → execute the planned operations in order, then proceed to STEP SAVE + STEP AUDIT.

**Otherwise (interactive mode):**

```
What would you like to do?

1. 📝 Add progress (new context entry)
2. ✅ Update objective status
3. ➕ Add new objective
4. ⏰ Add reminder
5. 🔍 None (just audit and exit)
6. 💾 Save and exit (skip audit)

Choose 1-6:
```

Route to corresponding operation. After any operation 1-4 completes, the user can return to this menu (loop) until they choose 5 or 6.

- **Option 5 (None — just audit)**: skip operations entirely. Go to STEP SAVE (which is a no-op since no content changed), then STEP AUDIT.
- **Option 6 (Save and exit, skip audit)**: rare escape hatch when the user knows the integrity check is unnecessary or has been done recently. Go directly to STEP SAVE without auditing. The `audit.is_already_audited` flag remains as it was. Use sparingly.

---

# OPERATION 1: Add Progress Entry

```
📝 Describe the progress, finding, or decision:

(Examples: "Completed endpoint with validation",
 "Discovered bug in middleware",
 "Decision: use pattern X because Y")
```

Wait for user input. Store as `content`.

```
How would you describe your current state? (optional, Enter to skip)
(focused, frustrated, excited, uncertain, blocked)
```

Store as `mood` or null.

**Create context entry:**

```json
{
  "id": [next_id],
  "created_at": "[now UTC ISO 8601]",
  "content": "[user_input]",
  "mood": "[mood_if_provided]"
}
```

**Prepend** to `recent_context` array (index 0, newest first).

**Check: History Compaction Needed?**

IF `recent_context.length > 20`:
→ Go to **STEP COMPACT**

```
✅ Progress added!

Would you like to do another operation? (Yes/No)
```

IF "Yes" → Go to Step 3
IF "No" → Go to **STEP SAVE**

---

# OPERATION 2: Update Objective Status

```
What type of objective do you want to update?

1. Main objective
2. Secondary objective

Choose 1 or 2:
```

**Show objectives of selected type with current status:**

```
[Main/Secondary] Objectives:

1. [ID: 1] ⚪ not_started - [content truncated...]
2. [ID: 2] 🟡 active - [content truncated...]
3. [ID: 3] 🟢 achieved - [content truncated...]

Which one do you want to update? (number or ID):
```

User selects objective.

```
Current status: [current_status]

New status:
1. ⚪ not_started (pending)
2. 🟡 active (in progress)
3. 🔴 blocked (blocked)
4. 🟢 achieved (completed)
5. ⚫ abandoned (cancelled)

Choose 1-5:
```

**Update objective status.**

**Auto-create context entry documenting the change:**

```json
{
  "id": [next_id],
  "created_at": "[now UTC]",
  "content": "Objective [ID] status changed: [old] → [new]. [objective.content]"
}
```

**IF status changed to "achieved" on secondary objective:**

Check if ALL secondary objectives for related main are achieved.

IF yes:
```
🎉 All secondary objectives completed!

Mark main objective #[id] as achieved?
"[main_objective.content]"

(Yes/No)
```

IF "Yes" → Update main objective status to "achieved"

```
✅ Status updated!

Would you like to do another operation? (Yes/No)
```

IF "Yes" → Go to Step 3
IF "No" → Go to **STEP SAVE**

---

# OPERATION 3: Add New Objective

```
What type of objective do you want to add?

1. Main objective - High level, requires scope
2. Secondary objective - Granular, requires completion_guide

Choose 1 or 2:
```

---

## OPERATION 3A: Add Main Objective

```
📌 New main objective

What is the verifiable outcome? (max 180 chars)
(Example: "POST /products endpoint creates product with validation")
```

Store as `content`.

```
What is the business/technical context? (max 300 chars)
(Why is it needed? Who requires it?)
```

Store as `context`.

**IF project_type === "software":**

```
What are the reference files? (one per line, empty Enter to finish)
(Example: src/controllers/ProductController.ts)
```

Store as `files` array.

```
What project rules apply? (IDs separated by comma, or Enter for none)
(Example: 3, 7, 12)
```

Store as `rules` array.

Create main objective:
```json
{
  "id": [next_main_id],
  "created_at": "[now UTC]",
  "content": "[content]",
  "context": "[context]",
  "scope": {
    "files": ["[files]"],
    "rules": [[rules]]
  },
  "status": "not_started"
}
```

**IF project_type === "general":**

```
What reference materials apply? (one per line, empty Enter to finish)
(Example: Chapter 2 in Google Docs, Client brief, https://reference.com)
```

Store as `references` array.

```
What standards or guides apply? (one per line, or Enter for none)
(Example: APA 7th edition, Brand guidelines, ISO 27001)
```

Store as `standards` array.

Create main objective:
```json
{
  "id": [next_main_id],
  "created_at": "[now UTC]",
  "content": "[content]",
  "context": "[context]",
  "scope": {
    "references": ["[references]"],
    "standards": ["[standards]"]
  },
  "status": "not_started"
}
```

Go to confirmation step.

---

## OPERATION 3B: Add Secondary Objective

```
📝 New secondary objective

What is the specific outcome? (max 180 chars)
(Should be completable in one work session)
```

Store as `content`.

**IF project_type === "software":**

```
Provide the completion guide (one per line, empty Enter to finish):
(Reference specific files, patterns, line numbers, rules)

Example:
• Use pattern from src/services/UserService.ts:45
• Apply rule #3: input validation
```

**IF project_type === "general":**

```
Provide the completion guide (one per line, empty Enter to finish):
(Reference documents, sections, examples, standards)

Example:
• Follow Chapter 2 structure
• Apply APA format for citations
• Review tutor feedback (notes 15-nov)
```

Store as `completion_guide` array.

Create secondary objective:
```json
{
  "id": [next_secondary_id],
  "created_at": "[now UTC]",
  "content": "[content]",
  "completion_guide": ["[guide_items]"],
  "status": "not_started"
}
```

**Add to respective array and create context entry:**

```json
{
  "id": [next_id],
  "created_at": "[now UTC]",
  "content": "New [main/secondary] objective added: [content]"
}
```

```
✅ Objective added!

Would you like to do another operation? (Yes/No)
```

IF "Yes" → Go to Step 3
IF "No" → Go to **STEP SAVE**

---

# OPERATION 4: Add Reminder

```
⏰ New reminder

What do you want to remember?
```

Store as `reminder_content`.

```
When should the reminder appear?

1. Next session
2. In X hours (specify)
3. Specific date (YYYY-MM-DD HH:MM)

Choose 1-3:
```

Calculate `when` datetime based on selection.

Create reminder:
```json
{
  "id": [next_reminder_id],
  "created_at": "[now UTC]",
  "content": "[reminder_content]",
  "when": "[calculated_datetime]"
}
```

Add to `future_reminders` array.

```
✅ Reminder created!

Would you like to do another operation? (Yes/No)
```

IF "Yes" → Go to Step 3
IF "No" → Go to **STEP SAVE**

---

# STEP COMPACT: History Compaction

When `recent_context.length > 20`:

```
📦 Compacting history...

Recent context exceeds 20 entries.
Compacting oldest entries.
```

**Process:**

1. Take oldest entry (last in array)

2. Using **context-summarizer** subagent (or inline logic), compress to max 140 chars:
   - Original: "Completed endpoint implementation with full validation including email format, password strength, and duplicate user checks. Also added rate limiting middleware."
   - Summary: "EP done: validation (email, password, duplicates) + rate limiting middleware added"

3. Create `history_summary` entry:
```json
{
  "id": [next_summary_id],
  "created_at": "[now UTC]",
  "content": "[summary]",
  "mood": "[preserved_if_exists]"
}
```

4. **Prepend** to `history_summary` array

5. **Remove** oldest from `recent_context`

6. **Check:** IF `history_summary.length > 10`:
   - Remove oldest (last) from `history_summary`

```
✅ History compacted:
• Entry moved: "[original_content_truncated]..."
• Summary: "[summary]"
```

Return to calling step.

---

# STEP SAVE: Save and Exit

**Validate JSON against appropriate schema:**
- IF `project_type === "software"` OR `project_type === "agentic"` → Validate against `logbook_software_schema.json` (the schema is structurally compatible with both — agentic logbooks carry scope.files pointing to skill/hook/config files)
- IF `project_type === "general"` → Validate against `logbook_general_schema.json`

**Save to `ai_files/waves/[wave_name]/logbooks/[filename].json`**

## STEP AUDIT: Logbook Integrity Audit (always, unless explicitly skipped)

This step **runs every time the command reaches it**, regardless of which operations were performed. The contract: anything that passes through `logbook-update` ends with verified integrity.

**Skip only when:**
- The user explicitly chose Step 3 option 6 ("Save and exit, skip audit"). In that case, log a `recent_context` entry: `"Integrity audit skipped by user request"` and exit.

**Otherwise:**

1. Set `audit.is_already_audited = false` in the logbook (a fresh audit is owed).
2. Save the logbook with the flag updated (atomic write).
3. Spawn the integrity reviewer subagent following the **same protocol as Step A6 in `waves:logbook-create`**: blocking, model from `agent_config.metacognition_model` (default `opus`), output to `ai_files/waves/[wave_name]/audits/logbook-[basename].json`, same adversarial prompt that flags `missing_rules_in_primary`, `completion_guide_missing_apply_rule_lines`, `rule_id_not_found`, `decomposition_mismatch`, `duplicate_primary_content`, `primary_empty_scope_files`, `secondary_missing_completion_guide`, `scope_files_path_not_found`, `completion_guide_too_generic`, `orphan_secondary` (only `critical` and `warning` severities).
4. Process findings: critical findings reviewed and applied with full context; warnings decided per-finding; rejections recorded in `resolved_decisions` with `method: "integrity_audit_override"`.
5. After applying fixes (or determining none are needed), update the logbook: `audit.is_already_audited = true`, `audit.audit_file = "<relative path>"`.
6. Append a `recent_context` entry: `"Integrity audit run: [N] critical, [M] warnings. Audit report: ai_files/waves/[wave_name]/audits/logbook-[basename].json"`.

### Why STEP AUDIT is unconditional

Earlier designs gated this step on "structural changes only" (new objectives, scope.rules modified, completion_guide changed). That heuristic missed two important cases:
- The user wants to audit a logbook without modifying content (e.g. one created before Waves 2.2.0, or one they just want to re-verify after a `project_rules.json` update).
- A `recent_context` entry or status update can sometimes coincide with a stale audit on the rest of the logbook that should be re-run.

By making STEP AUDIT unconditional, `logbook-update` becomes the single entry point to verify integrity of any logbook on demand. The latency (~30-60s of the subagent) is paid once per `logbook-update` invocation, which is not a hot-path command. The escape hatch (option 6) is for the rare case where the user knows the audit is unnecessary.

**Show summary:**

```
✅ Logbook updated!

📁 File: ai_files/waves/[wave_name]/logbooks/[filename].json

📊 Changes made:
• Context entries added: [count]
• Objectives updated: [count]
• New objectives: [count]
• Reminders: [count]
[If integrity audit ran:]
• Integrity audit: [N] critical, [M] warnings ([applied/noted breakdown])

🎯 Next objective to work on:
[First not_started or active secondary objective]

Guide:
[completion_guide items]
```

---

# Quick Update Mode

When the agent has been working with the user and has context from the session, offer a quick update:

```
💡 I detected we've been working on:
• Completed: [detected achievements]
• Findings: [detected findings]

Would you like to add this to the logbook automatically? (Yes/No/Adjust)
```

This allows:
1. Detect completed objectives from conversation
2. Extract findings and decisions
3. Propose context entries
4. User confirms or adjusts

---

# Automatic Context Entry Triggers

The agent should automatically offer to add context entries when:

| Trigger | Suggested Entry |
|---------|-----------------|
| Error resolved | "Resolved [error]: [solution]" |
| Decision made | "Decision: [choice] because [reason]" |
| Blocker encountered | "Blocked: [issue]. Waiting for [dependency]" |
| Objective completed | "Completed: [objective.content]" |
| New discovery | "Found: [discovery] in [location]" |

---

## Status Icons Reference

| Icon | Status | Meaning |
|------|--------|---------|
| ⚪ | not_started | Pending, not yet begun |
| 🟡 | active | Currently in progress |
| 🔴 | blocked | Waiting on external input/dependency |
| 🟢 | achieved | Completed successfully |
| ⚫ | abandoned | Cancelled, no longer needed |

---

## Subagents Reference

| Subagent | Purpose |
|----------|---------|
| context-summarizer | Compress context entries for history_summary (max 140 chars) |

END OF COMMAND
