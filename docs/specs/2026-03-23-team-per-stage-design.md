# Team Per Stage — Design Spec (Addendum)

**Date**: 2026-03-23
**Status**: Draft
**Parent spec**: `2026-03-23-workflow-orchestration-integration-design.md`

## Overview

Each pipeline stage (`plan`, `execute`, `audit`) creates and manages its own team. Teams are ephemeral; the workspace is the only handoff mechanism between stages. This eliminates cross-stage team dependencies and makes each stage truly independently invocable.

### Architectural Principle

**Teams are ephemeral, workspace is persistent.** Each stage: TeamCreate → do work → TeamDelete. Stages communicate only through workspace files.

```
Plan team → workspace → Execute team → workspace → Audit team → workspace → report
```

---

## Section 1: Plan Stage Team

### Team Composition (2-3 teammates)

| Role | When Spawned | Purpose | recovery_class |
|------|-------------|---------|----------------|
| Researcher | Always (1-2) | Scan codebase, understand dependencies, find existing patterns | report-gap |
| Analyst | Complex tasks only | Evaluate complexity, estimate effort, identify risks | report-gap |
| Plan Reviewer | Always | Validate plan quality before user approval | skip-and-continue |

### Lifecycle

```
TeamCreate → spawn planning team → researchers scan codebase → analyst evaluates →
lead decomposes → plan-reviewer validates → user approval → TeamDelete
```

### Communication

Researchers use structured messages:
```
FINDING: {what was found}, relevance={high|medium|low}, files=[{paths}]
```

Analyst sends:
```
ANALYSIS: complexity={low|medium|high}, risks=[{risk list}], estimate={scope description}
```

Plan Reviewer sends (unchanged):
```
PLAN_REVIEW: status={approved|issues_found}, issues=[{check, severity, description, suggestion}]
```

### Frontmatter Changes

`skills/plan/SKILL.md` gains these tools:
```
allowed-tools: Read, Glob, Grep, Bash, Agent, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, TeamCreate, TeamDelete, SendMessage
```

### File Changes

| File | Change |
|------|--------|
| `skills/plan/SKILL.md` | Add TeamCreate/TeamDelete/SendMessage to allowed-tools. Add Phase 1.5: Create Planning Team section. Add team shutdown after user approval. |
| `skills/plan/agents/plan-reviewer.md` | Update from subagent prompt to teammate spawn template |
| `skills/plan/agents/researcher.md` | New: spawn template for plan-stage researcher |
| `skills/plan/agents/analyst.md` | New: spawn template for plan-stage analyst |
| `skills/execute/agents/spawn-templates.md` | Remove plan-reviewer references (now owned by plan stage) |
| `skills/execute/references/communication-protocol.md` | Add FINDING and ANALYSIS message types |
| `docs/workspace-templates.md` | Add `**Stage**: {plan\|execute\|audit}` field to progress.md template |

---

## Section 2: Execute Stage Team (Updated Lifecycle)

### Team Composition (2-4 teammates, unchanged)

| Role | When Spawned | Purpose | recovery_class |
|------|-------------|---------|----------------|
| Implementer(s) | Always | Write code, build features | full |
| Tester | If implementation tasks | Verify, run tests | full |
| Reviewer | If implementation tasks | Validate quality | skip-and-continue |
| Execute Reviewer | Always | Smoke test before handoff | skip-and-continue |

### Lifecycle (Updated — now fully self-contained)

```
TeamCreate → spawn execution team → coordinate → error recovery →
execute-reviewer validates → shutdown teammates → TeamDelete
```

Previously, execute created the team but audit shut it down. Now execute owns the full lifecycle: create, work, review, shutdown.

### What Changes

| Change | Before | After |
|--------|--------|-------|
| TeamDelete | Owned by audit stage | Owned by execute stage |
| Execute Reviewer | Subagent via Agent tool | Team member via SendMessage |
| Handoff to audit | Live team inherited | Workspace files only |
| Progress.md | Status: approved | Adds Status: executed after shutdown |

### Frontmatter Changes

`skills/execute/SKILL.md` — already has TeamCreate and TeamDelete. No frontmatter change needed.

### File Changes

| File | Change |
|------|--------|
| `skills/execute/SKILL.md` | Add TeamDelete to Phase 4 (after execute-review passes). Write `**Status**: executed` to progress.md before shutdown. |
| `skills/execute/agents/execute-reviewer.md` | Update from subagent prompt to teammate spawn template |

---

## Section 3: Audit Stage Team

### Team Composition (2-3 teammates)

| Role | When Spawned | Purpose | recovery_class |
|------|-------------|---------|----------------|
| Reviewer | Always | Validate completed work against plan, check integration | skip-and-continue |
| Elegance Reviewer | If code changes exist | 5-dimension quality assessment | skip-and-continue |
| Audit Reviewer | Always | Meta-review of report quality | skip-and-continue |

### Lifecycle

```
TeamCreate → spawn audit team → reviewer validates work → elegance reviewer scores →
lead captures lessons + updates patterns → lead generates report →
audit-reviewer validates report → TeamDelete
```

### Communication

Reviewer sends:
```
COMPLETED #review: findings_summary={description}, issues={N high, M medium, L low}
```

Elegance Reviewer sends (unchanged):
```
ELEGANCE_REVIEW: overall_score={1-5}, dimensions={...}, findings=[...]
```

Audit Reviewer sends (unchanged):
```
AUDIT_REVIEW: status={approved|revisions_needed}, issues=[...]
```

### Preconditions (Updated)

- Workspace exists with `task-graph.json` where at least one task has `status: completed`
- `progress.md` contains `**Status**: executed` (set by execute stage after shutdown)
- If all tasks incomplete → exit with "nothing to audit"
- **No dependency on execute team being alive** — audit creates its own team

