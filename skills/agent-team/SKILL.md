---
name: agent-team
description: >
  Orchestrates parallel work via Agent Teams. Triggers when a task has 2+ independent
  work streams that benefit from parallel execution with inter-agent communication.
  Triggers: "create a team", "work in parallel", "use agent team", "spawn teammates".
argument-hint: "[task description]"
allowed-tools: TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, AskUserQuestion, Read, Write, Edit, Glob, Grep, Bash
---

# Agent Team Orchestrator

Read [shared-phases.md](../../docs/shared-phases.md) for your identity, prerequisites, hooks, and shared phase logic (Phases 1, 2, 4, and shared steps of 3 and 5).

## Archetype Detection

Before proceeding with Phase 1, determine the team archetype from the user's task. Match against trigger patterns from [team-archetypes.md](../../docs/team-archetypes.md):

| Archetype | Trigger Patterns | Dedicated Skill |
|-----------|-----------------|-----------------|
| Implementation | "implement", "build", "create", "refactor", "fix", "migrate" | `/agent-implement` |
| Research | "research", "investigate", "explore", "analyze", "compare" | `/agent-research` |
| Audit | "audit", "review", "assess", "evaluate", "check compliance" | `/agent-audit` |
| Planning | "plan", "design", "architect", "spec", "propose", "strategy" | `/agent-plan` |
| Hybrid | Task combines 2+ of the above | This skill (`/agent-team`) |

**If a single archetype matches clearly**: Inform the user that a dedicated skill exists and proceed using that archetype's logic. Example: "This is an implementation task — I'll use the implementation team workflow."

**If the task combines types** (e.g., "research X then implement Y"): This is a Hybrid — proceed below.

**If no clear match**: Default to Implementation workflow.

## Phase 1 Override: Hybrid Decomposition

Apply shared Phase 1, then:
- **Identify which parts map to which archetype** (e.g., research streams vs implementation streams)
- **Compose roles from the full catalog** based on combined task types
- Show `Team type: hybrid ([component types])` in Phase 2 (e.g., `hybrid (research + implementation)`)

## Phase 3 Override: Hybrid Workspace Setup

Apply shared Phase 3 steps 1-7, plus:

### file-locks.json (conditional)

Create **only if ANY teammate writes project files** (implementers, writers with file ownership). Skip if all teammates are read-only.

See [workspace-templates.md](../../docs/workspace-templates.md#file-locksjson) for format.

### events.log

Initially empty. Append-only JSON event log.

### Branch Instructions (implementers only)

Include branch instruction in each **implementer's** spawn prompt only:
- "Create branch `{team-name}/{your-name}` before starting work. If git is unavailable, skip."

### Worktree Isolation (optional, implementers only)

If chosen in Phase 2, apply only to implementers. See implementation archetype for details.

## Phase 5 Override: Hybrid Completion

Apply shared Phase 5 steps 1-3, then:

### Pre-Shutdown Commit (conditional)

Only if implementers or writers with file ownership exist. Message each to commit their owned files. See implementation archetype for the commit protocol.

### Merge Branches (conditional)

Only if branching or worktrees were used. See implementation archetype for merge protocol.

### Completion Gate — Strictest Gate Rule

Include any check required by ANY component archetype present in the team:

| # | Check | Required if... |
|---|-------|---------------|
| 1 | **Uncommitted changes** | Any Implementer present |
| 2 | **Build & tests** | Any Implementer present |
| 3 | **Lint/format** | Any Implementer present |
| 4 | **Integration** | Any Implementer present OR Audit component |
| 5 | **Security scan** | Any Implementer present OR Audit component |
| 6 | **Workspace issues** | Always |
| 7 | **Plan completion** | Always |
| 8 | **Documentation sync** | Any Implementer present |

★ = Project-specific. PASS automatically if no tooling configured.

> **Lead judgment**: When the implementation component is minor (e.g., a single config change), mark checks as N/A with a brief note in `progress.md`.

Log gate result in `progress.md` Decision Log.

### Generate Report

Write `.agent-team/{team-name}/report.md` using the **standard report** template from [report-format.md](../../docs/report-format.md). If the Hybrid has no Implementation component, omit "Files Changed" and substitute the appropriate variant section (e.g., "What Was Discovered" or "What Was Audited").

**Self-check**: read the file back — does it contain the Executive Summary? If not, regenerate.

Then continue with shared Phase 5 steps 4-7 (remediation gate, report to user, shutdown, cleanup).
