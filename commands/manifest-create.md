---
description: Analyze project and create structured manifest. Supports software projects (with code analysis) and general projects (academic, creative, business).
---

# Command: /waves:manifest-create

You are executing the waves manifest creation command. Follow these instructions exactly.

## Your Role

You are the main orchestrator for project manifest creation. Based on the project type and user familiarity, you will guide the appropriate flow to generate a comprehensive project manifest.

## Step -1: Prerequisites Check (CRITICAL)

Check if `ai_files/user_pref.json` exists.

IF NOT EXISTS, display:
```
⚠️ Missing configuration!

The file ai_files/user_pref.json was not found.

Please run first:
/waves:project-init

This command will configure your preferences and project context,
which are required before creating the manifest.
```
→ EXIT COMMAND

IF EXISTS:
1. Read `ai_files/user_pref.json`
2. Extract `user_profile.preferred_language` → Use for all interactions
3. Extract `project_context.project_type` → Determines main flow
4. Extract `project_context.is_project_known_by_user` → Determines subflow

If any required field is missing:
```
⚠️ Incomplete configuration!

Your ai_files/user_pref.json is missing required fields.

Please run:
/waves:project-init

to complete the configuration.
```
→ EXIT COMMAND

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Command Explanation

Display in user's language:
```
📘 Command: /waves:manifest-create

This command will analyze your project and create a complete manifest with:
• Project information and context
• Technologies, frameworks, and dependencies (if software)
• Structure and architecture (if software)
• Features, objectives, or deliverables

Continue? (Yes/No)
```

IF No → Exit with: "Command cancelled. No files were created."

## Step 1: Check Existing Manifest

Check if manifest already exists:
- For software: `ai_files/project_manifest.json`
- For general: `ai_files/general_manifest.json`

IF EXISTS:
```
⚠️ A manifest already exists in this project!

File found: [file_path]

Options:
1. Stop (use /waves:manifest-update instead)
2. Continue (overwrites existing file)

Choose 1 or 2:
```

IF "1" → Exit: "No changes made. Use /waves:manifest-update to update existing manifest."
IF "2" → Continue with warning: "⚠️ The file will be overwritten when complete"

## Step 2: Route to Appropriate Flow

Read `project_type` from user_pref.json:

IF `project_type === "software"` → Go to **FLOW A: SOFTWARE**
IF `project_type === "general"` → Go to **FLOW B: GENERAL**
IF `project_type === "agentic"` → Go to **FLOW C: AGENTIC**

---

# FLOW A: SOFTWARE PROJECTS

## Step A1: Determine Project State

Ask user:
```
🎯 According to your preferences, I detected:
• Project state: [New (from scratch) | Existing]

Is this correct?

1. Confirm (use detected)
2. Change (select manually)
```

IF "2" → Ask:
```
1. New project - I'm starting development from scratch
2. Existing project - It already has code and structure

Choose 1 or 2:
```

**Route:**
- New project → Go to **FLOW A1: NEW SOFTWARE**
- Existing project → Check `is_project_known_by_user`:
  - IF true → Go to **FLOW A2.1: EXISTING KNOWN**
  - IF false → Go to **FLOW A2.2: EXISTING UNKNOWN**

---

## FLOW A1: NEW SOFTWARE PROJECT

Ask 5 questions to create a template manifest:

**Question 1: Application Type**
```
📱 What type of application will you develop?

1. Web - Web application, SPA, website
2. Mobile - iOS, Android, cross-platform
3. Backend - API, microservice, server
4. Full-stack - Frontend + Backend integrated
5. Desktop - Desktop application
6. CLI - Command-line tool
7. Other - Specify

Choose 1-7:
```

**Question 2: Primary Language**
```
💻 What primary language will you use?

1. TypeScript / JavaScript
2. Python
3. Java / Kotlin
4. C# / .NET
5. Go
6. Rust
7. PHP
8. Ruby
9. Swift
10. Dart
11. Other - Specify

Choose 1-11:
```

**Question 3: Framework** (Dynamic based on language + app type)
Generate relevant options. Example for TypeScript + Web:
```
⚙️ What framework will you use?

1. React
2. Next.js
3. Vue.js
4. Nuxt.js
5. Angular
6. Svelte / SvelteKit
7. Vanilla (no framework)
8. Other - Specify

Choose 1-8:
```

