# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2026-03-23

### Added
- **Team per stage** — each pipeline stage (plan, execute, audit) creates and manages its own team
- Plan stage team: Researcher(s) + Analyst + Plan Reviewer
- Audit stage team: Reviewer + Elegance Reviewer + Audit Reviewer
- New spawn templates: `researcher.md`, `analyst.md`, `reviewer.md` (audit stage)
- `**Pipeline status**` and `**Stage**` and `**Archetype**` fields in `progress.md` for cross-stage handoff
- `FINDING` and `ANALYSIS` message types for plan stage communication

### Changed
- Plan stage frontmatter gains `Agent, TeamCreate, TeamDelete, SendMessage`
- Execute stage now owns full lifecycle (TeamCreate through TeamDelete)
- Audit stage gains `TeamDelete`, creates its own team with 12-step Phase 5 ordering
- Workspace creation moved from execute stage to plan stage
- Review agents (plan-reviewer, execute-reviewer, audit-reviewer, elegance-reviewer) now communicate via SendMessage as team members

## [3.0.0] - 2026-03-23

### Breaking Changes
- **Skill restructure: 5 archetype skills to 4 pipeline stages** — replaced `agent-team`, `agent-implement`, `agent-research`, `agent-audit`, `agent-plan` skills with `start`, `plan`, `execute`, `audit` pipeline stages
- **Migrated shared docs into stage skills** — `docs/shared-phases.md`, `docs/spawn-templates.md`, `docs/communication-protocol.md`, `docs/coordination-patterns.md`, `docs/coordination-advanced.md`, `docs/report-format.md` moved into stage-specific `references/`, `agents/`, `examples/` subfolders

### Added
- **Pipeline entry point** (`skills/start/SKILL.md`) — type detection, prior context loading, routing to plan/execute/audit
- **Prior context loading** — plan stage loads lessons and error patterns from prior teams to inform decomposition
- **Plan-mode gate** — teammates propose their approach before executing; lead reviews and approves
- **Error recovery loop** — execute stage retries failed tasks with structured escalation (retry, reassign, simplify, skip)
- **Elegance review** — audit stage spawns an Elegance Reviewer agent to assess code quality beyond correctness
- **Lessons capture** — audit stage extracts reusable lessons for future teams
- **Pattern library** — audit stage builds coordination pattern recommendations from team experience
- **Inter-stage review agents** — plan-reviewer, execute-reviewer, audit-reviewer validate output between stages
- **Elegance Reviewer role** — new teammate role for post-execution quality assessment (auto-spawned by audit stage)
- **`recovery_class` field** — each teammate role now declares its error recovery behavior (full, report-gap, skip-and-continue, recover-only)
- **Plan-mode defaults** in `docs/team-archetypes.md` — each archetype has a default plan-mode setting
- **Stage-specific subfolders** — `references/`, `examples/`, `agents/` per stage skill for self-contained content

### Removed
- `docs/shared-phases.md` — phase logic inlined into each stage skill
- `docs/spawn-templates.md` — migrated to `skills/execute/agents/spawn-templates.md`
- `docs/communication-protocol.md` — migrated to `skills/execute/references/communication-protocol.md`
- `docs/coordination-patterns.md` — migrated to `skills/execute/references/coordination-patterns.md`
- `docs/coordination-advanced.md` — merged into `skills/execute/references/coordination-patterns.md`
- `docs/report-format.md` — migrated to `skills/audit/references/report-format.md`
- `skills/agent-team/` — replaced by `skills/start/`
- `skills/agent-implement/` — replaced by `skills/execute/`
- `skills/agent-research/` — replaced by `skills/execute/` (team type detection in start stage)
- `skills/agent-audit/` — replaced by `skills/audit/`
- `skills/agent-plan/` — replaced by `skills/plan/`

## [2.6.0] - 2026-03-20

