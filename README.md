# Agent Team

> Orchestrate parallel work via AI Agent Teams in Claude Code — with automated coordination, workspace tracking, and hook enforcement.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude_Code-Plugin-blueviolet)](https://github.com/ducdmdev/agent-team-plugin)

## What It Does

This plugin adds an **Agent Team** skill to Claude Code that decomposes complex tasks into parallel work streams executed by multiple AI teammates.

- A **team lead** coordinates but never writes code
- **Teammates** (implementers, reviewers, researchers) work in parallel — each owning distinct files
- **Hooks** enforce discipline: block premature completion, nudge idle teammates
- A **persistent workspace** tracks progress, tasks, issues, decisions, and generates a final report

## Prerequisites

| Requirement | Details |
|------------|---------|
| Claude Code CLI | With plugin support |
| Feature flag | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in shell env or `settings.json` |
| `jq` | Required by hook scripts. Hooks skip gracefully if missing |
| `git` | Optional — used for file change detection |

## Installation

### From Marketplace

First, add the marketplace:

```bash
claude plugin marketplace add ducdmdev/agent-team-plugin
```

Then install:

```bash
claude plugin install agent-team
```

### Local Development

```bash
claude --plugin-dir /path/to/agent-team-plugin
```

## Usage

Trigger the skill with phrases like:

```
> create a team to refactor the auth module
> work in parallel on the API endpoints and frontend components
> use agent team to build the new dashboard feature
> spawn teammates to review the PR from security, performance, and correctness angles
```

The skill activates when your task has **2+ independent work streams**. If the task is better handled sequentially, the lead will tell you.

## How It Works

```
Phase 1          Phase 2          Phase 3          Phase 4          Phase 5
Analyze    -->   Present Plan --> Create Team -->  Coordinate  -->  Synthesize
                 (user approves)  (spawn agents)   (track work)     (report)
```

| Phase | What Happens |
|-------|-------------|
| **1. Analyze** | Identify independent streams, dependencies, file ownership |
| **2. Plan** | Present teammate roles, task breakdown, and dependencies. **You approve before anything starts** |
| **3. Create** | Create team, initialize workspace, create tasks, spawn teammates with roles and protocols |
| **4. Coordinate** | Monitor progress, update workspace, resolve blockers, route handoffs between teammates |
| **5. Synthesize** | Collect results, verify integration, generate final report, shut down team |

### Teammate Roles

| Role | Purpose | Tools |
|------|---------|-------|
| **Implementer** | Write code, create files, build features | Read, Write, Edit, Bash, Grep, Glob |
| **Reviewer** | Validate quality, find issues | Read, Grep, Glob, Bash |
| **Researcher** | Investigate, analyze, report findings | Read, Grep, Glob, WebFetch, WebSearch |
| **Challenger** | Stress-test assumptions, find edge cases | Read, Grep, Glob, Bash, WebSearch |

### Communication Protocol

Teammates use structured messages for clean coordination:

```
STARTING #N:   what I plan to do, which files I'll touch
COMPLETED #N:  what I did, files changed, any concerns
BLOCKED #N:    severity={level}, what's blocking, impact
HANDOFF #N:    what I produced that another teammate needs
QUESTION:      what I need to know
```

## Hooks

Two hooks enforce team discipline automatically:

### TaskCompleted

Blocks premature task completion by checking:
- Workspace exists with all tracking files (`progress.md`, `tasks.md`, `issues.md`)
- Implementation tasks have actual file changes (via `git status`)

### TeammateIdle

Nudges idle teammates that still have in-progress tasks:
- Counts assigned in-progress tasks
- Loop protection: allows idle after 3 consecutive blocks (teammate is genuinely stuck)

Both hooks degrade gracefully — exit 0 if `jq` is missing.

## Workspace

Each team creates a persistent workspace at `.agent-team/{team-name}/` in your project:

```
.agent-team/{team-name}/
├── progress.md     # Team status, members, decisions, handoffs
├── tasks.md        # Task ledger with status and dependencies
├── issues.md       # Issue tracker with severity and resolution
└── report.md       # Final report (generated at completion)
```

- **Persists** after team deletion — it's the permanent record
- **Shared** — all teammates can read for context
- **Gitignored** — coordination artifacts, not deliverables

## Plugin Structure

```
agent-team-plugin/
├── .claude-plugin/
│   ├── plugin.json              # Plugin metadata
│   └── marketplace.json         # Marketplace registry
├── hooks/
│   └── hooks.json               # Hook definitions (${CLAUDE_PLUGIN_ROOT} paths)
├── scripts/
│   ├── verify-task-complete.sh  # TaskCompleted hook
│   └── check-teammate-idle.sh   # TeammateIdle hook
├── skills/
│   └── agent-team/
│       └── SKILL.md             # Main skill (team lead orchestrator)
├── docs/
│   ├── worker-roles.md          # Role definitions and spawn templates
│   ├── coordination-patterns.md # Conflict resolution and handoff patterns
│   └── report-format.md         # Final report specification
├── package.json
├── CLAUDE.md
├── LICENSE
└── README.md
```

## Troubleshooting

### Agent Teams not available

```
Error: TeamCreate tool is not available
```

Set the feature flag:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

Or in Claude Code `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### `jq` not installed

Hooks skip checks silently without `jq`. Install for full enforcement:

```bash
brew install jq          # macOS
sudo apt install jq      # Ubuntu/Debian
scoop install jq         # Windows
```

### Hooks not firing

1. Verify installed: `claude plugin list`
2. Check `hooks/hooks.json` exists
3. Ensure scripts are executable: `chmod +x scripts/*.sh`

### Team size limits

- **Max 4** for mixed teams (implementers + reviewers)
- **Up to 6** if extras are read-only (researchers, reviewers)
- Break larger tasks into sequential phases

## License

[MIT](LICENSE)
