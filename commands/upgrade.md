---
description: Apply Waves artifact migrations after a plugin update (idempotent, no marker)
allowed-tools: Read, Write, Edit, Bash
---

# /waves:upgrade — Artifact migrations (plugin-first, idempotent)

In Waves 3.0+ the framework (commands, hooks, agents, skills, schemas) lives in the Claude Code plugin and is updated with `/plugin update`. **This command does NOT copy framework files** — that is the plugin's job. Its only responsibility is to migrate your PROJECT ARTIFACTS (blueprint, rules, roadmaps, logbooks, CLAUDE.md) to match the framework version you now have installed, by applying declarative migrations from `${CLAUDE_PLUGIN_ROOT}/migrations/`.

**Single door (roadmap w6 decision #29):** `/waves:upgrade` is the only command a user ever needs to run to bring a project up to date, whatever version it starts from. It does NOT absorb the v2→v3 migration logic — it ORCHESTRATES it: Step 0 detects a pre-v3 project and executes `/waves:migrate-from-v2-to-v3` (the single owner of that logic) before the fingerprint chain. The migration command is removed once every host project has been migrated; this command stays forever.

## Step 0: Pre-v3 detection (orchestrate the one-time migration)

A project is **pre-v3** when it still carries per-project framework copies: any of `.claude/commands/waves:*.md`, `.claude/hooks/waves-*.sh`, or `ai_files/schemas/` exists (the legacy 2.x layout).

0. **Dual-install detection (field report 2026-06-10).** Check the same three indicators in the PARENT directories too (walk up from the project root, e.g. a workspace parent like `../.claude/commands/waves:*.md`). Claude Code loads parent-project commands, so a legacy copy in a parent SHADOWS the plugin with ~2.x protocol — the worst failure mode, because the agent silently follows old instructions. IF found in a parent → WARN the user with the exact paths and recommend removing the legacy copies there (back them up first; if the parent is not a git repo, suggest a tar backup). Do NOT delete parent files yourself without explicit user confirmation.
1. Check those three indicators in the project itself. IF none present → the project is v3+ → go to Step 1.
2. IF any present → inform the user:
   ```
   This project still has the Waves 2.x layout. Running the one-time migration
   first (/waves:migrate-from-v2-to-v3), then continuing with the migration chain.
   ```
   Execute the full `/waves:migrate-from-v2-to-v3` flow (read that command file and follow it — do NOT duplicate its logic here). If it aborts (dirty git tree, missing plugin), STOP this upgrade with its message — do not continue to Step 1 on a half-migrated project.
3. When it completes, continue to Step 1 — the fingerprint chain then applies every later migration (v3.0→v3.1, …) in order, so a v2 project lands fully current in ONE user command.

## Design: idempotent + auto-detect, no version marker

Since 3.0.2 there is **no `.waves-version` file**. The marker was deprecated because (a) `/plugin update` can run silently and desync the marker from the actual installed version, and (b) artifact state itself is a more honest source of truth.

Instead, every migration declares a **fingerprint** (a shell command whose exit code reveals whether the migration is already applied). `/waves:upgrade` evaluates each migration's fingerprint and applies only the ones whose fingerprint shows the change is missing. Result: running the command multiple times is safe — applied migrations are skipped automatically.

## Step 1: Detect language

1. Read `waves_files/user_pref.json`. Extract `preferred_language`. If missing, use English. (On an unmigrated project where only `ai_files/` exists, read `ai_files/user_pref.json` instead.)

**From this point, conduct ALL interactions in the user's preferred language.**

2. Read installed plugin version from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` → `.version`. Store as `plugin_version` (for the summary header only — not used for migration selection).

## Step 2: Evaluate fingerprints, select migrations

1. List migration files in `${CLAUDE_PLUGIN_ROOT}/migrations/*.md`. Each file's frontmatter declares:
   - `from_version` (informational, semver of starting state)
   - `to_version` (informational, semver of ending state)
   - `fingerprint` (shell command — exit 0 = already applied, non-zero = needs to apply)
   - `requires_clean_git` (optional, boolean) — safety flag, see Step 3
   - `destructive` (optional, boolean) — safety flag, see Step 3

2. For each migration in ascending `to_version` order:
   - Run the `fingerprint` shell command.
   - If exit 0 → migration already applied → skip.
   - If non-zero → migration pending → mark for application.

3. If no migrations are pending:
   ```
   ✅ All migrations already applied. Project is aligned with plugin v[plugin_version].
   ```
   → EXIT

4. Display:
   ```
   Pending migrations for plugin v[plugin_version]:
     • [to_version] — [one-line description from frontmatter]
     ...
   Applying...
   ```

## Step 3: Apply pending migrations

For each pending migration (ascending `to_version` order):

1. **Honor the safety flags** (ported from the v2→v3 migration's ceremony — destructive steps deserve it):
   - `requires_clean_git: true` → run `git status --porcelain`. If non-empty → STOP this migration (and everything after it in the chain) with: "Your git tree has uncommitted changes. Git is the safety net for this migration — commit or stash first, then re-run /waves:upgrade." If not a git repository → STOP and recommend `git init` + commit first.
   - `destructive: true` → compute and DISPLAY the full plan (the migration's Steps with paths resolved against THIS project) before touching anything, then ask for explicit confirmation: `Apply migration [to_version]? (yes/no)`. Anything but an explicit yes → skip this migration and everything after it (later migrations may depend on it). If the user invoked `/waves:upgrade --dry-run`, print the plan and STOP without mutating anything.
2. Read its body. Execute the `## Steps` section as a checklist.
3. Steps are artifact patches: add a missing field, move a file, update a CLAUDE.md block, etc. Each step SHOULD also be idempotent (check before write) but the fingerprint guarantees the migration as a whole is safe to re-run.
4. Ask the user a question ONLY where the migration step explicitly instructs you to.

## Step 4: Summary

```
=== Upgrade complete ===

Migrations applied:
  [for each applied migration: to_version — one-line description]

Artifacts patched:
  [for each file touched: path — what changed]

Plugin version: v[plugin_version]
===
```

No session restart is needed for artifact migrations (hooks/commands already updated by `/plugin update`).

## Note on legacy `.waves-version`

Projects upgraded from Waves 2.x may still have an `ai_files/.waves-version` file on disk. It is now an inert legacy artifact — no command reads or writes it. You can delete it with `rm ai_files/.waves-version` whenever convenient, or leave it (harmless).
