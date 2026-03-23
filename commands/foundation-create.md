---
description: Compact feasibility analysis into validated facts for blueprint creation
---

# Command: /foundation-create

You are executing the waves foundation creation command. Follow these instructions exactly.

## Your Role

You are the compaction engine. You read a completed feasibility analysis and distill it into a product foundation — the executive brief that feeds directly into the product blueprint. You extract, enrich, synthesize, and re-classify. You do NOT speculate or add information beyond what the feasibility contains, but you DO enrich by cross-referencing sections against each other.

**Key principle:** The feasibility is the research lab (thousands of simulations, dozens of iterations). The foundation is the executive brief (validated facts, not hypotheses). The blueprint is the architectural plan (built on the foundation).

## Step -1: Prerequisites Check (CRITICAL)

Check if `ai_files/user_pref.json` exists.
- If found: Extract `preferred_language` for all interactions
- If not found: EXIT with message: "user_pref.json not found. Please run /project-init first."

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Locate Feasibility Analysis

1. Check if `ai_files/feasibility.json` exists
2. IF NOT EXISTS → EXIT: "No feasibility analysis found. Run /feasibility-analyze first."
3. IF EXISTS → Read `ai_files/feasibility.json` completely into memory
4. Extract product name from `meta.analysis_name` (or use parameter if provided)

**Check for existing foundation:**
- If `ai_files/foundation.json` exists:
  - Show existing product name and source feasibility
  - Ask: "Overwrite? (Yes / No)"
  - If No → EXIT

## Step 1: Extract & Enrich Problem Statement

**Merge these sources into an enriched problem:**

| Field | Sources to merge |
|-------|-----------------|
| `pain` | `idea_profile.problem_statement.pain` + most common `buyer_personas[].pain_points` |
| `reality` | `idea_profile.problem_statement.reality` + `market_analysis.tam/sam/som` + bayesian `market_exists` posterior |
| `unsolved` | `idea_profile.problem_statement.unsolved` + `market_analysis.competitors[].gap` + `market_analysis.market_gap` |

**Derive evidence_strength:**
- `anecdotal`: No posteriors or all < 0.3
- `observed`: Some posteriors 0.3-0.5, qualitative data
- `measured`: Posteriors 0.5-0.7, quantitative market data
- `validated`: Posteriors > 0.7 or pre-sales confirm

**Present to user.** Ask: "Does this capture the problem? (Yes / Refine / Use original without enrichment)"
- If Refine → ask for corrections, apply
- If Use original → copy feasibility problem_statement as-is

## Step 2: Compact Target Users from Buyer Personas

For each `buyer_personas[]` in the feasibility:

1. `persona_source` ← buyer_persona.name
2. `description` ← Synthesize narrative from: occupation + pain_points + current_solution + decision_triggers. Write as if pointing at someone: "That person, with that problem"
3. `willingness_to_pay` ← buyer_persona.willingness_to_pay
4. `primary_acquisition_channel` ← buyer_persona.acquisition_channel
5. Assign sequential `id` starting from 1

**Present list to user.** Ask: "Confirm? (Yes / Add / Remove / Refine one)"

## Step 3: Compact Competitive Landscape

Extract from `market_analysis`:
- `market_size`: TAM, SAM, SOM with sources (if available)
- `competitors[]`: Top 3-5 with name, positioning, pricing, gap
- `market_gap_summary`: From market_gap
- `unfair_advantages[]`: From market_analysis.unfair_advantages + idea_profile.founder_advantage

**Present to user as a table.** Ask: "Accurate? (Yes / Refine)"

## Step 4: Compact Revenue Model

Extract from `revenue_model`:
- `model_type`
- `revenue_streams[]`: For each stream, include name, description, pricing, unit_economics, revenue_share_percent
- Cross-reference each stream with essential capabilities: which capabilities from `essential_capabilities_draft` does this stream depend on? Store as `capabilities_required`
- `pricing_tiers[]`: if present
- `flywheel`: description of reinforcement loop

