# Waves Migrations

Declarative **artifact** migrations applied by `/waves:upgrade`. The framework itself
(commands, hooks, agents, skills, schemas) is delivered by the Claude Code plugin and
updated with `/plugin update`. These files migrate a project's ARTIFACTS (blueprint,
project_rules, roadmaps, logbooks, CLAUDE.md) from one framework version to the next.

> **The marketplace source does NOT auto-reload (Claude Code behavior).** A directory
> marketplace (`source: directory`) is cached at install time; editing the source files
> does not propagate until you run `/plugin update`. A freshly published framework change
> is invisible to a host project until `/plugin update`, and only THEN does `/waves:upgrade`
> see the new migration files. Field report 2026-06: a published fix appeared "missing"
> because the host had not run `/plugin update` first.

## Idempotent + auto-detected (since 3.0.2)

Since 3.0.2 there is **no `.waves-version` marker file**. The marker was deprecated
because (a) `/plugin update` can run silently and desync the marker from reality, and
(b) artifact state itself is a more honest source of truth.

Instead, every migration declares a **fingerprint** — a shell command whose exit code
reveals whether the migration is already applied. `/waves:upgrade` evaluates fingerprints
and applies only the migrations whose fingerprint shows the change is missing. Running
the command multiple times is safe.

## File naming

```
v<from>-to-<to>.md      e.g.  v2.5-to-v3.0.md
```

## Frontmatter (required)

```yaml
---
from_version: "2.5.0"        # informational only — semver of starting state
to_version: "3.0.0"          # informational only — semver of ending state
description: "one-line summary shown in the upgrade report"
fingerprint: "<shell command>"    # exit 0 = already applied; non-zero = needs to apply
---
```

The `fingerprint` field is REQUIRED since 3.0.2. Examples:

| Migration kind | Example fingerprint |
|---|---|
| Adds a schema field | `jq -e '.properties.parent_blueprint' plugin/skills/.../product_blueprint_schema.json` |
| Removes legacy file | `! test -f .claude/commands/waves:project-init.md` |
| Renames an artifact path | `test -f waves_files/blueprint.json` |
| Adds a value to an enum | `jq -e '.properties.type.enum \| index("multi-project")' waves_files/project_rules.json` |

Pick the most direct fingerprint for what the migration actually changes.

## Body structure

```markdown
# Migration v<from> → v<to>

## Narrative
User-facing explanation: what changed at the artifact level and why.

## Steps
1. A concrete, idempotent artifact patch (add a field, move a file, configure a setting...).
2. Another step. Each step SHOULD also be idempotent (check before write), but the
   migration's fingerprint guarantees the migration as a whole is safe to re-run.
```

## How `/waves:upgrade` selects and applies migrations

1. Lists migration files in `${CLAUDE_PLUGIN_ROOT}/migrations/*.md`.
2. For each migration in ascending `to_version` order, evaluates the `fingerprint` shell
   command. Exit 0 → already applied → skipped. Non-zero → pending → applied.
3. For each pending migration, executes its `## Steps` checklist.
4. No version marker is written. The next `/waves:upgrade` will re-evaluate fingerprints.

## Scope boundary

These migrations touch ARTIFACTS only. One-time removal of legacy 2.x framework files
(`.claude/commands/waves:*.md`, `.claude/hooks/waves-*.sh`, `ai_files/schemas/`) is handled
by the separate `/waves:migrate-from-v2-to-v3` command — never by a migration file here.
