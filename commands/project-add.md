---
description: Create a new scoped project under projects/<name>/ with waves subdir and project_rules.json stub
allowed-tools: Read, Write, Bash, AskUserQuestion
---

# Command: /waves:project-add $ARGUMENTS

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.

You are creating a new scoped project under `projects/<name>/`. Greenfield: nothing pre-exists at that path. Your job is to validate the name, refuse collisions, mkdir the scope structure, ask the user for `project_type`, and write a minimal `project_rules.json` stub that validates against `plugin/skills/waves-protocol/references/project_rules_schema.json`.

## Your Role

You are a scope creator. The user has decided to add a new sub-project under this repo's `projects/` directory. You do exactly what is needed to bring the scope into existence — no more (REGLA-0). Subsequent commands (`/waves:rules-create --project <name>`, `/waves:manifest-create --project <name>`, etc.) fill it in.

## Step 1: Parse and validate the name

1. The scope name comes from `$ARGUMENTS`. If empty → abort:
   ```
   Usage: /waves:project-add <name>
   Example: /waves:project-add frontend
   ```
2. Validate characters: lowercase alphanumeric, dash, underscore only. Regex: `^[a-z0-9][a-z0-9_-]*$`. If invalid → abort:
   ```
   ❌ Invalid scope name '<name>'. Allowed: lowercase letters, digits, '-', '_'. First char must be alphanumeric.
   ```
3. Reserved names that conflict with framework files at root (`schemas`, `waves`): refuse with explanation.

## Step 2: Refuse collisions

1. If `projects/<name>/` already exists → abort:
   ```
   ❌ Scope '<name>' already exists at projects/<name>/.
      Run /waves:projects to list existing scopes, or pick a different name.
   ```
2. If `projects/` itself does not exist, that's fine — Step 3 will mkdir -p both levels.

## Step 3: mkdir scope skeleton

```bash
mkdir -p "projects/<name>/waves_files/waves"
```

The `waves/` subdir is created empty — `/waves:roadmap-create --project <name>` will populate it later. No other directories are created at this stage (YAGNI).

## Step 4: Ask for project_type interactively

Use AskUserQuestion to elicit `project_type`. The valid values come from `plugin/skills/waves-protocol/references/project_rules_schema.json` → `.properties.type.enum`:

| Value | Use when |
|-------|----------|
| `frontend` | UI / client app (Flutter, React, Vue, etc.). |
| `backend` | Server / API / worker (Dart, Node, Python, Go, etc.). |
| `fullstack` | Single codebase with both frontend + backend. |
| `agentic` | AI agent / skill / hook / prompt orchestration project (no traditional runtime). |

Question text: `"What kind of project is the '<name>' scope?"`. Header chip: `"Project type"`. multiSelect: `false`. Options as labeled above.

Persist the user's selection as `PROJECT_TYPE`. If the user picks Other and types a value not in the enum, re-ask once with a reminder of valid values; if they insist, abort cleanly (`/waves:rules-create` can update `type` later when valid).

## Step 5: Write the stub

Write `projects/<name>/waves_files/project_rules.json` with this exact shape (minimal, schema-compliant):

```json
{
  "project_name": "<name>",
  "project_description": "Scoped project '<name>' under <repo>. Replace this description and populate rules via /waves:rules-create --project <name>.",
  "language": "<inferred from type — see below>",
  "type": "<PROJECT_TYPE from Step 4>",
  "rules": {}
}
```

`language` inference (deterministic default — the user can override later with `/waves:rules-create`):

| PROJECT_TYPE | Default `language` |
|--------------|--------------------|
| `frontend` | `typescript` |
| `backend` | `dart` |
| `fullstack` | `typescript` |
| `agentic` | `markdown+bash+json` |

Do NOT pre-populate `rules` with example/placeholder rules. Empty `rules: {}` is schema-valid (the schema's `unevaluatedProperties` constraint is satisfied by absence). Subsequent `/waves:rules-create --project <name>` will autonomously extract real rules from the scope's code.

## Step 6: Confirm and exit

Print:
```
✅ Scope '<name>' created.

  Path:     projects/<name>/
  Type:     <PROJECT_TYPE>
  Language: <inferred>

Next steps:
  /waves:rules-create --project <name>      # extract rules from the scope's code
  /waves:manifest-create --project <name>   # generate the scope's manifest
  /waves:roadmap-create --project <name>    # plan the first wave for this scope
```

## Boundary

This command's success metric is: a new scope dir exists with a single schema-valid stub file. Anything beyond that (manifest generation, rules extraction, blueprint creation) belongs to the dedicated commands invoked with `--project <name>`. Do NOT:
- Pre-populate the manifest, blueprint, or roadmap.
- Write the marker file (this command does not switch the active scope — that happens when the user explicitly invokes `--project <name>` on a scope-aware command per Phase 3 w5 protocol).
- Touch root `waves_files/*.json` artifacts.

## Schema reference

The stub MUST validate against `plugin/skills/waves-protocol/references/project_rules_schema.json`. Required fields at root: `project_name`, `project_description`, `language`, `rules`. `type` is REQUIRED for scoped instances (this command always sets it). If schema validation fails post-write, the command aborts and rolls back the scope dir.
