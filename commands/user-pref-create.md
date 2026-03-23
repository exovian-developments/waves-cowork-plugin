---
description: Create detailed user preferences (advanced setup)
allowed-tools: Read, Write
---

# Plugin Command: user-pref-create

You are executing the waves plugin advanced user preferences creation command. Follow these instructions exactly.

## Your Role

You are the main orchestrator for detailed user preference configuration. Unlike `project-init` which asks 5 essential questions, this command walks the user through ALL available preferences from the schema. This is NOT an agent command — conduct it directly in the main thread.

## Step 0: Language and Existing Check

1. Display welcome in English first:
   ```
   📘 Command: user-pref-create

   🌍 What language do you prefer?
   Examples: English, Español, Português, Français, Deutsch, 日本語
   ```

2. Wait for response. Store as `preferred_language`.

3. Check if `ai_files/user_pref.json` exists.
   - IF EXISTS → Ask in user's language: "⚠️ Preferences already exist. Overwrite? (Yes/No)"
   - IF No → Exit with: "Use project-init (update variant) to modify existing preferences."

**From this point, conduct ALL interactions in the user's chosen language.**

## Step 1: Section 1 — LLM Guidance

Read `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/user_pref_schema.json` for field definitions.

Display:
```
📋 SECTION 1: LLM Behavior

These settings control how the AI assistant behaves:
```

For each field in `llm_guidance` section of schema, show:
```
📌 [field_name]
   Description: [from schema description]
   Default: [default value]

   Keep default or change? (Enter to keep, or type new value):
```

**Fields to ask about:**
- `explain_before_answering` — Should I explain my reasoning before answering?
- `ask_before_assuming` — Should I ask for clarification instead of assuming?
- `suggest_multiple_options` — Should I present multiple approaches?
- `allow_self_correction` — Should I correct myself if I find mistakes?
- `persistent_personality` — Should I maintain consistent personality across sessions?
- `feedback_loop_enabled` — Should I ask for feedback to improve?

Collect and store all responses.

## Step 2: Section 2 — User Profile

Display:
```
📋 SECTION 2: User Profile

Tell me about yourself and your preferences:
```

Ask for each field:

**Field 1: Name**
```
👤 What is your name?
```

**Field 2: Communication Tone**
```
💬 How do you prefer I communicate with you?

Enum options:
1. formal - Professional and respectful
2. neutral - Balanced, no particular tone
3. friendly - Warm and approachable
4. friendly_with_sarcasm - Casual with witty remarks
5. funny - Humorous and light-hearted
6. strict - Direct and no-nonsense

Choose 1-6 or describe your preference:
```

**Field 3: Emoji Usage**
```
😊 Do you like me to use emojis in my responses?

1. Yes (use emojis)
2. No (text only)

Choose 1 or 2:
```

**Field 4: Technical Background**
```
💻 Describe your technical background and role.

Example: "Senior full-stack developer with 10 years experience"
         "Data scientist learning cloud architecture"
         "Product manager without technical background"

Your background:
```

**Field 5: Explanation Style**
```
📚 What level of detail do you prefer in explanations?

Enum options:
1. direct - Short, concise answers
2. balanced - Explanation with technical context
3. teaching - Detailed step-by-step explanations
4. academic - Theoretical and thorough
5. pragmatic - Focus on practical application
6. brief - Minimal explanation, results only

Choose 1-6 or describe your preference:
```

**Field 6: Learning Style**
```
🧠 How do you prefer to learn?

Enum options:
1. visual - Diagrams, flowcharts, screenshots
2. reading - Text explanations and documentation
3. examples - Code samples and practical examples
4. interactive - Q&A and dialogue
5. mixed - Combination of multiple styles

Choose 1-5 or describe your preference:
```

Collect and store all responses.

## Step 3: Section 3 — Output Preferences

Display:
```
📋 SECTION 3: Output Preferences

How would you like me to format my responses?
```

Ask for each field:

**Field 1: Format Code with Comments**
```
📝 Should I add explanatory comments in code examples?

1. Yes - Comprehensive comments
2. No - Minimal/no comments

Choose 1 or 2:
```

**Field 2: Block Comment Tags**
```
🏷️ What comment tags should I use for block comments?

Default: "<!-- START -->" and "<!-- END -->"

Keep default or specify:
Start tag: [enter]
End tag: [enter]
```

**Field 3: Code Language for Examples**
```
💻 What's your primary programming language for examples?

Examples: typescript, javascript, python, java, go, rust, etc.

Your language (or "mixed" for project-dependent):
```

**Field 4: Use Inline Explanations**
```
💭 Should I include explanations within code blocks?

1. Yes - Inline explanations for key lines
2. No - Code only, explanations separate

Choose 1 or 2:
```

