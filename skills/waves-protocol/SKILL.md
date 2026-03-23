---
name: waves-protocol
description: >
  This skill should be used when the user asks to "initialize a project",
  "create a manifest", "create rules", "create a logbook", "update a manifest",
  "analyze project structure", "track development progress", "create a roadmap",
  "update roadmap", "analyze feasibility", "run feasibility analysis",
  "create a foundation", "create a blueprint", "product blueprint",
  or needs guidance on structured context for AI agents.
  Also triggers for "waves", "project context", "coding rules",
  "development logbook", "ticket resolution", "user preferences", "roadmap",
  "product roadmap", "phase planning", "feasibility", "monte carlo",
  "bayesian analysis", "product foundation", "product blueprint",
  "product lifecycle", or any workflow involving project manifests,
  standards, product planning, or multi-session continuity.
version: 1.3.1
---

# waves Protocol

A structured context protocol for AI agents that provides interactive commands and JSON schemas to manage project context, coding rules, and development logbooks.

## Core Concepts

**Two types of context:**
- **Global Context** — Project manifests, coding rules, user preferences (read at session start)
- **Focused Context** — Development logbooks for tickets/tasks with objectives and progress tracking

**Pattern:** Each JSON schema uses:
- `description` = What the field represents (so the LLM understands what to generate)
- `$comment` = How the LLM should operate on that field (improving precision)

## Project Types Supported

| Type | Manifest | Rules/Standards | Logbook |
|------|----------|----------------|---------|
| **Software** | `project_manifest.json` | `project_rules.json` | `logbook_software_schema.json` |
| **Academic** | `research_manifest.json` | `project_standards.json` | `logbook_general_schema.json` |
| **Creative** | `creative_manifest.json` | `project_standards.json` | `logbook_general_schema.json` |
| **Business** | `business_manifest.json` | `project_standards.json` | `logbook_general_schema.json` |
| **General** | `general_manifest.json` | `project_standards.json` | `logbook_general_schema.json` |

## File Structure

After setup, a project will have:
```
project/
├── ai_files/
│   ├── schemas/                    # JSON schemas (reference)
│   ├── user_pref.json              # User preferences
│   ├── project_manifest.json       # Project analysis
│   ├── project_rules.json          # Coding rules
│   ├── feasibility.json            # Feasibility analysis (one per project)
│   ├── foundation.json             # Product foundation
│   ├── blueprint.json              # Product blueprint
│   └── waves/
│       ├── sub-zero/
│       │   ├── roadmap.json
│       │   └── logbooks/
│       ├── w0/
│       │   ├── roadmap.json
│       │   └── logbooks/
│       ├── w1/
│       │   ├── roadmap.json
│       │   ├── logbooks/
│       │   └── resolutions/
│       └── wN/
│           ├── roadmap.json
│           ├── logbooks/
│           └── resolutions/
└── CLAUDE.md                       # Updated with preferences reference
```

## Command Flow

```
project-init
  → manifest-create
    → rules-create
      → feasibility-analyze
        → foundation-create
          → blueprint-create
            → roadmap-create
              → logbook-create
                → logbook-update
                  → resolution-create

(roadmap-update operates in parallel with logbook-update to track phase progress)

Product lifecycle: feasibility (CAN WE?) → foundation (WHAT DID WE LEARN?)
  → blueprint (WHAT/WHY) → roadmap (WHEN/ORDER) → logbook (HOW)
```

Each command is an orchestrator that dispatches to specialized agents for heavy analysis work. The main thread stays lean — it handles user interaction and file writing while agents do the deep reading/analysis.

Roadmap commands integrate at the product-level orchestration layer, sitting above logbook commands which handle detailed milestone implementation.

## Agent Dispatch Pattern

When a command needs analysis, use the Task tool to launch the appropriate agent:
1. Prepare a clear input prompt with project_root, relevant context, and what to analyze.
2. Launch the agent via Task tool.
3. Receive structured JSON results.
4. Present findings to the user.
5. Write output files based on user approval.