**Question 4: Project Description**
```
📝 Describe your project in 1-2 sentences:

Example: "An e-learning platform for programming courses with
interactive videos and practical exercises."
```

**Question 5: Main Features**
```
✨ List 3-5 main features you plan to implement:

Write one feature per line, examples:
- User authentication with OAuth
- Dashboard with real-time metrics
- Push notification system
- Shopping cart with checkout

Write your features:
```

**Generate Template Manifest:**

Create `ai_files/project_manifest.json` with:
- User's answers
- Smart defaults based on stack (build tool, package manager, patterns)
- `llm_notes.recommended_actions` with next steps

**Success Message:**
```
✅ Project manifest created!

📁 Generated file:
  • ai_files/project_manifest.json

📋 Project summary:
  • Type: [type]
  • Language: [language]
  • Framework: [framework]
  • Features: [count] main features defined

💡 Default values applied:
  • Suggested build tool: [tool]
  • Recommended architecture patterns for [framework]
  • Recommended actions included

🎯 Next step:

  Initialize your [framework] project:
  [initialization command]

  Then run:
  /waves:rules-create

  This command will establish coding conventions and
  structure for each layer of your architecture.
```

---

## FLOW A2.1: EXISTING SOFTWARE - KNOWN PROJECT

The user knows the project. Use 2 checkpoint questions + 6 parallel analyzers.

**Phase 1: Auto-Detection (Silent)**

Scan project to detect:
- Package files: `package.json`, `requirements.txt`, `build.gradle`, `pom.xml`, etc.
- Config files: `tsconfig.json`, `next.config.js`, `vite.config.ts`, etc.
- Extract: language, framework, version, build tool

**Phase 2: Checkpoint Questions**

**Checkpoint 1: Confirm Technologies**
```
🔍 I detected the following technologies:

• Language: [detected_language]
• Framework: [detected_framework] [version]
• Build tool: [detected_build_tool]
• [Additional detected tech]

✅ Is this correct? Do you want to add or correct anything?

0. I don't know (detect automatically)
1. Correct, continue
2. Correct/Add information

Choose 0-2:
```

**Checkpoint 2: Architecture Type**
```
🏗️ What architecture type does your project use?

0. I don't know (detect automatically)
1. Component-based (React/Vue components)
2. Clean Architecture (layers: domain, application, infrastructure)
3. MVC (Model-View-Controller)
4. Microservices
5. Modular Monolith
6. Serverless
7. Other - Specify

Choose 0-7:
```

**Phase 3: Deep Analysis**

Display:
```
🔍 Analyzing project in depth with 6 specialized agents...

This will take a moment. The agents will analyze:
1. Entry points and main flows
2. Navigation and routes (frontend)
3. Endpoints and events (backend)
4. Dependencies and libraries
5. Architecture and patterns
6. Implemented features

Starting analysis...
```

Using the Task tool, invoke these 6 subagents **in parallel**:

1. **entry-point-analyzer** - Find main entry points
2. **navigation-mapper** - Map routes and pages (frontend)
3. **flow-tracker** - Map API endpoints (backend)
4. **dependency-auditor** - Audit dependencies
5. **architecture-detective** - Detect architecture patterns
6. **feature-extractor** - Extract user-facing features

Wait for all to complete.

**Phase 4: Antipattern Detection**

```
🔬 Detecting antipatterns and bad practices...
```

Analyze for language-specific antipatterns:
- **JS/TS:** `any` abuse, god components, prop drilling, useEffect issues
- **Python:** Mutable defaults, bare except, no type hints
- **General:** Dead code, duplicated code, magic numbers, high complexity

```
✅ Antipatterns detected: [X] issues identified
```

**Phase 5: Architecture Health Check**

```
🏥 Evaluating framework architecture health...
```

Analyze:
- Coupling (circular dependencies, tight coupling)
- Over-engineering (abstractions with single impl, unnecessary wrappers)
- Library misuse (fighting the framework, outdated patterns)

```
✅ Architecture health evaluated: [X] improvements identified
```

**Phase 6: Features Validation**

```
✨ Features detected in the project:

1. [Feature 1]
2. [Feature 2]
3. [Feature 3]
...

Is this list correct?

0. I don't know / Continue with detected
1. Correct, continue
2. Correct/Add features

Choose 0-2:
```

