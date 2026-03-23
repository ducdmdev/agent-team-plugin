# Plan-Mode Protocol

## Purpose

For non-trivial tasks, teammates propose their approach before executing. The lead reviews and approves, preventing wasted work on the wrong approach. This is an orchestration-level pattern that ensures alignment before code is written.

## Activation

Plan-mode activates per-teammate when task complexity >= standard (3+ steps or architectural decisions). The lead marks plan-mode teammates in the Phase 2 plan presentation. User can override: "make all teammates plan-mode" or "skip plan-mode".

**Archetype defaults:**

| Archetype | Plan-mode default | Rationale |
|-----------|-------------------|-----------|
| Implementation | ON for complexity >= standard | Prevents wasted coding effort on wrong approach |
| Research | OFF | Researchers explore freely; constraining defeats purpose |
| Audit | OFF | Auditors follow checklists; proposals add overhead |
| Planning | ON always | Planners should propose before drafting |
| Hybrid | Follows detected archetype rules | Mixed teams use the most relevant default |

## Ownership Boundary

- **Plan stage** (`agent-team:plan`): MARKS which teammates get plan-mode in the Phase 2 presentation
- **Execute stage** (`agent-team:execute`): INJECTS the directive into spawn prompts and handles PLAN_PROPOSAL evaluation during Phase 4 coordination

The plan stage determines *who* needs plan-mode. The execute stage enforces *how* it works at runtime.

## Spawn Directive

Injected by execute stage into plan-mode teammates' spawn prompts:

```
PLAN-MODE ACTIVE: Before writing any code, send a PLAN_PROPOSAL message to the lead.
Do NOT write/edit files until you receive PLAN_APPROVED.
```

## Message Types

### PLAN_PROPOSAL

Sent by teammate to lead after analyzing their assigned task:

```
PLAN_PROPOSAL #N:
  approach={description of proposed approach}
  alternatives_considered={what else was evaluated and why rejected}
  files_to_touch={list of files to create/modify}
  estimated_complexity={low|medium|high}
  risks={potential issues or unknowns}
```

### PLAN_APPROVED

Sent by lead to teammate when proposal is accepted:

```
PLAN_APPROVED #N
```

The teammate may now proceed with implementation.

### PLAN_REVISION

Sent by lead to teammate when proposal needs changes:

```
PLAN_REVISION #N: {specific feedback on what needs to change}
```

The teammate revises their proposal and sends a new PLAN_PROPOSAL.

## Revision Limits

Max 2 revision rounds per teammate. After 2 rounds:
- If the proposal is close, the lead accepts the current version with notes
- If the proposal is fundamentally misaligned, the lead reassigns the task to a different teammate or restructures the approach

## Workspace Tracking

Proposals are logged in `progress.md` Plan Proposals table:

```markdown
## Plan Proposals
| Teammate | Task | Proposal | Status | Revisions |
|----------|------|----------|--------|-----------|
| auth-impl-1 | #1 | Refactor via adapter pattern | Approved | 0 |
| db-impl-2 | #3 | Migrate to connection pooling | Revision requested | 1 |
```

Status values: `Pending`, `Approved`, `Revision requested`, `Rejected`

## Relationship to Platform mode: "plan"

This plan-mode gate is an **orchestration-level pattern** -- teammates propose their overall approach via structured messages to the lead. It is DISTINCT from the Claude Code platform `mode: "plan"` parameter, which gates individual tool use at the agent level.

| Concept | Scope | What it controls |
|---------|-------|-----------------|
| Plan-mode protocol (this doc) | Team coordination | Teammate proposes approach before writing code |
| Platform `mode: "plan"` | Individual agent | Agent cannot use Write/Edit tools until mode changes |

Both can be used together: a teammate spawned with `mode: "plan"` AND the plan-mode directive will first propose their approach (orchestration level), get approved, then have their platform mode changed to allow tool use (platform level). However, the orchestration-level protocol is sufficient on its own for most cases.
