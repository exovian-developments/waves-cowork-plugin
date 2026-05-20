---
description: Create a new development logbook for a ticket/task with structured objectives, autonomous design resolution, code tracing, UI detection, and actionable completion guides.
---

# Command: /waves:logbook-create

You are executing the waves logbook creation command. Follow these instructions exactly.

## Your Role

You are the main orchestrator for logbook creation. You will gather task information, detect UI requirements, analyze related code, resolve ALL design decisions autonomously using SRP/KISS/YAGNI/DRY/SOLID principles, and create a structured logbook with main and secondary objectives.

**Autonomy principle:** You are trusted to make high-quality design decisions when you have clear business context (blueprint, ticket description, project rules) and established architecture. You only escalate to the user when detecting business-level contradictions that design principles cannot resolve.

## Step -1: Prerequisites Check (CRITICAL)

Check if `ai_files/user_pref.json` exists.

IF NOT EXISTS:
```
⚠️ Missing configuration!

Please run first:
/waves:project-init

This command requires user preferences to be configured.
```
→ EXIT COMMAND

IF EXISTS:
1. Read `ai_files/user_pref.json`
2. Extract `user_profile.preferred_language` → Use for all interactions
3. Extract `user_profile.explanation_style` → Use for contextualizing questions
4. Extract `project_context.project_type` → Determines flow (software vs general)

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Parameter Check and Tip

Check if filename parameter was provided with the command.

IF NO parameter:
```
💡 TIP: You can run faster with:
   /waves:logbook-create TICKET-123.json
```

IF parameter provided:
- Validate filename format
- Must end in `.json`
- No special characters except `-` and `_`
- IF invalid → Ask for valid filename

## Step 0.5: Smart Wave Detection (CRITICAL)

Before checking for existing logbooks, determine the target wave. DO NOT ask the user if context is clear:

1. List `ai_files/waves/*/roadmap.json` to find all waves with roadmaps
2. Read each roadmap — find which has status "active" or "in_progress"
3. If only ONE wave is active → use that wave automatically
4. If the user provided context (ticket description, milestone name) that matches a specific milestone in a roadmap → use that wave
5. Only ask the user if genuinely ambiguous (multiple active waves, no clear match)
6. Store as `target_wave`
7. Create directory `ai_files/waves/[target_wave]/logbooks/` if it doesn't exist

## Step 1: Check Existing Logbook

Check if `ai_files/waves/[target_wave]/logbooks/[filename].json` exists (if filename was provided).

IF EXISTS:
```
⚠️ A logbook with that name already exists!

File: ai_files/waves/[target_wave]/logbooks/[filename].json

Options:
1. Use different name
2. Overwrite (current content will be lost)

Choose 1 or 2:
```

IF "1" → Ask for new filename, repeat check
IF "2" → Continue with warning

## Step 2: Gather Ticket/Task Information

```
📋 Let's create a work logbook.

What is the title of the ticket or task?
(Example: "Implement GET /products/:id endpoint")
```

Wait for user response. Store as `ticket_title`.

```
Do you have a ticket URL? (Jira, GitHub, etc.)
(Enter URL or press Enter to skip)
```

Store as `ticket_url` or null.

```
Describe the ticket/task with all relevant details:
• What needs to be accomplished?
• Are there acceptance criteria?
• Any constraints or special considerations?
```

Wait for user response. Store as `ticket_description`.

## Step 2.1: UI Detection (NEW)

After receiving the ticket description, analyze it for UI-related keywords:

**UI Indicators to detect:**
- Frontend, UI, UX, interface, screen, page, view, component
- Form, button, modal, dialog, popup, dropdown, input
- Layout, design, styling, CSS, responsive, mobile
- User interaction, click, hover, navigation
- Display, show, render, present

IF UI indicators detected:
```
🎨 I detected this ticket may involve UI changes:

Detected UI elements:
• [list detected UI-related terms/requirements]

Do you have visual references I can analyze?
(Mocks, wireframes, design files, screenshots)

Supported formats:
• Images: PNG, JPG, SVG, WebP
• Figma: Export as PNG or provide screenshot
• PDF: Design specifications

Options:
1. Yes, I have visual references (provide path or paste)
2. No visual references available
3. UI is not part of this ticket

Choose:
```

**IF "1" (has visual references):**
```
Please provide the path to the visual reference(s):
(You can provide multiple paths, one per line)

Examples:
• ./designs/product-detail-mock.png
• ~/Downloads/figma-export.png
```

