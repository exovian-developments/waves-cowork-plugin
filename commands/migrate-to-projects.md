---
description: Migrate a flat waves_files/ project to multi-project structure (auto, --interactive, --dry-run)
allowed-tools: Read, Write, Bash, AskUserQuestion, Glob, Grep
---

# Command: /waves:migrate-to-projects $ARGUMENTS

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.

You are transforming a single-project `waves_files/` layout into a multi-project layout (`projects/<scope>/...`). Three modes — default `auto`, `--interactive`, `--dry-run`. Every migration decision is classified per the Waves 5-level trust contract; auto applies only Level 1-2, escalates Level 3+ to the user (in `--interactive` mode) or aborts (in `auto` mode, asking the user to re-run with `--interactive`). `--dry-run` prints the plan without touching disk.

## Your Role

You are a transformation orchestrator. The user has a working `waves_files/` and now wants to split it across multiple scoped projects (e.g., extract the frontend rules from a monorepo's mixed rules file into `projects/frontend/waves_files/project_rules.json`). You:

1. **Infer** the scope partitioning from filesystem signals (monorepo markers, language stacks, manifest hints).
2. **Plan** every file operation as a classified migration step.
3. **Execute** the plan respecting the chosen mode + the 5-level escalation gate.
4. **Reuse** the scope-creation primitive from `/waves:project-add` whenever the plan needs to create a new scope.

## Step 1: Parse mode flags

Mode is single-select; flags are mutually exclusive:

| Invocation | Mode |
|------------|------|
| `/waves:migrate-to-projects` | `auto` (default) |
| `/waves:migrate-to-projects --interactive` | `interactive` |
| `/waves:migrate-to-projects --dry-run` | `dry-run` |

If both `--interactive` and `--dry-run` are passed → abort with usage hint.

## Step 2: Refuse if already multi-project

1. If `projects/` exists and contains ≥1 subdirectory → abort:
   ```
   ❌ This repo is already in multi-project mode. /waves:migrate-to-projects only converts single-project layouts.
      Run /waves:projects to inspect the existing scopes.
   ```
2. If `waves_files/` itself does not exist → abort: nothing to migrate.

## Step 3: Infer scope partitioning

Inspect the working tree for monorepo signals and build a `PROPOSED_SCOPES` list. Heuristics (apply each; multiple matches = multiple proposed scopes):

| Signal | Proposed scope name | Inferred type |
|--------|---------------------|---------------|
| `packages/<name>/` or `apps/<name>/` directories at repo root | `<name>` per directory | infer from `package.json` / `pubspec.yaml` / file extensions |
| `frontend/` + `backend/` sibling directories | `frontend`, `backend` | `frontend`, `backend` |
| `pubspec.yaml` at root + nested `pubspec.yaml` files | One scope per nested `pubspec.yaml` parent | `backend` (Dart) or `frontend` (Flutter) per `dependencies.flutter` presence |
| `package.json` workspaces array | One scope per workspace pattern | `frontend` if React/Vue/Next, else `backend` |
| No signals → single proposed scope using current `project_name` | `<project_name>` | inherit `type` from current `waves_files/project_rules.json` |

For each proposed scope, also detect:
- **Owned rules**: which rule categories in current `waves_files/project_rules.json` likely belong to this scope (e.g., `presentation_layer` → frontend scope; `api_layer` → backend scope; `governing_principles` stays at root as shared).
- **Owned logbooks**: which `waves_files/waves/*/logbooks/*.json` reference files inside this scope's directories (parse `objectives.main[].scope.files`).
- **Owned manifest sections**: if a scope dir has its own `pubspec.yaml`/`package.json`, the manifest likely splits.

## Step 4: Build migration plan

For each file currently at root, classify the migration step. Plan entries:

```
{ source: <abs_path>, dest: <abs_path or "stays_root">, classification: L1|L2|L3|L4|L5, reason: "..." }
```

5-level classification rubric for migration decisions (aligned with Waves trust contract):

| Level | Decision type | Example |
|-------|---------------|---------|
| **L1** | Mechanical move with no semantic change | Copy `waves_files/waves/w1/logbooks/X.json` into a scope's `waves/w1/logbooks/` if all files it references live under one scope dir. |
| **L2** | Mechanical with cosmetic adjustment | Update `project_name` field in the moved logbook to match scope. |
| **L3** | Scope-level decision (was-mixed → is-split) | Split `project_rules.json` rules across `governing_principles` (root) + `presentation_layer` (frontend scope) + `api_layer` (backend scope). Requires user judgment on category assignment. |
| **L4** | Business-level decision affecting capability behavior | The current blueprint references a capability that now lives in one scope only — does it remain a root capability or move to the scope's blueprint? Affects `parent_blueprint`/`child_blueprint` linkage (Phase 1 w5 tree blueprints). |
| **L5** | Discovery decision with independent value | Heuristic surfaces a scope partitioning the user did not anticipate (e.g., detected a `tools/` directory worth its own scope). Surface as a proposal, do not apply automatically. |

Plan rendering format (used by all three modes):

```
Migration plan for waves_files/ → multi-project

  SOURCE                                  DEST                                          LEVEL  REASON
  ──────────────────────────────────────  ──────────────────────────────────────────  ─────  ────────────────────
  waves_files/waves/w1/logbooks/login.json   projects/frontend/waves_files/waves/w1/logbooks/login.json  L1     references only lib/ui/* files
  waves_files/project_rules.json (split)     root + frontend/ + backend/                 L3     split 25 rules across 3 dests
  waves_files/blueprint.json                 stays_root                                  L1     root blueprint governs all scopes
  waves_files/project_manifest.json (split)  root + scope manifests                      L3     monorepo with per-package manifests
  ...

Summary: <N> L1 ops, <N> L2 ops, <N> L3 ops, <N> L4 ops, <N> L5 proposals
```

## Step 5: Mode-specific execution

### Mode `dry-run`

1. Print the plan from Step 4. Done. Disk untouched.
2. Print:
   ```
   This was a dry run. Re-invoke without --dry-run to apply (or with --interactive for L3+ control).
   ```
3. EXIT.

### Mode `auto`

1. Print the plan.
2. If any plan entry has classification L3, L4, or L5 → ABORT:
   ```
   🛑 Auto mode encountered <N> Level 3+ decisions (scope/business/discovery).

   Per Waves trust contract, L3+ decisions require human judgment. Re-run as:

     /waves:migrate-to-projects --interactive

   to resolve each one with explicit input.
   ```
   Do NOT apply any operations. EXIT non-zero.
3. If all entries are L1-L2 → apply them in order (Step 6).
4. Print summary + EXIT.

### Mode `interactive`

1. Print the plan.
2. For each L1-L2 entry: apply immediately (Step 6) — these are auto-approved per trust contract.
3. For each L3+ entry: STOP. Use AskUserQuestion to escalate:
   ```
   Level <N> decision: <reason>

   Proposed: <SOURCE> → <DEST>

   How do you want to handle this?
     - Apply as proposed
     - Modify (you specify new dest)
     - Skip (leave at root for now)
     - Abort migration
   ```
   Apply the user's choice. If "Abort", roll forward nothing — print already-applied operations and EXIT.
4. After all entries processed, print final summary.

## Step 6: Apply a single plan entry (atomic)

For each entry to apply:

1. **If dest requires a new scope dir**: invoke the scope-creation primitive identical to `/waves:project-add` (Phase 4 P2):
   - `mkdir -p "projects/<scope_name>/waves_files/waves"`
   - If a stub `project_rules.json` does not yet exist for this scope, ask `project_type` (per `/waves:project-add` Step 4) and write the stub (per `/waves:project-add` Step 5).
   - This reuse is intentional — do not duplicate the primitive logic; reference and follow `/waves:project-add` Steps 3-5.
2. **Move/split the file**:
   - For L1 simple move: `mkdir -p $(dirname <dest>) && mv <source> <dest>`.
   - For L2 cosmetic adjust: move + `jq` patch the `project_name` (or equivalent) field.
   - For L3 split: read source, partition content by user-confirmed mapping, write each partition to its dest. Source file is removed only after all destinations are written successfully.
3. **Log to recent_context** of the destination's nearest logbook (if applicable) or to a top-level migration log file (`waves_files/.migration-2026-MM-DD.log`).

## Step 7: Post-migration validation

After all operations applied (in `auto` or `interactive` mode):

1. Run schema validation against every moved/created `project_rules.json` (root + each scope) using `plugin/skills/waves-protocol/references/project_rules_schema.json`.
2. Validate the root `blueprint.json` (if present) still parses.
3. Print a final summary:
   ```
   ✅ Migration complete.

   Scopes created: <list>
   Files moved: <count>
   Files split: <count>
   Schema validation: PASS / FAIL on <path>

   Next steps:
     /waves:projects                          # inspect the new layout
     /waves:rules-create --project <scope>    # populate any empty rules
   ```

## Boundary and reuse

- **Reuse `/waves:project-add` Step 3-5 primitives** (mkdir, stub write, interactive type elicitation) verbatim when creating new scope dirs during migration. Do not re-implement those steps inline — reference them and follow the same logic. This is the DRY discipline that keeps scope creation behavior consistent across `project-add` and `migrate-to-projects`.
- **5-level classification is non-negotiable**. Any decision the agent is tempted to make silently that affects scope assignment, blueprint/capability mapping, or rule category split → that decision is Level 3+ and MUST escalate (in `interactive`) or abort (in `auto`).
- **No partial apply on abort**: if the user aborts mid-migration in interactive mode, do not roll back already-applied L1-L2 operations (they are mechanical and reversible via git). Print what was applied so the user can git restore if needed.
- **Never touch hidden files** under `waves_files/` (e.g., `.migration-*.log`, future `.waves-version`) — the migration log is the only file this command writes outside the regular artifact tree.
