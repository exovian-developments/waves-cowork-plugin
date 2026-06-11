#!/bin/bash
# run-artifact-validate-cases.sh — cases for the waves-artifact-validate rail (w6 post-release,
# upstream report from projects_control_center_local 2026-06-11).
#
# Cases:
#   1. valid-passes        — well-formed, schema-valid, unique ids → exit 0
#   2. schema-error-blocks — cap violation → exit 2
#   3. duplicate-id-blocks — same id twice in an id-array → exit 2 with a
#                            'uniqueness:' line (JSON Schema cannot express
#                            this; 3 real collisions seen in the field)
#   4. nested-dup-blocks   — duplicate ids in a NESTED array → exit 2
#   5. broken-json-blocks  — unparseable artifact → exit 2
#
# Exit: 0 = all cases pass; 1 = a case failed.

set -uo pipefail

BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/waves-artifact-validate"

FAILURES=0
fail() { echo "FAIL [$1]: $2" >&2; FAILURES=$((FAILURES+1)); }
ok()   { echo "ok   [$1]"; }

SANDBOX=$(mktemp -d /tmp/waves-artifact-validate-cases.XXXXXX)
trap 'rm -rf "$SANDBOX"' EXIT

cat > "$SANDBOX/schema.json" <<'EOF'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "decisions": {"type": "array", "items": {"type": "object",
      "properties": {"decision": {"type": "string", "maxLength": 40}}}},
    "phases": {"type": "array"}
  }
}
EOF

# ============ Case 1: valid passes ============
printf '{"decisions":[{"id":1,"decision":"ok"},{"id":2,"decision":"ok"}]}\n' > "$SANDBOX/a.json"
if bash "$BIN" "$SANDBOX/a.json" --schema "$SANDBOX/schema.json" >/dev/null 2>&1; then
  ok valid-passes
else
  fail valid-passes "exit $?"
fi

# ============ Case 2: schema error blocks ============
printf '{"decisions":[{"id":1,"decision":"this text is far beyond the forty character cap"}]}\n' > "$SANDBOX/b.json"
if bash "$BIN" "$SANDBOX/b.json" --schema "$SANDBOX/schema.json" >/dev/null 2>&1; then
  fail schema-error-blocks "passed an over-cap value"
else
  ok schema-error-blocks
fi

# ============ Case 3: duplicate id blocks ============
printf '{"decisions":[{"id":7,"decision":"a"},{"id":7,"decision":"b"}]}\n' > "$SANDBOX/c.json"
ERR=$(bash "$BIN" "$SANDBOX/c.json" --schema "$SANDBOX/schema.json" 2>&1); RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$ERR" | grep -q '^uniqueness:'; then
  ok duplicate-id-blocks
else
  fail duplicate-id-blocks "exit=$RC err=$ERR"
fi

# ============ Case 4: nested duplicate blocks ============
printf '{"phases":[{"id":1,"milestones":[{"id":"1.1"},{"id":"1.1"}]}]}\n' > "$SANDBOX/d.json"
ERR=$(bash "$BIN" "$SANDBOX/d.json" --schema "$SANDBOX/schema.json" 2>&1); RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$ERR" | grep -q 'uniqueness:.*milestones'; then
  ok nested-dup-blocks
else
  fail nested-dup-blocks "exit=$RC err=$ERR"
fi

# ============ Case 5: broken JSON blocks ============
printf '{ broken' > "$SANDBOX/e.json"
if bash "$BIN" "$SANDBOX/e.json" --schema "$SANDBOX/schema.json" >/dev/null 2>&1; then
  fail broken-json-blocks "parsed garbage"
else
  ok broken-json-blocks
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "run-artifact-validate-cases: $FAILURES case(s) failed" >&2
  exit 1
fi
echo "run-artifact-validate-cases: all 5 cases passed"
