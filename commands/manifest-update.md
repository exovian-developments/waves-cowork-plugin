---
description: Update manifest with detected project changes
allowed-tools: Read, Write, Glob, Grep, Bash, Task
---

# Plugin Command: manifest-update

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.


You are executing the waves plugin manifest update command. Follow these instructions exactly.

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

You are the main orchestrator for manifest updates. Detect changes since the last update and propose precise manifest modifications based on actual code/project changes. Dispatch to agents via Task tool for heavy analysis work.

### Two entry points (w6 Phase 10)

The manifest now stays fresh by TWO paths, and you should know which one you are on:

- **Automatic (primary): Flow C — hook-delegated graduated freshness.** After every commit that touches CODE, the `waves-manifest-freshness.sh` hook delegates a SCOPED, magnitude-proportional refresh of just that commit's changes (see Flow C below). This is the path that actually keeps the manifest fresh in practice — the always-heavy manual re-scan went unused for months (product_decision #26). Most freshness happens here, invisibly, at the commit boundary.
- **Manual (fallback): Flows A/B — full re-scan since `last_updated`.** Run `/waves:manifest-update` by hand only for a FIRST sync after a long gap, a drift-recovery audit, or when no commit boundary applies (Flow B, no git). These flows re-scan everything and are intentionally heavier — reserve them for when the incremental Flow C is not enough.

If you arrived here from the hook's `additionalContext`, go straight to **Flow C** and skip Steps 0-1.

## Step -1: Prerequisites Check (CRITICAL)

1. Check if `waves_files/user_pref.json` exists.
   - IF NOT EXISTS → Display error: "⚠️ Missing configuration! Run project-init first." → EXIT COMMAND

2. Read `waves_files/user_pref.json`:
   - Extract `user_profile.preferred_language` → Use for all interactions
   - Extract `project_context.project_type` → Determines flow

3. Check if corresponding manifest exists:
   - Software → `waves_files/project_manifest.json`
   - Academic → `waves_files/research_manifest.json`
   - Creative → `waves_files/creative_manifest.json`
   - Business → `waves_files/business_manifest.json`
   - General → `waves_files/general_manifest.json`

4. IF manifest NOT EXISTS → Display in user's language:
   ```
   ⚠️ No manifest found to update.

   Create one first with:
   manifest-create
   ```
   → EXIT COMMAND

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Read Current Manifest and Confirm

1. Read the manifest file.
2. Extract `last_updated` date and `project.name`.

3. Display in user's language:
   ```
   📘 Command: manifest-update

   I'll detect changes since the last manifest update
   and automatically update relevant fields.

   📅 Last updated: [last_updated date]
   📁 Manifest: [manifest_path]

   Continue? (Yes/No)
   ```

4. IF No → Exit.

## Step 1: Detect Version Control System

1. Check if `.git` directory exists at project root.

2. IF `.git` EXISTS:
   - Store `version_control = "git"`
   - Go to **Flow A: Git-based Update**

3. IF `.git` NOT EXISTS:
   - Store `version_control = "none"`
   - IF software project, show recommendation about initializing git.
   - Go to **Flow B: Timestamp-based Update**

---

## Flow A: Git-based Update

### Step A1: Analyze Git History via Task Tool

Display progress:
```
📊 Git history analysis:

📅 Period: [from] → [to] ([days] days)
📝 Analyzing commits and file changes...
```

Using Task tool, invoke **git-history-analyzer** agent to:
- Analyze git history since `last_updated` date
- Extract commits, authors, file changes
- Categorize modifications as new, modified, deleted

Display when complete:
```
📅 Period: [from] → [to] ([days] days)
📝 Commits found: [count]
📁 Files affected: [count]
```

### Step A2: Filter Autogenerated Files via Task Tool

Using Task tool, invoke agent to filter the git-detected files:
- Remove files matching .gitignore
- Identify framework autogenerated files
- Identify codegen outputs

Display:
```
🔍 Filtering autogenerated files:

Ignored by .gitignore: [count] files
Ignored by framework: [count] files
Ignored by codegen: [count] files

📋 Relevant files for analysis:
  • Modified: [count]
  • New: [count]
  • Deleted: [count]
```

### Step A3: Analyze Changes Against Manifest Criteria via Task Tool

Using Task tool, invoke **change-analyzer** agent to:
- Map changes to manifest fields
- Detect new features, dependencies, architecture changes
- Identify significant modifications vs minor updates

### Step A4: Present Proposed Changes

Display all proposed changes to the user:
```
📝 Proposed manifest changes:

[List each proposed change with action, field, and evidence]

Options:
1. Apply all changes
2. Review each one individually
3. Cancel
```

### Step A5: Apply Updates

For approved changes:
1. Update `last_updated` to today
2. Apply all approved modifications
3. Validate against schema

### Step A6: Success Message

Display in user's language:
```
✅ Manifest updated!

📁 File: [manifest_path]
📅 New date: [today]

📊 Update summary:

[Summary of changes by category]

🎯 Next step:

  If you added new architecture layers, consider:
  rules-update

  To document the conventions of the new code.
```

---

## Flow B: Timestamp-based Update

### Step B1: Find Changed Files via Task Tool

Display:
```
🔍 Scanning for file changes since [last_updated]...
```

Using Task tool, invoke **change-analyzer** agent to:
- Detect files modified or created since `last_updated`
- Filter by file type (relevant to project_type)
- Build list of changed files

Display:
```
📋 Changed files detected:
  • Modified: [count]
  • New: [count]

⚠️ Note: Without Git, deleted files cannot be detected.
```