**Present to user.** Ask: "Confirmed? (Yes / Refine)"

## Step 5: Compact Financial Benchmarks (CRITICAL COMPACTION)

This is the core compaction — thousands of Monte Carlo simulations into decision-relevant numbers.

**Extract:**
1. `revenue_targets` from feasibility root: survival_monthly, intermediate_monthly, comfortable_monthly, timeline_months
2. Identify the BEST scenario from `revenue_projections[]` (highest P(survival))
3. From that scenario's `monte_carlo.results`:
   - scenario_name, n_simulations
   - probability_survival_6mo, probability_comfortable_12mo
   - median_mrr_6mo, median_mrr_12mo
   - top_sensitivity_variables (top 3-5 by impact, with actionable_insight)
4. From that scenario's `bayesian_analysis.posterior_beliefs`:
   - market_exists, can_reach_customers, can_achieve_profitability
   - highest_risk: identify the belief with lowest posterior
5. `cost_structure` from `user_resources.financial_capacity`:
   - fixed_monthly_costs, runway_months, initial_investment_available
   - burn_rate_estimate (calculate if not explicit)
6. `kill_criteria` from the winning scenario

**Present as a dashboard.** Ask: "These benchmarks will guide blueprint scope. Accurate? (Yes / Refine)"

## Step 6: Synthesize SWOT Analysis

**SWOT does NOT exist in the feasibility — synthesize it here from multiple sections:**

| Quadrant | Sources |
|----------|---------|
| **Strengths** | `idea_profile.founder_advantage` + `market_analysis.unfair_advantages` + `user_resources.skills` (high relevance) |
| **Weaknesses** | `user_resources.constraints` + bayesian beliefs with low posteriors + sensitivity variables with high impact that are hard to control |
| **Opportunities** | `market_analysis.market_gap` + `proactive_suggestions.positioning_angles` + `proactive_suggestions.partnership_opportunities` + timing factors |
| **Threats** | Competitors with small gaps + kill_criteria triggers + critical_assumptions that could fail |

**Present as a 2x2 grid.** Ask: "Accurate? (Yes / Refine)"

## Step 7: Re-classify Essential Capabilities (KEY TRANSFORMATION)

This is the most important transformation in the foundation. Feasibility classifies by revenue impact (blocking/enabling/expansion). The blueprint needs operational criticality (essential/important/desired).

**Source:** `essential_capabilities_draft.core_capabilities[]`

**Re-classification rules:**
- `revenue_blocking` → Apply test: "Without this, can the product EXIST?" → If no → `essential`. If yes (revenue loss but product works) → `important`
- `revenue_enabling` → Apply test: "Does it HURT to operate without?" → If product BREAKS → `essential`. If just hurts → `important`
- `usage_expansion` → Apply test: "Strengthens essential capabilities significantly?" → If yes → `important`. If just nice → `desired`

**For each capability:**
1. Assign `id`: "CAP-001", "CAP-002", etc.
2. Rewrite `content` in "The user can [specific action]" format
3. Set `classification`: essential / important / desired
4. Map `revenue_streams[]`: which streams depend on this capability
5. Identify `depends_on[]`: which CAP-XXX must exist first
6. Preserve `build_effort_days` from feasibility
7. Tag `feasibility_source`: original classification for traceability

**Present as a table grouped by classification.** Ask: "Agree with classification? (Yes / Reclassify one / Add / Remove)"
Iterate until confirmed.

## Step 8: Expand Essential Flows

From `essential_capabilities_draft.essential_flows_draft[]`:

For each flow:
1. Keep `flow_name` and `description`
2. ADD `entry_point`: Where/how the user enters (infer from capability context)
3. ADD `termination`: What marks completion (infer from flow description)
4. Map `capability_refs[]` to new CAP-XXX IDs
5. Preserve `revenue_connection`

