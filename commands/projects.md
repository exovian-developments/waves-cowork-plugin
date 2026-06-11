---
description: List scoped projects under projects/ with artifact counts and active scope flag
allowed-tools: Read, Bash, Glob
---

# Command: /waves:projects

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.

You are executing the `/waves:projects` command. It is **read-only**. Walk the filesystem, count artifacts per scope, detect the active scope from the session marker, and render an ASCII table. Zero mutation — never write, never delete.

## Your Role

You are a scope inspector. The user wants a snapshot of which scoped projects exist under the current repo's `projects/` directory, what artifacts each scope has, and which scope is currently active in this Claude Code session (per the marker file written by other `/waves:*` commands invoked with `--project <name>`).

## Step 1: Detect mode and short-circuit empty state

1. Check whether `projects/` exists and contains at least one subdirectory.
2. **If absent or empty**, print and exit:
   ```
   No scoped projects found.
   This repo is in single-project mode (waves_files/ at root governs everything).
   Run /waves:project-add <name> to create the first scope.
   ```
   → EXIT cleanly (no error).

## Step 2: Walk scopes and count artifacts

For each subdirectory under `projects/`, collect:

| Field | How to derive it |
|-------|------------------|
| `name` | Directory name (e.g., `frontend`, `backend`, `diamond-tui`). |
| `logbooks` | Count of `*.json` files under `projects/<name>/waves_files/waves/*/logbooks/`. |
| `manifest` | `✓` if `projects/<name>/waves_files/project_manifest.json` exists, else `—`. |
| `rules` | `✓` if `projects/<name>/waves_files/project_rules.json` exists, else `—`. |
| `blueprint` | `✓` if `projects/<name>/waves_files/blueprint.json` OR `product_blueprint.json` exists, else `—` (scopes typically inherit root blueprint per Phase 2 root-only validation, so `—` is the common case). |

Use Bash + Glob for the file enumeration. Keep the loop tight — one pass per scope.

## Step 3: Detect the active scope (current session marker)

The active scope is determined by the marker file `plugin/hooks/_lib/scope-resolve.sh` reads (Phase 3 w5):

1. Marker path: `${CLAUDE_PLUGIN_DATA}/markers/${CLAUDE_SESSION_ID:-default}/active-scope`.
2. If the file exists, compute the current `cwd_md5`:
   ```bash
   CWD_HASH=$(printf '%s' "$PWD" | { md5 -q 2>/dev/null || md5sum | awk '{print $1}'; })
   ```
3. `grep -E "^${CWD_HASH}=" "$marker" | head -1 | cut -d= -f2` yields the active scope name (or empty).
4. If the resolved scope name matches one in the walk (Step 2), flag that row as active.

If `CLAUDE_PLUGIN_DATA` is unset, the marker file does not exist, or no line matches the current cwd_md5 → **no scope is active** (this session has not invoked any `--project`-aware command yet, or is operating on root).

## Step 4: Render the ASCII table

Render to stdout (Claude Code displays it inline):

```
Scoped projects under projects/

  ACTIVE  NAME            LOGBOOKS  MANIFEST  RULES  BLUEPRINT
  ──────  ──────────────  ────────  ────────  ─────  ─────────
  ★       frontend               3         —      ✓          —
          backend                7         ✓      ✓          —
          diamond-tui            0         —      ✓          —

Active scope (this session, cwd <abbreviated path>): frontend
  Marker: ${CLAUDE_PLUGIN_DATA}/markers/${CLAUDE_SESSION_ID:-default}/active-scope
```

If **no scope is active** in this session, omit the `★` column entries and the trailing `Active scope:` paragraph; replace with a single line:

```
No active scope in this session — commands without --project operate on root.
```

## Step 5: Edge cases (silent, no abort)

- **Scope dir exists but is empty:** still list it; counts are all `0` / `—`. Useful signal for the user that a scope was created but never populated.
- **Marker file present but malformed** (no matching `cwd_md5=…` line): treat as "no active scope" — do not error.
- **No `jq` available:** the artifact counts can be done with Glob alone; do not require jq.
- **Scope with weird characters in the name:** print verbatim. The `project-add` command is responsible for refusing weird names upstream; `/waves:projects` only displays what exists.

## Boundary

This command is read-only and idempotent. It must never:
- Create or delete files under `projects/`.
- Modify any marker file.
- Mutate `waves_files/` in any way.

If you find yourself about to write, stop — that work belongs to `/waves:project-add`, `/waves:project-remove`, or `/waves:migrate-to-projects`.
