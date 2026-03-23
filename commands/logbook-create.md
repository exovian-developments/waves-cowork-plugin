---
description: Create new development logbook for a ticket/task
allowed-tools: Read, Write, Glob, Grep, Task
---

# Command: logbook-create $ARGUMENTS

You are executing the logbook creation command. Follow these instructions exactly.

## Your Role

You are the main orchestrator for logbook creation. You will gather task information, detect UI requirements, analyze related code, resolve uncertainties using YAGNI/SOLID principles, and create a structured logbook with main and secondary objectives. You will dispatch the objective-generator agent for deep code analysis.

## Step -1: Prerequisites Check

Check if `ai_files/user_pref.json` exists.

IF NOT EXISTS:
```
⚠️ Missing configuration!

Please initialize the project first.
```
→ EXIT COMMAND

IF EXISTS:
1. Read `ai_files/user_pref.json`
2. Extract `preferred_language` → Use for all interactions
3. Extract `explanation_style` → Use for contextualizing questions
4. Extract `project_type` → Determines flow (software vs general)

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Parameter Check

Check if filename parameter was provided with the command.

IF NO parameter:
```
💡 TIP: You can run faster with:
   logbook-create TICKET-123.json
```

IF parameter provided:
- Validate filename format (must end in `.json`, no special chars except `-` and `_`)
- Store as `logbook_filename`

## Step 0.5: Smart Wave Detection

Before checking for existing logbooks, determine the target wave:

1. List `ai_files/waves/*/roadmap.json` to find all waves with roadmaps
2. Read each roadmap — find which has status "active" or "in_progress"
3. If only ONE wave is active → use that wave automatically
4. If the user provided context (ticket description, milestone name) that matches a specific milestone in a roadmap → use that wave
5. Only ask the user if genuinely ambiguous (multiple active waves, no clear match)
6. Store as `target_wave`
7. Create directory `ai_files/waves/[target_wave]/logbooks/` if it doesn't exist

## Step 1: Check Existing Logbook

If filename was provided, check if `ai_files/waves/[target_wave]/logbooks/[filename].json` exists.

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

Store as `ticket_title`.

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

Store as `ticket_description`.

## Step 2.1: UI Detection

After receiving the ticket description, analyze it for UI-related keywords:
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

Options:
1. Yes, I have visual references
2. No visual references available
3. UI is not part of this ticket

Choose:
```

Store as `has_ui_indicators = true/false` and collect visual reference paths if provided.

## Step 2.2: Description Clarity Validation

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

---

# FLOW A: SOFTWARE PROJECT LOGBOOK

## Step A1: Initial Code Tracing

```
🔍 Analyzing project to identify related code...
```

1. **Read project manifest:**
   - Load `ai_files/project_manifest.json`
   - Identify relevant layers and features

2. **Trace related code:**
   - Search for files, classes, functions related to the ticket
   - Identify patterns and conventions in related code

3. **Load project rules (if exists):**
   - Read `ai_files/project_rules.json`
   - Identify rules that apply

4. **Present analysis:**
```
📊 Initial analysis complete:

Related layers:
• [layer1] ([path])
• [layer2] ([path])

Identified reference files:
• [file1]
• [file2]

Applicable rules:
• #[id]: [rule description]

Is this information correct? (Yes/No/Adjust)
```

## Step A2: Uncertainty Detection and Resolution

Before generating objectives, identify ALL points of uncertainty.

### Step A2.1: Identify Uncertainties

Analyze the gathered information for uncertainties in these categories:
- Directory/Location: Where to create new files? Which module?
- File Strategy: Create new file or modify existing?
- Library Choice: Which library for dates/state management?
- Entry Points: New route? New controller method?
- Architecture: New layer needed?
- Naming: Convention for new components?
- Dependencies: Add new package? Use existing utility?
- Scope: Include error handling? Add logging? Tests?

### Step A2.2-A2.5: Resolve with YAGNI and SOLID

For implementation uncertainties, apply:
- **YAGNI**: "What is the MINIMUM needed?"
- **SOLID**: Focus on S (Single Responsibility) and D (Dependency Inversion)

For requirement-level uncertainties, formulate questions adapted to `explanation_style`.

### Step A2.6: Document Resolutions

Store all resolutions in a local structure for inclusion in logbook context.

## Step A3: Generate Main Objectives

Based on ticket, analysis, and resolved decisions, generate main objectives.

```
🎯 Proposed main objectives:

OBJECTIVE 1:
├─ Content: [verifiable outcome]
├─ Context: [business/technical context]
├─ Reference files:
│  • [file1]
│  • [file2]
└─ Rules: #[id1], #[id2]

Do you approve these objectives? (Yes/No/Adjust)
```

## Step A4: Generate Secondary Objectives with Completion Guide

Using the Task tool, invoke the **objective-generator** agent with:
- `main_objectives` - Array of approved main objectives
- `project_manifest_path` - "ai_files/project_manifest.json"
- `project_rules_path` - "ai_files/project_rules.json" (if exists)
- `preferred_language` - User's language
- `ui_requirements` - UI analysis if applicable
- `resolved_decisions` - Decisions made above

The agent will:
1. Deep trace from `scope.files`
2. Discover related code, patterns, dependencies
3. Read referenced rules
4. Incorporate UI requirements if present
5. Generate secondary objectives with `completion_guide`

Present secondary objectives for approval:
```
📋 Generated secondary objectives:

For Main Objective 1:
┌─────────────────────────────────────────────────────┐
│ 1.1 [Secondary objective content]                  │
│     Guide:                                          │
│     • [completion_guide item 1]                     │
│     • [completion_guide item 2]                     │
├─────────────────────────────────────────────────────┤
│ 1.2 [Secondary objective content]                  │
│     Guide:                                          │
│     • [completion_guide item 1]                     │
└─────────────────────────────────────────────────────┘

Do you approve these secondary objectives? (Yes/No/Adjust)
```

---

# FLOW B: GENERAL PROJECT LOGBOOK

## Step B1: Gather References and Standards

```
📚 To create effective objectives, I need to know:

What reference materials do you have available?
(Documents, URLs, examples, previous work)
```

Store as `references`.

```
Are there standards or guides you must follow?
(Style guides, regulations, methodologies)
```

Store as `standards` or empty.

## Step B2-B3: Generate Main and Secondary Objectives

Generate main and secondary objectives based on ticket and references.

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

Create logbook structure following the schema from `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/logbook_software_schema.json` (or logbook_general_schema.json for general projects).

## Validate Against Schema

Validate the generated logbook against the appropriate schema.

## Save File

Save to `ai_files/waves/[target_wave]/logbooks/[filename].json`

Ensure `ai_files/waves/[target_wave]/logbooks/` directory exists.

## Success Message

```
✅ Logbook created successfully!

📁 File: ai_files/waves/[target_wave]/logbooks/[filename].json

📊 Summary:
• Ticket: [title]
• Main objectives: [count]
• Secondary objectives: [count]
• Decisions resolved: [count]

🎯 First objective to work on:
[First secondary objective content]

Guide:
[completion_guide items]

💡 Useful commands:
• objectives-implement [filename] - Implement with auto-auditing
• logbook-update [filename] - Update progress manually
• resolution-create [filename] - Generate resolution when done

Ready to start!
```

END OF COMMAND
