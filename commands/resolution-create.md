---
description: Generate ticket resolution document
allowed-tools: Read, Write, Glob
---

# Command: resolution-create $ARGUMENTS

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.

You are executing the resolution creation command. Follow these instructions exactly.

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

You generate structured resolution documents from completed logbooks. Resolutions serve as historical records of what was accomplished and learned.

**Note:** This command is for software projects only.

## Step -1: Prerequisites Check

1. Check if `waves_files/user_pref.json` exists.
   - IF NOT EXISTS → Display: "⚠️ Please initialize the project first." → EXIT COMMAND

2. Read `waves_files/user_pref.json`:
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
- Search in `waves_files/waves/*/logbooks/` for the file.
- IF NOT FOUND → Show error with available logbooks.

IF `$ARGUMENTS` is empty:
- List available logbooks from `waves_files/waves/*/logbooks/`:

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

## Step 2.5: Adversarial Verification — No-Fabrication (A→B, blocking)

A resolution is the worst risk/coverage ratio in the whole framework: it is the artifact most trusted as a historical record (future agents read it as ground truth) yet, until now, written with ZERO independent verification. The generating agent has every incentive to make the work sound complete and clean. This step extends design_principle #7 to the resolution write path — the in-command twin of `waves-foundational-audit.sh` and the foundation verifier. The author (you, the main agent) wrote the resolution; the no-fabrication check is **delegated to fresh subagents to remove author bias**. The verifier **classifies, it does not veto** — you decide with both outputs (project_rule #1). This runs LAST among the Phase 9 coverage additions because resolution is not yet in active use; it is the lowest-frequency path, highest-trust artifact.

### Step 2.5.1: Spawn analyst A (fresh, minimal context, blocking)

Spawn an Agent with `run_in_background=false` using the model from `agent_config.metacognition_model` in user_pref.json (default: `opus`). Do NOT pass your accumulated context. Pass only: the generated resolution markdown (from Step 2), the path to the logbook file, and the paths to its audit reports (the `integrity-audit`, `correctness-postplan`, `correctness-postimpl` files co-located in the logbook directory, if present).

```
You are a no-fabrication auditor with MINIMAL context by design. Another agent wrote the resolution below, claiming what was accomplished in a piece of work. Your job is to verify each claim against the EVIDENCE (the logbook's achieved objectives + its audit reports) — NOT to confirm the author's narrative.

Resolution:
<the Step 2 markdown>

Read the logbook at <logbook path> and its audit reports at <audit paths>. For EVERY substantive claim in the resolution (each completed objective, key decision, technical learning, "files modified"), judge:
- supported: a specific achieved objective, recent_context entry, or audit finding backs the claim. Cite the objective id / context id / audit field.
- unsupported: no objective/context/audit backs it — the claim is fabricated or inferred beyond the record. Cite what is MISSING.
- overstated: a real objective backs it, but the resolution inflates the outcome (e.g. "fully implemented and tested" when the objective is achieved but no test evidence exists in the audits).

Do NOT drop any claim. Output a compact list: claim -> verdict -> one-line reason citing the objective id / audit field (or what is missing). Under 350 words.
```

### Step 2.5.2: Persist A, then spawn verifier B (fresh, blocking)

Persist A's raw output into the logbook directory (timestamped) so it survives interruption. Then spawn a second fresh Agent (`run_in_background=false`, same model), pasting A's full output:

```
You are an independent, skeptical verifier with MINIMAL context by design. Auditor A judged a resolution's claims against the work record below. Verify and classify each of A's verdicts — NOT expand, NOT filter.

A's verdicts:
<<< PASTE A's FULL OUTPUT HERE >>>

Apply TWO lenses to each verdict:
1) TECHNICAL — Read the logbook and its audit reports and confirm or refute A's citation. Does the objective id / audit field A names actually exist and actually say what A claims? Cite objective id / audit field.
2) VALUE — is A's verdict real or pedantic? Apply KISS/YAGNI. A reasonable summary that compresses three objectives into one sentence is not "overstated" if all three are achieved.

Classify EACH as: confirmed (A's verdict holds) / smoke (A is wrong or pedantic) / unverifiable (insufficient evidence — say so) / gold (confirmed AND high-impact: a fabricated claim that would mislead every future reader). Output: claim -> A's verdict -> your class -> one-line reason citing the objective id / audit field. Under 300 words.
```

### Step 2.5.3: Present both, correct, then preview

Present BOTH A's verdicts and B's classification to the user. Then, as the main agent, **rewrite the claims B confirmed as unsupported/overstated** — remove fabrications, soften inflated outcomes to match the evidence — BEFORE the Step 3 preview. The subagents never edit the resolution (project_rule #5); only you do, after seeing both lenses. `smoke` → keep the claim; `unverifiable` → your judgment; `confirmed`/`gold` → correct it. Only then proceed to preview the corrected resolution.

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

1. Derive the wave and slug from the logbook's path. The slug is the logbook basename without `.json` (directory-per-logbook convention, design_principle #11 — see SKILL.md). Do not ask the user — infer automatically. Transition: a logbook may still be in the OLD flat layout (`logbooks/auth-implementation.json`) or the new directory (`logbooks/auth-implementation/logbook.json`); handle both.
2. Save the resolution INTO the logbook's own directory: `waves_files/waves/[wN]/logbooks/[slug]/resolution.md` (fixed name; `ticket_resolution_schema`, a markdown document). Create the directory if needed.
   - Example: logbook `auth-implementation` → `waves_files/waves/w1/logbooks/auth-implementation/resolution.md`. This co-locates the resolution with the logbook + its audits, replacing the old sibling `resolutions/` directory.

## Step 5: Success Message

```
✅ Resolution created!

📁 File: waves_files/waves/[wN]/logbooks/[slug]/resolution.md

📊 Summary:
  • Objectives completed: [count]
  • Objectives pending: [count]
  • Decisions documented: [count]
  • Learnings captured: [count]

💡 This resolution will serve as a future reference
for similar problems and decisions.
```

END OF COMMAND
