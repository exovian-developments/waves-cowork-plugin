---
description: Create a new development logbook for a ticket/task with structured objectives, autonomous design resolution, code tracing, UI detection, and actionable completion guides.
---

# Command: /waves:logbook-create

> **Artifacts directory:** `waves_files/` is the canonical Waves artifacts directory (v3.1+). On an unmigrated project — no `waves_files/` but `ai_files/` exists — read every `waves_files/` path in this command as `ai_files/`, and suggest running `/waves:upgrade` once.

You are executing the waves logbook creation command. Follow these instructions exactly.

## Multi-project scope

Apply the **Multi-project Path Resolution** helper from `plugin/skills/waves-protocol/SKILL.md` before any other step:

- Parse `--project <name>` from the command arguments.
- If present: set `base_path = projects/<name>/waves_files/` and validate that projects/<name>/ exists (abort with a "scope not found" error if it does not).
- If absent: set `base_path = waves_files/` (backwards-compatible default — identical to pre-3.x single-project behavior).

Use `base_path` for every `waves_files/...` reference in the steps below. When the steps say `waves_files/<artifact>` they mean `<base_path><artifact>` in multi-project mode.

When `--project` is present, also write the **session marker** via bash BEFORE any artifact operation — this is what makes the active scope visible to hooks (`plugin/hooks/_lib/scope-resolve.sh`) when they fire on subsequent Edit/Write:

```bash
mkdir -p "${CLAUDE_PLUGIN_DATA}/markers/${CLAUDE_SESSION_ID:-default}"
printf '%s=%s\n' "$(printf '%s' "$PWD" | { md5 -q 2>/dev/null || md5sum | awk '{print $1}'; })" "<scope_name>" \
  > "${CLAUDE_PLUGIN_DATA}/markers/${CLAUDE_SESSION_ID:-default}/active-scope"
```

Idempotent (overwrite-safe). The marker maps `<cwd_md5>=<scope_name>` so a session that traverses multiple cwds keeps one line per cwd. When `--project` is absent, **do not write** the marker — hooks fall back to root naturally.

## Your Role

You are the main orchestrator for logbook creation. You will gather task information, detect UI requirements, analyze related code, resolve ALL design decisions autonomously using SRP/KISS/YAGNI/DRY/SOLID principles, and create a structured logbook with main and secondary objectives.

**Autonomy principle:** You are trusted to make high-quality design decisions when you have clear business context (blueprint, ticket description, project rules) and established architecture. You only escalate to the user when detecting business-level contradictions that design principles cannot resolve.

## Step -1: Prerequisites Check (CRITICAL)

**Multi-project note (root-only validation):** prerequisite artifacts (`user_pref.json`, `project_manifest.json`, `project_rules.json`, plus any required blueprint/roadmap) are validated at root (`waves_files/<artifact>`) regardless of whether the `--project <name>` flag is set. Scopes inherit root prerequisites. If a root prerequisite is missing in multi-project mode, abort with a message pointing to root setup (e.g., "Run /waves:project-init at root first — multi-project scopes inherit root prerequisites.") — NEVER to a per-scope path. The `base_path` from the Multi-project scope helper applies to WORK artifacts (logbooks, scoped rules/manifest/blueprint), not to prerequisite existence checks.

Check if `waves_files/user_pref.json` exists.

IF NOT EXISTS:
```
⚠️ Missing configuration!

Please run first:
/waves:project-init

This command requires user preferences to be configured.
```
→ EXIT COMMAND

IF EXISTS:
1. Read `waves_files/user_pref.json`
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

1. List `waves_files/waves/*/roadmap.json` to find all waves with roadmaps
2. Read each roadmap — find which has status "active" or "in_progress"
3. If only ONE wave is active → use that wave automatically
4. If the user provided context (ticket description, milestone name) that matches a specific milestone in a roadmap → use that wave
5. Only ask the user if genuinely ambiguous (multiple active waves, no clear match)
6. Store as `target_wave`
7. Create directory `waves_files/waves/[target_wave]/logbooks/` if it doesn't exist

## Step 1: Check Existing Logbook

Check if the logbook already exists, in EITHER layout (directory-per-logbook convention + transition tolerance): the new directory layout `waves_files/waves/[target_wave]/logbooks/[slug]/logbook.json` OR the old flat layout `waves_files/waves/[target_wave]/logbooks/[filename].json` (where `[slug]` is `[filename]` without `.json`). If either is found, treat the logbook as existing.

