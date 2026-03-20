---
name: agent-plan
description: >
  Orchestrates parallel planning via Agent Teams. Triggers when a task involves
  designing, architecting, or producing specs with 2+ independent planning concerns.
  Triggers: "plan in parallel", "design with a team", "architect with teammates",
  "produce specs in parallel", "strategy with a team".
argument-hint: "[planning scope or design question]"
allowed-tools: TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, AskUserQuestion, Read, Write, Edit, Glob, Grep, Bash
---

# Planning Team Orchestrator

Read [shared-phases.md](../../docs/shared-phases.md) for your identity, prerequisites, hooks, and shared phase logic (Phases 1, 2, 4, and shared steps of 3 and 5).

## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1a (plan detection & preparation) and Phase 1b (decompose from plan), then:
- **Decompose by planning concern** (architecture, data model, API design, etc.)
- **Default roles**: 1-2 Planners or Strategists + Researcher + optional Challenger
- Detect archetype as `planning` — show `Team type: planning (auto-detected)` in Phase 2

**Example decomposition**: For "design the microservices migration architecture":
- Stream 1 (Planner): API design concern — service boundaries, contracts, versioning
- Stream 2 (Planner): Data model concern — database per service, migration strategy, consistency
- Stream 3 (Strategist): Infrastructure concern — deployment topology, service mesh, observability
- Optional (Researcher): Prior art — how similar-scale companies approached the same migration

## Phase 3 Override: Workspace Setup

Apply shared Phase 3 steps 1-7, with these differences:

After shared Phase 3 step 4 (create tasks), execute step 4a: create `task-graph.json` with initial critical path and convergence points. See [workspace-templates.md](../../docs/workspace-templates.md#task-graphjson) for schema.
- **SKIP file-locks.json** — Planners write docs to workspace, not project files
- **SKIP branch instructions** — no code branches
- If multiple Planners, assign distinct workspace sub-paths (e.g., `{workspace}/planner-1/`) to avoid write conflicts
- File ownership hook (PreToolUse) is N/A for this archetype

## Phase 5 Override: Completion

Apply shared Phase 5 steps 1-3, then:

- **SKIP pre-shutdown commit** — planners write to workspace, not project files
- **SKIP branch merge** — no branches created

### Completion Gate (2 checks only)

| # | Check | How | PASS Criteria | On FAIL |
|---|-------|-----|---------------|---------|
| 6 | **Workspace issues** | Read `issues.md` | 0 OPEN issues | Route to teammate |
| 7 | **Plan completion** | Compare Phase 2 plan vs TaskList | Every planning concern has completed tasks | Create missing tasks |

Checks #1-#5 and #8 are N/A for planning teams.

Log gate result in `progress.md` Decision Log.

### Plan Status Update

Update the source plan file per shared Phase 5 Plan Status Update section.

### Generate Report

Write `.agent-team/{team-name}/report.md` using the **plan report** variant from [report-format.md](../../docs/report-format.md#plan-report). Replace "Files Changed" with "What Was Planned". Use "Design contributions" and "Decisions proposed" in Per-Teammate Summaries.

**Self-check**: read the file back — does it contain the Executive Summary? If not, regenerate.

Then continue with shared Phase 5 steps 4-7 (remediation gate, report to user, shutdown, cleanup).
