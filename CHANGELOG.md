# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.4.0] - 2026-03-09

### Added
- **PROGRESS message type**: Optional granular progress reporting for long-running tasks
- **CHECKPOINT message type**: Intermediate results with downstream task notification
- **Confidence grades**: Optional `[X%]` annotation on reviewer/auditor findings
- **Priority marking**: Optional `priority={critical|high|normal|low}` on STARTING/HANDOFF
- **Checkpoint/Rollback pattern**: Save and resume long-running tasks at natural breakpoints
- **Deadline Escalation pattern**: Proactive time-based escalation for stalled tasks
- **Circular Dependency Detection**: DAG validation in Phase 2 to prevent deadlocks
- **Graceful Degradation pattern**: Controlled scope reduction under resource pressure
- **Warm vs Cold Handoff**: Context-level distinction for result handoffs
- **Anti-Pattern Catalog**: 8 documented coordination pitfalls with prevention/mitigation
- **Scaling Patterns documentation**: Read-only extension, phased execution, sub-agent specialization

## [2.3.0] - 2026-03-09

### Added
- **4 archetype-specific skills** — `/agent-implement`, `/agent-research`, `/agent-audit`, `/agent-plan` each with focused Phase 3/5 overrides and archetype-specific completion gates
- **Shared phases doc** (`docs/shared-phases.md`) — extracted shared logic (Phases 1, 2, 4, shared steps of 3 and 5) referenced by all archetype skills

### Changed
- **`/agent-team` slimmed to hybrid catch-all** — 102 lines (down from 443), with archetype auto-detection table that recommends dedicated skills when a clear match exists
- **`docs/team-archetypes.md` simplified** — 95 lines (down from 157), now a detection reference only (phase profiles moved into each skill)
- **Test suite extended** — `test-doc-references.sh` loops over all `skills/*/SKILL.md` instead of hardcoded path
- **README updated** — new Archetype-Specific Commands table and updated plugin structure tree
- **CLAUDE.md updated** — file ownership table expanded, "Adding a New Archetype Skill" guide added

## [2.2.1] - 2026-03-06

### Changed
- **Communication protocol consolidated** — new `docs/communication-protocol.md` as canonical source; 11 spawn templates now use `{COMMUNICATION_PROTOCOL}` placeholder injected at spawn time
- **Terminology standardized** — renamed `worker-roles.md` → `teammate-roles.md`; "worker" eliminated from all active file references
- **SKILL.md restructured** — moved Setup Failures, Workspace Update Protocol, file-locks/events.log details to docs; replaced with one-line references
- **Quick Start section** added to SKILL.md for fast orientation
- **Concrete examples** added: Phase 2 plan example and Phase 3 spawn prompt assembly example
- **Protocol injection instruction** added to Phase 3 for lead to read and substitute protocol at spawn time

## [2.2.0] - 2026-03-05

### Added
- **5 team archetypes** — Implementation, Research, Audit, Planning, Hybrid with auto-detection from task trigger patterns, phase profile overrides, and archetype-specific completion gates
- **6 new roles** — Analyst, Planner, Writer, Strategist, Auditor, Scout with full spawn templates, subagent type annotations, and structured output formats
- **3 report variants** — Findings Report (research), Audit Report (audit), Plan Report (planning) with shared outer structure and domain-specific content sections
- **Archetype dispatch in SKILL.md** — Phase 1 detection, Phase 2 team type display with user override, Phase 3-5 override callouts referencing team-archetypes.md
- **Team archetypes reference** (`docs/team-archetypes.md`) — trigger patterns, phase profiles, Strictest Gate Rule for Hybrid teams, disambiguation notes for ambiguous triggers
- **Role variants** — Migrator/Integrator/Debugger (Implementer), Facilitator (Challenger), Validator (Tester), Documenter (Writer)

### Changed
- Role Selection Guide expanded with Archetype column and 8 new task type entries
- custom-roles.md intro updated to list all 12 built-in roles

## [2.1.0] - 2026-03-04

