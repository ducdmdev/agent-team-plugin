# Agent Team Plugin — Development Guide

## Project Overview

A Claude Code plugin that adds an Agent Team skill for orchestrating parallel work via AI teammates. The plugin provides a team lead orchestrator, hook enforcement, and persistent workspace tracking.

## Architecture

```
.claude-plugin/        Plugin manifest + marketplace registry
hooks/hooks.json       Plugin-level hooks (use ${CLAUDE_PLUGIN_ROOT} for paths)
scripts/               Hook scripts (bash, require jq)
skills/agent-team/     SKILL.md — the main skill prompt (team lead orchestrator)
docs/                  Reference docs consumed by SKILL.md at runtime
```

### Key Design Decisions

- **Hooks are plugin-level** (`hooks/hooks.json`), not in SKILL.md frontmatter — this is how Claude Code plugins register hooks
- **`${CLAUDE_PLUGIN_ROOT}`** is the only valid path variable in hooks.json — it resolves to the plugin install directory at runtime
- **SKILL.md inlines** workspace templates and communication protocol so the skill is self-contained for core workflow. Detailed role definitions and patterns stay in `docs/` to keep SKILL.md focused
- **workspace.md is not a standalone file** — its content was inlined into SKILL.md Phase 3 and Phase 4
- **No `disable-model-invocation`** — the skill auto-invokes on matching trigger phrases

## File Ownership

| Area | Purpose | Edit Guidelines |
|------|---------|----------------|
| `.claude-plugin/plugin.json` | Plugin identity | Bump version here on release |
| `.claude-plugin/marketplace.json` | Marketplace registry | Bump version here too, keep in sync with plugin.json |
| `hooks/hooks.json` | Hook registration | Only change timeout values or add new hooks |
| `scripts/*.sh` | Hook enforcement logic | Written in bash (`#!/bin/bash`), degrade gracefully without `jq` |
| `skills/agent-team/SKILL.md` | Core skill prompt | Most changes go here. Keep Phase 1-5 structure |
| `docs/worker-roles.md` | Role definitions + spawn templates | Update when adding new roles |
| `docs/coordination-patterns.md` | Conflict resolution, handoffs | Update when adding new coordination patterns |
| `docs/report-format.md` | Final report template | Update when changing report structure |

## Conventions

### Versioning

- Follow semver: `MAJOR.MINOR.PATCH`
- Version must be updated in **both** `plugin.json` and `marketplace.json` (and `package.json` if publishing to npm)
- Use `claude plugin validate .` before releasing

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat:     new feature or capability
fix:      bug fix
docs:     documentation changes (README, CLAUDE.md, docs/)
refactor: code restructuring without behavior change
chore:    maintenance (package.json, CI, dependencies)
```

### Scripts

- Must be executable (`chmod +x`)
- Must handle missing `jq` gracefully (exit 0 if not found)
- Must handle missing `git` gracefully (skip git-dependent checks)
- Exit codes: `0` = allow, `2` = block with feedback to stderr

### SKILL.md Editing

- The frontmatter (`---` block) defines skill metadata — do not add `hooks:` or `disable-model-invocation` back
- Phase structure (1-5) is the core contract — preserve it
- Inlined sections (workspace templates in Phase 3, communication protocol in Phase 4) must stay in sync with `docs/` if the same content exists in both places
- Doc references use `../../docs/` relative paths from `skills/agent-team/`

## Testing

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

1. Start a team session
2. Try marking a task complete without file changes — TaskCompleted hook should block
3. Let a teammate go idle with in-progress tasks — TeammateIdle hook should nudge

## Common Tasks

### Adding a New Hook

1. Add the script to `scripts/`
2. Make it executable
3. Register it in `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}/scripts/your-script.sh`
4. Document in SKILL.md Hooks section and README

### Adding a New Teammate Role

1. Add the role definition and spawn template to `docs/worker-roles.md`
2. Update the Role Selection Guide table
3. Update README Teammate Roles table

### Releasing a New Version

1. Update version in `.claude-plugin/plugin.json`
2. Update version in `.claude-plugin/marketplace.json`
3. Update version in `package.json`
4. Run `claude plugin validate .`
5. Commit with `chore: bump version to X.Y.Z`
6. Tag with `git tag vX.Y.Z`
