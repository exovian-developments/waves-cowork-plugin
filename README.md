# Waves™ Plugin for Claude

Product development framework for the AI agent era — from idea validation to production delivery.

Works with **Claude Code** and **Claude Desktop (Cowork mode)**.

## Install

### Option 1: Marketplace (recommended)

Add the marketplace and install:

```bash
claude plugin marketplace add exovian-developments/waves-plugin
claude plugin install waves
```

Updates are automatic when the marketplace is refreshed.

### Option 2: Direct install from GitHub

```bash
claude plugin install exovian-developments/waves-plugin
```

### Option 3: Download .plugin file

Download `waves.plugin` from [Releases](https://github.com/exovian-developments/waves-plugin/releases) and open it in Claude Desktop.

## What it does

Waves gives Claude the complete product lifecycle:

- **Feasibility** → Validate your idea with Monte Carlo and Bayesian analysis
- **Foundation** → Compact feasibility into validated facts
- **Blueprint** → Define the product: capabilities, flows, rules, metrics
- **Roadmap** → Plan delivery in phases with milestones
- **Logbook** → Track implementation with objectives and session continuity

It supports software projects (any language/framework) and general projects (academic, creative, business).

## Commands

| Command | Description |
|---------|-------------|
| `/project-init` | Set up preferences and project context (start here) |
| `/feasibility-analyze` | Pre-blueprint feasibility with Monte Carlo and Bayesian projections |
| `/foundation-create` | Compact feasibility into validated facts for blueprint |
| `/blueprint-create` | Create complete product blueprint from foundation |
| `/manifest-create` | Analyze your project and create a comprehensive manifest |
| `/manifest-update` | Detect changes and update the manifest |
| `/rules-create` | Extract coding rules or define standards |
| `/rules-update` | Update rules based on code changes |
| `/roadmap-create` | Create roadmap with phases, milestones, and dependencies |
| `/roadmap-update` | Update roadmap progress and decisions |
| `/logbook-create` | Start a development logbook for a ticket or task |
| `/logbook-update` | Track progress and add context entries |
| `/objectives-implement` | Implement objectives with automatic code auditing |
| `/resolution-create` | Generate a resolution document from a completed logbook |
| `/user-pref-create` | Advanced preferences setup |
| `/user-pref-update` | Modify existing preferences |

## Getting started

### New product (from scratch)

1. Run `/project-init`
2. Run `/feasibility-analyze`
3. Run `/foundation-create`
4. Run `/blueprint-create`
5. Run `/roadmap-create`
6. Run `/logbook-create` for each ticket

### Existing project

1. Run `/project-init`
2. Run `/manifest-create`
3. Run `/rules-create`
4. Run `/logbook-create` for each ticket

## Framework documentation

For the full Waves™ Framework specification, see [exovian-developments/waves](https://github.com/exovian-developments/waves).

## Version

v1.3.1 — Aligned with Waves™ Framework v1.3.1

## License

Apache-2.0
