# Agent Team Plugin — Development Guide

## Project Overview

A Claude Code plugin that adds an Agent Team skill for orchestrating parallel work via AI teammates. The plugin provides a team lead orchestrator, hook enforcement, and persistent workspace tracking.

## Architecture

```
.claude-plugin/        Plugin manifest + marketplace registry
hooks/hooks.json       Plugin-level hooks (use ${CLAUDE_PLUGIN_ROOT} for paths)
scripts/               Hook scripts (bash, require jq)
skills/start/          Pipeline entry point — type detection + routing
skills/plan/           Plan stage — decomposition, DAG, approval
  references/          Prior context loading, plan-mode protocol
  examples/            Plan proposal examples
  agents/              Plan-reviewer agent
skills/execute/        Execute stage — spawn, coordination, error recovery
  references/          Communication protocol, coordination patterns, error recovery
  agents/              Spawn templates, execute-reviewer agent
skills/audit/          Audit stage — gates, elegance review, report, lessons
  references/          Completion gates, elegance rubric, report format
  examples/            Lessons-learned examples
  agents/              Audit-reviewer, elegance-reviewer agents
docs/                  Shared reference docs (roles, archetypes, workspace templates, custom roles)
```

### Key Design Decisions

- **Hooks are plugin-level** (`hooks/hooks.json`), not in SKILL.md frontmatter — this is how Claude Code plugins register hooks
- **`${CLAUDE_PLUGIN_ROOT}`** is the only valid path variable in hooks.json — it resolves to the plugin install directory at runtime
- **Each stage skill is self-contained** — stage-specific references, examples, and agents live in subfolders (`references/`, `examples/`, `agents/`) alongside SKILL.md
- **Shared docs** (`docs/`) contain only cross-cutting references: teammate roles, workspace templates, team archetypes, custom roles
- **Team per stage** — each pipeline stage (plan, execute, audit) creates and manages its own ephemeral team. Teams communicate with the lead via SendMessage. Workspace files are the only handoff between stages.
- **No `disable-model-invocation`** — the skill auto-invokes on matching trigger phrases

## File Ownership

| Area | Purpose | Edit Guidelines |
|------|---------|----------------|
| `.claude-plugin/plugin.json` | Plugin identity | Bump version here on release |
| `.claude-plugin/marketplace.json` | Marketplace registry | Bump version here too, keep in sync with plugin.json |
| `hooks/hooks.json` | Hook registration (9 hook entries) | Update timeout values, add new hooks, or update hook command paths |
| `scripts/*.sh` | Hook enforcement logic (12 scripts) | Written in bash (`#!/bin/bash`), degrade gracefully without `jq` |
| `skills/start/SKILL.md` | Pipeline entry point | Type detection, prior context, routing to plan/execute/audit |
| `skills/plan/SKILL.md` | Plan stage | Decomposition, DAG creation, plan-review, user approval |
| `skills/plan/references/` | Plan stage references | Prior context loading, plan-mode protocol |
| `skills/plan/examples/` | Plan stage examples | Plan proposal example |
| `skills/plan/agents/` | Plan stage agents | Plan-reviewer, researcher, analyst agent definitions |
| `skills/execute/SKILL.md` | Execute stage | Spawn, coordination, error recovery loop |
| `skills/execute/references/` | Execute stage references | Communication protocol, coordination patterns, error recovery |
| `skills/execute/agents/` | Execute stage agents | Spawn templates, execute-reviewer agent |
| `skills/audit/SKILL.md` | Audit stage | Completion gates, elegance review, report, lessons |
| `skills/audit/references/` | Audit stage references | Completion gates, elegance rubric, report format |
| `skills/audit/examples/` | Audit stage examples | Lessons-learned example |
| `skills/audit/agents/` | Audit stage agents | Audit-reviewer, elegance-reviewer, reviewer agents |
| `docs/teammate-roles.md` | Role definitions + selection guide | Update when adding new roles |
| `docs/workspace-templates.md` | Workspace file templates + `task-graph.json` schema | Update when adding new workspace files or changing DAG schema |
| `docs/team-archetypes.md` | Team type definitions + phase profiles | Update when adding new archetypes or modifying plan-mode defaults |
| `docs/custom-roles.md` | Project-specific role template | Reference for users creating custom roles |
| `CHANGELOG.md` | Version history | Add entry for each release |
| `README.md` | User-facing documentation | Keep in sync with feature changes |
| `tests/` | Hook and structure tests | `hooks/` for hook tests, `structure/` for plugin validation |
| `.agent-team/0309-protocol-research/` | Research findings | Reference only — do not modify. Contains 4 reports on protocol, patterns, resilience, and scaling |

