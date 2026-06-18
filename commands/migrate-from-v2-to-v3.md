---
description: One-time migration to Waves 3.0 — relocates artifacts to the directory-per-logbook layout (auto, --dry-run) and removes legacy framework files
allowed-tools: Read, Bash, Edit, Write
deprecated_in: 3.2.0
---

# /waves:migrate-from-v2-to-v3 — One-time migration to v3.0 (TEMPORAL)

> ⚠️ **DEPRECATED — REMOVE IN v3.2.0.** This is a single-use transitional command that migrates a project to Waves 3.0: (a) it **relocates** artifacts into the **directory-per-logbook** layout (w6), and (b) it removes the legacy 2.x per-project framework copies (commands/hooks/schemas now served by the plugin). A migrated project never needs it again; it will be deleted in release 3.2.0. **Migration is ONE-WAY.**

You are migrating THIS project to Waves 3.0. This command (a) **relocates every logbook + its analyses into its own directory** (`logbooks/<slug>/logbook.json` + co-located `integrity-audit.json` / `resolution.md`), and (b) removes the project's legacy framework copies. **It is STRUCTURAL ONLY — it moves files, it NEVER edits the content of an existing logbook.** Each existing logbook is an immutable historical snapshot: its internal shape reflects the schema of its moment, and that record of the framework's evolution must be preserved. The new v3 fields (parent_main_id, audit.integrity, etc.) are optional (schemas are OPEN, design_principle #11), so old logbooks stay valid without them; only NEW logbooks are born with the v3 shape. Forward-only.

## Modes

| Invocation | Mode |
|---|---|
| `/waves:migrate-from-v2-to-v3` | `auto` — preview, confirm, then apply |
| `/waves:migrate-from-v2-to-v3 --dry-run` | `dry-run` — print the full plan (every file move), touch NOTHING, exit |

**When to use `--dry-run`:** run it **FIRST, always** — especially on a real consumer project — to review exactly what will move before any mutation. Then re-invoke without `--dry-run` to apply. The dry run is the safe preview; the real run is gated by a clean git tree + post-relocation validation.

## ⚠️ Critical sequencing — NEVER invert this order

The correctness of this command IS its order. Mutating artifacts or removing framework files before the plugin is confirmed working + git is clean leaves the project in a broken, backup-less state.

1. **Confirm the plugin is installed and functional** (Step 1).
2. **Confirm the git tree is clean** (Step 2) — git is the ONLY safety net; there is no automatic backup.
3. **Plan + confirm** (Step 3) — in `--dry-run`, stop here after printing the plan.
4. **Relocate artifacts** (Step 3.5 — move only, never edit content), **THEN remove legacy framework files** (Step 4).
5. **Validate every relocated logbook** (Step 5); if any fails to parse/validate, the migration is NOT done.

If Step 1 or Step 2 fails, ABORT immediately and change NOTHING.

## Step 0: Language

Read `ai_files/user_pref.json` (or `user_pref.json`) → `preferred_language` (default English). Conduct all interactions in that language.

## Step 0.5: Parse arguments

Detect `--dry-run` in the invocation. If present, set `dry_run = true` (Step 3 prints the full plan and EXITS without mutating anything). Otherwise `dry_run = false` (auto mode). No other flags.

## Step 1: Pre-flight — plugin installed and functional

1. Verify `$CLAUDE_PLUGIN_ROOT` is set and points to a directory containing `commands/`, `hooks/`, and `skills/waves-protocol/references/` (the schemas the commands depend on).
2. IF `$CLAUDE_PLUGIN_ROOT` is unset or any of those is missing → **ABORT**:
   ```
   ❌ Waves plugin not detected (or incomplete). Install it first:
      /plugin marketplace add exovian-developments/waves-cowork-plugin
      /plugin install waves@waves-cowork-plugin
   Confirm /waves:* commands work, THEN re-run this migration.
   ```
   → EXIT (remove nothing)

## Step 2: Pre-flight — git tree clean

1. Run `git status --porcelain`.
2. IF the output is non-empty (uncommitted changes) → **ABORT**:
   ```
   ❌ Your git tree has uncommitted changes. git is the only safety net for this
      destructive migration — there is no automatic backup. Commit or stash first,
      then re-run /waves:migrate-from-v2-to-v3.
   ```
   → EXIT (remove nothing)
3. IF this is not a git repository → **ABORT** with a recommendation to `git init` and commit the current state first (so the migration is reversible). → EXIT (remove nothing)

## Step 3: Plan, report, and confirm (or, in `--dry-run`, stop here)

Compute the FULL plan WITHOUT mutating anything yet:

1. **Artifact relocation plan** (directory-per-logbook fold — see Step 3.5 for the exact rules). Scan every `ai_files/waves/*/logbooks/` (generic over any project tree, not waves-specific):
   - For each logbook still in the OLD flat layout (`logbooks/X.json`, no `X/` directory), list the moves: `X.json → X/logbook.json`, plus `audits/logbook-X.json → X/integrity-audit.json` and `resolutions/X-resolution.md → X/resolution.md` IF those siblings exist.
   - Skip logbooks already in the new layout (idempotent — no move listed for them).
   - This plan lists ONLY file moves. No logbook CONTENT is edited — see the structural-only note in Step 3.5.
2. **Legacy framework removal plan** — files that WILL be removed: `.claude/commands/waves:*.md`, `.claude/hooks/waves-*.sh`, `ai_files/schemas/` (the framework schema copies), and waves hook entries in `.claude/settings.json` (entries whose `command` references `waves-*.sh`).
   - **Schema heterogeneity classification (NEVER assume `ai_files/schemas/` is homogeneous).** Before listing the schema dir for removal, compare each `ai_files/schemas/*.json` against the canonical set in `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/` (match by filename; a file present there is a framework copy, removable). **Any schema NOT present in the plugin's references is USER-OWNED** — it must be classified `user-owned (preserve)`, NEVER bundled into the removal. A field report (2026-06) had a project carrying 4 custom schemas in `ai_files/schemas/`; a dry-run that listed them as user-owned is what prevented an `rm -rf` from destroying them.
3. **Display the full plan** (artifact moves + legacy removals, with counts + paths). When the schema dir is mixed, show the split explicitly: `[N] framework schemas (removable)` + `[K] user-owned schemas (PRESERVED — list each path)`. If any user-owned schema exists, the plan must propose a destination (move to `waves_files/schemas_custom/` or leave in place) and **require explicit confirmation before removing anything from `ai_files/schemas/`** — homogeneous dirs (framework-only) get removed without extra friction (don't punish the common case). State clearly: **every logbook's CONTENT is preserved untouched — only its file location is normalized; non-waves config and user-owned schemas are never touched.**
4. **IF `dry_run`:** print `"This was a --dry-run. Nothing changed. Re-invoke without --dry-run to apply."` and **EXIT** (zero mutations).
5. **ELSE** ask for explicit confirmation: `Apply this migration — [A] artifact moves, [B] legacy removals? (yes/no)`. IF the answer is not an explicit yes → EXIT (change nothing).

## Step 3.5: Relocate artifacts to the directory-per-logbook layout (STRUCTURAL ONLY)

ONLY after Step 3 confirmation (and only when NOT `--dry-run`). This step **moves files; it NEVER edits the content of any logbook.** Each existing logbook is an immutable historical snapshot — its internal shape is the schema of its moment and must be preserved as the record of the framework's evolution. The new v3 fields are optional (schemas OPEN, design_principle #11), so relocated logbooks stay valid as-is. Do NOT backfill `parent_main_id`, do NOT restructure the `audit` object, do NOT rewrite any internal path — relocation is forward-only and content-free.

For each logbook still in the OLD flat layout, in each `ai_files/waves/*/logbooks/` (use `git mv`, which preserves history; git is the safety net):

1. `mkdir -p logbooks/<slug>/` where `<slug>` is the logbook basename without `.json` (e.g. `phase_1`, `L03-2-867`).
2. `git mv logbooks/<slug>.json logbooks/<slug>/logbook.json`.
3. IF `audits/logbook-<slug>.json` exists → `git mv` it to `logbooks/<slug>/integrity-audit.json`.
4. IF `resolutions/<slug>-resolution.md` exists → `git mv` it to `logbooks/<slug>/resolution.md`.
5. Tolerate missing siblings (move only what exists; no error). Skip any logbook whose `<slug>/` directory already exists (idempotent — already migrated). Old v2 logbooks have NO `correctness-postplan/postimpl.json` (those gates were inline pre-3.0) — do NOT fabricate them.

## Step 4: Remove legacy framework + write the version marker

ONLY after Steps 1-3 have all passed (and Step 3.5 in a non-dry-run):

1. Remove `.claude/commands/waves:*.md`.
2. Remove `.claude/hooks/waves-*.sh`.
3. **Remove ONLY the framework schemas from `ai_files/schemas/`** (the files classified `removable` in Step 3 because they match a canonical schema in the plugin's references). For any schema classified `user-owned`, apply the destination confirmed in Step 3 (move to `waves_files/schemas_custom/` or leave) — NEVER `rm` it. Remove the now-empty `ai_files/schemas/` directory only if no user-owned schema remains in it.
4. **Clean `.claude/settings.json` (if it exists):** remove every hook entry whose `command` references a `waves-*.sh` script (these now point to deleted files and would error on every tool call). If a hook-event array (`SessionStart`/`PreToolUse`/`PostToolUse`) becomes empty after removal, drop it; if the entire `hooks` object becomes empty, drop the `hooks` key. **Preserve all non-waves content** (permissions, other hooks, unrelated settings). The plugin now provides the hooks via its own `hooks.json`.
5. Do NOT touch any other file in `ai_files/` or `.claude/` (user-owned commands, other hooks, etc.).
6. **Clean up legacy version markers.** Remove `ai_files/.waves-version` and `.claude/waves-version` if either exists. Since 3.0.2 no marker file is needed — the plugin version is read from `$CLAUDE_PLUGIN_ROOT` at runtime and `/waves:upgrade` uses artifact-state fingerprints to decide what to migrate.

## Step 5: Post-migration validation gate + verify and summarize

0. **Validation gate (BLOCKING — the migration is not "done" until this passes).** For every logbook RELOCATED in Step 3.5, validate via the **kernel rail** (not an inline `python3 -m jsonschema` call — the rail adds id-uniqueness and a visible degradation warning when no interpreter is present, and avoids the deprecated-CLI warning seen in the field):
   ```
   bash ${CLAUDE_PLUGIN_ROOT}/kernel/bin/waves-artifact-validate \
     logbooks/<slug>/logbook.json \
     ${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/<SCHEMA>
   ```
   **Pick `<SCHEMA>` by `project_type`** (read `project_type` from `user_pref.json`; default `software`): `software` or `agentic` → `logbook_software_schema.json`; `general` → `logbook_general_schema.json`. **If `project_type` names a variant with no `logbook_<type>_schema.json` in the references (e.g. `agentic`), emit an EXPLICIT one-line warning naming the fallback — `"project_type 'agentic' has no dedicated logbook schema; validating against logbook_software_schema.json (structurally compatible)"` — and continue.** NEVER fall back silently. Since content was NOT touched, a logbook that was valid before stays valid — this gate confirms the relocation did not corrupt anything AND surfaces any logbook that was ALREADY invalid before migration (a pre-existing broken artifact). IF any relocated logbook fails validation → **STOP, report the failing logbook + field, and do NOT declare the migration complete.** git is the safety net — recoverable with `git restore` / `git reset`. (Known fields validate strictly; OPEN extras pass — design_principle #11.)
1. Confirm 0 files remain matching `.claude/commands/waves:*.md` or `.claude/hooks/waves-*.sh`, and that no FRAMEWORK schema remains in `ai_files/schemas/`. User-owned schemas, if any, are present at their confirmed destination (this is expected — `ai_files/schemas/` may still exist if it holds only user-owned files).
2. Confirm `.claude/settings.json` (if present) has no remaining `waves-*.sh` references.
3. Confirm `ai_files/.waves-version` and `.claude/waves-version` are both absent.
4. Confirm `ai_files/` artifacts are still present (blueprint, project_rules, roadmaps, logbooks).
5. Display the summary:
   ```
   === Migration complete: Waves 2.x → 3.0 plugin-first ===

   Removed:
     [N] .claude/commands/waves:*.md
     [M] .claude/hooks/waves-*.sh
     ai_files/schemas/
     [K] waves hook entries from .claude/settings.json
     legacy version markers (.claude/waves-version, ai_files/.waves-version) if present

   Kept (untouched):
     ai_files/ artifacts (blueprint, rules, roadmaps, logbooks, user_pref, manifest)

   The framework is now served by the plugin. Run /waves:version to confirm.
   ===
   ```
