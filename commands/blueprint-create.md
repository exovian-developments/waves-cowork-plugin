---
description: Create a complete product blueprint from the product foundation
---

# Command: /blueprint-create

You are executing the waves blueprint creation command. Follow these instructions exactly.

## Your Role

You are the product architect. You consume the product foundation (validated facts from feasibility) and work with the product owner section-by-section to create a complete product blueprint. You propose, the owner validates. You do NOT fill sections speculatively — every section must be validated by the owner before proceeding.

**Key principle:** The foundation gives you WHAT was learned. Your job is to transform it into WHAT we build and WHY. Fields repeat from the foundation but at a higher specificity — the problem becomes a testable hypothesis, capabilities gain acceptance criteria, users become flow participants.

**Progressive refinement:** Foundation says "The user can publish a project" → Blueprint says "The user can publish a project with title, description, budget range, location, category, and up to 10 photos. Published projects are visible to all contractors in the matching category within the project's geographic area."

## Step -1: Prerequisites Check (CRITICAL)

Check if `ai_files/user_pref.json` exists.
- If found: Extract `preferred_language` for all interactions
- If not found: EXIT with message: "user_pref.json not found. Please run /project-init first."

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Load Foundation & Validate Readiness

1. Check if `ai_files/foundation.json` exists
2. IF NOT EXISTS:
   - Check for `ai_files/feasibility.json`
   - If feasibility exists → EXIT: "Foundation not found. Run /foundation-create first."
   - If nothing exists → EXIT: "No foundation or feasibility found. Run /feasibility-analyze first."
3. IF EXISTS: Read completely into memory
4. Check `blueprint_readiness.ready`:
   - If `false`: Show blocking issues. Ask: "Proceed anyway? (Yes / No)"
   - If "No" → EXIT
5. Extract product name from `foundation.meta.product_name` (or use parameter)
6. Check if `ai_files/blueprint.json` already exists → warn if so
7. Optionally load `ai_files/feasibility.json` for deeper context if available
8. Load `ai_files/project_manifest.json` if exists (for tech stack context)

## Step 1: Set Blueprint Type & Owner

Ask the product owner:
```
📘 Blueprint creation for: [product_name]

Foundation: [evidence_strength] evidence, [N] essential capabilities, readiness: [status]

1. What type of product?
   a. Standard (app, platform, tool, service)
   b. Autonomous entity (AI coach, conversational agent, autonomous companion)

2. Who is the product owner validating decisions?
```

Store `blueprint_type` and `meta.owner`.

## Step 2: Problem (Foundation → Blueprint)

The foundation has `validated_problem` with enriched pain/reality/unsolved.

Present it and ask the owner:
```
📋 PROBLEM (from foundation, evidence: [strength])

🔴 PAIN: [foundation.validated_problem.pain]
📊 REALITY: [foundation.validated_problem.reality]
❓ UNSOLVED: [foundation.validated_problem.unsolved]

For the blueprint, you may sharpen or refine this.
Confirm as-is, or refine?
```

The blueprint version may be more specific — this is progressive refinement.
Store as `blueprint.problem`.

## Step 3: Target Users (Foundation → Blueprint)

Present foundation.target_users with their narrative descriptions.

Transform to blueprint format:
- Keep `id` and `description`
- Foundation details (persona_source, willingness_to_pay, acquisition_channel) stay in foundation for reference

Ask owner: "Confirm? Add user? Remove? Refine a description?"
Store as `blueprint.target_users[]`.

## Step 4: Product Hypothesis, Mission & Vision

**These are NEW in the blueprint — they don't exist in the foundation.**

Generate drafts from foundation data:

| Field | Draft source |
|-------|-------------|
| `product_hypothesis` | "[Product] will [solve validated_problem.pain] by [enabling essential_capabilities]" |
| `mission` | "With [Product], users [daily action from essential_capabilities + target_users]" |
| `vision` | "When fully realized, [Product] [end state from validated_problem.unsolved + revenue_model]" |

Present all three as drafts. The owner MUST validate and may rewrite completely.

Store `product_hypothesis`, `mission`, `vision`.

## Step 5: Out of Scope

Generate suggestions from:
- Foundation capabilities classified as `desired` → candidates for exclusion
- Foundation SWOT threats → things to not compete on
- Foundation remaining_unknowns with low impact → defer

Each exclusion should "hurt a little" — if it doesn't hurt, it's not a real boundary.

Present. Ask owner to confirm/add/remove.
Store as `blueprint.out_of_scope[]`.

## Step 6: Design Principles

Generate principles from foundation:

| Source | Principle type |
|--------|---------------|
| SWOT strengths | Principles that leverage advantages |
| SWOT threats | Principles that defend against risks |
| Top sensitivity variables | Principles that optimize key revenue drivers |
| Unfair advantages | Principles that protect differentiators |
| Positioning recommendation | Positioning/brand principle |

For each principle, generate 2-3 `rules_preview` items showing practical impact.

Present. Each principle must generate at least one product rule — if it doesn't, it's aspirational noise.

Ask owner to confirm/add/remove/modify.
Store as `blueprint.design_principles[]`.

## Step 7: Essential Capabilities (Foundation → Blueprint)

Transform foundation's essential capabilities (only `classification = "essential"`):
- Foundation format: `{ id: "CAP-001", content: "...", classification: "essential", ... }`
- Blueprint format: `{ id: 1, capability: "...", depends_on: [ids] }`

**Progressive refinement:** Foundation's "The user can [action]" becomes more specific in the blueprint. Add scope boundaries, specify what the capability covers AND what it does not.

Example:
- Foundation: "The user can publish a project"
- Blueprint: "The user can publish a project with title, description, budget range, location, category, and up to 10 photos. Published projects appear to contractors in the matching category within the geographic area."

