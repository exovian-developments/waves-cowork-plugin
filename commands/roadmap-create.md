---
description: Create a product-level roadmap with phases and milestones
allowed-tools: Read, Grep, Glob, Bash(git:*), Task
---

# Plugin Command: roadmap-create

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.


You are executing the waves plugin roadmap creation command. This is an interactive orchestrator that gathers project context and delegates heavy analysis to the roadmap-orchestrator agent.

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

You are the main orchestrator for roadmap creation. Keep this thread lean — collect user input, check prerequisites, detect context, then dispatch to the agent for analysis.

## Step 1: Check Prerequisites

**Multi-project note (root-only validation):** prerequisite artifacts (`user_pref.json`, `project_manifest.json`, `project_rules.json`, plus any required blueprint) are validated at root (`waves_files/<artifact>`) regardless of whether the `--project <name>` flag is set. Scopes inherit root prerequisites. If a root prerequisite is missing in multi-project mode, abort with a message pointing to root setup (e.g., "Run /waves:project-init at root first — multi-project scopes inherit root prerequisites.") — NEVER to a per-scope path. The `base_path` from the Multi-project scope helper applies to WORK artifacts (logbooks, scoped rules/manifest/blueprint), not to prerequisite existence checks.

Verify user preferences and project structure exist:

```bash
test -f waves_files/user_pref.json && echo "✓ User preferences found" || echo "✗ Missing waves_files/user_pref.json"
test -f waves_files/project_manifest.json && echo "✓ Project manifest found" || echo "⚠ No manifest (optional)"
```

If user_pref.json doesn't exist:
- Ask: "Would you like to run `project-init` first to set up your preferences?"
- If yes → Exit with message to run project-init
- If no → Continue with defaults

## Step 2: Detect Project Context

Scan for:
- `waves_files/project_manifest.json` (primary context)
- `waves_files/project_rules.json` (constraints)
- `waves_files/project_standards.json` (standards and conventions)

Read each file if present and summarize findings:
```
✓ Found project manifest
  - Project type: [type]
  - Technology: [stack]
  - Team size: [size]

⚠ No coding rules found
```

## Step 3: Gather Product Vision

Ask the user (in their preferred language from user_pref.json):

```
📋 Let's create your product roadmap.

1️⃣ What is your product name?
   Example: "MyApp", "Analytics Platform", "Mobile Game"

→ Awaiting input:
```

After each response, confirm and continue:

```
2️⃣ What does it do? (1-2 sentence description)

→ Awaiting input:
```

```
3️⃣ Who is the product owner? (person responsible for decisions)

→ Awaiting input:
```

```
4️⃣ What's the primary business goal for the next 6 months?
   Example: "Launch MVP", "Reach 10K users", "Migrate to new stack"

→ Awaiting input:
```

```
5️⃣ Any known constraints? (timeline, budget, team size, tech choices)
   Example: "2 engineers, 3 months, must use React"
   Or: "0. I don't know (auto-detect)"

→ Awaiting input:
```

Store responses as:
```json
{
  "product_name": "string",
  "product_description": "string",
  "product_owner": "string",
  "primary_goal": "string",
  "constraints": "string"
}
```

## Step 4: Dispatch to roadmap-orchestrator Agent

Create an analysis prompt:

```
You are the roadmap-orchestrator agent. Create a new product roadmap.

PROJECT CONTEXT:
- Product name: {product_name}
- Description: {product_description}
- Owner: {product_owner}
- Primary goal: {primary_goal}
- Constraints: {constraints}

PROJECT FILES:
{manifest content if exists}
{rules content if exists}
{standards content if exists}

TASK: Analyze this context and generate a roadmap with:
1. 3-5 phases (max 7) following YAGNI principle
2. Phase 1 always "Foundation"
3. 2-5 milestones per phase with acceptance criteria
4. Identified decisions and open questions
5. Phase durations and status

Output as JSON matching logbook_roadmap_schema.json format.
```

Use the Task tool to invoke the agent:

```
Task: roadmap-orchestrator
Input: [analysis prompt above]
```

Wait for the agent to return a JSON roadmap structure.

## Step 5: Present Proposed Roadmap

Display the roadmap to the user in a readable format:

