---
description: Generate ticket resolution document
allowed-tools: Read, Write, Glob
---

# Command: resolution-create $ARGUMENTS

You are executing the resolution creation command. Follow these instructions exactly.

## Your Role

You generate structured resolution documents from completed logbooks. Resolutions serve as historical records of what was accomplished and learned.

**Note:** This command is for software projects only.

## Step -1: Prerequisites Check

1. Check if `ai_files/user_pref.json` exists.
   - IF NOT EXISTS → Display: "⚠️ Please initialize the project first." → EXIT COMMAND

2. Read `ai_files/user_pref.json`:
   - Extract `preferred_language`
   - Extract `project_type`

3. IF `project_type !== "software"`:
   ```
   ⚠️ This command is for software projects only.

   For general projects, your logbook already documents progress.
   Use logbook-update to mark objectives as completed
   and add final context entries.
   ```
   → EXIT COMMAND

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Determine Logbook

IF `$ARGUMENTS` is provided:
- Use it as the logbook filename.
- Search in `ai_files/waves/*/logbooks/` for the file.
- IF NOT FOUND → Show error with available logbooks.

IF `$ARGUMENTS` is empty:
- List available logbooks from `ai_files/waves/*/logbooks/`:

```
📚 Available logbooks:

[For each .json file, showing which wave it belongs to]:
  [number]. [wave]/[filename] (last modified: [date])

Choose a logbook:
```

## Step 1: Read and Analyze Logbook

1. Read the selected logbook file.
2. Extract:
   - `ticket.title` and `ticket.description`
   - All objectives (main + secondary) with their statuses
   - `recent_context` entries
   - `history_summary` entries
   - `future_reminders` (if any)

3. Analyze the logbook to identify:
   - Objectives achieved vs abandoned
   - Key decisions made (from context entries)
   - Blockers encountered and how they were resolved
   - Technical learnings
   - Files modified (from objective scopes)

## Step 2: Generate Resolution Document

Create a markdown document following this structure:

```markdown
# Resolution: [ticket.title]

**Date:** [today's date]
**Duration:** [calculated from logbook timestamps]
**Logbook:** [logbook filename]
**Ticket:** [ticket.url if present]

## Summary

[2-3 sentence summary of what was accomplished]

## Objectives Completed

[For each achieved objective]:
- [x] [objective content]

## Objectives Not Completed

[For each abandoned/blocked objective]:
- [ ] [objective content] — [reason]

## Key Decisions

[List important decisions extracted from context entries]
- [decision] — [reasoning]

## Challenges & Solutions

[For each blocker that was resolved]:
1. **[Challenge]** → [Solution]

## Technical Learnings

[Key technical insights gained during the work]
- [learning]

## Files Modified

[List of files from objective scopes]
- [file path] — [what was changed]

## Future Considerations

[From future_reminders and unfinished objectives]
- [consideration]
```

## Step 3: Preview and Confirm

Display the generated resolution and ask:

```
📄 Resolution preview:

[Show the full resolution]

Options:
1. Save as-is
2. Edit before saving
3. Cancel

Choose:
```

IF "Edit" → Let user provide modifications, apply edits, regenerate preview.

## Step 4: Save File

1. Derive the wave from the logbook's path (e.g., if logbook is at `ai_files/waves/w1/logbooks/auth-implementation.json`, the wave is `w1`). Do not ask the user — infer automatically.
2. Create directory if needed: `ai_files/waves/[wN]/resolutions/`
3. Save as: `ai_files/waves/[wN]/resolutions/[logbook-name]-resolution.md`
   - Example: logbook at `ai_files/waves/w1/logbooks/auth-implementation.json` → `ai_files/waves/w1/resolutions/auth-implementation-resolution.md`

## Step 5: Success Message

```
✅ Resolution created!

📁 File: ai_files/waves/[wN]/resolutions/[filename]

📊 Summary:
  • Objectives completed: [count]
  • Objectives pending: [count]
  • Decisions documented: [count]
  • Learnings captured: [count]

💡 This resolution will serve as a future reference
for similar problems and decisions.
```

END OF COMMAND