For each provided path:
1. Read the image file using the Read tool
2. Analyze the visual elements:
   - Layout structure
   - Components visible
   - Colors, typography (if distinguishable)
   - Interactive elements
   - State variations (if multiple screens)

Store analysis as `ui_requirements`:
```json
{
  "has_ui": true,
  "visual_references": ["path1.png", "path2.png"],
  "detected_components": ["header", "product card", "add to cart button"],
  "layout_notes": "Grid layout with 3 columns on desktop",
  "interaction_notes": "Button shows loading state on click",
  "unresolved_ui_questions": []
}
```

**IF "2" (no visual references):**
```
⚠️ UI work without visual references may lead to misalignment.

I'll proceed with text-based requirements, but consider:
• Getting design approval before implementation
• Creating simple wireframes first
• Confirming with stakeholders

Continue anyway? (Yes/No)
```

Store: `ui_requirements.has_ui = true, visual_references = []`

**IF "3" (no UI):**
Store: `ui_requirements.has_ui = false`

## Step 2.2: Description Clarity Validation

**Validate description clarity:**
IF description is vague or unclear:
```
🤔 I need more clarity to create precise objectives.

[Specific questions about unclear aspects]

Can you clarify?
```
Repeat until objectives are clear enough.

## Step 3: Route to Appropriate Flow

Read `project_type` from user_pref.json:

IF `project_type === "software"` → Go to **FLOW A: SOFTWARE**
IF `project_type === "general"` → Go to **FLOW B: GENERAL**
IF `project_type === "agentic"` → Go to **FLOW A: SOFTWARE** (same flow; logbook_software_schema is structurally compatible — objectives carry scope.files pointing to skill/hook/config files and scope.rules referencing agentic rule categories. The orthogonality reviewer and integrity audit subagents work identically. The only semantic difference is that for agentic projects, "code" means skill markdown / hook JSON / prompt files rather than Dart/TS source — but the structural model is the same.)

---

# FLOW A: SOFTWARE PROJECT LOGBOOK

Uses schema: `ai_files/schemas/logbook_software_schema.json`

## Step A1: Initial Code Tracing

```
🔍 Analyzing project to identify related code...
```

1. **Read project manifest:**
   - Load `ai_files/project_manifest.json`
   - Identify relevant layers from `architecture_patterns_by_layer`
   - Identify relevant features from `features`
   - Note entry points and tech stack

2. **Trace related code:**
   - Search for files, classes, functions related to the ticket
   - Identify patterns and conventions in related code
   - Note dependencies between components

3. **Load project rules (if exists):**
   - Read `ai_files/project_rules.json`
   - Identify rules that apply to identified layers/features
   - Note rule IDs for `scope.rules`

4. **Search for product-level context files:**
   - Search for `ai_files/blueprint.json` → IF EXISTS: Read and extract relevant capabilities, flows, design principles, and product rules that relate to the ticket
   - Search for `ai_files/technical_guide.md` → IF EXISTS: Read and extract relevant technical guidelines, architecture decisions, and implementation patterns
   - Search for `ai_files/feasibility.json` → IF EXISTS: Read and extract relevant revenue model context, buyer personas, and essential capabilities
   - Search for roadmap files: `ai_files/waves/*/roadmap.json` → IF ANY EXIST: Read and extract current phase, milestones, and relevant decisions. If multiple roadmaps found, prioritize the one for the target wave or the one most relevant to the ticket.

   **For each file found:** Extract only the sections relevant to the ticket description. Store as `product_context`.

   **For each file NOT found:** Note in a list but DO NOT stop or error. Continue normally.

5. **Present analysis:**
```
📊 Initial analysis complete:

Related layers:
• [layer1] ([path])
• [layer2] ([path])

Identified reference files:
• [file1]
• [file2]
• [file3]

Applicable rules:
• #[id]: [rule description]
• #[id]: [rule description]

Product context sources:
  [For each file found:]
  ✓ [filename] — [brief summary of relevant content extracted]
  [For each file NOT found:]
  ○ [filename] — not found (skipped)

Is this information correct? (Yes/No/Adjust)
```

IF "Adjust" → User provides corrections, update analysis

## Step A1.5: Additional Source Files (Open for Extension)

After presenting the initial analysis, ask the user if they have additional files to use as context:

```
📂 Do you have additional files I should use as context for this logbook?

These could be:
• Design documents, specs, or PRDs
• Architecture diagrams or technical docs
• Related ticket descriptions or meeting notes
• Any other file that provides context for this task

Options:
  [paths] Provide one or more file paths (one per line)
  [n]     No additional files, continue
```