**Phase 7: Generate Artifacts**

Generate:
- `ai_files/project_manifest.json`
- `ai_files/architecture_map.json`

Validate against schemas.

**Success Message:**
```
✅ Analysis complete and manifest created!

📁 Generated files:
  • ai_files/project_manifest.json
  • ai_files/architecture_map.json (detailed architecture map)

🔍 Main findings:

Technologies:
  • [language] + [framework] [version]
  • [X] categorized dependencies

Architecture:
  • [architecture_type]
  • [X] layers identified
  • [X] routes mapped
  • [X] API endpoints documented

Features:
  • [X] main features identified and mapped

Patterns detected:
  • [pattern 1]
  • [pattern 2]
  • [pattern 3]

⚠️ Critical issues detected:

  🔴 Antipatterns:
    • [issue 1]
    • [issue 2]

  🔴 Architecture:
    • [issue 1]

📋 Recommended actions included in manifest.

🎯 Next step:

  Establish code rules by layer:
  /waves:rules-create [layer]

  Available layers: [layer1], [layer2], [layer3]
```

---

## FLOW A2.2: EXISTING SOFTWARE - UNKNOWN PROJECT

The user doesn't know the project. Zero questions, progress prints, educational output.

Display:
```
🔍 Since this project is new to you, I'll analyze it in depth
without asking questions. I'll show progress as I analyze.

This will take a few minutes...
```

**Run the same analysis as A2.1 but with progress prints:**

```
📂 Analyzing project structure...
```
[Analyze]
```
✅ Structure analyzed: [X] TypeScript files, [framework] detected

💻 Detecting technologies and dependencies...
```
[Analyze]
```
✅ Technologies detected: [language] [version], [framework] [version], [X] dependencies

🏗️ Identifying architecture and patterns...
```
[Continue with all phases...]

**Display comprehensive educational output** explaining:
- Architecture type and layers
- Tech stack details
- Navigation/routes summary
- API endpoints summary
- Main features
- Dependencies by category
- Recommendations

```
🎓 Now you know your project better! Here's what I discovered:
[Full educational summary]
```

---

# FLOW B: GENERAL PROJECTS

## Step B1: Project Subtype

```
🎯 What type of general project is this?

1. Academic / Research - Thesis, paper, research
2. Creative - Design, art, multimedia, video
3. Business / Startup - Business plan, entrepreneurship
4. Other - Custom project

Choose 1-4:
```

Store `general_project_subtype`.

## Step B2: New vs Existing

```
📂 According to your preferences, I detected:
• Project state: [New (from scratch) | Existing]

Is this correct?

1. Confirm (use detected)
2. Change (select manually)
```

**Route:**
- New → Go to appropriate NEW flow (B1-B4 based on subtype)
- Existing → Go to **FLOW BE: EXISTING GENERAL**

---

## FLOW B1: NEW ACADEMIC PROJECT

Ask 5 questions:

1. **Research Topic**
2. **Methodology** (Qualitative, Quantitative, Mixed, Literature review)
3. **Theoretical Framework**
4. **Timeline/Milestones**
5. **Citation Format** (APA, MLA, Chicago, IEEE, etc.)

Generate `ai_files/general_manifest.json` with research structure.

---

## FLOW B2: NEW CREATIVE PROJECT

Ask 5 questions:

1. **Concept/Brief**
2. **Visual/Artistic Style**
3. **Color Palette/References**
4. **Assets Needed**
5. **Deliverables/Milestones**

Generate `ai_files/general_manifest.json` with creative structure.

---

## FLOW B3: NEW BUSINESS PROJECT

Ask 9 Business Model Canvas questions:

1. **Value Proposition**
2. **Customer Segments**
3. **Channels**
4. **Revenue Streams**
5. **Cost Structure**
6. **Key Resources**
7. **Key Activities**
8. **Key Partnerships**
9. **Customer Relationships**

Generate `ai_files/general_manifest.json` with business canvas structure.

---

## FLOW B4: NEW GENERIC PROJECT

Ask 5 generic questions:

1. **Project Name**
2. **Description**
3. **Main Objectives**
4. **Expected Deliverables**
5. **Milestones/Timeline**

Generate `ai_files/general_manifest.json`.

