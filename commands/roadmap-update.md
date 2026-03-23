---
description: Update an existing product roadmap
allowed-tools: Read, Grep, Glob, Bash(git:*), Task
---

# Plugin Command: roadmap-update

You are executing the waves plugin roadmap update command. This is an interactive orchestrator that manages roadmap modifications, delegating complex updates to the roadmap-orchestrator agent.

## Your Role

You are the main orchestrator for roadmap updates. Keep this thread lean — load the roadmap, present a dashboard, ask what changed, dispatch to the agent, and apply confirmed changes.

## Step 1: Check Prerequisites

Verify project setup:

```bash
test -f ai_files/user_pref.json && echo "✓ User preferences found" || echo "✗ Missing user_pref.json"
```

If missing, ask user to run `project-init` first.

## Step 2: Select Roadmap File

List available roadmap files in wave directories:

```bash
ls -1 ai_files/waves/*/roadmap.json 2>/dev/null
```

If none found:
```
⚠ No roadmaps found in ai_files/waves/

To create a new roadmap, run: roadmap-create
```
Exit.

If exactly one roadmap exists:
```
✓ Using roadmap: Wave {wave_name} (ai_files/waves/{wave_name}/roadmap.json)
```

If multiple exist, ask:
```
📋 Which roadmap would you like to update?

Options:
  1. Wave sub-zero (ai_files/waves/sub-zero/roadmap.json)
  2. Wave 0 (ai_files/waves/w0/roadmap.json)
  3. Wave 1 (ai_files/waves/w1/roadmap.json)
  ...

Choose a number or wave name:
```

Store selected roadmap path.

## Step 3: Load and Display Dashboard

Read the selected roadmap JSON file.

Display a dashboard:

```
📊 ROADMAP DASHBOARD: {product_name}

Overall Status: {status}
Last Updated: {last_updated}
Created: {created_at}

PHASE PROGRESS:
─────────────────────────────────────────

Phase 1: {phase_name}
  Status: {status}

  Milestones ({completed}/{total} done):
    ✓ phase-1.1: {milestone_name} [COMPLETED]
    ◐ phase-1.2: {milestone_name} [ACTIVE]
    ○ phase-1.3: {milestone_name} [NOT_STARTED]

Phase 2: {phase_name}
  Status: {status}

  Milestones ({completed}/{total} done):
    ○ phase-2.1: {milestone_name} [NOT_STARTED]
    ○ phase-2.2: {milestone_name} [NOT_STARTED]

[Continue for all phases]

RECENT DECISIONS ({count}):
  • {decision_1}
  • {decision_2}
  [show last 3]

OPEN QUESTIONS ({count}):
  ❓ {question_1}
  ❓ {question_2}
  [show last 3]

─────────────────────────────────────────

What would you like to update?
```

## Step 4: Ask Update Type

Present update options in user's language:

```
🔄 UPDATE OPTIONS:

  1. Update milestone progress (mark complete, active, blocked, abandoned)
  2. Record a decision made during development
  3. Add or resolve an open question
  4. Transition to next phase
  5. Restructure phases/milestones (reorder, add, remove)
  0. Cancel

Choose a number:
```

Store user's choice.

## Step 5: Gather Update Details

Based on update type:

### Type 1: Update Milestone Progress

```
🎯 Update Milestone Status

Which milestone?
  • phase-1.1: {name}
  • phase-1.2: {name}
  • phase-1.3: {name}
  [show all incomplete milestones]

Choose milestone ID:
```

```
What's the new status?
  • active (currently working on it)
  • completed (done!)
  • blocked (stuck, explain why)
  • abandoned (not doing this one)

Choose status:
```

If blocked or abandoned:
```
Explain why:
```

If completed:
```
When was it completed? (YYYY-MM-DD or "today")
```

Gather:
```json
{
  "update_type": "progress",
  "milestone_id": "phase-1.2",
  "new_status": "completed",
  "timestamp": "2026-02-26",
  "notes": "string or null"
}
```

### Type 2: Record a Decision

```
📝 Record Decision

Which milestone does this decision relate to?
  • phase-1.1: {name}
  • phase-1.2: {name}
  [show active/completed milestones]

Or: 0. General/not tied to a milestone

Choose:
```

```
What decision was made?
  Example: "Chose PostgreSQL over MongoDB for ACID compliance"
           "Decided to use React hooks instead of class components"

Type the decision:
```

```
Why was this decision important?
  Example: "Data consistency is critical for transactions"

Brief explanation:
```

Gather:
```json
{
  "update_type": "decision",
  "milestone_id": "phase-1.1 or null",
  "decision_text": "string",
  "rationale": "string",
  "timestamp": "ISO 8601"
}
```

### Type 3: Add or Resolve Open Question

```
❓ Manage Open Questions

Options:
  1. Add a new question
  2. Resolve an existing question

Choose 1 or 2:
```

If adding:
```
What's the question?
  Example: "Should we implement caching with Redis or memcached?"
           "How do we handle real-time collaboration?"

Type the question:
```

Gather:
```json
{
  "update_type": "question",
  "action": "add",
  "question_text": "string",
  "related_milestone": "phase-X.Y or null",
  "timestamp": "ISO 8601"
}
```

If resolving:
```
Which question was resolved?
  • {question_1}
  • {question_2}
  [show open questions]

Choose a number:
```

```
What was the resolution?
  Example: "Chose Redis for its performance and community support"

Type the resolution:
```

