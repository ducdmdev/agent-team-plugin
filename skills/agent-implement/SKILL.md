---
name: agent-implement
description: >
  Orchestrates parallel implementation work via Agent Teams. Triggers when a task involves
  building, refactoring, fixing, or migrating code with 2+ independent work streams.
  Triggers: "implement in parallel", "build with a team", "refactor with teammates",
  "fix in parallel", "migrate with a team".
argument-hint: "[implementation task description]"
allowed-tools: TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, AskUserQuestion, Read, Write, Edit, Glob, Grep, Bash
---

# Implementation Team Orchestrator

Read [shared-phases.md](../../docs/shared-phases.md) for your identity, prerequisites, hooks, and shared phase logic (Phases 1, 2, 4, and shared steps of 3 and 5).

## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1a (plan detection & preparation) and Phase 1b (decompose from plan), then:
- **Decompose by module/area** (frontend vs backend, auth vs payments) or **by layer** (data model vs API vs UI). Plan tasks with implementation verbs (build, refactor, fix, migrate) map to implementer streams.
- **Default roles**: 1-2 Implementers + Reviewer (standard) or + Reviewer + Tester (complex)
- Detect archetype as `implementation` — show `Team type: implementation (auto-detected)` in Phase 2

## Phase 3 Override: Workspace Setup

Apply shared Phase 3 steps 1-7, plus:

After shared Phase 3 step 4 (create tasks), execute step 4a: create `task-graph.json` with initial critical path and convergence points. See [workspace-templates.md](../../docs/workspace-templates.md#task-graphjson) for schema.

### file-locks.json

Create `.agent-team/{team-name}/file-locks.json` mapping each teammate to owned files/directories. Used by PreToolUse hook. See [workspace-templates.md](../../docs/workspace-templates.md#file-locksjson) for format.

```json
{
  "teammate-name": ["src/auth/", "src/middleware/auth.ts"],
  "other-teammate": ["src/api/", "tests/api/"]
}
```

### events.log

Initially empty. Append-only JSON event log. Written by SubagentStart/Stop hooks and the lead during coordination. See [workspace-templates.md](../../docs/workspace-templates.md#eventslog) for format.

### Branch Instructions

Include in each **implementer's** spawn prompt:
- "Create branch `{team-name}/{your-name}` before starting work. If git is unavailable, skip."

### Worktree Isolation (optional)

If `isolation: worktree` was chosen in Phase 2:
- For each implementer, run `scripts/setup-worktree.sh {team-name} {teammate-name}`
- Include the worktree path in the implementer's spawn prompt as their working directory
- If worktree creation fails, fall back to shared mode and log warning in `issues.md`

## Phase 5 Override: Completion

Apply shared Phase 5 steps 1-3, then:

### Pre-Shutdown Commit

Message each **implementer** to commit their owned files:
```
Commit your owned files before shutdown.
- Stage ONLY files in your owned area: git add <your owned files>
- Commit with a descriptive message following project conventions
- Send me the commit hash when done
- If the commit fails, fix the issue and retry. Do NOT proceed without a successful commit.
```
Wait for all implementers to confirm. Log failures in `issues.md` as **high** severity.

### Merge Branches

- If worktree isolation: run `scripts/merge-worktrees.sh {team-name}`
- If auto-branching only: `git merge --no-ff {team-name}/{teammate-name}` per branch
- If merge conflicts: log in `issues.md`, assign implementer to resolve
- If neither branching nor worktrees: skip

### Completion Gate (ALL 8 checks must PASS)

Run checks in order. Items marked ★ are project-specific — PASS automatically if no tooling configured.

| # | Check | How | PASS Criteria | On FAIL |
|---|-------|-----|---------------|---------|
| 1 | **Uncommitted changes** | `git status` scoped to each implementer's owned files | All owned files committed | Message implementer to commit |
| 2 | **Build & tests** | Assign teammate: "Run build + test commands, report PASS/FAIL" | Exit 0, all tests pass | Create fix task |
| 3 | **Lint/format** ★ | Assign teammate: "Run lint, report new warnings/errors" | No new lint errors | Create fix task |
| 4 | **Integration** | Assign teammate: "Verify cross-module connections". If any convergence points in `task-graph.json` were flagged during Phase 4, verify they were resolved. | Cross-teammate outputs connect, flagged convergence points resolved | Create integration fix task |
| 5 | **Security scan** ★ | Assign teammate: "Check for secrets, OWASP top 10 in changed files" | No new security issues | Create fix task (critical) |
| 6 | **Workspace issues** | Read `issues.md` | 0 OPEN issues | Route to teammate |
| 7 | **Plan completion** | Compare Phase 2 plan vs TaskList | Every stream has completed tasks | Create missing tasks |
| 8 | **Documentation sync** | Assign teammate: "Check if README/docs need updates" | No stale docs | Create doc update task |

Log gate result in `progress.md` Decision Log.

### Plan Status Update

Update the source plan file per shared Phase 5 Plan Status Update section.

### Generate Report

Write `.agent-team/{team-name}/report.md` using the **standard report** template from [report-format.md](../../docs/report-format.md). Copy References from `progress.md`.

**Self-check**: read the file back — does it contain the Executive Summary? If not, regenerate.

Then continue with shared Phase 5 steps 4-7 (remediation gate, report to user, shutdown, cleanup).