```
📊 PROPOSED ROADMAP: {product_name}

Vision:
  Mission: {mission from roadmap}
  Key Outcomes:
    - {outcome 1}
    - {outcome 2}
    ...

PHASES:
─────────────────────────────────────────

Phase 1: {phase name}
  Duration: {duration_weeks} weeks
  Status: not_started

  Milestones:
    • {milestone_id}: {milestone_name}
      Acceptance: {first acceptance criterion}
    • {milestone_id}: {milestone_name}
      Acceptance: {first acceptance criterion}

[Repeat for each phase]

DECISIONS IDENTIFIED:
  - {decision 1}
  - {decision 2}

OPEN QUESTIONS:
  - {question 1}
  - {question 2}

─────────────────────────────────────────

Does this roadmap align with your vision? (yes/no/adjust)
```

## Step 6: User Validation

If user says "adjust":
- Ask: "What should change? (phases, milestones, timeline, goals)"
- Gather adjustments
- Call agent again with refined prompt

If user says "yes":
- Proceed to Step 7

If user says "no":
- Ask: "Would you like to start over or adjust specific areas?"
- Handle response appropriately

## Step 7: Generate Roadmap File

Read the schema from plugin references:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/logbook_roadmap_schema.json"
```

Apply timestamps to the roadmap JSON:
- `created_at`: Current UTC timestamp (ISO 8601)
- `last_updated`: Current UTC timestamp (ISO 8601)

Construct output path using wave convention:
- List `waves_files/waves/` directory to find existing wave directories
- If none exist AND `waves_files/feasibility.json` or `waves_files/foundation.json` exist: suggest `sub-zero`
- If none exist AND no feasibility/foundation: use `w0` (foundation wave — agnostic capabilities)
- If `sub-zero` exists but no `w0`: suggest `w0`
- If `w0` exists but no `w1`: suggest `w1`
- If `wN` exists: suggest `w[N+1]` (increment from highest existing)
- Ask user to confirm wave name
- Create directory `waves_files/waves/[wave_name]/` if it doesn't exist

```
waves_files/waves/[wave_name]/roadmap.json
```

Example: `waves_files/waves/sub-zero/roadmap.json`, `waves_files/waves/w0/roadmap.json`, `waves_files/waves/w1/roadmap.json`

Wave types:
- sub-zero = Initial feasibility/foundation setup
- w0 = Foundation — agnostic capabilities not in any base project
- w1+ = Business waves — vertical-specific capabilities

Write the roadmap JSON to the file.

**Prepend** a reference to `product_roadmaps` in `waves_files/blueprint.json` (if blueprint exists):
- Read `waves_files/blueprint.json`
- If `product_roadmaps` array does not exist, create it as empty array first
- Prepend (insert at index 0) a new entry: `{"wave": "[wave_name]", "path": "waves/[wave_name]/roadmap.json"}`
- Write the updated blueprint back
- If blueprint does not exist, skip this step silently

## Step 8: Confirm Success

Display:

```
✅ Roadmap created successfully!

📄 File: waves_files/waves/{wave_name}/roadmap.json

Next steps:
  • Use `roadmap-update` to track progress
  • Use `logbook-create` to start working on Phase 1 milestones
  • Reference this roadmap in your CLAUDE.md context

Happy building! 🚀
```

## Error Handling

### User Interrupts
If user cancels during any step:
```
✗ Roadmap creation cancelled.

To create a roadmap later, run: roadmap-create
```

### Agent Fails
If the roadmap-orchestrator agent returns errors:
```
⚠ Agent Analysis Failed

Error: {error message}

Try:
1. Simplify project constraints
2. Provide a clearer vision statement
3. Check that project files are valid JSON
```

### File Write Fails
If writing the roadmap file fails:
```
⚠ Could not save roadmap

Path: {path}
Error: {error}

Try:
1. Ensure waves_files/ directory exists
2. Check file permissions
3. Use a different filename
```

## Milestone ID Convention

The roadmap-orchestrator assigns milestone IDs in format: `{phase_id}.{sequence}`

Example:
- Phase 1 milestones: phase-1.1, phase-1.2, phase-1.3
- Phase 2 milestones: phase-2.1, phase-2.2
- Phase 3 milestones: phase-3.1, phase-3.2, phase-3.3, phase-3.4

These IDs are immutable and used for tracking and cross-referencing in logbooks.

## Notes

- Always respect the user's language preference from user_pref.json
- Be encouraging about the vision and goals
- Keep the roadmap realistic (not over-optimistic)
- Explain why phases are ordered as they are
- Emphasize that the roadmap is a living document — it will evolve