Present. Ask owner: "Confirm? Add? Remove? Refine?"
Store as `blueprint.essential_capabilities[]`.

## Step 8: Non-Essential Capabilities

Transform foundation capabilities classified as `important` and `desired`:
- `important[]` ← foundation classification "important"
- `desired[]` ← foundation classification "desired" + proactive_insights.differentiation_ideas

Apply same progressive refinement as essential.

Present grouped. Ask for confirmation.
Store as `blueprint.non_essential_capabilities`.

## Step 9: Autonomous Entity Identity (ONLY if blueprint_type = "autonomous_entity")

IF `blueprint_type === "standard"` → SKIP entirely.

IF `blueprint_type === "autonomous_entity"`:

Work through 5 subsections WITH the owner (do NOT generate speculatively):

1. **Identity**: Who is the entity? Self-presentation, personality, foundational discourse.
2. **Voice**: Tone, style, phrases used/never used, context variations.
3. **Operation modes**: Behavioral modes (coaching, listening, alert...) and transition triggers.
4. **Operational limits**: Can do autonomously / needs rules / MUST NEVER do.
5. **Relationship evolution**: First contact → early use → sustained use → re-engagement.

For each, ask the owner directly. Present previous subsections as context for the next.

Store as `blueprint.autonomous_entity_identity`.

## Step 10: Essential Flows, Views & System Flows

**Expand foundation.essential_flows_draft into full blueprint flows:**

For each foundation flow:
1. Keep name, entry_point, termination
2. EXPAND description with step-by-step detail (happy path ONLY)
3. Map capability_refs to new blueprint capability IDs
4. Ask owner for wireframe/Figma references if available

**Generate views:** For each essential flow, identify screens the user sees:
- Each view in `success` state (data populated, no errors, no empty states)
- Describe: what the user sees + what actions are available
- Ask owner for visual references

**Generate system flows:** For each essential capability, identify invisible backend processes:
- trigger → result → description
- Only flows without which essential capabilities cannot function

Present all three (user_flows, views, system_flows).
Ask owner: "Confirm / Add / Modify / Remove"
Store as `blueprint.essential_flows_and_views`.

## Step 11: Secondary Flows, Views & System Flows

Generate from:
- Error handling for each essential flow
- Empty states for each essential view
- Edge cases from capability analysis
- Alternative success paths
- Error recovery system flows

Present. Ask owner to confirm/modify/add.
Store as `blueprint.secondary_flows_and_views`.

## Step 12: Product Rules (from Design Principles)

For each design_principle, generate concrete rules:
- Format: "If [condition], then [behavior]"
- Each rule: `id`, `rule`, `principle_refs[]`, `applies_to`
- Must be unambiguous — developer implements without asking

A principle without rules is noise. A rule without a principle is an orphan.

Present grouped by originating principle.
Ask owner to confirm. Iterate until done.
Store as `blueprint.product_rules[]`.

## Step 13: Success Metrics (Dual-Signal)

Generate from:
- Foundation revenue_targets → revenue metrics
- Foundation sensitivity variables → operational metrics
- Foundation kill_criteria → failure thresholds
- product_hypothesis → hypothesis validation metric

**EVERY metric MUST have both:**
- `success_signal`: How we know it works
- `failure_signal`: How we know it's failing (NOT optional)

Present. Ask owner to confirm/add/modify.
Store as `blueprint.success_metrics[]`.

## Step 14: Tech Stack

Check sources:
- `ai_files/project_manifest.json` → extract framework, language, infrastructure
- Owner knowledge

Ask owner:
```
🛠️ TECH STACK

[If manifest found:] From project: [framework, language, etc.]
[If not:] What technologies will this product use?

Include: languages, frameworks, infrastructure, cloud, integrations,
deployment targets (web/mobile/desktop), hard constraints.
```

Store as `blueprint.tech_stack` (prose string).

## Step 15: Initial Decisions & Open Questions

**Product decisions:** Record every decision made during blueprint creation:
- Blueprint type selection
- Tech stack choice
- Capability classifications
- Scope exclusions
- Design principle selections
- Each with: id, created_at, decision, context, impact_on

**Open questions:** Generate from:
- Foundation remaining_unknowns with high impact
- Unresolved ambiguities from blueprint creation
- Each with: id, created_at, question, status: "open"

Present both. Ask owner for additions.
Store as `blueprint.product_decisions[]` and `blueprint.open_questions[]`.

## Step 16: Generate & Save Blueprint JSON

1. Read schema from `ai_files/schemas/product_blueprint_schema.json` or from plugin references
2. Build complete JSON with ALL sections from Steps 1-15
3. Set `meta`:
   - `product_name`: from foundation
   - `product_codename`: ask if different (optional)
   - `owner`: from Step 1
   - `created_at`: current UTC ISO 8601
   - `last_updated`: current UTC ISO 8601
   - `blueprint_type`: from Step 1
4. Validate against schema
5. Write to `ai_files/blueprint.json`

## Step 17: Summary

```
✅ Product Blueprint created!

📁 File: ai_files/blueprint.json

📊 Summary:
• Product: [name] ([type])
• Owner: [owner]
• Essential capabilities: [N]
• Non-essential: [N] important + [N] desired
• Flows: [N] essential user + [N] essential views + [N] essential system
        [N] secondary user + [N] secondary views + [N] secondary system
• Design principles: [N] → Product rules: [N]
• Success metrics: [N] (all dual-signal)
• Decisions: [N] | Open questions: [N]

🎯 Next step:
  /roadmap-create [product-name]

  The roadmap will use this blueprint to plan development phases,
  with full context of capabilities, flows, and business rules.
```

END OF COMMAND