### Frontmatter Changes

`skills/audit/SKILL.md` gains TeamCreate:
```
allowed-tools: Read, Write, Glob, Grep, Bash, Agent, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, TeamCreate, TeamDelete, SendMessage
```

### Phase 5 Ordering (Updated)

1. **TeamCreate** (new — create audit team)
2. **Spawn audit teammates** (new — Reviewer, Elegance Reviewer if applicable, Audit Reviewer)
3. Reviewer validates work (existing completion gate checks, now done by teammate)
4. Remediation gate (existing, if open issues — lead coordinates fixes)
5. Elegance gate (Elegance Reviewer teammate scores code)
6. Lessons capture (lead synthesizes)
7. Pattern library update (lead writes)
8. Report generation (lead writes)
9. Audit Reviewer validates report (teammate)
10. **Shutdown teammates** (parallel)
11. **TeamDelete**
12. Cleanup

### File Changes

| File | Change |
|------|--------|
| `skills/audit/SKILL.md` | Add TeamCreate to allowed-tools. Add team creation at start of Phase 5. Move TeamDelete from inherited to owned. Update 10-step to 12-step ordering. Remove "spawned after remediation gate" Elegance Reviewer lifecycle note (now spawned with team at start). |
| `skills/audit/agents/elegance-reviewer.md` | Update from subagent prompt to teammate spawn template |
| `skills/audit/agents/audit-reviewer.md` | Update from subagent prompt to teammate spawn template |
| `skills/audit/agents/reviewer.md` | New: spawn template for audit-stage reviewer (runs completion gate checks) |

---

## Section 4: Cross-Stage Handoff — Workspace Only

### Progress.md Stage Tracking

New field in `progress.md`:
```markdown
**Stage**: {plan|execute|audit}
**Status**: {approved|executed|audited}
```

Stage transitions:
- Plan stage writes: `**Stage**: plan`, then `**Status**: approved` after user approval
- Execute stage writes: `**Stage**: execute`, then `**Status**: executed` after TeamDelete
- Audit stage writes: `**Stage**: audit`, then `**Status**: audited` after TeamDelete

### Preconditions per Stage

| Stage | Precondition | What it checks |
|-------|-------------|----------------|
| `plan` | None (or task description) | Starts fresh |
| `execute` | `**Status**: approved` in progress.md | Plan stage completed and user approved |
| `audit` | `**Status**: executed` in progress.md | Execute stage completed |

### Independent Invocation

| Command | Creates team? | Precondition |
|---------|--------------|--------------|
| `/agent-team:start [task]` | 3 teams sequentially | None |
| `/agent-team:plan [task]` | Planning team | None |
| `/agent-team:execute` | Execution team | Workspace with approved plan |
| `/agent-team:audit` | Audit team | Workspace with executed results |

Each invocation is fully self-contained: TeamCreate → work → TeamDelete.

---

## Summary of All File Changes

### New Files

| File | Purpose |
|------|---------|
| `skills/plan/agents/researcher.md` | Spawn template for plan-stage researcher |
| `skills/plan/agents/analyst.md` | Spawn template for plan-stage analyst |
| `skills/audit/agents/reviewer.md` | Spawn template for audit-stage reviewer |

### Modified Files

| File | Change |
|------|--------|
| `skills/plan/SKILL.md` | Add TeamCreate/TeamDelete/SendMessage to tools. Add team creation, coordination, shutdown. |
| `skills/plan/agents/plan-reviewer.md` | Subagent prompt → teammate spawn template |
| `skills/execute/SKILL.md` | Own TeamDelete (no longer delegated to audit). Write `**Status**: executed`. |
| `skills/execute/agents/execute-reviewer.md` | Subagent prompt → teammate spawn template |
| `skills/execute/references/communication-protocol.md` | Add FINDING and ANALYSIS message types |
| `skills/audit/SKILL.md` | Add TeamCreate. Own full lifecycle. Update to 12-step ordering. |
| `skills/audit/agents/elegance-reviewer.md` | Subagent prompt → teammate spawn template |
| `skills/audit/agents/audit-reviewer.md` | Subagent prompt → teammate spawn template |
| `docs/workspace-templates.md` | Add `**Stage**` and update `**Status**` field in progress.md template |
| `README.md` | Update How It Works to show 3 teams |
| `CLAUDE.md` | Update architecture description |
| `CHANGELOG.md` | Add team-per-stage entry |

### Version Impact

This is a **minor version bump** (3.0.0 → 3.1.0). No skill names change. Additive: each stage gains team management. Workspace format gains one new field.

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| 3 teams per task increases resource usage | Medium | Plan and audit teams are small (2-3); only execute is 2-4 |
| Plan team adds latency before user sees plan | Low | Researchers parallelize; plan team is fast for simple tasks |
| Audit team duplicates execute reviewer's work | Low | Execute reviewer is smoke test; audit team does deep review |
| Workspace handoff loses live team context | Low | Workspace files already capture all decisions, issues, events |

---

## Testing Plan

| Test | Validates |
|------|-----------|
| Plan stage frontmatter has TeamCreate, TeamDelete, SendMessage | Tools updated |
| Audit stage frontmatter has TeamCreate | Tools updated |
| Plan stage has researcher.md and analyst.md | New spawn templates exist |
| Audit stage has reviewer.md | New spawn template exists |
| FINDING and ANALYSIS in communication-protocol.md | New message types |
| `**Stage**` field in workspace-templates.md progress.md | Handoff field exists |
| `**Status**: executed` documented | Execute stage marker |
| Integration: `/agent-team:plan` creates and destroys its own team | Full lifecycle |
| Integration: `/agent-team:audit` works without prior team | Independent invocation |