**Present expanded flows.** Ask: "Complete? (Yes / Add flow / Modify / Remove)"

## Step 9: Calculate Timeline Constraints

Extract:
- `time_to_mvp_weeks` from essential_capabilities_draft
- `time_to_first_revenue_weeks` from essential_capabilities_draft
- `available_hours_weekly` from user_resources.time_weekly_hours
- Calculate `runway_deadline`: feasibility.meta.created_at + runway_months

**Perform scope feasibility check:**
- Sum build_effort_days across ALL essential capabilities
- Convert to weeks at available_hours_weekly (assume 8h = 1 day)
- Compare against time_to_mvp_weeks and runway_months

Generate `scope_feasibility_check`:
- If weeks_needed ≤ time_to_mvp × 0.8 → "FEASIBLE with [buffer] weeks buffer"
- If weeks_needed ≤ time_to_mvp → "TIGHT — minimal buffer, consider deferring [lowest-priority essential]"
- If weeks_needed > time_to_mvp → "INFEASIBLE — reduce scope by deferring [capabilities] to post-launch"

**Present assessment with recommendation.**

## Step 10: Collect Proactive Insights & Remaining Unknowns

**Proactive insights** — extract from `proactive_suggestions`:
- `positioning_recommendation`: best positioning_angle
- `differentiation_ideas[]`: capability_ideas with impact/complexity
- `marketing_strategies[]`: with effort and ROI
- `partnership_opportunities[]`

**Remaining unknowns** — extract from:
- `next_steps.remaining_unknowns`
- `bayesian_analysis.next_evidence_to_gather`
- Low-confidence areas identified during compaction

For each unknown, assess:
- `impact`: high (blocks blueprint decision), medium (affects non-essential scope), low (nice to know)
- `recommended_resolution`: how to resolve before or during blueprint

**No mandatory user checkpoint — informational presentation only.**

## Step 11: Assess Blueprint Readiness

**Ready = true when ALL of:**
- evidence_strength ≥ "observed"
- At least 1 target user with willingness_to_pay
- At least 1 essential capability
- feasibility_confidence ≥ "medium"
- Monte Carlo with ≥ 1000 simulations
- Bayesian market_exists ≥ 0.5

**Calculate confidence_level:**
- Copy from feasibility's confidence assessment

**If not ready:**
- List blocking_issues
- `recommended_next_step` → specific action (e.g., "Return to feasibility and run with adjusted pricing")

**If ready:**
- `recommended_next_step` → "Run /blueprint-create with this foundation as input"

## Step 12: Generate & Save Foundation JSON

1. Read schema from `ai_files/schemas/product_foundation_schema.json` or from plugin references
2. Build complete foundation JSON with ALL sections from Steps 1-11
3. Set `meta`:
   - `product_name`: from Step 0
   - `foundation_version`: "1.0"
   - `created_at`: current UTC ISO 8601
   - `last_updated`: current UTC ISO 8601
   - `source_feasibility`: filename of selected feasibility
   - `feasibility_confidence`: from feasibility
   - `feasibility_iteration_count`: from feasibility.meta.iteration_count
4. Validate against schema
5. Write to `ai_files/foundation.json`

## Step 13: Summary

```
✅ Product Foundation created!

📁 File: ai_files/foundation.json

📊 Summary:
• Product: [name]
• Source: [feasibility file] ([iteration_count] iterations)
• Evidence strength: [level]
• Essential capabilities: [N] | Important: [N] | Desired: [N]
• Essential flows: [N]
• Financial: Monte Carlo [N] sims, P(survival@6mo): [X]%
• SWOT: [S/W/O/T counts]
• Blueprint readiness: [READY ✅ / NOT READY ⚠️]

🎯 Next step:
[If ready:]
  /blueprint-create
  The blueprint will consume this foundation as primary input.

[If not ready:]
  [Specific blocking issues and recommendations]
```

END OF COMMAND
