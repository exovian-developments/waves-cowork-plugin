---
description: Analyze project and create structured manifest
allowed-tools: Read, Write, Glob, Grep, Bash, Task
---

# Plugin Command: manifest-create

You are executing the waves plugin manifest creation command. Follow these instructions exactly.

## Your Role

You are the main orchestrator for project manifest creation. Based on the project type and user familiarity, guide the appropriate flow to generate a comprehensive project manifest. For heavy analysis, launch specialized agents via the Task tool to work in parallel.

## Step -1: Prerequisites Check (CRITICAL)

Check if `ai_files/user_pref.json` exists.

IF NOT EXISTS, display:
```
⚠️ Missing configuration!

The file ai_files/user_pref.json was not found.

Please run first:
project-init

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
project-init

to complete the configuration.
```
→ EXIT COMMAND

**From this point, conduct ALL interactions in the user's preferred language.**

## Step 0: Command Explanation

Display in user's language:
```
📘 Command: manifest-create

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
1. Stop (use manifest-update instead)
2. Continue (overwrites existing file)

Choose 1 or 2:
```

IF "1" → Exit: "No changes made. Use manifest-update to update existing manifest."
IF "2" → Continue with warning: "⚠️ The file will be overwritten when complete"

## Step 2: Route to Appropriate Flow

Read `project_type` from user_pref.json:

IF `project_type === "software"` → Go to **FLOW A: SOFTWARE**
IF `project_type === "general"` → Go to **FLOW B: GENERAL**

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
  rules-create

  This command will establish coding conventions and
  structure for each layer of your architecture.
```

---

## FLOW A2.1: EXISTING SOFTWARE — KNOWN PROJECT

The user knows the project. Use 2 checkpoint questions + 6 parallel analyzers via Task tool.

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

**Phase 3: Deep Analysis via Task Tool**

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

Using the Task tool, invoke these 6 agents **in parallel**:

1. **entry-point-analyzer** - Find main entry points, trace execution flows
2. **navigation-mapper** - Map routes and pages (frontend components and navigation)
3. **flow-tracker** - Map API endpoints, data flows, backend structure
4. **dependency-auditor** - Audit dependencies, categorize by type
5. **architecture-detective** - Detect architecture patterns and principles
6. **feature-extractor** - Extract user-facing features and capabilities

Create a Task with all 6 agents to run in parallel:
```
Launch agents entry-point-analyzer, navigation-mapper, flow-tracker, dependency-auditor,
architecture-detective, feature-extractor in parallel to analyze project structure.
```

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
  rules-create [layer]

  Available layers: [layer1], [layer2], [layer3]
```

---

## FLOW A2.2: EXISTING SOFTWARE — UNKNOWN PROJECT

The user doesn't know the project. Zero questions, progress prints, use 6 parallel analyzers via Task tool, educational output.

Display:
```
🔍 Since this project is new to you, I'll analyze it in depth
without asking questions. I'll show progress as I analyze.

This will take a few minutes...
```

**Run parallel analysis same as A2.1 but with progress prints:**

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

Launch the same 6 agents via Task tool in parallel as in A2.1.

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

1. **Research Topic** - What is your research about?
2. **Methodology** (Qualitative, Quantitative, Mixed, Literature review)
3. **Theoretical Framework** - What theories or frameworks guide your research?
4. **Timeline/Milestones** - Key dates and deliverables
5. **Citation Format** (APA, MLA, Chicago, IEEE, etc.)

Generate `ai_files/general_manifest.json` with research structure.

---

## FLOW B2: NEW CREATIVE PROJECT

Ask 5 questions:

1. **Concept/Brief** - Describe your creative vision
2. **Visual/Artistic Style** - What's the visual direction?
3. **Color Palette/References** - Key colors and inspiration
4. **Assets Needed** - Images, videos, music, etc.
5. **Deliverables/Milestones** - What's the end product?

Generate `ai_files/general_manifest.json` with creative structure.

---

## FLOW B3: NEW BUSINESS PROJECT

Ask 9 Business Model Canvas questions:

1. **Value Proposition** - What value do you provide?
2. **Customer Segments** - Who are your customers?
3. **Channels** - How do you reach them?
4. **Revenue Streams** - How do you make money?
5. **Cost Structure** - What are your main costs?
6. **Key Resources** - What do you need?
7. **Key Activities** - What do you do?
8. **Key Partnerships** - Who do you work with?
9. **Customer Relationships** - How do you interact?

Generate `ai_files/general_manifest.json` with business canvas structure.

---

## FLOW B4: NEW GENERIC PROJECT

Ask 5 generic questions:

1. **Project Name** - What's it called?
2. **Description** - Brief overview
3. **Main Objectives** - What are you trying to achieve?
4. **Expected Deliverables** - What's the output?
5. **Milestones/Timeline** - Key dates

Generate `ai_files/general_manifest.json`.

---

## FLOW BE: EXISTING GENERAL PROJECT

**Phase 1: Directory Discovery via Task Tool**

Display:
```
📂 Analyzing your project structure...
```

Using Task tool, invoke **general-scanner** agent:
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

**Phase 3: Analysis via Task Tool**

Using Task tool, invoke agents to analyze selected scope in parallel.

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

## Validation

Before saving any manifest, validate against the appropriate schema:
- Software: `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/software_manifest_schema.json`
- General: `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/general_manifest_schema.json`

END OF COMMAND
