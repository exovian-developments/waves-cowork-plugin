#!/bin/bash
# waves-doc-sync.sh — PreToolUse hook for release tag discipline (Waves 2.3.x+)
#
# Triggers when git creates a NEW version tag (git tag vN.N.N).
# Verifies that the tagged commit modifies BOTH FRAMEWORK.md and CHANGELOG.md.
# If either is missing, blocks with exit 2 unless .claude/waves-doc-sync-bypass exists.
#
# Background: between Waves 2.0.0 (2026-04-15) and 2.3.0 (2026-05-14), 17 releases
# shipped while FRAMEWORK.md remained frozen at 2.0. The hook prevents this regression.
#
# Bypass: single-use file at .claude/waves-doc-sync-bypass.
# Usage logged at /tmp/waves-doc-sync-bypass.log so bypasses remain auditable.

set -euo pipefail
INPUT=$(cat)

# Extract bash command from PreToolUse input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Parse only first line (heredocs etc. won't trigger spurious matches)
FIRST_LINE=$(echo "$COMMAND" | head -1)

# Match: git tag vN.N.N (create a new version tag)
# Skip: git tag -d/--delete (deletion), git tag -l/--list (listing), git tag with non-vN.N.N name
if ! echo "$FIRST_LINE" | grep -qE '(^|[[:space:]])git[[:space:]]+tag[[:space:]]+v[0-9]'; then
    exit 0
fi

# Skip explicit delete/list/force-without-target
if echo "$FIRST_LINE" | grep -qE 'git[[:space:]]+tag[[:space:]]+(-d|-l|--delete|--list)'; then
    exit 0
fi

# Bypass file present? Single-use, auto-deleted, audit-logged.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
BYPASS="$PROJECT_DIR/.claude/waves-doc-sync-bypass"
if [ -f "$BYPASS" ]; then
    REASON=$(cat "$BYPASS" 2>/dev/null | head -1)
    echo "$(date -u +%FT%TZ) bypass used | cmd=$FIRST_LINE | reason=${REASON:-no reason given}" >> /tmp/waves-doc-sync-bypass.log
    rm -f "$BYPASS"
    exit 0
fi

# Identify the tag target: HEAD unless a specific commit-ish is given as 3rd arg.
# Format expectations:
#   git tag vN.N.N                   → target = HEAD
#   git tag vN.N.N <sha-or-ref>      → target = <sha-or-ref>
#   git tag -a vN.N.N -m "msg"       → target = HEAD (with annotation)
#   git tag -a vN.N.N <sha> -m "msg" → target = <sha>
TARGET_SHA=$(echo "$FIRST_LINE" | awk '
    {
        for (i=1; i<=NF; i++) {
            if ($i ~ /^v[0-9]+\./) {
                # Found the tag name; the next non-flag, non-option-value arg is the target
                for (j=i+1; j<=NF; j++) {
                    # Skip option values like -m "..." (-m consumes next token)
                    if ($j == "-m" || $j == "--message" || $j == "-F" || $j == "--file") { j++; continue }
                    # Skip flags
                    if ($j ~ /^-/) continue
                    print $j
                    exit
                }
                print "HEAD"
                exit
            }
        }
    }')

# Resolve target to a SHA. If invalid, do not block (let git itself complain).
RESOLVED=$(cd "$PROJECT_DIR" && git rev-parse "$TARGET_SHA" 2>/dev/null || echo "")
if [ -z "$RESOLVED" ]; then
    exit 0
fi

# Get list of files changed in that commit
CHANGED=$(cd "$PROJECT_DIR" && git show --name-only --format="" "$RESOLVED" 2>/dev/null || echo "")

# Check both required files at repo root
HAS_FRAMEWORK=$(echo "$CHANGED" | grep -cE '^FRAMEWORK\.md$' || true)
HAS_CHANGELOG=$(echo "$CHANGED" | grep -cE '^CHANGELOG\.md$' || true)

if [ "${HAS_FRAMEWORK:-0}" -gt 0 ] && [ "${HAS_CHANGELOG:-0}" -gt 0 ]; then
    exit 0
fi

# Block with descriptive message
FRAMEWORK_STATUS=$( [ "${HAS_FRAMEWORK:-0}" -gt 0 ] && echo "✓ modified" || echo "✗ MISSING" )
CHANGELOG_STATUS=$( [ "${HAS_CHANGELOG:-0}" -gt 0 ] && echo "✓ modified" || echo "✗ MISSING" )

cat >&2 <<EOF
═══ Waves doc-sync hook BLOCKED ═══

Command: $FIRST_LINE
Target commit: ${RESOLVED:0:8}

The commit being tagged must modify BOTH framework documents so that the
website agent and the framework reference stay in sync with shipped code.

  FRAMEWORK.md:  $FRAMEWORK_STATUS
  CHANGELOG.md:  $CHANGELOG_STATUS

Why this hook exists:
  Between Waves 2.0.0 (2026-04-15) and 2.3.0 (2026-05-14), 17 releases shipped
  while FRAMEWORK.md remained frozen at 2.0. This hook prevents that regression.
  See FRAMEWORK.md §18.6 for context.

To proceed correctly:
  1. Add a commit (or amend) that updates the missing file(s).
  2. Re-run git tag.

To bypass (rare cases: patch-only release, out-of-band tag, doc-only commit):
  echo "reason here" > .claude/waves-doc-sync-bypass
  # then re-run git tag (single-use; the file is deleted automatically)
  # bypass is logged at /tmp/waves-doc-sync-bypass.log
EOF
exit 2
