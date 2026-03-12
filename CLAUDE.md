# Agent Team Plugin — Development Guide

## Project Overview

A Claude Code plugin that adds an Agent Team skill for orchestrating parallel work via AI teammates. The plugin provides a team lead orchestrator, hook enforcement, and persistent workspace tracking.

## Architecture

```
.claude-plugin/        Plugin manifest + marketplace registry
hooks/hooks.json       Plugin-level hooks (use ${CLAUDE_PLUGIN_ROOT} for paths)
scripts/               Hook scripts (bash, require jq)
skills/agent-team/     Hybrid/catch-all orchestrator
skills/agent-implement/ Implementation team orchestrator
skills/agent-research/  Research team orchestrator
skills/agent-audit/     Audit team orchestrator
skills/agent-plan/      Planning team orchestrator
docs/                  Shared phases + reference docs consumed by skills at runtime
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
| `skills/agent-team/SKILL.md` | Hybrid/catch-all skill | Archetype detection + hybrid-specific overrides |
| `skills/agent-implement/SKILL.md` | Implementation skill | Implementation-specific Phase 3/5 |
| `skills/agent-research/SKILL.md` | Research skill | Research-specific Phase 3/5 |
| `skills/agent-audit/SKILL.md` | Audit skill | Audit-specific Phase 3/5 |
| `skills/agent-plan/SKILL.md` | Planning skill | Planning-specific Phase 3/5 |
| `docs/shared-phases.md` | Shared phase logic | Changes here affect ALL archetype skills |
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

### Adding a New Archetype Skill

1. Create a new `skills/agent-{name}/SKILL.md` with frontmatter (name, description, argument-hint, allowed-tools)
2. Reference `../../docs/shared-phases.md` for shared logic (Phases 1, 2, 4)
3. Add archetype-specific Phase 3 and Phase 5 overrides
4. Add the archetype to the detection table in `skills/agent-team/SKILL.md`
5. Add trigger patterns to `docs/team-archetypes.md`
6. Add the report variant template to `docs/report-format.md`
7. Update `tests/structure/test-doc-references.sh` (auto-detected via `skills/*/SKILL.md` glob)
8. Update `README.md` Archetype-Specific Commands table and Plugin Structure tree
9. Add row to `CLAUDE.md` File Ownership table
10. Test: run `bash tests/run-tests.sh`, then trigger the skill with a matching phrase

### Releasing a New Version

1. Run `bash tests/run-tests.sh` — all tests must pass
2. Update version in `.claude-plugin/plugin.json`
3. Update version in `.claude-plugin/marketplace.json`
4. Add entry to `CHANGELOG.md`
5. Run `claude plugin validate .`
6. Commit with `chore: bump version to X.Y.Z`
7. Tag with `git tag vX.Y.Z`