IF EXISTS:
```
⚠️ A logbook with that name already exists!

File: waves_files/waves/[target_wave]/logbooks/[filename].json

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

Uses schema: `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/logbook_software_schema.json`

## Step A1: Initial Code Tracing

```
🔍 Analyzing project to identify related code...
```

1. **Read project manifest:**
   - Load `waves_files/project_manifest.json`
   - Identify relevant layers from `architecture_patterns_by_layer`
   - Identify relevant features from `features`
   - Note entry points and tech stack

2. **Trace related code:**
   - Search for files, classes, functions related to the ticket
   - Identify patterns and conventions in related code
   - Note dependencies between components

3. **Load project rules (if exists):**
   - Read `waves_files/project_rules.json`
   - Identify rules that apply to identified layers/features
   - Note rule IDs for `scope.rules`

4. **Resolve blueprint chain + extract governance context (CRITICAL — replaces vague "read blueprint" with deterministic chain walk + targeted jq queries).**

   The goal: load ONLY the blueprint subset that impacts this logbook's business direction, then embed it in the logbook as `governance_context` (schema field). This subset is reprinted at implementation time by `objectives-implement` Step 5 Governance banner — same pattern as project_rules.json injection. Avoids loading full blueprints (typically 50-100KB each) into agent context.

   **Step 4a — Walk the blueprint chain (parent_blueprint refs, cycle-protected).**

   ```
   chain = []
   visited = {}
   current = base_path/blueprint.json  (or product_blueprint.json if that's the convention used)
   
   loop:
     if current path already in visited → break (cycle protection per Phase 1 w5 sandbox)
     if file does not exist → break
     visited.add(current)
     
     bp_type = jq -r '.meta.blueprint_type // "standard"' $current
     # Level inference (deterministic, single rule):
     #   - bp_type == "company" → level = "company"   (independent of position)
     #   - bp_type != "company" AND path starts with "projects/<X>/" → level = "scope"
     #   - bp_type != "company" AND path is base waves_files/blueprint.json (no projects/ prefix) → level = "product"
     # This requires company_blueprint.json to declare meta.blueprint_type="company" (now enforced in schemas).
     # Scope vs product distinction comes from PATH, not chain position — handles arbitrary chain depth correctly.
     if bp_type == "company": level = "company"
     elif path matches "projects/<X>/...": level = "scope"
     else: level = "product"
     chain.append({level, path: current, blueprint_type: bp_type})
     
     parent = jq -r '.parent_blueprint // empty' $current
     if parent set → current = resolve relative path → loop
     else → break
   
   # Append company_blueprint if present at conventional location and not already in chain
   if [ -f "../company_blueprint.json" ] OR similar discovery → append {level: "company", path, blueprint_type: "company"}
   ```

   For single-project mode with no parent_blueprint, chain has 1 entry. For multi-project scope with parent ref, typically 2. With company_blueprint, 3.

   **Step 4b — Extract ticket keywords for matching.**

   Build `TICKET_KEYWORDS` from ticket.title + ticket.description: extract nouns/proper nouns/distinctive terms (3-8 keywords). These drive the `test(...)` jq filters in Step 4c.

   **Step 4c — For each blueprint in chain, run targeted jq queries (deterministic, no LLM filter).**

   ```bash
   BP=<path>; LEVEL=<scope|product|company>
   
   # Matched capabilities (HIGH priority)
   jq --arg kw "$TICKET_KEYWORDS_REGEX" --arg lvl "$LEVEL" '
     ((.essential_capabilities // []) | map(. + {level: $lvl, is_essential: true}))
     + ((.non_essential_capabilities.important // []) | map(. + {level: $lvl, is_essential: false}))
     + ((.non_essential_capabilities.desired // []) | map(. + {level: $lvl, is_essential: false}))
     | map(select(.capability | test($kw; "i")))
     | map({level, id, capability, is_essential, acceptance_criteria: (.acceptance_criteria // [])})
   ' $BP
   
   # Collect matched capability IDs for downstream filters
   MATCHED_CAP_IDS=$(...| jq '[.[].id]')
   
   # Related flows (HIGH priority): capability_refs intersects matched IDs
   jq --argjson ids "$MATCHED_CAP_IDS" --arg lvl "$LEVEL" '
     (
       ((.essential_flows_and_views.user_flows // []) | map(. + {level: $lvl, type: "user_flow"}))
       + ((.essential_flows_and_views.system_flows // []) | map(. + {level: $lvl, type: "system_flow"}))
       + ((.essential_flows_and_views.views // []) | map(. + {level: $lvl, type: "view"}))
       + ((.secondary_flows_and_views.user_flows // []) | map(. + {level: $lvl, type: "user_flow"}))
       + ((.secondary_flows_and_views.system_flows // []) | map(. + {level: $lvl, type: "system_flow"}))
       + ((.secondary_flows_and_views.views // []) | map(. + {level: $lvl, type: "view"}))
     )
     | map(select((.capability_refs // []) | any(. as $r | $ids | index($r))))
     | map({level, type, id, name, entry_point: (.entry_point // ""), termination: (.termination // "")})
   ' $BP
   
   # Governing design principles (HIGH priority): principles that generated product_rules whose applies_to references matched capabilities.
   # Single-pass jq (no $BP $BP pipe hack):
   jq --argjson matched "$MATCHED_CAP_IDS" --arg lvl "$LEVEL" '
     . as $root
     | (.product_rules // [])
       | map(select((.applies_to // "") | test(($matched | map(tostring) | join("|")); "i")))
       | [.[].principle_refs[]?] | unique
       | map(. as $pid | $root.design_principles[]? | select(.id == $pid))
       | map({level: $lvl, id, principle})
   ' $BP
   
   # Applicable product rules (HIGH priority)
   jq --argjson matched "$MATCHED_CAP_IDS" --arg lvl "$LEVEL" '
     (.product_rules // [])
     | map(select((.applies_to // "") | test(($matched | map(tostring) | join("|")); "i")))
     | map({level: $lvl, id, rule, applies_to})
   ' $BP
   
   # Out of scope reminders (HIGH priority): out_of_scope items whose statement overlaps with ticket keywords
   jq --arg kw "$TICKET_KEYWORDS_REGEX" --arg lvl "$LEVEL" '
     (.out_of_scope // [])
     | map(select(.statement | test($kw; "i")))
     | map({level: $lvl, id, statement})
   ' $BP
   
   # Relevant product decisions (MEDIUM priority): impact_on references matched capabilities OR decision text matches ticket keywords
   jq --argjson matched "$MATCHED_CAP_IDS" --arg kw "$TICKET_KEYWORDS_REGEX" --arg lvl "$LEVEL" '
     (.product_decisions // [])
     | map(select(
         ((.impact_on // "") | test(($matched | map(tostring) | join("|")); "i"))
         or ((.decision // "") | test($kw; "i"))
       ))
     | map({level: $lvl, id, decision, impact_on})
   ' $BP
   
   # Success metrics tied to matched capabilities (MEDIUM priority).
   # success_metrics rarely cross-reference capability IDs structurally (schema has no capability_refs on this field).
   # Heuristic: include metrics whose `metric` text mentions any keyword from TICKET_KEYWORDS_REGEX.
   # If keyword match yields zero, include first 2 metrics as fallback (some signal > none, agent decides relevance).
   jq --arg kw "$TICKET_KEYWORDS_REGEX" --arg lvl "$LEVEL" '
     (.success_metrics // []) as $all
     | ($all | map(select((.metric // "") | test($kw; "i")))) as $matched
     | (if ($matched | length) > 0 then $matched else $all[:2] end)
     | map({level: $lvl, id, metric, success_signal})
   ' $BP
   
   # Autonomous entity identity (HIGH priority IF blueprint_type=autonomous_entity)
   jq --arg lvl "$LEVEL" '
     if .meta.blueprint_type == "autonomous_entity" and (.autonomous_entity_identity // null) != null then
       .autonomous_entity_identity + {level: $lvl}
     else null end
   ' $BP
   ```

   Aggregate results across all blueprints in chain into a single `governance_context` object matching the schema shape. Each entry carries `level` field for traceability.

   **Step 4d — Search for other product-level context files** (these are AUXILIARY — not embedded into governance_context but kept in working memory for the rest of A1):

   - Search for `waves_files/technical_guide.md` → IF EXISTS: Read and extract relevant technical guidelines, architecture decisions, and implementation patterns
   - Search for `waves_files/feasibility.json` → IF EXISTS: Read and extract relevant revenue model context, buyer personas, and essential capabilities
   - Search for roadmap files: `waves_files/waves/*/roadmap.json` → IF ANY EXIST: Read and extract current phase, milestones, and relevant decisions. If multiple roadmaps found, prioritize the one for the target wave or the one most relevant to the ticket.

   **For each file found:** Extract only the sections relevant to the ticket description. Store as `product_context` (working memory only — NOT embedded into the persisted logbook).

   **For each file NOT found:** Note in a list but DO NOT stop or error. Continue normally.

   **Why governance_context is embedded but product_context is not:** governance_context drives implementation alignment (`objectives-implement` consumes it via banner). product_context is one-shot enrichment for objective generation in this logbook-create session only — once the logbook is written, the relevant info has already shaped the objectives.

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

When the subagent returns, run a fresh skeptical verifier (B) BEFORE acting on A's decision. This is the A→B verifier pattern (blueprint design_principle #7 / product_rule #9): A proposes, B verifies with two lenses and classifies (it does NOT veto), and you decide with both in context.

1. **Verify with verifier B (adversarial, blocking).** Spawn a SECOND blocking Agent (same model as A). B has minimal context by design — pass it ONLY A's full JSON output and this prompt EXACTLY:

   ---
   You are an independent, skeptical verifier with MINIMAL context by design. Analyst A proposed the decomposition below for a ticket. Verify and classify each proposed dimension — do NOT expand it, do NOT filter it out.

   A's decomposition:
   <<< PASTE A's FULL JSON OUTPUT HERE >>>

   Apply TWO lenses:
   1) TECHNICAL — read this project's project_rules.json and project_manifest.json. Does each proposed dimension have real rules backing (a category that actually contains rules) and do the cited manifest layers exist? A dimension with no rules behind it is not a real orthogonal axis. Cite the rule category / layer you checked.
   2) VALUE — over- or under-decomposition? Apply KISS/YAGNI. Would mixing these dimensions in one primary actually cause rule drift (justifies the split), or are they the same task with different verbs (smoke)?

   Classify the OVERALL decision AND each dimension as exactly one of: confirmed / smoke / unverifiable / gold. Do NOT drop any dimension. Output a compact list: item → class → one-line reason citing the rule category or file you checked. Under 250 words.
   ---

   B classifies, it does NOT veto.

2. **Persist the decision (A + B)** in `resolved_decisions` of the logbook with `method: "orthogonality_review"`:

```json
{
  "uncertainty": "Should this ticket decompose into multiple orthogonal primaries?",
  "resolution": "<decision>: <reasoning summary>",
  "method": "orthogonality_review",
  "reasoning": "<full reasoning from the subagent>",
  "dimensions_evaluated": [...],
  "subagent_output": {...},
  "verifier_classification": {...}
}
```

3. **Decide with BOTH A and B in context:**
   - **If `decision == single_focus`**: proceed to Step A3 normally — generate one main objective. The reasoning is recorded; if it turns out to be wrong later, the audit trail exists.
   - **If `decision == multi_focus`**: Step A3 is constrained. You **must** generate one main objective per dimension declared by the subagent. You may refine the `content`, the `scope.files`, and the `scope.rules` of each — but you cannot collapse two dimensions into one primary.
   - **Respect B's classification:** a dimension B marked `smoke` (no rules backing, or same task with different verbs) → re-evaluate and consider collapsing it. `unverifiable` → use your own judgment. `confirmed`/`gold` → safe. If you genuinely believe the decomposition is wrong (A over-decomposed, or B flagged a dimension as smoke that you agree is spurious), surface this to the user before proceeding (Level 3 escalation per the trust contract — outside the current objective's autonomy).

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

### Hard layer: `function_signatures` + `test_cases` (mandatory for code-touching secondaries)

A `completion_guide` describes *how to do the work*; it does not make the agent confront the real API surface or the edge cases the new code must survive. The hard layer does — it is the design-time defense against relational runtime bugs (design_principle #10, product_rule #10). For **every secondary that creates or modifies code**, populate both fields:

1. **`function_signatures`** — the real signatures this secondary creates/modifies, with concrete types. No `any`/`dynamic`/`Object?`/`interface{}`. Generics are allowed but **must carry explicit type-parameter bounds**; if a bound is genuinely unavoidable, justify it in the secondary's `content`. Read the actual sibling code to get the real types — do not guess.

2. **`test_cases`** — the behavioral scenarios this secondary must satisfy, as a DESIGN SPEC (no verdict; the primary's `verification_demonstrations` prove them by reference — enumerate once, prove once, per product_rule #10). Enumerate:
   - **happy paths** (`edge_case: false`) — the normal expected behavior.
   - **edge cases** (`edge_case: true`) — every boundary, concurrency, error-recovery, or cross-handler interaction. To find them, **read the sibling handlers/functions in the same file/module** and ask: what invariant do they enforce that this new code must also preserve? (e.g. a sibling that calls `toIdle()` on error, or respects a lockout during a probe, or trims input — the new code must too.)
   - For a generic signature, include **one `edge_case: true` row per concrete instantiation that matters** — a generic's correctness lives in its instantiations.

**HARD RULE (forcing function — blocks the logbook):** a secondary is **not ready** if any `test_cases` row with `edge_case: true` has an **empty `expected`**. Filling that `expected` is what forces the agent to read the sibling code and learn the invariant. Do not persist the logbook with an unresolved edge case; resolve it (fill `expected` from real code) or, if it genuinely does not apply, remove the row with a one-line note in the secondary's preceding `completion_guide` step.

**A secondary touching shared state, async, or sibling handlers with ZERO `edge_case: true` rows is SUSPECT** — re-examine before persisting.

**Backwards-compat / scope:** both fields are OPTIONAL at the schema level. **Omit both** for doc-only, config-only, or greenfield secondaries that introduce no callable API surface. Pre-3.x logbooks without these fields remain valid.

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

For any secondary that declared the hard layer, list it under that secondary so the design is visible: the `function_signatures` (one per line) and the `test_cases` as `name → expected [edge]`, marking edge cases. Surfacing the edge cases here is what lets the user catch a missing invariant before any code is written.

**No approval checkpoint.** The agent proceeds directly to Step A4.5 (verification design).

Go to **Step A4.5**

---

# FLOW B: GENERAL PROJECT LOGBOOK

Uses schema: `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/logbook_general_schema.json`

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

**No approval checkpoint.** The agent proceeds directly to Step A4.5 (verification design).

Go to **Step A4.5**

---

## Step A4.5: Verification-designer (subagent, blocking)

After Step A4 (Flow A) or B3 (Flow B) generates secondary objectives, **delegate verification_demonstrations design to a fresh adversarial subagent**. The main agent has just finished decomposition + secondary generation and is biased toward "good enough — persist". A fresh subagent with no accumulated context proposes type-aware demonstrations per primary based purely on what each primary declares it will produce.

This step aterriza design_principle #8 (Demonstration over declaration) and applies to **both Flow A (software/agentic) and Flow B (general)** because the `verification_demonstrations` field exists on both `logbook_software_schema.json` and `logbook_general_schema.json` (Phase 1 w4).

### Spawn the subagent

Spawn an Agent with `run_in_background=false` (blocking — A4.7 verifier B consumes its output) using the model from `agent_config.metacognition_model` in user_pref.json (default: `opus`).

**Inputs (per primary, batch all primaries in a single dispatch):**
- Primary content + `scope.files` (or `scope.references` in Flow B) + `acceptance_criteria` extracted from the matched blueprint capability/flow (if any)
- `project_type` (software / agentic / general)
- The closed enum of 10 verification types from the schema (unit_test, integration_test, sandbox_execution, schema_validation, behavior_check, release_verification, state_change_verification, external_observation, documentation_consistency, adversarial_review)

### Verification-designer subagent prompt

```
You are a verification-designer with MINIMAL context by design. Another agent just generated primary objectives for a logbook. Your job is to propose verification_demonstrations per primary — observable executable evidence that will prove the primary outcome was achieved.

Project type: <software | agentic | general>

For each primary, you receive:
  - content: <verifiable outcome statement>
  - scope.files (Flow A) or scope.references (Flow B): <array of paths/refs>
  - acceptance_criteria: <ACs from blueprint matched capability, or "none extracted">

Type taxonomy (closed enum):
  - unit_test, integration_test — Software code-level
  - sandbox_execution — execute artifact in sandbox + observe output
  - schema_validation — validate JSON against schema
  - behavior_check — runtime branching / output structure
  - release_verification — public artifact (tag, release) observable externally
  - state_change_verification — file/config/db delta observable via grep/diff
  - external_observation — third-party API or visible artifact (curl, gh api)
  - documentation_consistency — docs match reality (grep for keywords)
  - adversarial_review — fresh-subagent critique

Pattern matching by extension (documented in $comment of logbook_software_schema.json):
  - .dart, .ts, .py → unit_test + integration_test
  - .json schemas → schema_validation + sandbox_execution
  - .md commands/skills → sandbox_execution + behavior_check
  - .sh hooks → sandbox_execution + behavior_check
  - tag/release keywords in content → release_verification
  - settings/config changes → state_change_verification
  - Cross-cutting (docs alignment) → documentation_consistency
  - Adversarial subagent work → adversarial_review

Constraints (CRITICAL):
  - Each demonstration MUST be observable and executable (not aspirational).
  - target must be a concrete artifact (file path, function name, URL, command).
  - expected must describe an observable outcome (exit code, grep match, HTTP status).
  - command_or_method must be a runnable command (or "Manual: <reviewer/role>" for human verification).
  - At least 1 demonstration per primary. Prefer 2-3 for primaries with multiple acceptance criteria.
  - Demonstrations MUST cover the acceptance_criteria when present. Map each AC to at least one demonstration.
  - INTEGRATION / WIRING objectives (a primary that connects component A into B — wiring a sub-model into a parent, registering a handler, mounting a route, attaching a sub-state machine): the demonstration MUST assert the integration is REACHED AND ACTIVE AT RUNTIME — a test that drives the system to the integration point and asserts the wired component is instantiated AND exercised (its state advances, its output appears, its effect is observable). It is NOT sufficient to assert that the wiring code compiles, that existing tests still pass, or that "no regression occurred": an inert or nil wire satisfies all of those while doing nothing (this is the exact failure mode that let a dormant sub-state ship as "achieved" — see product_decision #22). State the runtime assertion explicitly in `expected`.

Return ONLY a JSON object of this exact shape (no prose):
{
  "designs": [
    {
      "primary_id": <int>,
      "demonstrations": [
        {
          "type": "<one of the 10 enum values>",
          "target": "<concrete artifact ≤200 chars>",
          "expected": "<observable outcome ≤300 chars>",
          "command_or_method": "<runnable command ≤300 chars>",
          "rationale": "<one line: why this type for this primary>"
        }
      ]
    }
  ]
}
```

Receive `designer_response` and proceed to Step A4.7 (verifier B). If the subagent fails (non-JSON or errors), record a warning and proceed treating it as `designs: []` per primary — the integrity audit at Step A6 will flag missing demonstrations.

## Step A4.7: Verifier B on A4.5 (inline, second fresh subagent)

A4.5 is an LLM-judgment subagent — per design_principle #7 / product_rule #9, it requires a paired verifier B. B applies a double lens (technical + value) and classifies each demonstration as `confirmed | smoke | unverifiable | gold` without vetoing. The main agent receives BOTH A4.5 raw output and B classifications.

### Spawn the verifier subagent

Spawn an Agent with `run_in_background=false`. Inline pattern per blueprint decision #14 — no materialized agent file.

**Inputs (minimal):**
- A4.5's raw `designer_response` JSON (verbatim)
- The corresponding primary content + scope.files/references + acceptance_criteria (per primary, B re-reads what A4.5 saw)

### Verifier B prompt

```
You are a verifier B with MINIMAL context by design. A verification-designer (A4.5) just proposed demonstrations for each primary in a logbook. Your job is NOT to confirm — it is to CLASSIFY each proposed demonstration using two lenses, and never veto. The main agent will decide with both raw A4.5 output and your classification.

A4.5's raw output (verbatim):
<designer_response JSON>

For each primary, you also receive:
  - content
  - scope.files (or scope.references)
  - acceptance_criteria

For EACH demonstration in EACH primary, apply BOTH lenses:

LENS 1 — Technical (evidence-based):
  Does target reference an artifact that exists or will exist in scope.files?
  Does command_or_method look executable (not "TBD" or "manually verify")?
  Does the type match the artifact (e.g. .json schema → schema_validation, not unit_test)?

LENS 2 — Value (KISS / overengineering / coverage):
  Does the demonstration actually cover an acceptance_criterion? If no ACs were extracted, does it cover the primary's content statement?
  Is the demonstration aspirational ("should work") or concrete (exit code, grep match)?
  Is the type appropriate or over-engineered for the primary (e.g. release_verification on a refactor primary)?
  For an INTEGRATION / WIRING primary (connects component A into B): does the demonstration assert the integration is REACHED AND ACTIVE at runtime, or does it only check compilation / "existing tests still pass" / non-regression? The latter is a FALSE-CONFIDENCE demonstration — an inert or nil wire passes it while doing nothing — classify it `smoke` and say so in the rationale (product_decision #22).

Classify each demonstration into EXACTLY one of:
  - confirmed  — technical lens supports AND value lens says it covers AC/content meaningfully.
  - smoke      — at least one lens says no (target doesn't fit, aspirational, or wrong type for primary).
  - unverifiable — cannot confirm without external context the verifier does not have.
  - gold       — valuable insight beyond original scope (e.g. surfaces a missing AC, or proposes a stronger demonstration type).

Return ONLY a JSON object of this exact shape:
{
  "classifications": [
    {
      "primary_id": <int>,
      "demonstration_idx": <int — 0-based index in A4.5's array for this primary>,
      "verdict": "confirmed" | "smoke" | "unverifiable" | "gold",
      "technical_lens": "<one-line>",
      "value_lens": "<one-line>",
      "rationale": "<one paragraph combining both lenses>"
    }
  ]
}

Constraints:
- NEVER modify a file.
- NEVER veto by omitting — classify EVERY demonstration from A4.5.
- The main agent receives BOTH A4.5 raw output and your classifications.
```

Receive `verifier_b_response`. If B fails, treat all A4.5 demonstrations as `unverifiable` and proceed.

### Decision tree (per primary)

| Dominant verdict (per primary) | Main agent action |
|--------------------------------|-------------------|
| confirmed or gold | Accept A4.5 demonstrations for this primary. Gold findings logged in `resolved_decisions` as discoveries. |
| smoke | Re-evaluate. Options: (1) loop back to A4.5 with a new prompt scoping the smoke reasons; (2) document override in `resolved_decisions` with `method: "verification_designer_override"` and reasoning. |
| unverifiable | Accept with note in `recent_context` documenting uncertainty. |

Proceed to Step A4.6 with the **accepted** demonstrations (smoke-dominant primaries either looped or overridden).

## Step A4.6: Feasibility-checker (subagent, blocking, deterministic)

A4.5 + A4.7 produced demonstrations. Now verify they can actually be executed in the current environment. This is a **deterministic gate** — pure command-runner, no LLM judgment. Per rules_preview of design_principle #8: "Deterministic gates (stub-check, schema-validate, sandbox-run) run before adversarial subagents — cheap and infallible for what they catch."

**A4.6 does NOT pair with verifier B** — its findings are observable shell output (command exists or it doesn't; `gh auth status` succeeds or fails), not LLM judgment requiring independent classification.

### Spawn the subagent

Spawn an Agent with `run_in_background=false`. The subagent is allowed to use `Bash` tool to run deterministic checks. Pass it only the accepted demonstrations from A4.7's confirmed/gold/unverifiable verdicts.

### Feasibility-checker subagent prompt

```
You are a feasibility-checker. Your job is deterministic: for each demonstration, run shell commands to verify the dependencies required by command_or_method exist locally and are usable.

Input: accepted demonstrations (post-A4.7) per primary. Each has {type, target, expected, command_or_method}.

For each demonstration's command_or_method, infer required dependencies. Use this map:

  - command_or_method contains 'gh api' or 'gh release' or 'gh auth' → requires: gh CLI + gh authentication
    Check: command -v gh && gh auth status
  - command_or_method contains 'jq' → requires: jq
    Check: command -v jq
  - command_or_method contains 'ajv' → requires: ajv (npm)
    Check: command -v ajv
  - command_or_method contains 'python3 -m jsonschema' → requires: python3 + jsonschema
    Check: command -v python3 && python3 -c 'import jsonschema'
  - command_or_method contains 'curl' → requires: curl
    Check: command -v curl
  - command_or_method contains 'docker' → requires: docker
    Check: command -v docker
  - command_or_method contains 'dart' → requires: dart SDK
    Check: command -v dart
  - command_or_method contains 'npm test' or 'npm run' → requires: npm
    Check: command -v npm

For each dep, run the check. If the check fails (non-zero exit or empty output), record as missing_dep.

Return ONLY a JSON object of this exact shape:
{
  "ready": <bool — true if all deps satisfied across all demonstrations>,
  "missing_deps": [
    {
      "dep_name": "<short name, e.g. 'gh' or 'gh auth' or 'jq'>",
      "required_by": [{"primary_id": <int>, "demonstration_target": "<copy of target>"}],
      "install_suggestion": "<suggested install command, e.g. 'brew install gh && gh auth login'>",
      "verify_command": "<command to confirm fixed, e.g. 'gh auth status'>"
    }
  ]
}

Constraints:
- Only deterministic shell checks. No LLM judgment about whether a demo is meaningful.
- High confidence: a check either passes or fails. No "maybe".
- If a demonstration's command_or_method doesn't match any known dep pattern, do NOT flag — assume it's project-local (e.g. `npm test -- file.test.ts` is fine if npm is present).
```

Receive `feasibility_response`. If subagent fails, treat as `ready: true, missing_deps: []` and proceed (the user will discover deps missing when they actually try to run demonstrations — not blocking).

## Step A4.8: Provisioning auto-injection (consume A4.6 missing_deps)

If `feasibility_response.missing_deps` is non-empty, **auto-inject provisioning secondary objectives** at the START of `objectives.secondary[]` — before any implementation secondaries.

For each entry in `missing_deps`:

1. Create a new secondary object with the next available `id`:
   ```json
   {
     "id": <next>,
     "created_at": "<UTC ISO 8601>",
     "content": "Provisioning: install + configure <dep_name>",
     "completion_guide": [
       "Run: <install_suggestion>",
       "Verify: <verify_command> returns success",
       "If verification fails, address before proceeding to implementation secondaries"
     ],
     "status": "not_started"
   }
   ```

2. Prepend to `objectives.secondary[]` (provisioning secondaries come FIRST — before implementation).

3. Renumber subsequent secondary IDs to maintain monotonic order. If renumbering breaks references elsewhere (rare), document in `resolved_decisions` with method `"provisioning_id_renumber"`.

**Example**: A4.6 reports `missing_deps=[{dep_name: "gh", install_suggestion: "brew install gh && gh auth login", verify_command: "gh auth status"}]`. A4.8 prepends:

```json
{
  "id": 1,
  "content": "Provisioning: install + configure gh",
  "completion_guide": [
    "Run: brew install gh && gh auth login",
    "Verify: gh auth status returns success",
    "If verification fails, address before proceeding to implementation secondaries"
  ],
  "status": "not_started"
}
```

The original `id: 1` (first implementation secondary) becomes `id: 2`, and so on.

**Populate verification_demonstrations**: write A4.5/A4.7-accepted demonstrations into each primary's `verification_demonstrations` field with `verdict: "pending"`. The objectives-implement command at Step 7.5 + Step 8 will execute them and flip verdicts to `pass` or `fail`.

Display:
```
🔬 Verification design complete:
  • Demonstrations proposed: [N total across primaries]
  • Verifier B classifications: confirmed=[X], smoke=[Y], unverifiable=[Z], gold=[W]
  • Smoke handled: [looped K / overridden K]
  • Feasibility check: [ready ✓ | missing_deps: K]
  • Provisioning secondaries injected: [K]
```

Proceed to **STEP FINAL** (persist the logbook).

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
  "governance_context": {
    "blueprint_chain": [
      {"level": "scope|product|company", "path": "...", "blueprint_type": "standard|autonomous_entity|company"}
    ],
    "matched_capabilities": [
      {"level": "product", "id": 3, "capability": "...", "is_essential": true, "acceptance_criteria": ["..."]}
    ],
    "related_flows": [
      {"level": "product", "type": "user_flow", "id": 1, "name": "...", "entry_point": "...", "termination": "..."}
    ],
    "governing_design_principles": [
      {"level": "product", "id": 1, "principle": "..."}
    ],
    "applicable_product_rules": [
      {"level": "product", "id": 6, "rule": "...", "applies_to": "..."}
    ],
    "out_of_scope_reminders": [
      {"level": "product", "id": 2, "statement": "..."}
    ],
    "relevant_decisions": [
      {"level": "company", "id": 5, "decision": "...", "impact_on": "..."}
    ],
    "success_metrics": [
      {"level": "product", "id": 1, "metric": "...", "success_signal": "..."}
    ],
    "autonomous_entity_identity": null
  },
  "audit": {
    "is_already_audited": false
  }
}
```

The `audit` object is required by the schema. Initialize it with `is_already_audited: false` at creation; Step A6 (post-persist integrity audit) will flip this to `true` and add `audit_file` after the integrity reviewer subagent runs.

The `governance_context` object is populated from Step 4 (Resolve blueprint chain + extract governance context). If no blueprint exists at all (greenfield project without `waves_files/blueprint.json`), emit `governance_context` with empty arrays — the field stays schema-valid and the `objectives-implement` Governance banner simply has nothing to print. If a blueprint exists but no capabilities/flows match the ticket keywords, also emit empty arrays (the chain walk still populates `blueprint_chain`). NEVER omit the field entirely — schema permits it optional but consistency across logbooks favors always-present.

## Validate Against Schema

Validate against appropriate schema:
- Software: `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/logbook_software_schema.json`
- General: `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/logbook_general_schema.json`

## Save File

The logbook and all its analyses co-locate in **one directory per logbook** (directory-per-logbook convention, design_principle #11 — see SKILL.md):

- **Logbook directory:** `waves_files/waves/[target_wave]/logbooks/[slug]/`, where `[slug]` is `[filename]` without the `.json` extension.
- **Persist the logbook as:** `waves_files/waves/[target_wave]/logbooks/[slug]/logbook.json` (fixed name, not `[slug].json`).

Create the directory if needed. **Transition:** if a logbook already exists in the OLD flat layout (`waves_files/waves/[target_wave]/logbooks/[filename].json`, no directory), read it in place — the relocation happens in `migrate_v2_to_v3` (w6 Phase 4). Write NEW logbooks only in the directory layout.

## Step A6: Post-persist Integrity Audit (deterministic validator + semantic reviewer, blocking)

A6 runs in two stages so that **"audited" implies "valid"**: (1) a deterministic schema validator that BLOCKS on hard schema failures, then (2) a fresh adversarial subagent that surfaces semantic omissions. The deterministic stage runs FIRST and is cheap; it catches what the semantic reviewer structurally can miss (a logbook once passed A6 "clean" while violating `maxLength` 41×).

### Stage 1: Deterministic schema validation (blocking, runs FIRST — no LLM)

Before spawning any subagent, validate the persisted logbook against its schema deterministically:

- Run `python3 -m jsonschema -i <logbook path> ${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/logbook_software_schema.json` (use `logbook_general_schema.json` for general projects); or an equivalent `ajv` / `jq` check.
- This validates the KNOWN fields strictly — `type`, `required`, `maxLength`. The schemas are OPEN (design_principle #11): an undeclared extra field is NOT a hard failure (it passes — it is signal for the corpus miner, not an error). Only known-field type/required/maxLength violations block.
- **On hard failure: STOP.** Print the failing field path and the constraint (e.g. `objectives.main[0].content: 181 > maxLength 180`) and do NOT proceed to Stage 2 — the logbook is not "audited" until it is schema-valid. Fix the field, re-validate, then continue.
- On pass: proceed to Stage 2.

### Stage 2: Semantic integrity reviewer (subagent)

Once the logbook is schema-valid, **delegate the semantic integrity audit to a fresh adversarial subagent** that reads the persisted file from disk (not memory). The main agent has just finished a long generation flow and is biased toward "done, move on." A fresh subagent reads the artifact as-is and surfaces the omissions you would miss.

### Spawn the subagent

Spawn an Agent with `run_in_background=false` (blocking — the result determines whether fixes need to be applied before declaring the logbook ready) using the model from `agent_config.metacognition_model` in user_pref.json (default: `opus`).

Pass these inputs as paths (not content) so the subagent reads from disk:
- The persisted logbook path: `waves_files/waves/[target_wave]/logbooks/[slug]/logbook.json`
- `waves_files/project_rules.json` (or equivalent rules file)
- `waves_files/project_manifest.json` (for layer detection)
- The blueprint path if it exists (`waves_files/blueprint.json`, `waves_files/product_blueprint.json`, etc.)

The subagent writes its output to `waves_files/waves/[target_wave]/logbooks/[slug]/integrity-audit.json` (the logbook's own directory; validates against `integrity_audit_schema`). This co-locates the audit with the logbook it audits (directory-per-logbook convention).

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

After the subagent (A) finishes:

1. Read the audit file at `waves_files/waves/[target_wave]/logbooks/[slug]/integrity-audit.json`.
2. **Verify A's findings with verifier B (adversarial, blocking).** Before acting on any finding, spawn a SECOND blocking Agent (same model). This is the A→B verifier pattern (blueprint design_principle #7 / product_rule #9): A finds, B verifies against the real logbook and classifies (it does NOT veto). Give B this prompt EXACTLY:

   ---
   You are an independent, skeptical verifier with MINIMAL context by design. Auditor A wrote integrity findings about a logbook. Verify and classify each finding against the ACTUAL files — do NOT add findings, do NOT delete any.

   Read from disk:
   - Audit findings: <audit file path>
   - The logbook A audited: <logbook path>
   - project_rules.json and project_manifest.json (to confirm rule ids / layers)

   For EACH finding, apply TWO lenses:
   1) TECHNICAL — does the cited element actually exist as A claims? Open the logbook and check: the cited primary_id/secondary_id exists; the "missing" rule is genuinely absent from that objective's scope/completion_guide; the cited rule_id exists (or doesn't) in project_rules.json. If A's citation does not match reality, it is a false positive.
   2) VALUE — is this a real integrity gap or pedantic noise? A finding that no reasonable reviewer would block on is smoke.

   Add a "classification" field to each finding, exactly one of: confirmed / smoke / unverifiable / gold. Do NOT delete any finding. Write the classifications back into the audit file (Read first, then overwrite atomically), preserving A's original fields.

   Output nothing but the updated JSON file.
   ---

   B classifies, it does NOT veto. After B returns, re-read the audit file (now carrying A's findings + B's classifications).
3. Update the logbook's `audit` object:
   - Populate the v3 `audit.integrity` gate_result: `{ "ran": true, "report_file": "waves_files/waves/[target_wave]/logbooks/[slug]/integrity-audit.json", "summary": { "critical": <N>, "warning": <M> }, "completed_at": "<UTC>" }`.
   - Keep the legacy fields for backwards-compat (v2): `audit.is_already_audited = true` and `audit.audit_file = "<integrity-audit.json path>"`.
   - Save the logbook (Edit tool, atomic write).
4. Process findings, respecting BOTH severity AND B's classification:
   - **`classification == smoke`**: likely false positive / pedantic. Do NOT apply; note it (you may still override if you independently disagree).
   - **`classification == unverifiable`**: use your own judgment with your full context.
   - **`classification == confirmed`/`gold`**: real. Then act by severity:
     - **critical**: review message and suggested_action; apply the correction by editing the logbook with the full context you have (rules text, manifest layers, blueprint capability, secondaries you generated). Decisions are level 1-2 of the Waves trust contract — proceed without user approval. If, after your own review, a confirmed finding is still genuinely incorrect, record the rejection in `resolved_decisions` with `method: "integrity_audit_override"` and a reasoning paragraph.
     - **warning**: decide whether to apply. If you apply, do so. If not, no action needed (warnings are not blocking).
5. After applying any fixes, append a new entry to the logbook's `recent_context` summarizing what was applied:
   ```
   "Integrity audit applied: [N] critical findings addressed, [M] warnings reviewed ([X] applied, [Y] noted). Audit report: waves_files/waves/[target_wave]/logbooks/[slug]/integrity-audit.json"
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

  📁 Full audit report: waves_files/waves/[target_wave]/logbooks/[slug]/integrity-audit.json
```

### Why Step A6 lives post-persist

The audit reads the logbook from disk so it can be re-run later (logbook-update, manual re-audit) without re-implementing the same logic in three commands. The audit file is a persistent artifact alongside the logbook — anyone reading the logbook months later can see whether it was audited and consult the report. This separation also keeps the main agent's context light during the audit: the subagent reads files, the main agent doesn't have to keep them all in memory.

## Step A7: Post-plan Correctness Gate (3 parallel reviewers + verifier B)

A6 checks the logbook's **integrity** (is it well-formed, complete, internally consistent?) with minimal context. A7 checks the plan's **correctness** against the REAL codebase, with FULL context — a different axis (design_principle #10, product_rule #11). It catches false API assumptions and missing edge cases *before* any code is written, when fixing them costs a logbook edit instead of a debugging session. This is the cheap half of the adversarial correctness layer (the post-impl gate in `objectives-implement` Step 9.8 is the safety net).

### When to run / skip

Run A7 when **any secondary declares `test_cases` with at least one `edge_case: true` row, or declares `function_signatures`** — i.e. the logbook plans real, relational code. **Skip** (and say so in one line) when the logbook is trivial: doc-only / config-only / single-file with no `function_signatures` and no `edge_case: true` rows. This threshold is configurable via a verification rule (`correctness_gate.post_plan`: `auto` (default) | `always` | `off`).

### Dispatch the 3 reviewers in PARALLEL (full-context, reads-only)

The three reviewers are independent and read-only, so they are parallel-safe. Spawn all three with `run_in_background: true` (using the model from `agent_config.metacognition_model` in user_pref.json, default `opus`), then collect:

1. **waves-correctness-reviewer** — false API assumptions, type/contract mismatches, logic errors in the planned approach vs the real signatures it will call.
2. **waves-silent-failure-hunter** — does the plan consider failure paths at all? Do the `test_cases` include error/recovery rows, or will failures be swallowed by construction?
3. **waves-cross-consistency-reviewer** — does the planned code preserve the invariants its sibling handlers/functions enforce? (This is the one that catches the Diamond #829/#830 class at design time: a new handler that omits the `toIdle()` / lockout / trim its siblings all honor.)

Pass each reviewer: the persisted logbook (so it sees every secondary's `function_signatures` + `test_cases`), the `scope.files`, and an instruction to **read widely** — the real callees, the sibling functions, the types — not just the files named. They review the PLAN against reality.

### Reviewer input contract (structural isolation — a guarantee of THIS command)

At the post-plan boundary the persisted logbook IS legitimate input (it is the artifact under review). What must NOT reach the reviewers is the **creator's framing**:

- **ALLOWED:** the persisted logbook read from disk, the `scope.files`, the assembled codebase (read widely), the project's schemas.
- **FORBIDDEN:** the reasoning/narrative of the session that created the logbook ("why I planned it this way"), and the conclusions of prior gates on this artifact (A6 integrity findings, earlier A7 passes) — each pass re-derives independently from the artifact.

Build each reviewer prompt only from ALLOWED. The reviewers also defensively discard author rationale per their own Input contract section, but the dispatcher must not leak it in the first place.

**Failure branch (mirror of the post-impl gate):** if any reviewer fails, times out, returns non-JSON, or reports `unreadable_input` — or its verifier B falls (treat that lens's findings as `unverifiable`) — the gate is degraded: record `"degraded": true` + `fallen_reviewers: [...]` in `audit.correctness_postplan` (fields declared in `gate_result`), surface it in the Display (`[ran | degraded: [reviewer] fell | skipped: trivial logbook]`, the fallen lens shows `FELL — no counts`), and do NOT declare the logbook ready on the surviving lenses alone: re-run the fallen lens, or proceed ONLY with a documented `resolved_decisions` override.

### Verifier B on each reviewer (A→B pattern)

Each reviewer A is an LLM-judgment analyst — per design_principle #7 / product_rule #9 it requires a paired verifier B. For each reviewer's findings, run an inline verifier B that reads the **cited evidence** (the real signatures / sibling code the finding quotes) and classifies each finding `confirmed | smoke | unverifiable | gold` with a double lens (technical: is it real? + value: would a reasonable reviewer block on it?). **B never vetoes and never adds findings** — it classifies. The main agent receives both A's raw findings and B's classifications.

### Act on the findings (the logbook is not "ready" until resolved)

- **`confirmed`/`gold`, severity critical/high** — fix the logbook now: tighten a `function_signature`, fill or correct a `test_cases.expected` (reading the sibling code the finding points to), or add the missing `edge_case: true` row. These are level 1-2 of the trust contract — proceed without approval; if you genuinely disagree with a confirmed finding, record the rejection in `resolved_decisions` with `method: "correctness_gate_override"` and a reasoning paragraph.
- **`confirmed`, severity medium/low** — apply if cheap; otherwise note in the secondary's `completion_guide`.
- **`smoke`/`unverifiable`** — no edit; the classification is the record.
- Append a `recent_context` entry: `"Post-plan correctness gate: [N] confirmed (fixed), [M] smoke. Reviewers: correctness/silent-failure/cross-consistency."`
- **Persist the report (directory-per-logbook convention):** write the gate's findings + verifier-B classifications to `waves_files/waves/[target_wave]/logbooks/[slug]/correctness-postplan.json`, which validates against `correctness_gate_schema` with `boundary: post_plan` — co-located with the logbook, not in a sibling `audits/`. Then populate the `audit.correctness_postplan` gate_result: `{ "ran": true, "report_file": "<that path>", "summary": { "confirmed": <N>, "smoke": <M> }, "completed_at": "<UTC>" }`. The `recent_context` entry above stays a SHORT summary — the full findings live in the file (no inline prose dump; design_principle #11 + DRY).

Cost: 3 reviewers + 3 verifiers, all parallel reads → wall-time ≈ one round; zero writes to the codebase.

### Display

```
🛡️ Post-plan correctness gate ([ran | skipped: trivial logbook]):
  correctness:        [N] findings ([c] confirmed)
  silent-failure:     [N] findings ([c] confirmed)
  cross-consistency:  [N] findings ([c] confirmed)
  → [k] confirmed findings fixed in the logbook before implementation.
```

## Success Message

```
✅ Logbook created successfully!

📁 File: waves_files/waves/[target_wave]/logbooks/[slug]/logbook.json

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
│  6. VERIFY DESIGN: Step A4.5 (verification-designer subagent)   │
│     proposes type-aware demonstrations per primary               │
│       ↓                                                         │
│  7. VERIFY DESIGN B: Step A4.7 (inline verifier B) classifies   │
│     confirmed/smoke/unverifiable/gold without vetoing            │
│       ↓                                                         │
│  8. FEASIBILITY CHECK: Step A4.6 (deterministic command-runner) │
│     verifies deps; outputs ready vs missing_deps                 │
│       ↓                                                         │
│  9. PROVISIONING: Step A4.8 auto-injects provisioning secondaries│
│     BEFORE implementation secondaries (per missing_deps)         │
│       ↓                                                         │
│ 10. SAVE: Generate and save logbook                             │
│       ↓                                                         │
│ 11. INTEGRITY AUDIT: Step A6 (fresh subagent) reads persisted   │
│     logbook from disk and flags structural issues                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Subagents Reference

This command uses **5 subagent dispatches** (all fresh, with minimal context by design):

1. **Step A2.5 Orthogonality reviewer** — decides single_focus vs multi_focus for primary objectives. Adversarial.
2. **Step A4.5 Verification-designer** — proposes type-aware `verification_demonstrations` per primary. Adversarial (LLM-judgment) → paired with verifier B.
3. **Step A4.7 Verifier B on A4.5** — classifies A4.5's demonstrations as confirmed/smoke/unverifiable/gold. Inline (no materialized file) per blueprint decision #14. Never vetoes.
4. **Step A4.6 Feasibility-checker** — deterministic command-runner verifying local deps for each demonstration's `command_or_method`. Does NOT pair with verifier B because its output is observable shell output (no LLM judgment).
5. **Step A6 Integrity reviewer** — reads persisted logbook from disk and flags structural integrity issues.

Implementation work (Steps A1, A2, A3, A4, B1-B3, STEP FINAL) stays in the main agent because writing decisions need full accumulated context. The 5 subagents delegate because they need independence from the implementer (verifier-pattern principle, design_principle #7 / product_rule #9).

END OF COMMAND
