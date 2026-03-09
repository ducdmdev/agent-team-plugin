---
name: agent-research
description: >
  Orchestrates parallel research via Agent Teams. Triggers when a task involves
  investigating, analyzing, or comparing approaches with 2+ independent research angles.
  Triggers: "research in parallel", "investigate with a team", "analyze with teammates",
  "compare approaches in parallel", "explore with a team".
argument-hint: "[research question or investigation topic]"
allowed-tools: TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, AskUserQuestion, Read, Write, Edit, Glob, Grep, Bash
---

# Research Team Orchestrator

Read [shared-phases.md](../../docs/shared-phases.md) for your identity, prerequisites, hooks, and shared phase logic (Phases 1, 2, 4, and shared steps of 3 and 5).

## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1, then:
- **Decompose by research question/hypothesis**, not by module
- **Default roles**: 2-3 Researchers (different angles) + optional Analyst or Challenger
- Detect archetype as `research` — show `Team type: research (auto-detected)` in Phase 2

## Phase 3 Override: Workspace Setup

Apply shared Phase 3 steps 1-7, with these differences:
- **SKIP file-locks.json** — all teammates are read-only, no file ownership to enforce
- **SKIP branch instructions** — no code branches needed
- File ownership hook (PreToolUse) is N/A for this archetype

## Phase 5 Override: Completion

Apply shared Phase 5 steps 1-3, then:

- **SKIP pre-shutdown commit** — no files to commit (read-only team)
- **SKIP branch merge** — no branches created

### Completion Gate (2 checks only)

| # | Check | How | PASS Criteria | On FAIL |
|---|-------|-----|---------------|---------|
| 6 | **Workspace issues** | Read `issues.md` | 0 OPEN issues | Route to teammate |
| 7 | **Plan completion** | Compare Phase 2 plan vs TaskList | Every research angle has completed tasks | Create missing tasks |

Checks #1-#5 and #8 are N/A for research teams (no code changes).

Log gate result in `progress.md` Decision Log.

### Generate Report

Write `.agent-team/{team-name}/report.md` using the **findings report** variant from [report-format.md](../../docs/report-format.md#findings-report). Replace "Files Changed" with "What Was Discovered". Use "Findings" instead of "Files modified" in Per-Teammate Summaries.

**Self-check**: read the file back — does it contain the Executive Summary? If not, regenerate.

Then continue with shared Phase 5 steps 4-7 (remediation gate, report to user, shutdown, cleanup).