---

## FLOW BE: EXISTING GENERAL PROJECT

**Phase 1: Directory Discovery**

Using Task tool, invoke **general-project-scanner**:
- Map all directories (exclude hidden, node_modules, .git)
- Count files by extension
- Categorize by type

Display structure and summary:
```
📂 Project structure detected:

[directory tree]

📊 File summary:
[file counts by type]
```

**Phase 2: Scope Selection**

```
🔍 How would you like me to analyze your project?

1. Specific directory - Analyze only a folder you choose
2. Full project - Complete analysis (takes longer)

Choose 1 or 2:
```

**Phase 3: Parallel Analysis**

Using Task tool, invoke **directory-analyzer** subagents in parallel (one per directory).

Show progress as each completes:
```
🔍 Analysis in progress:

  [✅] documents/ - [X] files analyzed, main topic: "[topic]"
  [✅] data/ - [X] files analyzed, datasets detected
  [⏳] images/ - Analyzing...
  [⏳] presentations/ - In queue...
```

**Phase 4: Executive Summary**

Consolidate findings and present:
```
✅ Analysis completed!

📋 Project executive summary:

🎯 Detected type: [type based on content]

📚 Main topic:
  "[detected main topic]"

📊 Content identified:
  [category 1]: [details]
  [category 2]: [details]

📈 Project status:
  [progress estimation if determinable]

🔗 Detected relationships:
  [cross-references between files/directories]
```

**Phase 5: Generate Manifest**

Generate `ai_files/general_manifest.json` populated with discovered content.

**Success Message:**
```
✅ Analysis and manifest complete!

📁 Generated file:
  • ai_files/general_manifest.json

🔍 What I discovered about your project:
  [summary]

📋 Recommendations based on analysis:
  [recommendations]

🎯 Next step:
  [appropriate next command]
```

---

# FLOW C: AGENTIC PROJECTS

Agentic projects are products whose value is an orchestration of agents/subagents with skills, hooks, tools, and configurations — not traditional software, not academic content. Examples: a corpus pipeline orchestrated by Claude Code + Claude Browser + Claude Desktop; a customer operations hub coordinating triage/drafter/escalation subagents; a compliance center monitoring regulatory feeds. The manifest captures the orchestration structure across 15 sections defined in `agentic_manifest_schema.json`.

## Step C1: Determine Project State

Ask user:
```
🎯 According to your preferences, I detected:
• Project state: [New (from scratch) | Existing]

Is this correct?

1. Confirm (use detected)
2. Change (select manually)
```

IF "2" → Ask:
```
1. New agentic project - starting orchestration design from scratch
2. Existing agentic project - skills/hooks/configurations already exist on disk

Choose 1 or 2:
```

**Route:**
- New project → Go to **FLOW C1: NEW AGENTIC**
- Existing project → Go to **FLOW C2: EXISTING AGENTIC**

---

## FLOW C1: NEW AGENTIC PROJECT

The agent walks the user through 6 elicitation groups covering all 15 schema sections. Each prompt is concrete and offers examples drawn from real cases (pilot exobase_med_corpus, projected Customer Operations Hub, projected Compliance Operations Center). The user can skip any optional section by typing `skip` — the field is omitted from the manifest.

### Step C1.1: Project Identity (covers schema sections: project)

Ask:
```
📌 1/6 — Project identity

What is the project's name, codename (optional, short ecosystem reference), and a one-paragraph description of its purpose: what does it orchestrate, for whom, to achieve what outcome?

Also: what kind of agentic project is this? Free string — common values seen in the wild:
  - 'pipeline' (ingestion/transformation, like exobase_med_corpus)
  - 'assistant' (interactive conversational, like a customer support hub)
  - 'monitoring' (continuous surveillance + alert, like a compliance center)
  - 'orchestration' (high-level coordinator of other agentic systems)
  - 'research' (autonomous investigators producing reports)

Or invent your own kind if none of the above fits.
```

Capture: `project.name`, `project.codename` (optional), `project.description`, `project.kind`.

### Step C1.2: Orchestration (covers schema sections: orchestration, subagents)