**IF user provides paths:**
- For each path:
  - Validate the file exists
  - Read the file
  - Extract relevant content related to the ticket
  - Add to `product_context` or `additional_sources`
- IF a file does not exist:
  ```
  ⚠️ File not found: [path] (skipping)
  ```
  Continue with the remaining files.
- Present summary of what was extracted:
  ```
  ✓ Read [N] additional source file(s):
    • [filename] — [brief summary of relevant content]
  ```

**IF "n" or empty:** Continue to Step A2.

Store all additional sources for inclusion in logbook context and completion guides.

## Step A2: Autonomous Design Resolution (CRITICAL)

Before generating objectives, identify and resolve ALL design decisions autonomously. The agent is trusted to make high-quality design decisions when it has clear business context (blueprint, ticket description, project rules) and applies established principles.

**Philosophy:** The agent resolves ALL code-level and architecture-level decisions autonomously. It only escalates to the user when detecting **business-level** contradictions, ambiguities, or incongruencies that design principles cannot resolve.

### Step A2.1: Identify Design Decisions

Analyze the gathered information for decisions needed in these categories:

| Category | Examples |
|----------|----------|
| **Directory/Location** | Where to create new files? Which module? |
| **File Strategy** | Create new file or modify existing? Split or merge? |
| **Library Choice** | Which library for dates? State management? Validation? |
| **Entry Points** | New route? New controller method? New service? |
| **Architecture** | New layer needed? Reuse existing pattern? |
| **Naming** | Convention for new components? Match existing or new pattern? |
| **Dependencies** | Add new package? Use existing utility? |
| **Scope** | Include error handling? Add logging? Create tests? |

### Step A2.2: Resolve Autonomously with Unified Principles

Apply the following principles **as a unified chain** (not as separate sequential steps) to resolve ALL design decisions:

| Principle | Question to Ask |
|-----------|-----------------|
| **SRP** | Does each class/function have a single, clear responsibility? |
| **KISS** | Is this the simplest solution that satisfies the requirement? |
| **YAGNI** | Is this needed NOW or is it speculative for the future? |
| **DRY** | Am I duplicating logic that already exists in the codebase? |
| **SOLID (full)** | Does the design respect Open/Closed, Liskov, Interface Segregation, Dependency Inversion? |

For each decision, the agent selects the principle(s) most relevant and resolves immediately. No user interaction needed.

### Step A2.3: Detect Business-Level Contradictions (Escalation Gate)

After resolving all code/architecture decisions, check if any remaining issues are **business-level**:

**Escalate ONLY when:**
- The ticket description contradicts the blueprint (e.g., ticket asks to remove a capability the blueprint marks as revenue_blocking)
- Acceptance criteria are mutually exclusive or logically impossible
- The ticket scope is fundamentally ambiguous about WHAT the business needs (not HOW to implement it)
- Product rules conflict with each other in a way that changes user-facing behavior

**DO NOT escalate when:**
- It's a code-level decision (file location, naming, pattern choice) → resolve with principles
- It's an architecture decision (new layer, split vs merge) → resolve with principles
- It's a scope decision (include tests, add logging) → resolve with YAGNI
- The answer can be inferred from existing codebase patterns → follow established patterns

**IF business-level contradictions detected:**
```
⚠️ I found [N] business-level issue(s) that I cannot resolve with design principles alone:

┌─────────────────────────────────────────────────────────────────┐
│ Issue 1: [category]                                             │
├─────────────────────────────────────────────────────────────────┤
│ [Explanation of the contradiction/ambiguity]                    │
│                                                                 │
│ Why I can't resolve this:                                       │
│ [Why design principles are insufficient — this is a business    │
│  decision that affects product behavior/scope]                  │
│                                                                 │
│ Options:                                                        │
│   1. [option 1 — business implication]                          │
│   2. [option 2 — business implication]                          │
└─────────────────────────────────────────────────────────────────┘
```

Wait for user response. Then continue.

**IF no business-level contradictions:** Continue directly to Step A2.4.

### Step A2.4: Transparency Report

Present ALL resolved decisions as a declaration (NOT a question):

```
🔧 Design decisions resolved:

  [For each decision:]
  • [decision description] → [resolution]
    Principle: [SRP|KISS|YAGNI|DRY|SOLID] — [one-line reasoning]

  [If business-level issues were resolved by user:]
  • [issue] → [user's choice]
    Source: user clarification
```

**This is informational only.** The agent does NOT ask for approval. The user can see the decisions and intervene if something looks wrong, but the flow does not stop.