Gather:
```json
{
  "update_type": "question",
  "action": "resolve",
  "question_index": number,
  "resolution_text": "string",
  "decision_made": "string",
  "timestamp": "ISO 8601"
}
```

### Type 4: Phase Transition

```
📍 Phase Transition

Current phase: {phase_name}
  Status: {status}
  Completion: {completed}/{total} milestones done

Is this phase complete? (yes/no)

If yes → ready to move to next phase
If no → use 'Update milestone progress' first
```

If phase is complete:
```
Moving to next phase:
  {next_phase_name}

Additional notes about this transition?
  (optional, press enter to skip)
```

Gather:
```json
{
  "update_type": "phase_transition",
  "from_phase_id": "phase-1",
  "to_phase_id": "phase-2",
  "completion_summary": "string or null",
  "timestamp": "ISO 8601"
}
```

### Type 5: Restructure Phases/Milestones

```
🔧 Restructure Roadmap

What would you like to do?
  1. Reorder phases (change priority)
  2. Add new milestone to a phase
  3. Remove a milestone
  4. Rename milestone or phase

Choose a number:
```

For each action, gather details:

```
If adding milestone:
  - Which phase?
  - Milestone name?
  - Description?
  - Acceptance criteria (comma-separated)?

If removing milestone:
  - Which milestone?
  - Confirm removal?

If reordering:
  - New phase order (comma-separated phase IDs)?

If renaming:
  - Current name?
  - New name?
```

Gather:
```json
{
  "update_type": "restructure",
  "action": "add|remove|reorder|rename",
  "target_phase": "phase-X",
  "target_milestone": "phase-X.Y or null",
  "changes": { "before": {}, "after": {} },
  "timestamp": "ISO 8601"
}
```

## Step 6: Dispatch to roadmap-orchestrator Agent

Create an analysis prompt:

```
You are the roadmap-orchestrator agent. Apply an update to an existing roadmap.

CURRENT ROADMAP:
{roadmap JSON content}

UPDATE REQUEST:
{update details gathered in Step 5}

TASK: Apply the {update_type} update and validate state transitions.

Return JSON matching the UPDATE mode output format:
- update_type: string
- affected_items: array of milestone/phase IDs
- changes: { before: {}, after: {} }
- context_entries: array of new logbook context entries
- validation: { status: valid|invalid, issues: [] }

If validation fails, explain what's wrong and suggest alternatives.
```

Use the Task tool:

```
Task: roadmap-orchestrator
Input: [analysis prompt above]
```

Wait for the agent to return validation and proposed changes.

## Step 7: Present Changes and Get Confirmation

Display:

```
🔍 PROPOSED CHANGES:

{change description from agent output}

AFFECTED ITEMS:
  • {item_1}
  • {item_2}

VALIDATION:
  Status: {valid|invalid}
  {issues if any}

{if valid}
CONTEXT ENTRIES THAT WILL BE GENERATED:
  • {context_entry_1}
  • {context_entry_2}
{/if}

Proceed? (yes/no)
```

If user says "no":
```
✗ Update cancelled.

What would you like to change?
  [return to Step 4]
```

If user says "yes":
- Proceed to Step 8

## Step 8: Apply Changes

Apply the changes from the agent to the roadmap JSON:

1. Update affected milestones/phases with new status/content
2. Add context_entries to `recent_context` array
3. Update `product.last_updated` to current UTC timestamp
4. Manage context compaction: if `recent_context` length > 20, move oldest entries to `history_summary`

Write the updated JSON back to the file.

## Step 9: Confirm Success

Display:

```
✅ Roadmap updated successfully!

Summary of changes:
  • {change_1}
  • {change_2}

{if context entries generated}
Logbook context generated: {count} entries

To view detailed progress, run:
  logbook-create (for new milestone logbooks)
  or logbook-update (for existing logbooks)
{/if}

Roadmap file: ai_files/waves/{wave_name}/roadmap.json
Last updated: {timestamp}
```

## Error Handling

### Validation Failures
If the roadmap-orchestrator reports validation errors:

```
⚠ Update cannot be applied:
  - {issue_1}
  - {issue_2}

Suggestions:
  {suggestion_1}
  {suggestion_2}

Would you like to adjust the update? (yes/no)
```

If yes, return to Step 4 to gather alternative details.

### File Write Fails
```
⚠ Could not save roadmap

Error: {error message}

Try:
1. Ensure the file is not open in another editor
2. Check directory permissions
3. Try again
```

### Missing Roadmap File
If the roadmap file is deleted between steps:

```
⚠ Roadmap file no longer exists: {path}

Return to file selection? (yes/no)
```

## Context Compaction Strategy

The roadmap uses rolling context to stay manageable:

- `recent_context`: Most recent 20 entries (detailed)
- `history_summary`: Older entries compressed to 10 summaries

When `recent_context.length > 20`:
1. Take oldest 5 entries
2. Summarize: "Milestones X and Y progressed; decisions A and B recorded"
3. Move summary to `history_summary`
4. Remove oldest entries from `recent_context`
5. Keep newest 15 entries + new entry = 20

## Notes

- Always show the current roadmap state before asking for updates
- Respect milestone dependencies (can't mark phase 2 complete if phase 1 isn't done)
- Keep decision descriptions concise but meaningful
- Encourage regular updates so the roadmap stays fresh
- Explain why certain changes might not be possible (validation errors)