### Step B2: Filter Autogenerated Files (if software)

IF software project: Using Task tool, filter the detected files to remove autogenerated ones.
IF general project: Skip (less relevant).

### Step B3: Analyze Changes via Task Tool

Using Task tool, invoke **change-analyzer** agent to analyze the changed files:
- Map changes to manifest fields
- Detect modifications worth noting
- Identify significant updates

### Step B4: Present and Apply

Display proposed changes:
```
📝 Proposed manifest changes:

[List each proposed change]

Options:
1. Apply all changes
2. Review each one individually
3. Cancel
```

For approved changes, apply and update `last_updated`.

Display limitation warning:
```
⚠️ Note: Without Git, deleted files cannot be detected.

If you deleted files that were in the manifest,
you may need to review them manually or use:
manifest-create (to regenerate from scratch)
```

Success message:
```
✅ Manifest updated!

📁 File: [manifest_path]
📅 New date: [today]

📊 Changes applied and recorded.
```

---

## Flow C: Commit-boundary graduated freshness (hook-delegated — w6 Phase 10)

This is the path the `waves-manifest-freshness.sh` hook delegates to after a commit that touches CODE (blueprint capability #8, product_decision #26). Unlike Flows A/B — which re-scan EVERYTHING since `last_updated`, the always-heavy manual mode that goes unused after months — Flow C is SCOPED to one commit's changed code files and runs an analysis budget PROPORTIONAL to the change. The manifest's discipline here is FRESHNESS (not the adversarial internal-consistency of w6 Phase 9), and its highest-value output is the `relations[]` blast-radius graph — the couplings grep cannot see.

The hook hands you, in its `additionalContext`: the manifest path, the list of CODE files changed in the commit (non-code paths — `waves_files/`, docs, lockfiles — were already filtered out at zero token cost), and the Waves artifact co-committed in the same diff (the INTENT source). You enter here directly — skip Steps 0-1 and Flows A/B.

### Step C1: Recover INTENT (the WHY) — not from the commit message

Read the WHY of the change from the Waves artifact co-committed in the SAME diff, in this priority order:
1. **artifact-in-diff** (preferred): the logbook / roadmap / diverged_work changed in this very commit — read its objective, decision, or recent_context to learn what the code was FOR. The why travels in the diff, so you never depend on a good commit message or a PR.
2. **active logbook**: if no Waves artifact is in the diff, fall back to the active logbook (the one with `not_started`/`active` objectives) in the current wave.
3. **diff + blueprint** (loose fix): if neither exists, infer intent from the diff itself + the blueprint capability the changed files serve.

Intent is what lets you SIZE the change correctly — the same 20-line diff is cosmetic in one context and a new capability in another.

### Step C2: Classify MAGNITUDE (proportional budget)

| Magnitude | Signal | Manifest action | Budget |
|-----------|--------|-----------------|--------|
| **cosmetic** | rename, formatting, a margin, one field, a comment, a log line | NO-OP — say so in one line, write nothing. Freshness, not churn. | ~0 |
| **structural** | a new module / dependency / layer / endpoint / entry point | update only the affected section (`modules`, `architecture_identified`, `platform_info`, `key_files`) + any `relations[]` edge the change creates or breaks | scoped read of the changed files only |
| **new-capability** | a new blueprint capability realized (a websocket, an encrypted store, a new external integration) | go to Step C3 (deep) | full analyzer pass SCOPED to the changed files |

When unsure between cosmetic and structural, prefer the cheaper class (KISS); the next commit that builds on it will reclassify. When the magnitude is high (new-capability) and the manifest rewrite would be broad, **present the proposed changes before writing** — do not silently rewrite large sections (project_rule #1: the agent informs, the human keeps authority over wide changes).

### Step C3: Deep new-capability analysis (the `relations[]` graph is the point)

For a new capability:
1. **Reuse the manifest-create analyzers** (`architecture-detective`, `dependency-auditor`, `feature-extractor`) via the Task tool — but SCOPED to the changed files, not the whole repo (REGLA-0 DRY: do not write new analyzers; the deep path only fires on new-capability, so the cost is paid where it is warranted).
2. **Compute the new technologies** the capability introduces (a library, a protocol, a store) → update `platform_info` / `technical_details`.
3. **Compute the blast-radius `relations[]` edges** the capability creates — the couplings grep cannot see (the new module `consumes` X; a `trigger` fires it; a flag `guards` it). Add them as `{from, to, kind, why}`. This is the highest-value output: the graph is the substrate that the cost sensor (cost-per-component), the corpus miner (findings per region), and the correctness layer all read.
4. **Write the manifest PROPORTIONALLY** — only the sections the capability touches. Update `last_updated`.

### Step C4: Bootstrap (dp#8) — this phase eats its own dogfood

This phase's own commit (the `relations[]` field + the freshness hook = a new capability of waves itself) is the first real exercise of Flow C: it should refresh waves' own `project_manifest.json` with the new hook scripts (as `key_files`) and the `relations[]` edges they create (e.g. `waves-manifest-freshness.sh` triggers a manifest update on a code commit; `waves-foundational-audit.sh` guards blueprint/roadmap writes). That refresh IS the `verification_demonstration` of Phase 10. NOTE: if the existing manifest predates the current schema or the project's `project_type` (e.g. a software-shaped manifest on an agentic project), a Flow C incremental update is the wrong tool — that is a full `manifest-create` regeneration, a separate proportional task; surface it rather than half-converting the shape inside an incremental refresh.

END OF COMMAND
