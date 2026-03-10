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

## See It In Action

![Agent Team Demo](demo.gif)

Here's what happens when you say: *"use agent team to refactor the auth module"*

```
You > use agent team to refactor the auth module

Phase 1 - Analyze
  Identified 3 independent streams: token validation, session management, middleware
  No file overlaps detected

Phase 2 - Plan (you approve before anything starts)
  Team type: implementation (auto-detected)
  Proposed team:
    auth-impl-1 (Implementer) — owns src/auth/token.ts, src/auth/validate.ts
    auth-impl-2 (Implementer) — owns src/auth/session.ts, src/middleware/auth.ts
    auth-reviewer (Reviewer)  — reviews all changes
  Approve? [y/n]

You > y

Phase 3 - Create
  Created team "0306-refactor-auth"
  Initialized workspace at .agent-team/0306-refactor-auth/
  Spawned 3 teammates in parallel

Phase 4 - Coordinate
  auth-impl-1:  STARTING #1: Refactoring token validation, touching src/auth/token.ts
  auth-impl-2:  STARTING #2: Extracting session logic to src/auth/session.ts
  auth-impl-1:  COMPLETED #1: Token validation refactored, 3 files changed
  auth-impl-2:  COMPLETED #2: Session management extracted, 2 files changed
  auth-impl-1:  HANDOFF #3: New token interface ready for reviewer
  auth-reviewer: STARTING #4: Reviewing all changes across both scopes
  auth-reviewer: COMPLETED #4: 0 high, 2 medium, 1 low issues found

Phase 5 - Synthesize
  All tasks completed (4/4)
  Completion gate: PASSED (build, tests, lint, integration)
  Report: .agent-team/0306-refactor-auth/report.md
  Team shut down. Total: 6 files changed, 0 open issues.
```

The workspace persists at `.agent-team/0306-refactor-auth/` with the full audit trail: tasks, issues, decisions, and final report.

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

### Archetype-Specific Commands

| Command | When to Use | Example |
|---------|------------|---------|
| `/agent-implement` | Build, refactor, fix, migrate code | "implement the new auth module in parallel" |
| `/agent-research` | Investigate, analyze, compare | "research database options with a team" |
| `/agent-audit` | Review, assess, evaluate | "audit security with parallel reviewers" |
| `/agent-plan` | Design, architect, produce specs | "design the API with a planning team" |
| `/agent-team` | Mixed work types or unsure | "research then implement the caching layer" |

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
| **Leader** | Coordinate team, track progress, never writes code | TaskCreate, TaskUpdate, SendMessage, Read, Write (workspace only) |
| **Implementer** | Write code, create files, build features | Read, Write, Edit, Bash, Grep, Glob |
| **Reviewer** | Validate quality, find issues | Read, Grep, Glob, Bash (read-only) |
| **Researcher** | Investigate, analyze, report findings | Read, Grep, Glob, WebFetch, WebSearch |
| **Challenger** | Stress-test assumptions, find edge cases | Read, Grep, Glob, Bash, WebSearch |
| **Tester** | Run tests, verify builds, check runtime behavior | Read, Grep, Glob, Bash |
| **Analyst** | Deep-dive into data, metrics, performance | Read, Grep, Glob, Bash (read-only) |
| **Planner** | Produce specs, architecture designs, decision docs | Read, Write (docs only), Grep, Glob |
| **Writer** | Produce documentation, ADRs, guides | Read, Write (docs only), Grep, Glob |
| **Strategist** | Evaluate trade-offs, recommend direction | Read, Grep, Glob, WebFetch, WebSearch |
| **Auditor** | Systematic checks against standards/checklists | Read, Grep, Glob, Bash (read-only) |
| **Scout** | Quick recon — scan and report structure | Read, Grep, Glob, Bash (read-only) |

### Team Types

The lead auto-detects the team type from your request and adapts the workflow accordingly:

| Team Type | When Used | Default Roles | Output |
|-----------|-----------|---------------|--------|
| **Implementation** | Build, refactor, fix, migrate code | Implementers + Reviewer + Tester | Code changes + report |
| **Research** | Investigate, analyze, compare approaches | Researchers + Analyst/Challenger | Findings report |
| **Audit** | Review, assess, evaluate against standards | Reviewers/Auditors + Challenger | Audit report |
| **Planning** | Design, architect, produce specs | Planners/Strategists + Researcher | Plan/spec document |
| **Hybrid** | Mixed work types (e.g., research then implement) | Mix from all roles | Standard report |

The team type determines which completion checks apply and what the final report looks like. You can override the auto-detected type during plan approval.