**Field 5: Highlight Gotchas**
```
⚠️ Should I explicitly highlight common pitfalls and gotchas?

1. Yes - Call out potential issues
2. No - Let me discover them

Choose 1 or 2:
```

**Field 6: Response Structure**
```
🏗️ How should I structure longer responses?

Suggested sections (choose all that apply):
1. summary - Brief overview first
2. details - Detailed explanation
3. code - Code examples if applicable
4. gotchas - Common pitfalls
5. alternatives - Other approaches
6. next_steps - Recommended follow-up

Enter numbers 1-6, comma-separated (e.g., 1,2,3,5):
```

Collect and store all responses.

## Step 4: Section 4 — Project Context

Display:
```
📋 SECTION 4: Project Context

Information about your project type:
```

Ask for:

**Field 1: Project Type**
```
🎯 What type of project are you working on?

1. software - Code, applications, systems
2. general - Research, business, creative, other

Choose 1 or 2:
```

**Field 2: Project Familiarity**
```
📚 How familiar are you with this project?

1. Well known - I understand its structure
2. New - I'm learning or starting from scratch

Choose 1 or 2:
```

Collect and store responses.

## Step 5: Show Comprehensive Summary

Display all selected values in a formatted summary:
```
📋 Your complete configuration:

═══════════════════════════════════════
LLM BEHAVIOR SETTINGS
═══════════════════════════════════════
[list all settings with values]

═══════════════════════════════════════
USER PROFILE
═══════════════════════════════════════
Name: [name]
Communication tone: [tone]
Emoji usage: [yes/no]
Technical background: [description]
Explanation style: [style]
Learning style: [style]

═══════════════════════════════════════
OUTPUT PREFERENCES
═══════════════════════════════════════
Code comments: [yes/no]
Comment tags: [start] / [end]
Primary language: [language]
Inline explanations: [yes/no]
Highlight gotchas: [yes/no]
Response structure: [section1, section2, ...]

═══════════════════════════════════════
PROJECT CONTEXT
═══════════════════════════════════════
Project type: [software/general]
Familiarity: [well known/new]

═══════════════════════════════════════

Save this configuration? (Yes/No/Edit [section_number]):
```

**If "Edit [section_number]":**
- Section 1 = LLM Behavior
- Section 2 = User Profile
- Section 3 = Output Preferences
- Section 4 = Project Context

Return to that section and re-ask all fields in that section.

**If "No":**
- Exit with: "Configuration cancelled. No files were created."

## Step 6: Generate user_pref.json

1. Read schema from `${CLAUDE_PLUGIN_ROOT}/skills/waves-protocol/references/user_pref_schema.json`.
2. Create `ai_files/user_pref.json` with all user-provided values.
3. Include all fields from schema with user values or defaults.
4. Set `created_at` to current UTC ISO 8601 timestamp.
5. Set `schema_version` from the schema file.
6. Validate the generated file against schema structure and types.

If validation fails, show user the error and offer to re-do relevant section.

## Step 7: Update CLAUDE.md

1. Check if `CLAUDE.md` exists in project root.

**IF EXISTS:**
- Read current content
- If it doesn't already have the Waves framework training block (check for "Waves Framework — Agent Operating Protocol"), prepend the full Waves training block as defined in the `/waves:project-init` command. This includes the Agent Operating Protocol, directory structure, artifact hierarchy, required agent behaviors, wave lifecycle, and available commands.
- If the block already exists but only has the old "User Preferences" header, replace it with the full Waves training block.

**IF NOT EXISTS:**
- Create new `CLAUDE.md` with the full Waves framework training block as defined in `/waves:project-init`.

## Step 8: Success Message

Display in user's language:
```
✅ Complete preferences created!

📁 Files created/updated:
  • ai_files/user_pref.json (created)
  • CLAUDE.md (updated)

🎨 Your personalization:

Non-default settings:
[List only fields that differ from schema defaults]

Example:
  • Communication tone: friendly_with_sarcasm
  • Learning style: visual
  • Response structure: summary, code, alternatives

💡 To modify later:
  Use project-init (update variant) for quick changes,
  or user-pref-create again for full customization.

⚠️ IMPORTANT: Restart your Claude Code session to load the new preferences.

📚 Your preferences will now guide:
  • How I communicate with you
  • Code formatting and examples
  • Explanation depth and style
  • Response organization

Ready to work with your preferences applied!
```

## Step 9: Final Confirmation

Display:
```
✅ Setup complete!

Your configuration is ready. Preferences will be applied after restart.

Next steps:
1. Restart Claude Code to load preferences
2. Run: project-init (if not already done)
3. Run: manifest-create (to analyze your project)

Questions? See the waves documentation.
```

END OF COMMAND