### Added
- **`task-graph.json` workspace file** — centralized DAG with task dependencies, critical path, and convergence points. Created in Phase 3, maintained by lead, read by 3 new hook scripts
- **`compute-critical-path.sh` hook** (TaskCompleted) — recomputes and displays remaining critical path after each task completion, warns about blocked critical tasks
- **`detect-resume.sh` hook** (SessionStart) — detects resumable workspaces with smart staleness validation via git timestamps (valid/stale/missing output files)
- **`check-integration-point.sh` hook** (TaskCompleted) — detects when convergence points (diamond dependencies) become fully unblocked, nudges lead to verify interface compatibility
- **Critical Path Awareness** in Phase 4 — lead prioritizes critical-path blockers over non-critical work
- **Resume from Existing Workspace** coordination pattern — valid/stale/remaining protocol with archive option
- **Integration Checkpoint Response** coordination pattern — lead response protocol for convergence nudges
- **CP column** in `tasks.md` — ★ marks critical path tasks, convergence notes in the Notes column

### Changed
- Phase 1b gains convergence point marking (step 6 after integration points)
- Phase 2 gains critical path display and integration checkpoint preview
- Phase 3 gains resume detection (step 1a) and `task-graph.json` creation (step 4a)
- Phase 4 gains critical-path-weighted prioritization and integration checkpoint processing
- Deadline Escalation gains critical-path acceleration (skip Nudge, go to Warn)
- Report gains critical path metrics (initial → final length, shift count) and integration checkpoint counts
- All 5 archetype SKILL.md files reference step 4a
- `agent-implement` completion gate check #4 gains convergence-point awareness

## [2.5.1] - 2026-03-17

### Changed
- **Split `coordination-patterns.md`** (633 lines) into core (316) + advanced (332) per skill best practices 500-line guidance
- **Split `teammate-roles.md`** (536 lines) into overview (168) + spawn-templates (407)
- **Added TOC to `shared-phases.md`** — explicit Contents section with anchor links

### Added
- **Concrete decomposition examples** in `agent-research`, `agent-audit`, `agent-plan` SKILL.md files
- **`docs/coordination-advanced.md`** — advanced coordination patterns (re-plan, adversarial review, checkpoint/rollback, escalation)
- **`docs/spawn-templates.md`** — detailed spawn prompt templates for all 11 teammate roles

### Fixed
- Missing `communication-protocol.md` in README Plugin Structure tree (pre-existing)

## [2.5.0] - 2026-03-17

### Added
- **Plan-aware Phase 1** — Phase 1 now scans for existing plan files, creates plans via `writing-plans` skill when none exist, and audits all plans through a 7-check gate before team decomposition
- **Phase 1a: Plan Detection & Preparation** — 5-step workflow (archetype context, scan, create, audit, user decision gate) with graceful fallback when writing-plans skill is unavailable
- **Phase 1b: Decompose from Plan** — team decomposition now derives parallel streams, file ownership, and dependencies from an approved plan rather than ad-hoc analysis
- **Plan audit gate** — 7 checks (task completeness, dependency coherence, file reference validity, scope coverage, reference freshness, feasibility, parallelizability) with severity levels
- **Plan Status Update in Phase 5** — automatically marks source plan as COMPLETED, PARTIAL, or ABANDONED after team finishes
- **Plan File Conventions** in workspace-templates — documented status values, scan behavior, minimum structure requirements
- **Early exit for trivial tasks** — skips plan detection for single-file, no-dependency tasks
- **Budget constraints** — limits scan depth, candidate reads, and context bundle size to keep Phase 1a lightweight
- **Plan-aware archetype detection** — plan content now informs team type detection alongside trigger patterns
- **IN PROGRESS status** at Phase 3 — plan file marked as in-progress during workspace init to warn concurrent teams

### Changed
- **Phase 2 template** — now includes `Based on:` line showing plan file path and source (existing/generated)
- **Phase Checklist** — updated to reflect Phase 1a/1b split and Phase 5 plan status update
- **All 5 archetype SKILL.md files** — Phase 1 overrides reference Phase 1a/1b, Phase 5 overrides include Plan Status Update step

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
