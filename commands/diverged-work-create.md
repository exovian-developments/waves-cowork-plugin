---
description: Capture a small unit of divergent work that surfaced mid-flight (during design or testing) as a diverged_work artifact — gather it, run an adversarial 3-gate audit, and either execute it now (disposition=executable) or promote it to a full logbook (disposition=promoted).
allowed-tools: Read, Bash, Glob, Grep, Write, Agent
---

# Command: /waves:diverged-work-create — lightweight divergent-work artifact

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.

You are executing the Waves diverged_work creation command. A **diverged_work** is the lightweight sibling of a logbook (w6 Phase 6): a SMALL, self-contained unit of work that surfaces mid-flight — while DESIGNING the main thread or while TESTING it — and diverges from what you were doing. Today such work can only land as a `recent_context` note, invisible to the second-order corpus miner (`/waves:corpus-mine`, design_principle #11). This command gives it a mineable home.

**It is NOT a logbook.** No `objectives.main`/`objectives.secondary` decomposition, no orthogonality review — a single closed unit. The two omissions are deliberate: if the work actually needed them, the adversarial audit below returns `promoted` and the unit graduates to a real logbook. Schema: `plugin/skills/waves-protocol/references/diverged_work_schema.json`. Agnostic to general/agentic/software.

## Multi-project scope

Apply the **Multi-project Path Resolution** helper from `plugin/skills/waves-protocol/SKILL.md` before any other step (identical to `/waves:logbook-create` — reuse it, do not reinvent, REGLA-0 #3):

- Parse `--project <name>` from the command arguments.
- If present: set `base_path = projects/<name>/waves_files/` and validate that `projects/<name>/` exists (abort with a "scope not found" error if it does not).
- If absent: set `base_path = waves_files/` (backwards-compatible default).

Use `base_path` for every `waves_files/...` reference below. When `--project` is present, also write the **session marker** via bash BEFORE any artifact operation (same snippet as `logbook-create`, so hooks see the active scope):

```bash
mkdir -p "${CLAUDE_PLUGIN_DATA}/markers/${CLAUDE_SESSION_ID:-default}"
printf '%s=%s\n' "$(printf '%s' "$PWD" | { md5 -q 2>/dev/null || md5sum | awk '{print $1}'; })" "<scope_name>" \
  > "${CLAUDE_PLUGIN_DATA}/markers/${CLAUDE_SESSION_ID:-default}/active-scope"
```

When `--project` is absent, do not write the marker — hooks fall back to root.

## Step -1: Prerequisites Check (CRITICAL)

Prerequisite artifacts are validated at root (`waves_files/<artifact>`) regardless of the `--project` flag — scopes inherit root prerequisites (same rule as `logbook-create`).

Check if `waves_files/user_pref.json` exists.

IF NOT EXISTS:
```
⚠️ Missing configuration!

Please run first:
/waves:project-init
```
→ EXIT COMMAND

IF EXISTS:
1. Read `waves_files/user_pref.json`
2. Extract `user_profile.preferred_language` → use for all interactions
3. Extract `project_context.project_type`

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Read-before-act gate (rule #4)

Before gathering, verify in order (rule #4 — local): (1) the product blueprint, (2) an active roadmap for the current wave, (3) the parent the work diverges from. A diverged_work always has a parent (a blueprint, a roadmap, or a logbook — `trigger_context.origin.parent_type`). If the blueprint or active roadmap is missing, do NOT proceed — inform the user and wait for authorization to continue with the gap.

## Step 0.5: Smart Wave Detection

Determine the target wave without asking when context is clear (identical to `logbook-create` Step 0.5): list `waves_files/waves/*/roadmap.json`, find the one with status `active`/`in_progress`, use it. Store as `target_wave`. Only ask if genuinely ambiguous.

## Step 1: Gather the diverged_work (human-in-the-loop)

This is a single-unit gather — present and wait where a choice is genuinely the user's (rule #1: in planning/refinement, propose and wait; do not assume). Collect, in order:

1. **title** — ONE verifiable outcome, phrased as a result (the schema caps it at 140 chars and the `$comment` teaches the discipline). If the user's phrasing carries a `+`, ` y `/` and `, or two verbs, surface it now: it is likely two units and the audit will return `promoted`.
2. **expected_end_state** — what is observably true once executed.
3. **trigger_context**:
   - `surfaced_during`: `design` or `testing`.
   - `origin`: `{ wave, parent_type: blueprint|roadmap|logbook, parent_ref }`. Infer `wave` from Step 0.5; ask which parent it diverged from and resolve `parent_ref` to a real package-qualified path (rule #6), optionally with an anchor (e.g. `waves_files/waves/w6/roadmap.json#decision-10`).
   - `why_surfaced` and `why_separate`: one sentence each (the honest reason it diverges).
4. **scope**: `files` (the full KNOWN blast radius — entry points only, real package-qualified paths #6) and `rules` (IDs from `project_rules.json` in scope).
5. **completion_guide**: the concrete how-steps. Append one **Apply rule #N: `<verbatim rule line>`** item per rule in `scope.rules` (same discipline as a logbook secondary). Each item is ONE step, ≤200 chars.
6. **verification**: the SINGLE deterministic check — `{ type (one of the 10-type taxonomy), command_or_method, expected }`. If the unit seems to need more than one check, say so — that is a signal for `promoted`.

Do NOT decompose into main/secondary objectives and do NOT run an orthogonality review. If you find yourself wanting either, that is exactly what the audit (Step 2) tests — let it decide, do not pre-empt it.

Hold the gathered object as `dw` (not yet written to disk).

## Step 2: Adversarial 3-gate audit (analyst A — assigns disposition)

The gather agent is biased toward `executable` (it is faster — no logbook to spin up). Delegate the disposition decision to a **fresh, independent auditor A** whose brief is adversarial: try to REFUTE that this is a single, closed, self-verifiable unit. This is the anti-fragmentation rail — it blocks abusing diverged_work to split a task that deserves a real logbook.

Spawn an Agent (`run_in_background=false`) with the model from `agent_config.metacognition_model` in `user_pref.json` (default `opus`). Apply rule #5 strictly: **the auditor is an explorer — it READS `dw` and the cited parent/scope files and CLASSIFIES; it never edits any file.** The auditor prompt:

```
You are auditor A with minimal context by design. The gather agent proposes the diverged_work below. Your job is to REFUTE that it is small enough to NOT be a logbook — NOT to confirm it. Assume the gather agent is biased toward 'executable' because it is faster. Evaluate exactly three gates; for each, try to find grounds to refute it:

  gate single_dimension — does it address EXACTLY ONE concern with ONE mindset? Refute if the title/scope/completion_guide mix orthogonal concerns (a '+', ' y '/' and ', two verbs, a colon-list, files in unrelated layers).
  gate closed_scope     — is the blast radius FULLY KNOWN and bounded? Refute if scope.files is open-ended ('and related files', 'probably several'), or the change plausibly ripples beyond the listed files.
  gate self_verifiable  — is there ONE deterministic check a subagent can run to prove it done? Refute if verification needs human judgment to read, or more than one check.

A gate is 'pass' ONLY when you could NOT refute it. Under genuine doubt on any gate, return 'refuted' (conservative bias).

disposition: if all three pass → 'executable'. If ANY gate is refuted (or you are in doubt) → 'promoted', and cite the gate(s) that failed so logbook-create inherits a precise starting point.

Return ONLY a JSON object of this exact shape (no prose):
{
  "gates": [
    {"name": "single_dimension", "verdict": "pass|refuted", "note": "<one-line reason>"},
    {"name": "closed_scope",     "verdict": "pass|refuted", "note": "<one-line reason>"},
    {"name": "self_verifiable",  "verdict": "pass|refuted", "note": "<one-line reason>"}
  ],
  "disposition": "executable|promoted",
  "disposition_reason": "<one rationale citing the deciding gate(s)>"
}

Constraints: high confidence only; do not invent gates; do not modify any file.
```

Receive the JSON and write it into `dw.audit` (set `auditor_model`).

## Step 3: Main agent re-judges (verifier B — A->B pattern, design_principle #7)

The auditor (A) assigned a disposition; YOU (the main agent, B) re-judge it before acting — do not accept it blind (rule #1; design_principle #7). Read `dw.audit.gates` adversarially:

- If you **concur**: set `dw.audit.reviewer_verdict = "concur"` and proceed with the assigned disposition.
- If you **disagree** (e.g. A refuted `closed_scope` on a gate you can show is bounded, or A passed a unit you can show is multi-concern): set `dw.audit.reviewer_verdict = "revise"`, record WHY in `dw.audit.disposition_reason`, and flip `dw.audit.disposition` accordingly. When B and A disagree and doubt remains, resolve to `promoted` (the conservative bias holds for B too).

Set `dw.created_at` to now (UTC).

## Step 4: Persist the artifact

Write `dw` to the diverged_work directory under the target wave, co-located like a logbook (design_principle #11 — directory-per-unit, navigable):

```
waves_files/waves/<target_wave>/diverged_work/<slug>/diverged_work.json
```

where `<slug>` is a kebab-case slug derived from the title. Validate it against `diverged_work_schema.json` before writing (the same deterministic validator `logbook-create` Step A6 uses — reuse it, REGLA-0 #3): hard schema failures (type/required/maxLength) BLOCK; an undeclared extra field is a signal, not a failure (OPEN, dp#11).

## Step 5: Dispatch on disposition

### Step 5A: disposition = executable

The audited object IS the subagent prompt. Offer to run it now:

```
✅ diverged_work 'audited as EXECUTABLE — single concern, closed scope, one deterministic check.
   File: waves_files/waves/<target_wave>/diverged_work/<slug>/diverged_work.json

Run it now with a subagent? (Yes/No)
```

IF Yes: spawn an Agent that receives `dw` as its brief — `title` + `expected_end_state` + `scope.files` + `completion_guide` (with the Apply-rule lines) — executes the unit, then runs `dw.verification.command_or_method` and reports whether `expected` held. **This executor subagent is intentional, design-sanctioned delegation** (the whole point of `executable`): it is NOT the rule #5 prohibition, which forbids delegating edits the USER asked the MAIN agent to do — here the diverged_work model itself prescribes subagent execution. Record the verification outcome back into the parent thread's `recent_context` (the logbook/roadmap/blueprint named in `trigger_context.origin`), NOT back into the diverged_work file (it is the immutable record of the divergence).

IF No: leave the file as the captured, audited unit for later execution.

### Step 5B: disposition = promoted

The audited object IS the formal seed for a logbook. Do NOT execute it. Hand it to `/waves:logbook-create`:

```
⤴️  diverged_work 'PROMOTED to a logbook — it failed gate(s): <cite the refuted gate(s)>.
   This is too big to be a single diverged unit. Seeding a logbook from it.

   The seed carried into /waves:logbook-create:
     • ticket title      ← dw.title
     • description       ← dw.expected_end_state + dw.trigger_context (why it exists)
     • scope.files/rules ← dw.scope
     • starting point    ← the gate that failed (e.g. 'closed_scope: blast radius needs bounding first')

Run /waves:logbook-create now with this seed? (Yes/No)
```

The lineage is `diverged_work[promoted] → logbook → resolution` — the corpus miner traces it (Phase 6 P4 wires the walker to read it). The `diverged_work.json` stays on disk as the promoted seed's record; the actual decomposition lives in the logbook that `/waves:logbook-create` produces, never back-filled here.

## Step 6: Summary

```
📋 diverged_work captured: <title>
   Disposition: <executable|promoted> (reviewer_verdict: <concur|revise>)
   File: waves_files/waves/<target_wave>/diverged_work/<slug>/diverged_work.json
   [executable + ran:] Verification: <pass|fail> — recorded in <parent> recent_context.
   [promoted:] Next: /waves:logbook-create (seed ready).
```

---

## Why this command has no decomposition machinery

`/waves:logbook-create` gathers, then runs an **orthogonality review** to split work into orthogonal primaries. This command deliberately omits that step. A diverged_work is the bet that the work is ONE unit; the adversarial audit (Step 2) is the check on that bet. If the bet is wrong, the audit returns `promoted` and routes to `logbook-create`, which has the decomposition machinery. Putting decomposition here too would erase the distinction and invite using diverged_work to fragment real tasks — the exact anti-pattern the conservative bias guards against.
