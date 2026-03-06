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
| `hooks/hooks.json` | Hook registration (6 hooks) | Update timeout values, add new hooks, or update hook command paths |
| `scripts/*.sh` | Hook enforcement logic (7 scripts) | Written in bash (`#!/bin/bash`), degrade gracefully without `jq` |
| `skills/agent-team/SKILL.md` | Core skill prompt | Most changes go here. Keep Phase 1-5 structure |
| `docs/teammate-roles.md` | Role definitions + spawn templates | Update when adding new roles |
| `docs/communication-protocol.md` | Structured message formats | Update when changing protocol prefixes or role-specific formats |
| `docs/coordination-patterns.md` | Conflict resolution, handoffs | Update when adding new coordination patterns |
| `docs/workspace-templates.md` | Workspace file templates | Update when adding new workspace files |
| `docs/report-format.md` | Final report template | Update when changing report structure |
| `docs/custom-roles.md` | Project-specific role template | Reference for users creating custom roles |
| `docs/team-archetypes.md` | Team type definitions + phase profiles | Update when adding new archetypes or modifying phase overrides |
| `CHANGELOG.md` | Version history | Add entry for each release |
| `README.md` | User-facing documentation | Keep in sync with feature changes |
| `tests/` | Hook and structure tests | `hooks/` for hook tests, `structure/` for plugin validation |

## Conventions

### Versioning

- Follow semver: `MAJOR.MINOR.PATCH`
- Version must be updated in **all three**: `plugin.json`, `marketplace.json`, AND `package.json`
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

### Run Full Test Suite

```bash
bash tests/run-tests.sh
```

Runs 9 test files (78 assertions) covering all hooks and plugin structure.

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

Six hooks registered in `hooks/hooks.json`:

1. **TaskCompleted** — try marking a task complete without file changes (should block)
2. **TeammateIdle** — let a teammate go idle with in-progress tasks (should nudge)
3. **SessionStart(compact)** — compact context in a team session (should recover workspace)
4. **PreToolUse(Write|Edit)** — have a teammate edit another's file (should warn, then block)
5. **SubagentStart** — spawn a teammate (should log to events.log)
6. **SubagentStop** — teammate shuts down (should log to events.log)

## Common Tasks

### Adding a New Hook

1. Add the script to `scripts/`
2. Make it executable
3. Register it in `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}/scripts/your-script.sh`
4. Document in SKILL.md Hooks section and README
5. Test: run `claude plugin validate .` then test manually in a team session

### Adding a New Teammate Role

1. Add the role definition and spawn template to `docs/teammate-roles.md`
2. Update the Role Selection Guide table
3. Update README Teammate Roles table

### Adding a New Team Archetype

1. Add the archetype definition to `docs/team-archetypes.md`
2. Include: trigger patterns, default roles, phase profile table, completion gate checks, report variant
3. Add the report variant template to `docs/report-format.md`
4. Update `README.md` Team Types table
5. Test: trigger the skill with a matching phrase and verify the lead selects the correct archetype

### Releasing a New Version

1. Run `bash tests/run-tests.sh` — all tests must pass
2. Update version in `.claude-plugin/plugin.json`
3. Update version in `.claude-plugin/marketplace.json`
4. Update version in `package.json`
5. Add entry to `CHANGELOG.md`
6. Run `claude plugin validate .`
7. Commit with `chore: bump version to X.Y.Z`
8. Tag with `git tag vX.Y.Z`