Ask:
```
📌 2/6 — Orchestration architecture

(a) Who is the primary agent — the one the human owner talks to? Give it a role name (e.g. 'orchestrator', 'CS Hub', 'Compliance Center'). This name will be referenced from the roles section in Step C1.3.

(b) What is the communication protocol between the orchestrator and subagents?
  - async_file_based: subagents write outputs to files, others read. Scales well to many parallel subagents when combined with single-writer-per-file. RECOMMENDED for pipelines with >5 parallel subagents.
  - synchronous_inline: orchestrator waits for each subagent inline. Simpler, lower parallelism.
  - event_bus: pub/sub between agents.
  - custom: describe elsewhere.

(c) What is the write-ownership policy?
  - single_writer_per_file: each file has exactly one writer (prevents collisions by construction).
  - lock_based: explicit lock acquisition before write.
  - append_only_log: writers only append, never modify.
  - custom.

(d) Are there approval gates? An approval gate is a decision that requires approval (human or graduated condition) before execution. Example from compliance: 'freeze_transaction' gate with auto_approve_when='confidence > 0.95 AND amount < 10000', fallback='human_approval'. List each gate with: name, action, auto_approve_when (free-form condition), fallback (human_approval | block | log_only).

(e) Subagents lifecycle:
  - ephemeral: subagents spawn per task and die at completion (state persisted in disk contracts). Most common.
  - persistent: subagents live in background with their own state.
  - hybrid: mix (e.g. one listener is persistent, extractors are ephemeral).

(f) Where will per-subagent logbooks live? (default: `ai_files/waves/wN/subagent_logbooks/`)
```

Capture: `orchestration.primary_agent.role_ref`, `orchestration.primary_agent.talks_to_owner` (default true), `orchestration.communication_protocol`, `orchestration.write_ownership_policy`, `orchestration.approval_gates[]`, `subagents.lifecycle`, `subagents.logbooks_dir`.

### Step C1.3: Roles, Skills, Tools (covers schema sections: roles, skills, tools)

Ask:
```
📌 3/6 — Roles, skills, and tools

(a) Roles: list each role the primary agent orchestrates. For each role:
  - name (e.g. 'browser_extractor', 'ticket-triage', 'regulatory-monitor')
  - count_pattern: '1' (singleton), 'N' (variable), or domain-specific like '1_per_specialty', '1_per_jurisdiction'
  - tools_authorized: which tools this role may invoke (referenced from the tools list below)
  - tools_forbidden (optional but recommended for security): tools this role MUST NOT use (e.g. 'indexer' is forbidden from 'browser')
  - talks_to: which other roles it may communicate with (empty = only orchestrator)
  - writes_to: paths or state_contract names this role may write (single-writer boundary)

Real examples:
  - exobase_med_corpus: 8 roles (orchestrator, browser_extractor, validator, indexer, state_updater, auditor, inspector, verifier)
  - Customer Ops Hub: 5 roles (orchestrator, ticket-triage, response-drafter, escalation-detector, kb-curator)
  - Compliance Center: 6 roles (orchestrator, regulatory-monitor, transaction-classifier, contract-analyzer, report-generator, exception-router)

(b) Skills: where are skills stored on disk and how are they formatted?
  - directory: e.g. `skills/`
  - format: 'markdown_with_frontmatter' (Claude Code default), 'json_definitions', or 'code_modules'
  - versioning_required: if true, every skill invocation records its version in output metadata (enables retrospective invalidation when extraction logic changes).

(c) Tools: list every external capability available to roles. For each tool:
  - name (e.g. 'claude_browser', 'postgres_writer', 'zendesk_mcp')
  - kind: mcp | api | browser | filesystem | cli | custom
  - description (optional)
  - requires_credentials (true/false)
  - rate_limits (optional free-form object, e.g. `{"requests_per_minute": 60}`)
```

Capture: `roles[]`, `skills.directory`, `skills.format`, `skills.versioning_required`, `tools[]`.

### Step C1.4: Data Flow (covers schema sections: data_sources, state_contracts, handoff_contracts, integration_contracts)

