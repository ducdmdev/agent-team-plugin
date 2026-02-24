# Agent Team Plugin

Orchestrates parallel work via Agent Teams with automated coordination, workspace tracking, and hook enforcement for Claude Code.

## What It Does

This plugin adds an **Agent Team** skill to Claude Code that lets you decompose complex tasks into parallel work streams executed by multiple AI teammates. A team lead coordinates the work while dedicated teammates implement, review, or research in parallel — each owning distinct files to avoid conflicts.

The plugin enforces team discipline through hooks that prevent premature task completion and nudge idle teammates, and maintains a persistent workspace that tracks progress, tasks, issues, and a final report.

## Prerequisites

- **Claude Code CLI** (with plugin support)
- **Agent Teams feature flag**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` must be set in your shell environment or Claude Code `settings.json` env
- **jq** — required by hook scripts for parsing JSON input. Hooks degrade gracefully (skip checks) if `jq` is not installed
- **git** (optional) — used by the `verify-task-complete` hook to detect file changes. If not in a git repo, the check is skipped

## Installation

```bash
claude plugin install agent-team-plugin
```

Or for local development, use the `--plugin-dir` flag:

```bash
claude --plugin-dir /path/to/agent-team-plugin
```

## Plugin Structure

```
agent-team-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata (name, description, version)
├── hooks/
│   └── hooks.json           # Hook definitions (TaskCompleted, TeammateIdle)
├── scripts/
│   ├── verify-task-complete.sh   # Blocks premature task completion
│   └── check-teammate-idle.sh    # Nudges idle teammates with pending work
├── skills/
│   └── agent-team/
│       └── SKILL.md         # Main skill definition (team lead orchestrator)
├── docs/
│   ├── worker-roles.md          # Role definitions and spawn templates
│   ├── coordination-patterns.md # Conflict resolution and handoff patterns
│   └── report-format.md         # Final report format specification
├── package.json
├── LICENSE
└── README.md
```

## Usage

Trigger the skill by including phrases like:

- "create a team to ..."
- "work in parallel on ..."
- "use agent team for ..."
- "spawn teammates to ..."

The skill activates when your task has 2 or more independent work streams that benefit from parallel execution. If the task is better handled sequentially, the lead will tell you and work in a single session instead.

### Example

```
> Use agent team to refactor the auth module: extract JWT logic into a service,
  update all route handlers, and add integration tests.
```

The lead will analyze the task, present a plan with teammate assignments, and wait for your confirmation before creating the team.

## How It Works

The skill follows a structured 5-phase workflow:

### Phase 1: Analyze and Decompose
The lead analyzes your task to identify independent work streams, sequential dependencies, and file ownership boundaries. If fewer than 2 parallel streams exist, it recommends a single session instead.

### Phase 2: Present Plan (Mandatory)
Before any work begins, the lead presents a detailed plan showing teammates, task breakdown, file ownership, and dependencies. **You must approve** before the team is created.

### Phase 3: Create Team
The lead creates the team, initializes the workspace, creates all tasks with dependency chains, and spawns teammates. Each teammate receives their role, assigned tasks, file ownership, and communication protocol.

### Phase 4: Coordinate
The lead monitors progress, updates workspace files, handles blocked teammates, resolves conflicts, and ensures work stays on track. Teammates communicate via structured messages (STARTING, COMPLETED, BLOCKED, HANDOFF, QUESTION).

### Phase 5: Synthesize and Complete
Once all tasks are done, the lead collects results, checks integration, generates a final report at `.agent-team/{team-name}/report.md`, and shuts down the team. The workspace persists as a permanent record.

## Hooks

The plugin registers two hooks that enforce team discipline automatically:

### TaskCompleted

**Script**: `scripts/verify-task-complete.sh`

Runs when any task is marked as completed. It checks:

1. **Workspace existence** — if this is a team task, verifies that the workspace directory (`.agent-team/{team-name}/`) exists with all required tracking files (`progress.md`, `tasks.md`, `issues.md`)
2. **File changes** — for implementation tasks (create, add, build, write, refactor, fix, migrate), verifies that actual file changes were made via `git status`

If checks fail, the hook blocks completion (exit 2) with a feedback message explaining what's missing.

### TeammateIdle

**Script**: `scripts/check-teammate-idle.sh`

Runs when a teammate goes idle. It checks:

1. **In-progress tasks** — counts tasks still assigned to and in-progress for the idle teammate
2. **Loop protection** — after 3 consecutive blocks, allows idle to prevent infinite loops (the teammate is genuinely stuck)

If the teammate has pending work, the hook blocks idle (exit 2) with a nudge to complete or update their tasks.

Both hooks require `jq` and degrade gracefully if it's missing (exit 0, allowing the action).

## Workspace

Each team creates a persistent workspace at `.agent-team/{team-name}/` in your project directory. This workspace:

- Survives team deletion (it's the permanent record)
- Is shared (teammates can read it for context)
- Is automatically added to `.gitignore`

### Workspace Files

| File | Purpose |
|------|---------|
| `progress.md` | Team status, member table, phase checklist, decision log, handoffs |
| `tasks.md` | Task table with IDs, owners, status, dependencies, and notes |
| `issues.md` | Issue tracker with severity, impact, affected tasks, and resolution |
| `report.md` | Final report generated in Phase 5 with executive summary and full results |

## Troubleshooting

### Agent Teams feature flag not enabled

```
Error: TeamCreate tool is not available
```

Set the environment variable before launching Claude Code:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

Or add it to your Claude Code `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### jq not installed

Hooks will silently skip their checks (exit 0) if `jq` is not found. Install it for full enforcement:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows (scoop)
scoop install jq
```

### Hooks not firing

1. Verify the plugin is installed: `claude plugin list`
2. Check that `hooks/hooks.json` exists in the plugin directory
3. Ensure hook scripts are executable: `chmod +x scripts/*.sh`
4. Check Claude Code logs for hook execution errors

### Team size limits

The default maximum is 4 teammates for mixed teams (implementers + reviewers). Up to 6 are allowed if the additional teammates beyond 4 are read-only (researchers, reviewers). If you need more, consider breaking the task into sequential phases.

## License

MIT