Store all resolutions for inclusion in logbook:
```json
{
  "resolved_decisions": [
    {
      "uncertainty": "Where to create ProductDetailDTO",
      "resolution": "Create new file src/dtos/ProductDetailDTO.ts",
      "method": "SRP",
      "reasoning": "Single responsibility, matches existing pattern of one DTO per file"
    }
  ],
  "user_clarifications": [
    {
      "question": "Ticket asks for pagination but blueprint defines single-product detail view",
      "answer": "No pagination, single product only",
      "impact": "Simpler response structure, aligned with blueprint"
    }
  ]
}
```

## Step A2.5: Orthogonality Review (subagent, blocking)

Before generating main objectives, **delegate the decomposition decision to a fresh adversarial subagent**. The main agent at this point is saturated with ticket context, blueprint context, design decisions, and rule analysis — exactly the conditions where it tends to under-decompose ("one primary is enough, let me move on"). A subagent with no accumulated context and an adversarial brief catches this systematically.

### Spawn the subagent

Spawn an Agent with `run_in_background=false` (blocking — the result conditions Step A3) using the model from `agent_config.metacognition_model` in user_pref.json (default: `opus`).

The subagent receives a payload containing:
- The ticket (title, description, ui_requirements)
- The matched blueprint capability/flow/view (if any) including `description`, `is_essential`, `acceptance_criteria`, related `design_principles` and `product_rules`
- The list of rule **categories** present in `project_rules.json` (architecture, presentation_layer, data_layer, api_layer, testing, naming_conventions, infra) — not the rule text itself
- The list of **layers** identified from `project_manifest.json` that the ticket touches
- The reference files identified during initial analysis

The subagent prompt is **adversarial by default**:

```
You are a decomposition critic. Your job is NOT to confirm the main agent's plan — it is to challenge it. Assume the main agent is biased toward single_focus because it is faster and produces less code. Your job is to find arguments for splitting this ticket into multiple orthogonal primary objectives.

A "dimension" is orthogonal when it requires:
  - A distinct mindset to address
  - A distinct subset of project rules to apply
  - A distinct success criterion to verify
  - It does not depend on other dimensions for its definition (only for its execution order)

Common decomposition patterns to evaluate:
  - Frontend UI: structure (which elements exist) → positioning (visual layout, spacing, design system tokens) → behavior (state, actions, side effects). Almost always 3 dimensions.
  - Migration: schema change → data backfill/transformation → cleanup of legacy fields. 3 dimensions.
  - API endpoint: request validation/contract → business logic → response shaping/serialization. Sometimes 3, sometimes 1 if trivial.
  - Refactor: extract pattern → rewire callers → remove dead code. Often 3.

Return single_focus ONLY when you genuinely cannot argue independent dimensions with distinct mindsets. When in doubt, prefer multi_focus — the cost of one extra primary is marginal; the cost of mixing dimensions in one primary is real and shows up as silent rule drift.

Be specific. Cite the matched capability id or name. Cite manifest layers. Cite rule categories. Do NOT recommend dimensions that have no rules backing them in this project.

Return ONLY a JSON object of this shape:

{
  "decision": "multi_focus" | "single_focus",
  "dimensions": [
    {
      "name": "<short label, e.g. 'structure'>",
      "mindset": "<one-line description of the mental stance for this dimension>",
      "rules_categories": ["<category from project_rules.json>"],
      "success_criterion": "<one-line definition of done for this dimension>",
      "independent_of_others": true | false
    }
  ],
  "reasoning": "<2-4 sentences. Why this decision. If single_focus, justify why other dimensions don't apply or are deferred. If multi_focus, justify why mixing them would dilute attention.>",
  "suggested_primaries": [
    {
      "content_draft": "<verifiable outcome for this dimension, ~140 chars max>",
      "scope_files_hint": ["<files this primary will touch — entry points only>"],
      "rules_categories_in_scope": ["<categories from project_rules.json relevant to this primary>"]
    }
  ]
}
```

### Process the subagent response

When the subagent returns:

1. **Persist the decision** in `resolved_decisions` of the logbook with `method: "orthogonality_review"`:

```json
{
  "uncertainty": "Should this ticket decompose into multiple orthogonal primaries?",
  "resolution": "<decision>: <reasoning summary>",
  "method": "orthogonality_review",
  "reasoning": "<full reasoning from the subagent>",
  "dimensions_evaluated": [...],
  "subagent_output": {...}
}
```

2. **If `decision == single_focus`**: proceed to Step A3 normally — generate one main objective. The reasoning is recorded; if it turns out to be wrong later, the audit trail exists.