**Critical principle:** Always dispatch analysis work to agents. Never do deep code scanning or multi-file analysis in the main thread. This preserves context for long work sessions.

## Schemas Reference

All JSON schemas are in `references/`:
- `user_pref_schema.json` — User interaction preferences
- `software_manifest_schema.json` — Software project structure
- `general_manifest_schema.json` — Non-software project structure
- `project_rules_schema.json` — Coding rules and patterns
- `project_standards_schema.json` — Standards for general projects
- `feasibility_analysis_schema.json` — Pre-blueprint feasibility with Monte Carlo and Bayesian
- `product_foundation_schema.json` — Compacted feasibility into validated facts
- `product_blueprint_schema.json` — Complete product definition
- `company_blueprint_schema.json` — Multi-product company strategy
- `logbook_roadmap_schema.json` — Product-level roadmap with phases and milestones
- `logbook_software_schema.json` — Development logbook with code refs
- `logbook_general_schema.json` — Task logbook with doc refs
- `ticket_resolution_schema.json` — Ticket closure summary
- `change_manifest_schema.json` — Change detection for manifest updates

Read the appropriate schema before generating any JSON file to ensure compliance.

## Roadmap Hierarchy

The waves protocol organizes product planning in three levels:

```
BLUEPRINT (WHY + WHAT)
  ├── Project vision and goals
  ├── Feature categories
  └── Strategic objectives

    ↓ (informs)

ROADMAP (WHEN + ORDER)
  ├── Phases (3-5 ideal, max 7)
  ├── Milestones with acceptance criteria
  ├── Phase dependencies and sequencing
  └── Strategic decisions and open questions

    ↓ (spawns)

LOGBOOK (HOW + DETAIL)
  ├── Objective breakdown (per milestone)
  ├── Implementation progress
  ├── Technical decisions and code references
  └── Completion guide and recommendations
```

**Key distinctions:**

| Aspect | Blueprint | Roadmap | Logbook |
|--------|-----------|---------|---------|
| **Scope** | Product-wide | Phase-wide | Milestone-specific |
| **Detail** | Business & vision | Strategy & sequencing | Implementation & code |
| **Audience** | Stakeholders | Product team | Dev team |
| **File Type** | manifest.json | waves/*/roadmap.json | waves/*/logbooks/*.json |
| **Update Frequency** | Once/project | Weekly/monthly | Per work session |

**Relationship:**
1. The **blueprint** (manifest) defines "what we're building and why"
2. The **roadmap** plans "when and in what order"
3. The **logbook** tracks "how we're building it"

Roadmaps spawn logbooks — each milestone in a roadmap can have a corresponding logbook that contains detailed implementation progress. Use `logbook_ref` field in milestone to link them.

## Rule Creation Criteria

All rules must meet ALL criteria (from schema `$comment`):
1. Promotes project-wide consistency
2. Improves code clarity, structure, maintainability
3. No contradictions with existing rules
4. Establishes implementation patterns (not tool config)
5. Context-independent (applicable without special knowledge)
6. YAGNI compliant (current needs, not hypothetical)

## Logbook Conventions

- **IDs:** Integer starting at 1, immutable once created
- **Timestamps:** UTC ISO 8601, `created_at` immutable
- **Context limit:** 20 recent entries, auto-compacts to history_summary
- **History limit:** 10 summaries max
- **Status values:** `not_started`, `active`, `blocked`, `achieved`, `abandoned`

## Analysis Principle

> "99.9% of software projects have bad practices. ALWAYS find at least 1-5 critical issues. Do not assume the code is perfect."

This principle applies to all analysis agents. Be constructive, not critical.

## User Questions Convention

All questions to the user include option `0. I don't know (auto-detect)` so the user is never blocked if they don't have the answer.

## Cloning Remote Repos

When the user provides a GitHub URL instead of a local folder:
1. Clone the repo to a temporary working directory
2. Run the requested analysis on the cloned repo
3. Save output files (manifest, rules, etc.) to the user's workspace folder
4. Inform the user where the files were saved