### Communication Protocol

Teammates use structured messages for clean coordination:

```
STARTING #N:   what I plan to do, which files I'll touch
COMPLETED #N:  what I did, files changed, any concerns
BLOCKED #N:    severity={level}, what's blocking, impact
HANDOFF #N:    what I produced that another teammate needs
QUESTION:      what I need to know
```

Optional extended messages for long-running tasks:

```
PROGRESS #N:   milestone={desc}, percent={0-100}, eta={minutes}
CHECKPOINT #N: intermediate results, artifacts, ready_for=[task IDs]
```

## Hooks

Five hooks enforce team discipline automatically:

### TaskCompleted

Blocks premature task completion by checking:
- Workspace exists with all tracking files (`progress.md`, `tasks.md`, `issues.md`)
- Implementation tasks have actual file changes (via `git status`)
- Supports scoped checks using `task_id` and `teammate_name`

### TeammateIdle

Nudges idle teammates that still have in-progress tasks:
- Counts assigned in-progress tasks
- Loop protection: allows idle after 3 consecutive blocks (teammate is genuinely stuck)

### SessionStart (compact)

Auto-recovers workspace context after context compaction:
- Detects active workspaces and injects recovery context
- Skips completed workspaces (status: done)

### PreToolUse (Write|Edit)

Enforces file ownership boundaries:
- Reads `file-locks.json` from the workspace to determine ownership
- First violation: warns (exit 0). Second violation: blocks (exit 2)
- Workspace files are always allowed regardless of ownership

### SubagentStart / SubagentStop

Tracks teammate lifecycle in `events.log`:
- Logs spawn and stop events with timestamps and teammate metadata
- Provides post-mortem analysis data

All hooks degrade gracefully — exit 0 if `jq` is missing.

## Workspace

Each team creates a persistent workspace at `.agent-team/{team-name}/` in your project, where `{team-name}` uses an `MMDD-` date prefix for uniqueness (e.g., `0304-refactor-auth`):

```
.agent-team/0304-refactor-auth/
├── progress.md      # Team status, members, decisions, handoffs
├── tasks.md         # Task ledger with status and dependencies
├── issues.md        # Issue tracker with severity and resolution
├── file-locks.json  # File ownership map (teammate -> files/directories)
├── events.log       # Structured JSON event log for post-mortem analysis
└── report.md        # Final report (generated at completion)
```

- **Persists** after team deletion — it's the permanent record
- **Shared** — all teammates can read for context
- **Gitignored** — coordination artifacts, not deliverables. Automatically added to `.gitignore` during Phase 3 workspace setup if not already excluded.

## Plugin Structure

```
agent-team-plugin/
├── .claude-plugin/
│   ├── plugin.json              # Plugin metadata
│   └── marketplace.json         # Marketplace registry
├── hooks/
│   └── hooks.json               # Hook definitions (${CLAUDE_PLUGIN_ROOT} paths)
├── scripts/
│   ├── verify-task-complete.sh      # TaskCompleted hook
│   ├── check-teammate-idle.sh       # TeammateIdle hook
│   ├── recover-context.sh           # SessionStart(compact) hook
│   ├── check-file-ownership.sh      # PreToolUse(Write|Edit) hook
│   ├── track-teammate-lifecycle.sh  # SubagentStart/Stop hook
│   ├── setup-worktree.sh            # Worktree creation for isolation mode
│   └── merge-worktrees.sh           # Worktree merge in Phase 5
├── skills/
│   ├── agent-team/
│   │   └── SKILL.md             # Hybrid/catch-all orchestrator
│   ├── agent-implement/
│   │   └── SKILL.md             # Implementation teams
│   ├── agent-research/
│   │   └── SKILL.md             # Research teams
│   ├── agent-audit/
│   │   └── SKILL.md             # Audit teams
│   └── agent-plan/
│       └── SKILL.md             # Planning teams
├── docs/
│   ├── shared-phases.md           # Shared phase logic for all archetype skills
│   ├── teammate-roles.md          # Role definitions and spawn templates
│   ├── coordination-patterns.md # Conflict resolution and handoff patterns
│   ├── workspace-templates.md   # Workspace file templates for Phase 3
│   ├── report-format.md         # Final report specification
│   ├── team-archetypes.md       # Team type definitions and phase profiles
│   └── custom-roles.md          # Template for project-specific roles
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

For teams larger than 4, verify: (1) every stream has zero file overlap, (2) cross-communication is minimal, (3) workspace churn is manageable.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed version history.

## License

[MIT](LICENSE)
