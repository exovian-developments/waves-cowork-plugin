# waves_kernel — deterministic rails of the Waves framework

The kernel is the open-core seam of Waves: every deterministic rail (validation,
gate evaluation, stub detection, relations queries, scope resolution, artifact
merge) lives here as a self-contained bash+jq CLI. The Claude Code plugin hooks
are thin wrappers that call these binaries; any other product (PCC) bundles its
own **copy** of this directory.

License: AGPL-3.0 (see LICENSE in this directory). Version: see VERSION.

**VERSION discipline (the copy model depends on it):** any change to kernel
content — even internal calibration that keeps the CLI contract intact — bumps
VERSION. Products bundle copies; comparing VERSION files is how a consumer
knows its copy drifted from the source. Plugin version and kernel version are
independent: the plugin can patch without touching the kernel, and vice versa.
History: 0.1.0 extraction (w6 P13) → 0.2.0 field-report calibration (gate-eval
allowlists, pre-commit sidecar/rename-aware fixes) → 0.3.0 upstream report from
projects_control_center_local (jq-missing now warns visibly in every bin —
fail-open stays, silence does not; waves-validate gains id-uniqueness checking,
which JSON Schema cannot express).

## The self-containment contract (hard rule)

`kernel/` references **nothing outside its own directory** — no `../` paths, no
`$CLAUDE_PLUGIN_ROOT`, no plugin file layout assumptions. Inputs arrive as CLI
arguments or environment variables documented per tool. This is what makes the
distribution model work: each product bundles a copy (`cp -r` is the whole
integration), and a copy that reaches outside its directory is a broken copy.

Verification of the contract: copy `kernel/` anywhere and run the bins from
there; `grep -rn '\.\./' kernel/bin/` must return nothing.

## CLI contract (stable surface)

Every tool in `bin/` follows the same conventions:

- Inputs are explicit arguments (file paths, values) — never implied layout.
- Exit codes are part of the contract: `0` = pass/clean, `2` = violation/block
  (mirrors the Claude Code hook contract the rails were extracted from),
  `1` = internal error.
- Output: human-readable findings on stderr for block paths; structured output
  on stdout where documented.
- `--help` on every bin prints usage.

Degradation note: if a consumer never wires a rail (e.g. a repo without the
merge driver configured), behavior degrades to the underlying tool's default —
visible degradation, never silent corruption.

## Inventory — classification of the 15 plugin hooks + 2 shared libs

Produced by the w6 Phase 13 rail inventory (logbook phase_13, secondary 1.1).
Three buckets: **deterministic** (logic moves into the kernel), **LLM-rail**
(adversarial A→B prompt scaffolding — stays in the plugin, the kernel never
runs an LLM), **glue** (Claude Code event plumbing — stays as hook, thin).

| # | File (lines) | Classification | Destination |
|---|---|---|---|
| 1 | waves-gate.sh (269) | deterministic rail + glue | gate decision logic → `bin/waves-gate-eval`; hook becomes wrapper (stdin parse + relay) |
| 2 | waves-stub-check.sh (265) | deterministic rail + glue | checkers + dispatcher → `bin/waves-stub-check`; hook becomes wrapper |
| 3 | _lib/scope-resolve.sh (62) | deterministic rail (seed) | moves to `lib/scope-resolve.sh`; `_lib/` keeps a 1-line shim so the 10 consuming hooks stay untouched |
| 4 | _lib/thread-resolve.sh (40) | deterministic rail (seed) | moves to `lib/thread-resolve.sh`; same shim pattern |
| 5 | waves-perceive.sh (254) | deterministic digest, Claude-specific surface | stays as hook (its output IS session context injection); consumes kernel lib via shim |
| 6 | waves-metacognition.sh (180) | LLM-rail + small deterministic notes | stays; only the ID-generation fix (primary 3) touches it |
| 7 | waves-rules-audit.sh (267) | LLM-rail (A/B prompts) | stays |
| 8 | waves-rules-audit-injector.sh (194) | glue (injection state machine for LLM findings) | stays; consumes kernel lib via shim |
| 9 | waves-blueprint-impact.sh (85) | LLM-rail | stays |
| 10 | waves-foundational-audit.sh (126) | LLM-rail | stays |
| 11 | waves-phase-audit.sh (113) | LLM-rail | stays |
| 12 | waves-doc-enforce.sh (74) | glue (counter check, Claude-context-specific) | stays |
| 13 | waves-doc-sync.sh (126) | deterministic, git-tag-discipline, single-surface | stays (release discipline is a repo concern, not a rail products consume) |
| 14 | waves-dart-analyze.sh (47) | glue (delegates to dart) | stays |
| 15 | waves-manifest-freshness.sh (127) | deterministic pre-filter + delegation prompt | stays; the zero-token filter is commit-boundary glue |
| 16 | waves-telemetry.sh (166) | deterministic sensor, plugin-local | stays (telemetry of THIS plugin's usage; not a product rail) |
| 17 | waves-cost.sh (170) | deterministic sensor, plugin-local | stays (reads Claude transcripts — inherently host-specific) |

Rails with no current hook home (scattered today, kernel gives them one):

| Rail | Today | Kernel home |
|---|---|---|
| validate | commands called `python3 -m jsonschema` inline with plugin schema paths | `bin/waves-validate <artifact.json> --schema <schema.json>` |
| relations | `relations[]` lives in project_manifest.json, read ad hoc | `bin/waves-relations <manifest.json> [--for <file>]` |
| merge | `bin/waves-merge` — git merge-driver (`%O %A %B %P`, writes `%A`) | per-field merge; id-arrays union-by-id; create-collisions renumbered (older keeps id); id-less arrays → 3-way set-union (concurrent appends both land, never silent loss); real same-field collision → per-field LWW by each side's last commit touching the file (theirs resolved via `GITHEAD_*` env — `MERGE_HEAD` is not yet written while a driver runs); non-JSON input → `git merge-file` fallback |
| merge setup | `bin/waves-merge-setup [--repo <dir>]` | idempotent wiring: `[merge "waves"]` in `.git/config` (local, every clone) + routing lines in `.gitattributes` (committed, travels). Unwired repo degrades to git default merge — visible markers, never silent loss |
| pre-commit | `bin/waves-pre-commit` + `bin/waves-pre-commit-install` | commit-boundary backstop: staged artifact JSONs must be well-formed; schema validation uses DELTA semantics (blocks only NEW errors vs HEAD — legacy invalidity warns, never blocks). Installer chains a pre-existing pre-commit (runs first, its failure still blocks). Bypass: `git commit --no-verify` |

Known limitation of id renumbering (waves-merge create-collisions): a renumbered
entry's NEW id is not propagated to free-text references elsewhere ("see decision
#30" in another field keeps saying #30). Artifact schemas carry no structured
cross-id references today, so renumbering is safe at the data level; prose
references are a human-readable convention, not a contract. If structured refs
ever land in a schema, the renumber step must learn to rewrite them first.

## Layout

```
kernel/
├── VERSION          # kernel version (starts 0.1.0; independent of plugin version)
├── LICENSE          # AGPL-3.0 full text — the open-core boundary
├── README.md        # this contract
├── bin/             # stable CLI entrypoints (the public surface)
├── lib/             # shared internals (scope-resolve, thread-resolve)
└── fixtures/        # known-input/known-output cases runnable offline
```