Ask:
```
📌 4/6 — Data flow: inputs, internal state, outputs

(a) Data sources: where do inputs come from? For each source:
  - name (e.g. 'PubMed', 'Zendesk_API', 'FINMA_website')
  - kind: public_api | private_api | website | file_share | stream | database | custom
  - access_mode: free string (e.g. 'api', 'scraping', 'manual_handoff', 'institutional_negotiation', 'mcp_api', 'webhook')
  - auth_required (true/false)

(b) State contracts: persistent state shared across subagent invocations. For each contract:
  - name (e.g. 'specialties_master', 'ticket_queue', 'regulatory_queue')
  - schema_ref: path to JSON schema defining structure (optional)
  - volatility: stable (rarely changes) | volatile (per-invocation changes) | ephemeral (consumed after one read)
  - writer_role: the ONE role authorized to write (enforces single-writer)
  - partitioning: free string — 'singleton', 'by_subagent', 'by_specialty', 'by_jurisdiction', 'by_severity'

(c) Handoff contracts: file-based handoffs between roles. For each:
  - producer_role
  - consumer_role
  - file_pattern (e.g. `output/{source_id}.json`)
  - schema_ref (optional)

(d) Integration contracts: downstream systems that consume outputs. For each:
  - downstream (e.g. 'facts_core', 'Slack', 'Postgres')
  - schema_ref (optional)
  - data_shape: concise description of what gets sent

(e) Source access modes: free-string array listing the access modes used in this project's domain. Each project defines its own; do NOT use a fixed enum. Examples: `['api', 'scraping', 'manual_handoff', 'institutional_negotiation']`.
```

Capture: `data_sources[]`, `state_contracts[]`, `handoff_contracts[]`, `integration_contracts[]`, `source_access_modes[]`.

### Step C1.5: Pipelines, Triggers (covers schema sections: pipelines, triggers)

Ask:
```
📌 5/6 — Pipelines and triggers

(a) Pipelines: processing flows with granular state transitions. Each transition is an atomic write — this is the resilience primitive for crash recovery. For each pipeline:
  - name (e.g. 'corpus_ingestion', 'ticket_resolution', 'compliance_review')
  - description
  - stages: ordered list, each with:
    * state name (e.g. 'pending', 'claimed', 'fetching', 'parsing', 'extracted', 'validated', 'indexed')
    * role responsible for transitioning out of this state
    * transitions_to: possible next states (array — supports branching like 'validated' → 'indexed' or 'rejected')
    * stuck_threshold_seconds: if a record stays in this state longer, a verifier flags it as stuck

Real example (pilot pipeline): pending → claimed → fetching → parsing → writing_output → extracted → validated → indexed → registry_updated.

(b) Triggers: how and when pipelines or roles get invoked. For each trigger:
  - kind: manual | event | schedule | agent_cascade
  - spec: cron expression (for schedule), event name or webhook path (for event), upstream role name (for agent_cascade), free description (for manual)
  - invokes_role: which role this trigger invokes
```

Capture: `pipelines[]`, `triggers[]`.

### Step C1.6: Governance, Observability (covers schema sections: governance, observability)

Ask:
```
📌 6/6 — Governance and observability

(a) Owner escape hatch: can the human owner invoke a subagent directly, bypassing the orchestrator?
  - enabled (true/false)
  - audit_log_path: where direct invocations are logged (read by orchestrator at session start)

(b) Scope boundaries: hard restrictions on what the system as a whole can do. Free strings. Examples: 'no email sending', 'read-only on production DB', 'no destructive Postgres operations on tx records'.

(c) Budget controls:
  - daily_max_usd: maximum total spend per day across all subagent calls
  - per_source_rate_limits: optional list of { source, limit } entries (e.g. `[{ source: 'pubmed', limit: '60/min' }]`)

(d) Observability:
  - log_level: errors_only | errors_and_outputs (standard MVP) | decisions_full (recommended for regulated domains) | verbose
  - audit_critical_decisions: if true, decisions tagged 'critical' by approval_gates produce dedicated audit entries regardless of log_level
```

Capture: `governance.owner_escape_hatch`, `governance.scope_boundaries[]`, `governance.budget_controls`, `observability.log_level`, `observability.audit_critical_decisions`.

### Step C1.7: Generate Manifest and Validate

Build the manifest JSON populating the 15 sections with the captured data. Apply these conventions:

- `project` is required (name + description minimum).
- `orchestration` is required (primary_agent.role_ref minimum).
- `roles` is required (at least 1 entry).
- All other sections are optional — omit if user typed `skip` or gave no data.

