---
description: Show the installed Waves plugin version
allowed-tools: Read
---

# /waves:version — Show Waves version

Report the installed Waves plugin (framework) version. Useful after `/plugin install` or `/plugin update` to confirm which version is actually loaded.

## Steps

1. Read the plugin version from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` → `.version`.
2. Read the repository URL from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` → `.repository` (optional decoration).
3. Display concisely (two lines max, no other side effects):

```
Waves plugin (framework): v<plugin_version>
Source: <repository_url>
```

   - IF `.repository` is absent or empty, omit the `Source:` line entirely.

That is the entire output. No other artifact reads, no marker checks, no initialization status, no migration history. Each of those concerns belongs to its own command (`/waves:project-init` to initialize, `/waves:upgrade` to migrate artifacts).
