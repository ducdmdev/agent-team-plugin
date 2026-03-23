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

### Team Naming

All 3 teams share the **same team name** (`MMDD-{task-slug}`) and the **same workspace directory** (`.agent-team/{team-name}/`). Each stage calls TeamCreate with the same name, uses the workspace, then TeamDelete. The workspace persists across all three stages; only the team resource is ephemeral.

When chained via `start`, the start skill generates the team name once and each stage reuses it. When invoked independently, the stage reads the team name from the existing workspace directory.

### Workspace Creation

The **plan stage** creates the workspace directory at the start of its team lifecycle (after TeamCreate, before spawning teammates). This is a change from the current design where the execute stage creates the workspace. The plan stage initializes:
- `progress.md` with `**Stage**: plan`, `**Archetype**: {type}`, and Learned Context
- `tasks.md` (empty, populated during decomposition)
- `task-graph.json` (empty, populated during decomposition)

The execute and audit stages read and extend the existing workspace — they do NOT re-create it.

### Parent Spec Overrides

This addendum overrides the following from the parent spec (`2026-03-23-workflow-orchestration-integration-design.md`):
- Plan stage frontmatter: gains `TeamCreate, TeamDelete, SendMessage` (parent had no team tools)
- Audit stage frontmatter: gains `TeamDelete` (parent had `TeamCreate` but not `TeamDelete`)
- Elegance Reviewer lifecycle: now spawned with the audit team at stage start (parent said "spawned after remediation gate")
- Workspace creation: now owned by plan stage (parent said execute stage)

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
TeamCreate → create workspace → spawn planning team → researchers scan codebase →
analyst evaluates → lead decomposes → plan-reviewer validates (max 2 fix cycles) →
shutdown teammates → TeamDelete → user approval
```

**TeamDelete timing**: The planning team is shut down BEFORE presenting the plan to the user. The team's job is to gather information and validate the plan structure. User approval is a lead-only interaction that doesn't need the team alive. This keeps the team lifecycle short and predictable.

**If invoked independently** (`/agent-team:plan`): Same lifecycle. After TeamDelete, the lead presents the plan and waits for user approval. Workspace persists with `**Pipeline status**: approved`.

### Communication

Researchers use structured messages:
```
FINDING: {what was found}, relevance={high|medium|low}, files=[{paths}]
```

Analyst sends:
```
ANALYSIS: complexity={low|medium|high}, risks=[{risk list}], estimate={scope description}, parallelizable={yes|no|partial}
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
| `skills/execute/SKILL.md` | Add TeamDelete to Phase 4 (after execute-review passes). Write `**Pipeline status**: executed` to progress.md before shutdown. |
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
- `progress.md` contains `**Pipeline status**: executed` (set by execute stage after shutdown)
- If all tasks incomplete → exit with "nothing to audit"
- **No dependency on execute team being alive** — audit creates its own team

### Frontmatter Changes

`skills/audit/SKILL.md` gains TeamDelete (TeamCreate already present):
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

Two new fields in `progress.md` (distinct from the existing `**Status**: active | completing | done` field which tracks team lifecycle):

```markdown
**Stage**: {plan|execute|audit}
**Pipeline status**: {approved|executed|audited}
```

The existing `**Status**` field tracks the team's internal lifecycle (active/completing/done). The new `**Pipeline status**` field tracks cross-stage handoff state. Both are needed and do not conflict.

Stage transitions:
- Plan stage creates workspace, writes `**Stage**: plan`. After user approval: `**Pipeline status**: approved`
- Execute stage updates `**Stage**: execute`. After TeamDelete: `**Pipeline status**: executed`
- Audit stage updates `**Stage**: audit`. After TeamDelete: `**Pipeline status**: audited`

### Backward Compatibility

If execute is invoked on a workspace without `**Pipeline status**` (e.g., hand-crafted or legacy workspace), treat the absence as "not gated" — proceed as if approved. Similarly, if audit is invoked without `**Pipeline status**: executed`, proceed with a warning but do not block.

### Skipping Stages

Running audit directly after plan (skipping execute) is intentionally blocked — the precondition `**Pipeline status**: executed` prevents this. If the user wants to audit without executing, they should run `/agent-team:audit` on a workspace where work was done manually (no `**Pipeline status**` field → backward compatibility allows it).

### Preconditions per Stage

| Stage | Precondition | What it checks |
|-------|-------------|----------------|
| `plan` | None (or task description) | Starts fresh |
| `execute` | `**Pipeline status**: approved` in progress.md | Plan stage completed and user approved |
| `audit` | `**Pipeline status**: executed` in progress.md | Execute stage completed |

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
| `skills/start/SKILL.md` | Update orchestration narrative: each stage creates/destroys its own team. **Keep** TeamCreate/TeamDelete/SendMessage in frontmatter (start inlines stage logic and needs all stage tools). Update Pipeline Flow text only. |
| `skills/plan/SKILL.md` | Add TeamCreate/TeamDelete/SendMessage to tools. Add workspace creation, team creation, coordination, shutdown. |
| `skills/plan/agents/plan-reviewer.md` | Add `## Communication` section with SendMessage protocol; update SKILL.md references from "spawn subagent" to "spawn teammate" |
| `skills/execute/SKILL.md` | Own TeamDelete (no longer delegated to audit). Write `**Pipeline status**: executed`. Update preconditions to check `**Pipeline status**: approved` (with backward-compat fallback). Gate Phase 3 workspace creation: skip if workspace already exists (plan stage created it). |
| `skills/execute/agents/execute-reviewer.md` | Add `## Communication` section with SendMessage protocol; update SKILL.md references from "spawn subagent" to "spawn teammate" |
| `skills/execute/references/communication-protocol.md` | Add FINDING and ANALYSIS message types |
| `skills/audit/SKILL.md` | Add TeamDelete to allowed-tools (TeamCreate already present). Own full lifecycle. Update to 12-step ordering. Add `**Pipeline status**: executed` precondition with backward-compat fallback. |
| `skills/audit/agents/elegance-reviewer.md` | Add `## Communication` section with SendMessage protocol; update SKILL.md references from "spawn subagent" to "spawn teammate" |
| `skills/audit/agents/audit-reviewer.md` | Add `## Communication` section with SendMessage protocol; update SKILL.md references from "spawn subagent" to "spawn teammate" |
| `docs/workspace-templates.md` | Add `**Stage**`, `**Pipeline status**`, and `**Archetype**` fields to progress.md template (distinct from existing `**Status**` field) |
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
| `**Pipeline status**: executed` documented | Execute stage marker |
| Integration: `/agent-team:plan` creates and destroys its own team | Full lifecycle |
| Integration: `/agent-team:audit` works without prior team | Independent invocation |
