---
description: Remove a scoped project under projects/<name>/ with safety gates against pending work
allowed-tools: Read, Bash, AskUserQuestion
---

# Command: /waves:project-remove $ARGUMENTS

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.

You are about to delete a scoped project. Your success metric is **correct REFUSAL** when work is pending — not deletion. Assume the user is wrong. Enumerate logbooks, classify pending work, refuse loudly with itemized blockers, require an explicit confirmation token, and only then `rm -rf`. Never silently destroy non-empty work.

## Your Role

You are an adversarial deleter. Two gates protect the user from losing in-flight work: (1) **pending-work refusal** based on logbook status enumeration, (2) **explicit confirmation token**. Both must pass independently. No backup is taken — git is the only recovery path, which is why the gates exist.

## Step 1: Validate scope exists

1. `$ARGUMENTS` must be a non-empty scope name. If empty → abort with usage hint.
2. If `projects/<name>/` does not exist → abort:
   ```
   ❌ Scope '<name>' not found at projects/<name>/.
      Run /waves:projects to list existing scopes.
   ```

## Step 2: Enumerate logbooks and classify pending work

Find every `projects/<name>/waves_files/waves/*/logbooks/*.json` and read each one. For each logbook, classify:

| Logbook state | Counts as pending? |
|---------------|--------------------|
| All `main` objectives have `status` ∈ {`achieved`, `abandoned`} | **No** (safe to discard) |
| Any `main` objective has `status = active` | **Yes** (work in progress) |
| Any `main` objective has `status = not_started` AND has `verification_demonstrations` with `verdict != pass` for any primary | **Yes** (pending commitment with unmet acceptance) |
| Any `main` objective has `status = blocked` | **Yes** (blocked needs human intervention before delete) |

Use `jq` to read the statuses deterministically:

```bash
jq -r '[.objectives.main[] | {id, status, name: .content}] | tostring' "<logbook_path>"
```

Build a `BLOCKERS` list: every (logbook_path, main_id, status, content) tuple flagged as pending.

## Step 3: REFUSAL (Gate 1) — list blockers if pending

If `BLOCKERS` is non-empty, print and **abort**:

```
🔴 Refusing to remove scope '<name>' — pending work detected.

Blockers (must be resolved first):

  [for each blocker]
  • <logbook_path> :: primary #<id> [<status>]
    "<content>"

Resolution options:
  1) Run /waves:logbook-update <logbook> and mark the primary 'abandoned' if obsolete.
  2) Run /waves:objectives-implement <logbook> to finish the primary (status → 'achieved').
  3) Manually edit the logbook to fix the status (last resort, document why in recent_context).

Re-run /waves:project-remove <name> after blockers are clear.
```

EXIT non-zero. Do NOT proceed to Gate 2 or Step 4.

This refusal is the command's primary purpose. List of blockers must be complete and itemized — the user cannot fix what they cannot see.

## Step 4: Confirmation token (Gate 2) — explicit destructive intent

Only reached when `BLOCKERS` is empty (all logbooks are achieved/abandoned or scope has no logbooks at all).

Use AskUserQuestion to require an exact-match destructive token:

- Question: `"This will permanently delete projects/<name>/ (no backup, git is the only recovery). Type the exact phrase to confirm:"`
- Header: `"Confirm delete"`
- Options: First option label is `"YES, REMOVE <name>"` (with the scope name interpolated literally) plus a `"Cancel"` option. Use multiSelect: false. Encourage the user to use the "Other" custom-text field so they have to type the exact phrase — but the explicit option is provided so they can pick it deliberately.

If the user picks Cancel, or types anything other than the exact phrase `YES, REMOVE <name>` → abort cleanly:
```
Aborted. Scope '<name>' was not deleted.
```

If exact match → proceed to Step 5.

## Step 5: Destructive removal

```bash
rm -rf "projects/<name>"
```

If the scope was the only one and `projects/` is now empty, leave the empty `projects/` directory in place — `/waves:project-add` will reuse it. Removing it would change mode detection (filesystem inference) and is out of scope for this command.

## Step 6: Active-scope marker cleanup (best-effort, non-blocking)

If the deleted scope happened to be the active scope in the current session marker, the next hook invocation will fall back to root naturally (per Phase 3 w5 helper). No explicit marker cleanup is required, but as a courtesy:

```bash
MARKER="${CLAUDE_PLUGIN_DATA:-}/markers/${CLAUDE_SESSION_ID:-default}/active-scope"
if [ -f "$MARKER" ]; then
  CWD_HASH=$(printf '%s' "$PWD" | { md5 -q 2>/dev/null || md5sum | awk '{print $1}'; })
  grep -v "^${CWD_HASH}=<name>$" "$MARKER" > "${MARKER}.tmp" 2>/dev/null && mv "${MARKER}.tmp" "$MARKER" || true
fi
```

Failures here are silent (marker is advisory).

## Step 7: Confirm

Print:
```
✅ Scope '<name>' removed from projects/.

Recovery: git status / git restore if you need to undo.
```

## Boundary

This command's correctness is measured by REFUSAL behavior, not by deletion behavior. Specifically:

- **Never** delete a scope with `BLOCKERS` non-empty, regardless of confirmation token. The token is the second gate, not the only gate.
- **Never** automatically "fix" or "clean up" logbook statuses to bypass the refusal. That belongs to `/waves:logbook-update` and is a user decision.
- **Never** take backups, snapshots, or copy the scope dir elsewhere. Git is the safety net; making the deletion appear "soft" weakens the gate's signal value.
- **Never** delete `projects/` itself even if empty after removal — the empty dir is meaningful for filesystem mode inference.
