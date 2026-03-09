---
name: agent-audit
description: >
  Orchestrates parallel audits via Agent Teams. Triggers when a task involves
  reviewing, assessing, or evaluating code against standards with 2+ independent audit lenses.
  Triggers: "audit in parallel", "review with a team", "assess with teammates",
  "security review with a team", "code review in parallel", "check compliance".
argument-hint: "[audit scope and standards]"
allowed-tools: TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, AskUserQuestion, Read, Write, Edit, Glob, Grep, Bash
---

# Audit Team Orchestrator

Read [shared-phases.md](../../docs/shared-phases.md) for your identity, prerequisites, hooks, and shared phase logic (Phases 1, 2, 4, and shared steps of 3 and 5).

## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1, then:
- **Decompose by audit lens/checklist area** (security, performance, compliance, style)
- **Default roles**: 2-3 Reviewers or Auditors (different lenses) + optional Challenger
- Detect archetype as `audit` — show `Team type: audit (auto-detected)` in Phase 2

## Phase 3 Override: Workspace Setup

Apply shared Phase 3 steps 1-7, with these differences:
- **SKIP file-locks.json** — all teammates are read-only
- **SKIP branch instructions** — no code branches needed
- File ownership hook (PreToolUse) is N/A for this archetype

## Phase 5 Override: Completion

Apply shared Phase 5 steps 1-3, then:

- **SKIP pre-shutdown commit** — no files to commit
- **SKIP branch merge** — no branches created

### Completion Gate (4 checks)

| # | Check | How | PASS Criteria | On FAIL |
|---|-------|-----|---------------|---------|
| 4 | **Integration** | Verify audit covered cross-module concerns | Audit comprehensiveness confirmed | Assign follow-up audit task |
| 5 | **Security** | Verify audit covered security aspects | Security coverage confirmed | Assign security audit task |
| 6 | **Workspace issues** | Read `issues.md` | 0 OPEN issues | Route to teammate |
| 7 | **Plan completion** | Compare Phase 2 plan vs TaskList | Every audit lens has completed tasks | Create missing tasks |

Checks #1-#3 and #8 are N/A for audit teams (no code changes). Note: #4 and #5 assess audit coverage, not code correctness.

Log gate result in `progress.md` Decision Log.

### Generate Report

Write `.agent-team/{team-name}/report.md` using the **audit report** variant from [report-format.md](../../docs/report-format.md#audit-report). Replace "Files Changed" with "What Was Audited". Use "Audit findings" and "Items checked" in Per-Teammate Summaries.

**Self-check**: read the file back — does it contain the Executive Summary? If not, regenerate.

Then continue with shared Phase 5 steps 4-7 (remediation gate, report to user, shutdown, cleanup).