### Added
- **Date-prefixed workspace names** — `MMDD-{task-slug}` format prevents name collisions and enables chronological sorting
- **CLAUDE.md + skill hints in spawn prompts** — all 5 spawn templates instruct teammates to read project conventions; role-specific skill hints (`/tdd`, `/requesting-code-review`, `/verification-before-completion`)
- **Documentation references in workspace files** — References sections in progress.md and report.md templates, Ref column in tasks.md, Phase 1 step to identify reference docs
- **Completion Gate (Phase 5)** — 8-item hard gate (uncommitted, build, lint, integration, security, issues, plan, docs) replaces the vague "Check integration" step

### Changed
- Remediation Gate (Phase 5 step 8) simplified to handle residual issues only — primary issue resolution now handled by Completion Gate
- Quality Gate pattern in coordination-patterns.md updated with Completion Gate cross-reference

## [2.0.1] - 2026-03-04

### Fixed
- TaskCompleted hook no longer blocks teammates whose output goes to gitignored `.agent-team/` workspace (e.g., `report.md`). Previously caused stuck retry loops when task subject contained implementation keywords like "Write".

## [2.0.0] - 2026-03-01

### Added
- **Git worktree isolation** (opt-in) — `isolation: worktree` in Phase 2 plan gives each implementer a dedicated worktree
- **Nested task decomposition** — senior implementers can create sub-tasks and spawn sub-agents
- Worktree setup and merge scripts (`scripts/setup-worktree.sh`, `scripts/merge-worktrees.sh`)

### Changed
- Major version bump: nested decomposition changes the team coordination model

## [1.6.0] - 2026-03-01

### Added
- Auto-branch per teammate — implementers create `{team-name}/{name}` branches, merged in Phase 5
- `events.log` workspace file — structured JSON event log for post-mortem analysis
- Direct Handoff coordination pattern — authorized peer-to-peer messaging with audit trail
- Branch Merge step in Phase 5

## [1.5.0] - 2026-03-01

### Added
- **SessionStart(compact) hook** — auto-recovers workspace context after compaction
- **PreToolUse(Write|Edit) hook** — enforces file ownership (warn-then-block)
- **SubagentStart/SubagentStop hooks** — tracks teammate lifecycle in events.log
- `file-locks.json` workspace file — maps teammates to owned files/directories

### Changed
- TaskCompleted hook now uses `task_id` and `teammate_name` for scoped git checks
- Hooks section in SKILL.md updated to document all 5 hooks

## [1.4.0] - 2026-02-28

### Added
- Re-read workspace instruction in all spawn templates (prevents context drift)
- Team metrics section in final report template
- Custom roles reference in Phase 1 decomposition

### Changed
- `tasks.md` workspace template now groups tasks by status (In Progress / Blocked / Pending / Completed)
- TeammateIdle hook updated to parse grouped tasks.md format

## [1.3.0] - 2026-02-27

### Added
- **Re-plan on Block** coordination pattern — structured re-planning when critical blockers invalidate the original plan
- **Adversarial Review Rounds** coordination pattern — multi-round cross-review for high-stakes changes
- **Quality Gate** coordination pattern — final validation pass before Phase 5 synthesis
- **Auto-Block on Repeated Failures** coordination pattern — auto-escalation after 3 blocked attempts on the same task
- Custom role definitions template (`docs/custom-roles.md`) — project-specific roles alongside built-in ones
- `description` field in `hooks/hooks.json` for better UX in `/hooks` menu

## [1.2.0] - 2026-02-26

### Added
- Remediation Gate in Phase 5 — spawn fix team for unresolved issues (max 1 cycle)
- Tester role with spawn template
- Pre-shutdown commit protocol for implementers
- Complexity assessment and dedicated reviewer/tester gate for complex plans
- Remediation cycle tracking in `progress.md`

## [1.1.0] - 2026-02-24

### Added
- TeammateIdle hook with loop protection (3 strikes)
- Batch updates coordination pattern
- First contact verification pattern
- Parallel shutdown pattern

## [1.0.0] - 2026-02-23

### Added
- Initial release: 5-phase team orchestrator
- TaskCompleted hook with workspace and git change verification
- 5 teammate roles: Implementer, Reviewer, Researcher, Challenger, Leader
- Persistent workspace with progress.md, tasks.md, issues.md
- Structured communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF/QUESTION)
- Coordination patterns library
- Final report generation
