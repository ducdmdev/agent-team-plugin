# Agent Team

> Orchestrate parallel work via AI Agent Teams in Claude Code — with automated coordination, workspace tracking, and hook enforcement.

[![Claude Code Plugin](https://img.shields.io/badge/Claude_Code-Plugin-blueviolet)](https://github.com/ducdmdev/agent-team-plugin)
[![Live Demo](https://img.shields.io/badge/Live_Demo-Terminal_Dark-0f0f23)](https://ducdmdev.github.io/agent-team-plugin/)

## What It Does

This plugin adds **Agent Team pipeline skills** to Claude Code that decompose complex tasks into parallel work streams executed by multiple AI teammates across 3 stages.

- A **team lead** coordinates each stage but never writes code
- **3 pipeline stages** — plan (decompose), execute (build), audit (verify) — each with its own team
- **Teammates** (implementers, reviewers, researchers, analysts) work in parallel — each owning distinct files
- **Hooks** enforce discipline: block premature completion, nudge idle teammates
- **Inter-stage review agents** validate output before handoff between stages
- A **persistent workspace** tracks progress, tasks, issues, decisions, and generates a final report

## See It In Action

![Agent Team Demo](assets/demo.gif)

Here's what happens when you say: *"use agent team to refactor the auth module"*

```
You > use agent team to refactor the auth module

━━ Stage 1 — Plan ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [Planning team created: 2 Researchers + 1 Plan Reviewer]

  researcher-1:  FINDING: auth module has 3 sub-modules (token, session, middleware), relevance=high
  researcher-2:  FINDING: token interface shared across 4 consumers, relevance=high
  researcher-1:  FINDING: no tests for session management, relevance=medium
  plan-reviewer: PLAN_REVIEW: status=approved

  Team plan for: refactor auth module
  Archetype: implementation (auto-detected — say "change to [type]" to override)
  Complexity: standard

  Teammates (3):
  - auth-impl-1 (Implementer, plan-mode): token validation + middleware
  - auth-impl-2 (Implementer): session management
  - auth-reviewer (Reviewer): validate all changes

  Task breakdown:
  1. Refactor token validation logic        -> auth-impl-1
  2. Extract session management             -> auth-impl-2
  3. Update middleware to use new interfaces -> auth-impl-1 (blocked by #2)
  4. Review all changes                     -> auth-reviewer (blocked by #1, #3)

  Pipeline status: approved
  Workspace: .agent-team/0323-refactor-auth/

  [Planning team shut down]
  Approve?

You > y

━━ Stage 2 — Execute ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [Execution team created: 2 Implementers + 1 Reviewer + 1 Execute Reviewer]

  auth-impl-1:  PLAN_PROPOSAL #1: Adapter pattern for token validation...
  Lead:         PLAN_APPROVED #1
  auth-impl-1:  STARTING #1: Refactoring token validation, touching src/auth/token.ts
  auth-impl-2:  STARTING #2: Extracting session logic to src/auth/session.ts
  auth-impl-1:  COMPLETED #1: Token validation refactored, 3 files changed
  auth-impl-2:  BLOCKED #2: severity=medium, error_type=recoverable, need token interface shape
  Lead:         Recovery: forwarding token interface from impl-1 to impl-2
  auth-impl-2:  COMPLETED #2: Session management extracted, 2 files changed
  auth-impl-1:  STARTING #3: Updating middleware to use new interfaces
  auth-impl-1:  COMPLETED #3: Middleware updated, 1 file changed
  auth-reviewer: STARTING #4: Reviewing all changes across both scopes
  auth-reviewer: COMPLETED #4: 5 issues found — 0 high, 3 medium, 2 low

  exec-reviewer: EXECUTE_REVIEW: status=ready_for_audit, 4/4 tasks done, 6 files changed

  Pipeline status: executed
  [Execution team shut down]

━━ Stage 3 — Audit ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [Audit team created: 1 Reviewer + 1 Elegance Reviewer + 1 Audit Reviewer]

  reviewer:          Completion gate (8/8 passed):
                       ✓ Uncommitted changes  ✓ Build & tests    ✓ Lint/format
                       ✓ Integration          ✓ Security scan    ✓ Workspace issues
                       ✓ Plan completion      ✓ Documentation sync

  elegance-reviewer: ELEGANCE_REVIEW: overall_score=4.2
                       simplicity=4, consistency=5, readability=4, testability=4, minimal_impact=4
                       2 findings: 1 improve, 1 nitpick

  Lessons captured -> .agent-team/0323-refactor-auth/lessons.md
  Pattern library updated (1 new pattern from resolved BLOCKED issue)

  audit-reviewer:    AUDIT_REVIEW: status=approved

  Report: .agent-team/0323-refactor-auth/report.md
  Pipeline status: audited
  [Audit team shut down]

  Total: 6 files changed, 4/4 tasks completed, 0 open issues, elegance score 4.2/5
```

The workspace persists at `.agent-team/0323-refactor-auth/` with the full audit trail: tasks, issues, decisions, lessons, and final report.

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

### Pipeline Commands

| Command | When to Use | Example |
|---------|------------|---------|
| `/agent-team:start` | Full pipeline for any task type | "use agent team to refactor auth" |
| `/agent-team:plan` | Plan only, without executing | "plan the API redesign with a team" |
| `/agent-team:execute` | Resume from an approved plan | "execute the plan" |
| `/agent-team:audit` | Re-run verification on completed work | "audit the team output" |

## How It Works

```
plan --> [plan-review] --> user approval --> execute --> [execute-review] --> audit --> [audit-review] --> report
```

The pipeline is split into four stages, each a separate skill:

| Stage | What Happens |
|-------|-------------|
| **Start** | Entry point — detects team type, loads prior context, routes to the appropriate pipeline |
| **Plan** | Loads prior context, decomposes task into parallel streams, creates DAG with dependencies, presents plan for **user approval** |
| **Execute** | Creates team, initializes workspace, spawns teammates, coordinates work, resolves blockers, runs error recovery |
| **Audit** | Runs completion gates, elegance review, generates final report, captures lessons learned |

Each stage creates its own team:
- **Plan team** (2-3): Researchers scan the codebase + Analyst evaluates complexity + Plan Reviewer validates the plan
- **Execute team** (2-4): Implementers write code + Tester verifies + Reviewer validates + Execute Reviewer smoke-tests
- **Audit team** (2-3): Reviewer runs completion gates + Elegance Reviewer scores quality + Audit Reviewer validates report

Each stage has an optional **inter-stage review agent** (plan-reviewer, execute-reviewer, audit-reviewer) that validates output before the next stage begins.

**Plan-aware:** The plan stage scans for existing plan files (`docs/plans/`, `docs/specs/`, etc.). If found, it audits and uses the plan. If not found, it gathers context and creates one. The team decomposition derives from the approved plan.

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
| **Elegance Reviewer** | Post-execution quality assessment (auto-spawned by audit stage) | Read, Grep, Glob, Bash (read-only) |

### Team Types

The lead auto-detects the team type from your request and adapts the workflow accordingly:

| Team Type | When Used | Default Roles | Output |
|-----------|-----------|---------------|--------|
| **Implementation** | Build, refactor, fix, migrate code | Implementers + Reviewer + Tester | Code changes + report |
| **Research** | Investigate, analyze, compare approaches | Researchers + Analyst/Challenger | Findings report |
| **Audit** | Review, assess, evaluate against standards | Reviewers/Auditors + Challenger | Audit report |
| **Planning** | Design, architect, produce specs | Planners/Strategists + Researcher | Plan/spec document |
| **Hybrid** | Mixed work types (e.g., research then implement) | Mix from all roles | Standard report |

The team type determines which completion checks apply and what the final report looks like. You can override the auto-detected type during plan approval. The start stage auto-detects the type and routes to the plan stage with appropriate defaults.

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

Thirteen hooks enforce team discipline and provide DAG-aware coordination:

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

### ValidateTaskGraph (SubagentStart)

Validates `task-graph.json` schema and detects circular dependencies before each teammate is spawned:
- Checks: valid JSON, nodes have required fields, dependency references resolve, no cycles
- Blocks teammate spawn if task-graph is invalid or has circular dependencies
- Gracefully allows spawn if task-graph doesn't exist yet (workspace may still be initializing)

### WorkspaceCompleteness (SubagentStart)

Validates all 4 tracking files and required fields before teammate spawn:
- Checks `progress.md`, `tasks.md`, `issues.md`, `task-graph.json` exist in the workspace
- Validates that `progress.md` contains required fields (`Archetype`, `Pipeline status`)
- Blocks teammate spawn if workspace is incomplete or missing required metadata

### PlanRevisionLimit (PreToolUse(SendMessage))

Enforces max 2 plan-mode revision rounds per teammate:
- Counts `PLAN_REVISION` messages sent to each teammate
- Blocks the third `PLAN_REVISION` with guidance to approve or reassign
- Prevents infinite plan-mode loops that waste context and time

### PreShutdownCommit (PreToolUse(TeamDelete))

Blocks TeamDelete if any owned files have uncommitted changes:
- Reads `file-locks.json` to determine which files each teammate owns
- Checks `git status` for uncommitted changes in owned files
- Blocks team deletion until all owned files are committed or explicitly abandoned

### SubagentStart / SubagentStop

Tracks teammate lifecycle in `events.log`:
- Logs spawn and stop events with timestamps and teammate metadata
- Provides post-mortem analysis data

### ComputeCriticalPath (TaskCompleted)

Recomputes and displays the critical path after each task completion:
- Reads `task-graph.json` for the dependency graph
- Outputs remaining critical path and identifies blocked critical tasks
- Informational only — always allows task completion

### DetectResume (SessionStart)

Detects resumable workspaces at session start:
- Scans for incomplete `task-graph.json` files in `.agent-team/`
- Validates completed task output files via git timestamps (valid/stale/missing)
- Outputs resume context with options to resume or start fresh

### CheckIntegrationPoint (TaskCompleted)

Detects when convergence points become fully unblocked:
- Checks if all upstream tasks of a convergence point are completed
- Nudges the lead to verify interface compatibility before downstream task starts
- Informational only — silent when no convergence point is ready

All hooks degrade gracefully — exit 0 if `jq` is missing.

## Workspace

Each team creates a persistent workspace at `.agent-team/{team-name}/` in your project, where `{team-name}` uses an `MMDD-` date prefix for uniqueness (e.g., `0304-refactor-auth`):

```
.agent-team/0304-refactor-auth/
├── progress.md      # Team status, members, decisions, handoffs
├── tasks.md         # Task ledger with status tracking
├── issues.md        # Issue tracker with severity and resolution
├── file-locks.json  # File ownership map (teammate -> files/directories)
├── task-graph.json  # DAG: task dependencies, critical path, convergence points
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
│   ├── validate-task-graph.sh       # ValidateTaskGraph hook (SubagentStart)
│   ├── check-workspace-completeness.sh  # WorkspaceCompleteness hook
│   ├── enforce-plan-revision-limit.sh   # PlanRevisionLimit hook
│   ├── enforce-pre-shutdown-commit.sh   # PreShutdownCommit hook
│   ├── track-teammate-lifecycle.sh  # SubagentStart/Stop hook
│   ├── setup-worktree.sh            # Worktree creation for isolation mode
│   ├── merge-worktrees.sh           # Worktree merge in Phase 5
│   ├── compute-critical-path.sh     # ComputeCriticalPath hook
│   ├── detect-resume.sh             # DetectResume hook
│   ├── check-integration-point.sh   # CheckIntegrationPoint hook
│   ├── record-demo.sh              # Demo recording utility
│   └── generate-demo-cast.sh       # Demo asciicast generator
├── skills/
│   ├── start/
│   │   └── SKILL.md             # Pipeline entry point — type detection + routing
│   ├── plan/
│   │   ├── SKILL.md             # Plan stage — decomposition + DAG + approval
│   │   ├── references/          # Prior context loading, plan-mode protocol
│   │   ├── examples/            # Plan proposal examples
│   │   └── agents/              # Plan-reviewer, researcher, analyst agents
│   ├── execute/
│   │   ├── SKILL.md             # Execute stage — spawn + coordination + recovery
│   │   ├── references/          # Communication protocol, coordination patterns, error recovery
│   │   └── agents/              # Spawn templates, execute-reviewer agent
│   └── audit/
│       ├── SKILL.md             # Audit stage — gates + elegance + report + lessons
│       ├── references/          # Completion gates, elegance rubric, report format
│       ├── examples/            # Lessons-learned examples
│       └── agents/              # Audit-reviewer, elegance-reviewer, reviewer agents
├── docs/
│   ├── teammate-roles.md          # Role definitions and selection guide
│   ├── workspace-templates.md     # Workspace file templates
│   ├── team-archetypes.md         # Team type definitions and phase profiles
│   └── custom-roles.md            # Template for project-specific roles
├── tests/
│   ├── run-tests.sh               # Test runner (16 test files)
│   ├── lib/
│   │   └── test-helpers.sh        # Shared test utilities
│   ├── hooks/                     # Hook-specific tests
│   └── structure/                 # Plugin structure validation tests
├── CLAUDE.md
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

