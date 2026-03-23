---
description: Extract coding rules from project codebase
allowed-tools: Read, Write, Glob, Grep, Task
---

# Plugin Command: rules-create

You are executing the waves plugin rules creation command. Follow these instructions exactly.

## Your Role

You are the main orchestrator for project rules/standards creation. For software projects, analyze existing code to extract patterns and conventions via specialized agents. For general projects, guide the user through defining standards.

## Step -1: Prerequisites Check (CRITICAL)

1. Check if `ai_files/user_pref.json` exists.
   - IF NOT EXISTS → Display: "⚠️ Missing configuration! Run project-init first." → EXIT COMMAND

2. Read `ai_files/user_pref.json`:
   - Extract `user_profile.preferred_language` → Use for all interactions
   - Extract `project_context.project_type` → Determines main flow

3. IF `project_type === "software"`:
   - Check `ai_files/project_manifest.json` exists
   - IF NOT EXISTS → Display: "⚠️ Run manifest-create first." → EXIT COMMAND

4. Check if rules file already exists:
   - Software → `ai_files/project_rules.json`
   - General → `ai_files/project_standards.json`
   - IF EXISTS → Ask: "Rules already exist. Overwrite / Merge / Cancel?"

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Command Explanation

Display in user's language:
```
📘 Command: rules-create

[If software]:
I'll analyze the existing code to identify patterns,
conventions, and also detect potential antipatterns.

[If general]:
I'll guide you to define the standards you need
for your project.

Continue? (Yes/No)
```

IF No → Exit.

## Step 1: Fork by Project Type

- IF `project_type === "software"` → Go to **Flow A**
- IF `project_type === "general"` → Go to **Flow B**

---

## Flow A: Software — Layer-Based Analysis

### Step A1: Read Project Manifest

1. Read `ai_files/project_manifest.json`
2. Extract: `primary_language`, `framework`, `architecture_patterns_by_layer`, `modules`, `features`
3. Show project context summary and ask which layer to analyze:

```
📊 Project context (from manifest):

Language: [language]
Framework: [framework]
Type: [frontend/backend/fullstack]

Detected layers:
[List layers from manifest]

Which layer to analyze?

1. architecture
2. presentation_layer
3. data_layer
4. api_layer
5. naming_conventions
6. testing
7. infra
8. All layers (full analysis)

Choose 1-8:
```

### Step A2: Invoke Analysis Agents in Parallel via Task Tool

For each selected layer, launch these 3 agents IN PARALLEL using Task tool:

**Subagent 1: pattern-extractor**
- Analyzes code in the layer for consistent patterns (3+ occurrences)
- Returns: List of detected patterns with locations and frequency

**Subagent 2: convention-detector**
- Analyzes naming and structural conventions
- Returns: Conventions with consistency percentages

**Subagent 3: antipattern-detector**
- Analyzes code for known antipatterns (educational, constructive tone)
- Returns: Antipatterns with explanations and suggestions

Display progress:
```
🔍 Analyzing layer: [layer]

[✅] Pattern Extractor — [count] patterns identified
[✅] Convention Detector — [count] conventions detected
[⏳] Antipattern Detector — Analyzing...
```

Create a Task that launches all 3 agents in parallel on the selected layer.

### Step A3: Validate Against Criteria via Task Tool

Using Task tool, invoke agent validation to ensure each pattern/convention meets criteria:
- Promotes project-wide consistency
- Improves maintainability
- No contradictions with other rules
- Establishes implementation patterns (not tool config)
- Context-independent
- YAGNI compliant

### Step A4: Present Findings

Display in user's language:
```
📋 Analysis completed for: [layer]

═══════════════════════════════════════
✅ PATTERNS IDENTIFIED ([count] proposed rules)
═══════════════════════════════════════

[For each rule: section, description (max 280 chars)]

═══════════════════════════════════════
⚠️ ANTIPATTERNS DETECTED (Educational)
═══════════════════════════════════════

[For each antipattern: severity, location, problem, suggestion]

Options:
1. Save all proposed rules
2. Review and select individually
3. Analyze another layer
4. See more antipattern details
```

### Step A5: Generate Rules File

Read `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/project_rules_schema.json` for structure reference.

Generate `ai_files/project_rules.json` with:
- Project info from manifest
- Validated rules organized by section
- IDs starting at 1, incrementing
- `created_at` timestamps in UTC ISO 8601
- Descriptions max 280 characters

Validate the generated file against the schema.

### Step A6: Success Message

```
✅ Project rules created!

📁 File: ai_files/project_rules.json
📊 Rules generated: [count]

By section:
[List sections with rule counts]

⚠️ Antipatterns identified: [count]
(Review the report to improve code quality)

🎯 Next steps:

To analyze more layers:
rules-create [layer]

To update rules after code changes:
rules-update

To start working:
(appropriate next command based on project type)
```

---

## Flow B: General Projects — User-Guided Standards

### Step B1: Show Suggestions

Based on manifest type, show relevant standard suggestions:
- Academic: citation format, document structure, tables/figures, file naming
- Creative: file specs, color palette, typography, asset naming
- Business: processes, communication, KPIs, templates
- General: file organization, naming, workflows, documentation

Frame as "ideas" not requirements.

### Step B2: Open Question

```
📝 What standards or rules do you want to define for your project?

Describe freely what you need. I can help you structure it afterwards.

[Show example response relevant to project type]
```

### Step B3: Structure User Input via Task Tool

Using Task tool, invoke agent to parse free-form input into structured categories.

Show the structured result for confirmation:
```
📋 Structured standards:

[List categorized standards]

Is this correct? (Yes/Edit/Cancel)
```

If user wants changes → iterate.

### Step B4: Generate Standards File

Generate `ai_files/project_standards.json` with structured standards matching the schema from `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/project_standards_schema.json`.

### Step B5: Success Message

```
✅ Project standards created!

📁 File: ai_files/project_standards.json
📊 Categories defined: [count]

[List categories]

🎯 Next step:

To update standards later:
rules-update

To start working:
(appropriate next command based on project type)
```

END OF COMMAND
