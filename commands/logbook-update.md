---
description: Update logbook with progress and new context
allowed-tools: Read, Write, Edit
---

# Command: logbook-update $ARGUMENTS

You are executing the logbook update command. Follow these instructions exactly.

## Your Role

You are the main orchestrator for logbook updates. You will help users track progress, update objective statuses, add new objectives discovered during work, and manage reminders.

## Step -1: Prerequisites Check

Check if `ai_files/user_pref.json` exists.

IF NOT EXISTS:
```
⚠️ Missing configuration!

Please initialize the project first.
```
→ EXIT COMMAND

IF EXISTS:
1. Read `ai_files/user_pref.json`
2. Extract `preferred_language` → Use for all interactions
3. Extract `project_type` → For schema validation

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Logbook Selection

Check if filename parameter was provided with the command.

**IF parameter provided:**
1. Search for file in `ai_files/waves/*/logbooks/[filename].json`
2. IF NOT EXISTS → Error: "Logbook not found: [filename]"
3. IF EXISTS → Load logbook, note which wave it belongs to, continue

**IF NO parameter:**
1. Show tip:
```
💡 TIP: You can run faster with:
   logbook-update TICKET-123.json
```

2. List available logbooks from all waves `ai_files/waves/*/logbooks/*.json`, showing which wave each belongs to, and let user select

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
┌────┬────────────────────────────────────────────┬─────────────┐
│ ID │ Content                                    │ Status      │
├────┼────────────────────────────────────────────┼─────────────┤
│ 1  │ [objective.content truncated...]           │ [icon] [status] │
│ 2  │ [objective.content truncated...]           │ [icon] [status] │
└────┴────────────────────────────────────────────┴─────────────┘

📝 Secondary Objectives (active/pending):
┌────┬────────────────────────────────────────────┬─────────────┐
│ 1  │ [objective.content truncated...]           │ [icon] [status] │
│ 2  │ [objective.content truncated...]           │ [icon] [status] │
└────┴────────────────────────────────────────────┴─────────────┘

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

```
What would you like to do?

1. 📝 Add progress (new context entry)
2. ✅ Update objective status
3. ➕ Add new objective
4. ⏰ Add reminder
5. 💾 Save and exit

Choose 1-5:
```

Route to corresponding operation.

---

# OPERATION 1: Add Progress Entry

```
📝 Describe the progress, finding, or decision:

(Examples: "Completed endpoint with validation",
 "Discovered bug in middleware",
 "Decision: use pattern X because Y")
```

Store as `content`.

```
How would you describe your current state? (optional, Enter to skip)
(focused, frustrated, excited, uncertain, blocked)
```

Store as `mood` or null.

**Create context entry and prepend to `recent_context` array.**

**Check: History Compaction Needed?**

IF `recent_context.length > 20`:
→ Go to **STEP COMPACT**

```
✅ Progress added!

Would you like to do another operation? (Yes/No)
```

---

# OPERATION 2: Update Objective Status

```
What type of objective do you want to update?

1. Main objective
2. Secondary objective

Choose 1 or 2:
```

Show objectives of selected type with current status. User selects objective.

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

**Auto-create context entry documenting the change.**

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

**IF project_type === "general":**

```
What reference materials apply? (one per line, empty Enter to finish)
(Example: Chapter 2 in Google Docs, Client brief)
```

Store as `references` array.

```
What standards or guides apply? (one per line, or Enter for none)
(Example: APA 7th edition, Brand guidelines)
```

Store as `standards` array.

Confirm and add to logbook.

---

## OPERATION 3B: Add Secondary Objective

```
📝 New secondary objective

What is the specific outcome? (max 180 chars)
(Should be completable in one work session)
```

Store as `content`.

```
Provide the completion guide (one per line, empty Enter to finish):

[For software projects:]
(Reference specific files, patterns, line numbers, rules)

[For general projects:]
(Reference documents, sections, examples, standards)
```

Store as `completion_guide` array.

Confirm and add to logbook.

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

Calculate `when` datetime. Create reminder and add to `future_reminders` array.

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

2. Compress to max 140 chars using summarization logic

3. Create `history_summary` entry and prepend to array

4. Remove oldest from `recent_context`

5. IF `history_summary.length > 10`:
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
- IF `project_type === "software"` → Validate against `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/logbook_software_schema.json`
- IF `project_type === "general"` → Validate against `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/logbook_general_schema.json`

**Save to `ai_files/waves/[wave_name]/logbooks/[filename].json`**

**Show summary:**

```
✅ Logbook updated!

📁 File: ai_files/waves/[wave_name]/logbooks/[filename].json

📊 Changes made:
• Context entries added: [count]
• Objectives updated: [count]
• New objectives: [count]
• Reminders: [count]

🎯 Next objective to work on:
[First not_started or active secondary objective]

Guide:
[completion_guide items]
```

END OF COMMAND