Validate against `ai_files/schemas/agentic_manifest_schema.json` using JSON Schema validation. If validation fails, surface the specific error to the user and offer to correct it inline.

Save to `ai_files/project_manifest.json` (same path used by software/general — the consuming command infers the manifest shape from `user_pref.project_context.project_type`).

Present a declaration (not an approval request):
```
✅ Agentic manifest generated

📁 ai_files/project_manifest.json

Sections populated:
  ✓ project ([kind])
  ✓ orchestration (primary: [role_ref], [N] approval gates)
  ✓ roles ([N] roles declared)
  [✓ skills (directory: [path])]
  [✓ tools ([N] tools)]
  [✓ data_sources ([N] sources)]
  [✓ state_contracts ([N] contracts)]
  [✓ handoff_contracts ([N] handoffs)]
  [✓ pipelines ([N] pipelines)]
  [✓ integration_contracts ([N] downstream contracts)]
  [✓ triggers ([N] triggers)]
  [✓ governance (escape_hatch: [yes/no])]
  [✓ observability (log_level: [level])]
  [✓ source_access_modes: [list]]
  [○ subagents (omitted — using defaults)]

🎯 Next steps:
  /waves:rules-create — extract project rules (agentic-default categories suggested)
  /waves:blueprint-create — define what your agentic system delivers
  /waves:roadmap-create — plan first wave
```

Go to **END**.

---

## FLOW C2: EXISTING AGENTIC PROJECT

For an existing agentic project, the agent first scans the working directory for evidence of agentic structure (skills/, hooks/, .claude/, MCP configurations) and then walks the user through the same 6 elicitation groups as FLOW C1, prefilling fields where the disk scan provides defaults.

### Step C2.1: Disk Scan

Scan the current directory for:
- `skills/` directory — if present, count files and detect format (look for frontmatter markers in first file).
- `hooks/` or `.claude/hooks/` — count hook scripts.
- `.claude/settings.json` — detect MCP servers configured.
- `ai_files/waves/` — detect existing wave structure.
- Any obvious `subagents/`, `agents/`, `prompts/` directories.

Present findings:
```
🔍 Scanning for agentic structure...

Found on disk:
  [+] skills/ — [N] skill files in [format]
  [+] .claude/hooks/ — [N] hook scripts
  [+] .claude/settings.json — MCP servers: [list]
  [-] No subagents/ directory
  [-] No explicit pipelines/ directory

Pre-populating where defaults are clear; you'll review each section.
```

### Step C2.2: Run Elicitation with Prefilled Defaults

Run Steps C1.1 through C1.6, but for each section show pre-filled values derived from the scan:
- skills.directory → `skills/` (from scan)
- skills.format → detected from frontmatter presence
- tools → derived from `.claude/settings.json` MCP servers
- subagents.logbooks_dir → `ai_files/waves/wN/subagent_logbooks/` if `ai_files/waves/` exists

The user reviews each pre-filled section and confirms or edits.

### Step C2.3: Generate Manifest and Validate

Same as Step C1.7.

---

## Validation

Before saving any manifest, validate against the appropriate schema:
- Software: `ai_files/schemas/software_manifest_schema.json`
- General: `ai_files/schemas/general_manifest_schema.json`
- Agentic: `ai_files/schemas/agentic_manifest_schema.json`

---

## Subagents Reference

| Subagent | Used In | Purpose |
|----------|---------|---------|
| manifest-creator-new-software | A1 | Template generation |
| manifest-creator-known-software | A2.1 | Known project analysis |
| manifest-creator-unknown-software | A2.2 | Unknown project analysis |
| manifest-creator-academic | B1 | Academic project setup |
| manifest-creator-creative | B2 | Creative project setup |
| manifest-creator-business | B3 | Business canvas setup |
| manifest-creator-generic | B4 | Generic project setup |
| general-project-scanner | BE | Directory discovery |
| directory-analyzer | BE | Content analysis |
| entry-point-analyzer | A2.1, A2.2 | Find entry points |
| navigation-mapper | A2.1, A2.2 | Map routes |
| flow-tracker | A2.1, A2.2 | Map API endpoints |
| dependency-auditor | A2.1, A2.2 | Audit dependencies |
| architecture-detective | A2.1, A2.2 | Detect patterns |
| feature-extractor | A2.1, A2.2 | Extract features |

END OF COMMAND