## Conventions

### Versioning

- Follow semver: `MAJOR.MINOR.PATCH`
- Version must be updated in **both**: `plugin.json` and `marketplace.json`
- Use `claude plugin validate .` before releasing

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat:     new feature or capability
fix:      bug fix
docs:     documentation changes (README, CLAUDE.md, docs/)
refactor: code restructuring without behavior change
chore:    maintenance (CI, dependencies)
```

### Scripts

- Must be executable (`chmod +x`)
- Must handle missing `jq` gracefully (exit 0 if not found)
- Must handle missing `git` gracefully (skip git-dependent checks)
- Exit codes: `0` = allow, `2` = block with feedback to stderr

### SKILL.md Editing

- The frontmatter (`---` block) defines skill metadata — do not add `hooks:` or `disable-model-invocation` back
- Each stage skill has its own phase structure — preserve the stage-specific flow
- Stage-specific content lives in subfolders (`references/`, `examples/`, `agents/`) — keep SKILL.md focused on orchestration logic, detailed reference material in subfolders
- Doc references use `../../docs/` relative paths from `skills/{stage}/` for shared docs, `./references/` or `./agents/` for stage-local files

## Testing

### Run Full Test Suite

```bash
bash tests/run-tests.sh
```

Runs 12 test files covering all hooks and plugin structure.

### Validate Plugin

```bash
claude plugin validate .
```

### Local Test

```bash
claude --plugin-dir /path/to/agent-team-plugin
```

Then trigger with: "use agent team to [task]"

### Verify Hooks

Nine hook entries registered in `hooks/hooks.json`:

1. **TaskCompleted** — try marking a task complete without file changes (should block)
2. **TeammateIdle** — let a teammate go idle with in-progress tasks (should nudge)
3. **SessionStart(compact)** — compact context in a team session (should recover workspace)
4. **PreToolUse(Write|Edit)** — have a teammate edit another's file (should warn, then block)
5. **SubagentStart** — spawn a teammate (should log to events.log)
6. **SubagentStop** — teammate shuts down (should log to events.log)
7. **ComputeCriticalPath** — complete a task and check stderr for critical path update
8. **DetectResume** — start a new session with an incomplete workspace and check stdout for resume context
9. **CheckIntegrationPoint** — complete both upstream tasks of a convergence point and check stderr for integration nudge

## Common Tasks

### Adding a New Hook

1. Add the script to `scripts/`
2. Make it executable
3. Register it in `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}/scripts/your-script.sh`
4. Document in the relevant stage skill's SKILL.md and README
5. Test: run `claude plugin validate .` then test manually in a team session

### Adding a New Teammate Role

1. Add the role definition to `docs/teammate-roles.md`
2. Add the spawn template to `skills/execute/agents/spawn-templates.md`
3. Update the Role Selection Guide table in `docs/teammate-roles.md`
4. Update README Teammate Roles table

### Adding a New Pipeline Stage

1. Create a new `skills/{stage}/SKILL.md` with frontmatter (name, description, argument-hint, allowed-tools)
2. Create subfolders as needed: `references/`, `examples/`, `agents/`
3. Add stage-specific orchestration logic, referencing `../../docs/` for shared docs
4. Update `skills/start/SKILL.md` routing table to include the new stage
5. Add trigger patterns to `docs/team-archetypes.md` if applicable
6. Update `tests/structure/test-doc-references.sh` — add assertions for new skill and subfolders
7. Update `README.md` Pipeline Commands table and Plugin Structure tree
8. Add rows to `CLAUDE.md` File Ownership table
9. Test: run `bash tests/run-tests.sh`, then trigger the skill with a matching phrase

### Releasing a New Version

1. Run `bash tests/run-tests.sh` — all tests must pass
2. Update version in `.claude-plugin/plugin.json`
3. Update version in `.claude-plugin/marketplace.json`
4. Add entry to `CHANGELOG.md`
5. Run `claude plugin validate .`
6. Commit with `chore: bump version to X.Y.Z`
7. Tag with `git tag vX.Y.Z`