3. **If `decision == multi_focus`**: Step A3 is constrained. You **must** generate one main objective per dimension declared by the subagent. You may refine the `content`, the `scope.files`, and the `scope.rules` of each — but you cannot collapse two dimensions into one primary. If you genuinely believe the subagent over-decomposed, surface this to the user before proceeding (this is a Level 3 escalation per the trust contract — outside the current objective's autonomy).

### Why this step exists

The same principle that justifies the rules audit subagent (Layer C) applies here: a fresh agent without the accumulated context of `logbook-create` produces less biased decomposition decisions. The cost is +30-60s of latency per logbook creation, paid once per ticket — negligible vs. the cost of a logbook that mixes dimensions and produces drifted code. The decision is recorded in `resolved_decisions` so the trail is auditable.

## Step A3: Generate Main Objectives

Based on ticket, analysis, resolved decisions, **and the orthogonality review from Step A2.5**, generate main objectives:
- If A2.5 returned `single_focus`: generate one main objective.
- If A2.5 returned `multi_focus`: generate one main objective per dimension. The contents must be distinctive and non-overlapping — a reader should be able to tell from `content` alone which dimension each primary attends, without needing a `focus` label. If two contents could be swapped without losing meaning, they are not orthogonal — collapse or re-evaluate.
- Each objective must have: content, context, scope (files + rules)
- Prioritize by dependency order (in multi_focus, typically the order returned by the subagent)
- Include resolved decisions in context
- Apply YAGNI: only objectives that directly satisfy the ticket requirements

**Present objectives as a declaration (NOT asking for approval):**

```
🎯 Main objectives defined:

OBJECTIVE 1:
├─ Content: [verifiable outcome]
├─ Context: [business/technical context + key decisions made]
├─ Reference files:
│  • [file1]
│  • [file2]
└─ Rules: #[id1], #[id2]

[Additional objectives if any]
```

**No approval checkpoint.** The agent proceeds directly to secondary objectives. The user can see the objectives and intervene naturally if something looks wrong, but the flow does not stop.

## Step A4: Generate Secondary Objectives with Completion Guide

For each main objective, perform deep code analysis directly (no subagent delegation):

1. Deep trace from `scope.files`
2. Discover related code, patterns, dependencies
3. Read referenced rules from `project_rules.json` — **load full rule text, not just IDs**
4. Incorporate UI requirements if present
5. Incorporate product context (blueprint capabilities, flows, principles)
6. Generate secondary objectives with `completion_guide`
7. Apply YAGNI to completion_guide: only actionable steps, no speculative items

### Rule injection (mandatory)

For every secondary objective, after writing the implementation steps, **append one `completion_guide` entry per applicable rule** using this exact format:

```
Apply rule #<id>: <full rule description text from project_rules.json>
```

Rationale: rule IDs alone force the implementer to mentally jump to `project_rules.json` on every step — a context switch the agent often skips silently. Having the rule text inline makes the constraint physically visible during implementation. Truncate rules over 200 chars only if absolutely necessary (the schema caps `completion_guide` items at 200 chars); otherwise include verbatim.

The applicable rules for a secondary objective are inherited from its parent main objective's `scope.rules`. If the parent's rules don't all apply to this specific secondary, narrow the list with judgment — but **never silently drop a rule**: if you exclude one, document why in the secondary's preceding step.

**Present secondary objectives as a declaration (NOT asking for approval):**

```
📋 Secondary objectives defined:

For Main Objective 1:
┌─────────────────────────────────────────────────────────────┐
│ 1.1 [Secondary objective content]                           │
│     Guide:                                                  │
│     • [completion_guide item 1: implementation step]        │
│     • [completion_guide item 2: implementation step]        │
│     • Apply rule #3: <rule text>                            │
│     • Apply rule #7: <rule text>                            │
├─────────────────────────────────────────────────────────────┤
│ 1.2 [Secondary objective content]                           │
│     Guide:                                                  │
│     • [completion_guide item 1: implementation step]        │
│     • Apply rule #3: <rule text>                            │
└─────────────────────────────────────────────────────────────┘
```

**No approval checkpoint.** The agent proceeds directly to save the logbook.

Go to **STEP FINAL**

---

# FLOW B: GENERAL PROJECT LOGBOOK

Uses schema: `ai_files/schemas/logbook_general_schema.json`

Key differences from software:
- `scope.files` → `scope.references` (documents, URLs, assets)
- `scope.rules` → `scope.standards` (style guides, regulations, methodologies)
- `completion_guide` references documents/practices instead of code

## Step B1: Gather References and Standards

```
📚 To create effective objectives, I need to know:

What reference materials do you have available?
(Documents, URLs, examples, previous work)

Examples:
• "Chapter 2 already completed in Google Docs"
• "Client brief in PDF"
• "https://competitor.com/landing for inspiration"
```

Store as `references`.

```
Are there standards or guides you must follow?
(Style guides, regulations, methodologies)

Examples:
• "APA 7th edition for citations"
• "Company brand guidelines"
• "ISO 27001 for documentation"
• None specific (Enter to skip)
```

Store as `standards` or empty.

## Step B2: Generate Main Objectives

Based on ticket and references, generate main objectives autonomously:
- Each objective has: content, context, scope (references + standards)
- Focus on deliverables and milestones
- Apply YAGNI: only objectives that directly satisfy the task requirements

**Present objectives as a declaration (NOT asking for approval):**

```
🎯 Main objectives defined:

OBJECTIVE 1:
├─ Content: [verifiable outcome]
├─ Context: [why this is needed]
├─ References:
│  • [reference1]
│  • [reference2]
└─ Standards: [applicable standards]
```

**No approval checkpoint.** The agent proceeds directly to secondary objectives.

## Step B3: Generate Secondary Objectives

Generate secondary objectives autonomously:
- Break down main objectives into actionable steps
- `completion_guide` references documents, examples, standards

**Present secondary objectives as a declaration (NOT asking for approval):**

```
📋 Secondary objectives defined:

For Main Objective 1:
┌─────────────────────────────────────────────────────────────┐
│ 1.1 [Secondary objective content]                           │
│     Guide:                                                  │
│     • [reference to document/section]                       │
│     • [standard to apply]                                   │
│     • [example to follow]                                   │
├─────────────────────────────────────────────────────────────┤
│ 1.2 [Secondary objective content]                           │
│     Guide:                                                  │
│     • [completion guide items]                              │
└─────────────────────────────────────────────────────────────┘
```

**No approval checkpoint.** The agent proceeds directly to save the logbook.

Go to **STEP FINAL**

---

# STEP FINAL: Generate and Save Logbook

## Ask for Filename (if not provided)

IF filename not provided earlier:
```
📁 What name do you want for the logbook?
(Example: TICKET-123.json, feature-auth.json)
```

Validate filename format.

## Generate Logbook JSON

Create logbook structure:

```json
{
  "ticket": {
    "title": "[from user input]",
    "url": "[from user input or null]",
    "description": "[from user input]",
    "ui_requirements": {
      "has_ui": true|false,
      "visual_references": ["paths if any"],
      "notes": "[UI analysis summary]"
    }
  },
  "objectives": {
    "main": [
      {
        "id": 1,
        "created_at": "[UTC ISO 8601]",
        "content": "[approved content]",
        "context": "[approved context]",
        "scope": {
          "files": ["[files array]"],
          "rules": [1, 2, 3]
        },
        "status": "not_started"
      }
    ],
    "secondary": [
      {
        "id": 1,
        "created_at": "[UTC ISO 8601]",
        "content": "[approved content]",
        "completion_guide": ["[guide items]"],
        "status": "not_started"
      }
    ]
  },
  "resolved_decisions": [
    {
      "uncertainty": "[what was unclear]",
      "resolution": "[what was decided]",
      "method": "YAGNI|SOLID|user_clarification",
      "reasoning": "[why]"
    }
  ],
  "recent_context": [
    {
      "id": 1,
      "created_at": "[UTC ISO 8601]",
      "content": "Logbook created. Main objectives: [count]. Secondary objectives: [count]. Decisions resolved: [count]. Ready to start implementation."
    }
  ],
  "history_summary": [],
  "future_reminders": [],
  "audit": {
    "is_already_audited": false
  }
}
```

The `audit` object is required by the schema. Initialize it with `is_already_audited: false` at creation; Step A6 (post-persist integrity audit) will flip this to `true` and add `audit_file` after the integrity reviewer subagent runs.

## Validate Against Schema

Validate against appropriate schema:
- Software: `ai_files/schemas/logbook_software_schema.json`
- General: `ai_files/schemas/logbook_general_schema.json`

## Save File

Save to `ai_files/waves/[target_wave]/logbooks/[filename].json`

Ensure `ai_files/waves/[target_wave]/logbooks/` directory exists, create if needed.

## Step A6: Post-persist Integrity Audit (subagent, blocking)

Once the logbook is persisted, **delegate an integrity audit to a fresh adversarial subagent** that reads the persisted file from disk (not memory). The main agent has just finished a long generation flow and is biased toward "done, move on." A fresh subagent reads the artifact as-is and surfaces the omissions you would miss.

### Spawn the subagent

Spawn an Agent with `run_in_background=false` (blocking — the result determines whether fixes need to be applied before declaring the logbook ready) using the model from `agent_config.metacognition_model` in user_pref.json (default: `opus`).

Pass these inputs as paths (not content) so the subagent reads from disk:
- The persisted logbook path: `ai_files/waves/[target_wave]/logbooks/[filename].json`
- `ai_files/project_rules.json` (or equivalent rules file)
- `ai_files/project_manifest.json` (for layer detection)
- The blueprint path if it exists (`ai_files/blueprint.json`, `ai_files/product_blueprint.json`, etc.)

The subagent writes its output to `ai_files/waves/[target_wave]/audits/logbook-[basename].json` (create the audits directory if missing). The path follows the same convention as the rules audit hook (Layer C).

### Adversarial subagent prompt

```
You are a logbook integrity reviewer. Your job is NOT to validate that the logbook looks good — it is to assume it is wrong and find where. The main agent that produced this logbook just finished a long generation flow and is biased toward "done, persist, move on." Your job is to find the omissions a future implementer would not detect until the damage is done.

Read these files from disk:
- Logbook: <path>
- Project rules: <path>
- Project manifest: <path>
- Blueprint (if present): <path>

Be especially strict with these patterns:

1. missing_rules_in_primary — A primary touches a layer (per the manifest) whose category in project_rules.json contains rules, yet scope.rules is empty or missing those rules. Example: primary touches 'lib/widgets/' (presentation per manifest), project_rules has rules in 'presentation_layer' category, but scope.rules=[]. There is NO excuse for this — flag it as critical.

2. completion_guide_missing_apply_rule_lines — A secondary's parent primary has scope.rules=[3,7,12], but the secondary's completion_guide does not include lines like 'Apply rule #3: ...', 'Apply rule #7: ...', 'Apply rule #12: ...'. This is the silent failure mode of Layer A. Flag every occurrence as critical.

3. rule_id_not_found — scope.rules references a rule id that does not exist in project_rules.json. Critical (broken reference).

4. decomposition_mismatch — resolved_decisions contains an orthogonality_review with decision='multi_focus' but the logbook has only 1 main objective, OR decision='single_focus' but there are 2+ main objectives. Critical.

5. duplicate_primary_content — Two primaries with semantically equivalent content. If 'Build login form' and 'Style login form' are both primaries, they are not orthogonal — they are the same task with different verbs. Critical.

6. primary_empty_scope_files — A primary that is supposed to implement something but scope.files=[]. Critical.

7. secondary_missing_completion_guide — A secondary without completion_guide or with completion_guide=[]. Critical (schema violation).

8. scope_files_path_not_found — scope.files references a path that does not exist in the working tree and is not marked '(new)'. Warning (could be intentional if the file is about to be created, but should be flagged).

9. completion_guide_too_generic — completion_guide entries that don't cite file:line or a concrete pattern, just generic advice ('apply best practices', 'handle errors'). Warning.

10. orphan_secondary — A secondary whose content does not contribute to any specific primary's outcome. Warning.

Only flag items you can justify with structural citation: primary id, secondary id, file path, rule id. No speculation. If you cannot cite, downgrade to warning or omit.

Severity rules:
- critical: omission that will cause the implementer to write drifted code or fail.
- warning: imperfection that the agent should review but may be intentional.
- DO NOT use any other severity. If something doesn't reach 'warning', omit it.

Output JSON to <audit file path> in this exact shape:

{
  "logbook_path": "<absolute path of the audited logbook>",
  "audited_at": "<UTC ISO 8601>",
  "model": "<model name>",
  "summary": { "critical": <int>, "warning": <int> },
  "findings": [
    {
      "id": <int starting at 1>,
      "severity": "critical" | "warning",
      "category": "<one of the categories above>",
      "location": { "primary_id": <int or null>, "secondary_id": <int or null> },
      "message": "<one-paragraph explanation citing the structural elements>",
      "suggested_action": "<a textual suggestion for what to correct. Do NOT prescribe exact JSON edits — the main agent has the full context and will decide how to apply.>"
    }
  ]
}

If summary.critical == 0 && summary.warning == 0, the logbook passed clean — emit findings: [] and the main agent will know.

Write ONLY the JSON file. No prose, no commentary outside the file.
```

### Process the subagent response

After the subagent finishes:

1. Read the audit file at `ai_files/waves/[target_wave]/audits/logbook-[basename].json`.
2. Update the logbook's `audit` object:
   - Set `audit.is_already_audited = true`.
   - Set `audit.audit_file = "<relative path to the audit JSON>"`.
   - Save the logbook (Edit tool, atomic write).
3. Process findings:
   - **For each critical finding**: review the message and suggested_action. Apply the correction by editing the logbook with the full context you have (rules text, manifest layers, blueprint capability, secondaries you generated). Decisions are level 1-2 of the Waves trust contract — proceed without user approval. If a critical finding is genuinely incorrect (false positive after your review), record the rejection in `resolved_decisions` with `method: "integrity_audit_override"` and a reasoning paragraph.
   - **For each warning finding**: decide whether to apply. If you apply, do so. If you don't, no action needed (warnings are not blocking).
4. After applying any fixes, append a new entry to the logbook's `recent_context` summarizing what was applied:
   ```
   "Integrity audit applied: [N] critical findings addressed, [M] warnings reviewed ([X] applied, [Y] noted). Audit report: ai_files/waves/[target_wave]/audits/logbook-[basename].json"
   ```

### Display the audit summary

```
🔍 Integrity audit complete:

  Critical: [N]
  Warning: [M]

  [If N==0 && M==0:]
  ✅ Logbook passed clean.

  [If N>0 || M>0:]
  Findings applied:
    [For each finding the agent applied:]
    [severity icon] #[id] [category] — [one-line summary of the fix]
  Findings noted (not applied):
    [For each finding the agent decided to leave:]
    [severity icon] #[id] [category] — [one-line reason]

  📁 Full audit report: ai_files/waves/[target_wave]/audits/logbook-[basename].json
```

### Why Step A6 lives post-persist

The audit reads the logbook from disk so it can be re-run later (logbook-update, manual re-audit) without re-implementing the same logic in three commands. The audit file is a persistent artifact alongside the logbook — anyone reading the logbook months later can see whether it was audited and consult the report. This separation also keeps the main agent's context light during the audit: the subagent reads files, the main agent doesn't have to keep them all in memory.

## Success Message

```
✅ Logbook created successfully!

📁 File: ai_files/waves/[target_wave]/logbooks/[filename].json

📊 Summary:
• Ticket: [title]
• Main objectives: [count]
• Secondary objectives: [count]
• Decisions resolved: [count] (YAGNI: X, SOLID: Y, Clarified: Z)
[• UI requirements: included (if applicable)]

🎯 First objective to work on:
[First secondary objective content]

Guide:
[completion_guide items]

💡 Useful commands:
• /waves:implement [filename] - Implement with auto-auditing
• /waves:logbook-update [filename] - Update progress manually
• /waves:resolution-create [filename] - Generate resolution when done

Ready to start!
```

---

## Status Icons Reference

| Icon | Status | Meaning |
|------|--------|---------|
| ⚪ | not_started | Pending, not yet begun |
| 🟡 | active | Currently in progress |
| 🔴 | blocked | Waiting on external input/dependency |
| 🟢 | achieved | Completed successfully |
| ⚫ | abandoned | Cancelled, no longer needed |

---

## Autonomous Design Resolution Summary

```
┌─────────────────────────────────────────────────────────────────┐
│              AUTONOMOUS DESIGN RESOLUTION FLOW                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. DETECT: Identify all design decisions needed                │
│       ↓                                                         │
│  2. RESOLVE: Apply unified principles (SRP+KISS+YAGNI+DRY+     │
│     SOLID) — agent resolves autonomously                        │
│       ↓                                                         │
│  3. ESCALATION GATE: Check for business-level contradictions    │
│     • Ticket vs blueprint conflicts                             │
│     • Mutually exclusive acceptance criteria                    │
│     • Fundamental scope ambiguity (WHAT, not HOW)               │
│     • Conflicting product rules affecting user behavior         │
│     IF found → Ask user (ONLY these)                            │
│     IF not → Continue without stopping                          │
│       ↓                                                         │
│  4. TRANSPARENCY REPORT: Declare all decisions made             │
│     (informational, NOT asking for approval)                    │
│       ↓                                                         │
│  5. OBJECTIVES: Generate main + secondary autonomously          │
│     (declared, NOT asking for approval)                         │
│       ↓                                                         │
│  6. SAVE: Generate and save logbook                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Subagents Reference

This command does NOT use subagents. All steps (code tracing, design resolution, objective generation, completion guide creation) are executed directly by the main agent to preserve full context and ensure consistency in design decisions.

END OF COMMAND
