# Workspace Templates

Templates for the 3 workspace tracking files initialized during Phase 3. The lead creates these immediately after TeamCreate.

## Contents

- [progress.md](#progressmd) — team status, members, phase checklist, decisions, handoffs
- [tasks.md](#tasksmd) — task ledger with status tracking
- [issues.md](#issuesmd) — issue tracker with severity and impact

## progress.md

````markdown
# Team: {team-name}

**Task**: {one-line description of the overall task}
**Status**: active | completing | done
**Created**: {timestamp}
**Last updated**: {timestamp}
**Remediation cycle**: 0

## Team Members

| Name | Role | Status | Current Task |
|------|------|--------|-------------|
| {name} | {role} | active / idle / shutdown | {task ID or "—"} |

## Phase Checklist

- [ ] Phase 1: Decomposed task, identified 2+ independent streams
- [ ] Phase 2: Presented plan, received user confirmation
- [ ] Phase 3: TeamCreate, workspace initialized, tasks created, teammates spawned
- [ ] Phase 4: All teammates sent STARTING, coordination active
- [ ] Phase 5: All tasks completed, report generated, teammates shut down, cleanup done

## Decision Log

Append-only log of significant decisions.

- [{timestamp}] {decision and reasoning}

## Handoffs

Cross-teammate information transfers.

- [{timestamp}] {source} → {target}: {what was handed off}
````

## tasks.md

````markdown
# Tasks: {team-name}

**Last updated**: {timestamp}

## In Progress

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|

## Blocked

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Pending

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Completed

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
````

## issues.md

````markdown
# Issues: {team-name}

**Last updated**: {timestamp}
**Open**: 0 | **Resolved**: 0

| # | Severity | Reporter | Description | Impact | Affected Tasks | Status | Resolution |
|---|----------|----------|-------------|--------|---------------|--------|------------|

## Severity Guide
- **critical**: Blocks multiple teammates or the entire team
- **high**: Blocks one teammate or one task chain
- **medium**: Degrades quality or slows progress but work continues
- **low**: Cosmetic, minor, or nice-to-have

## Impact Categories
- **blocked**: Work cannot proceed
- **degraded**: Quality or scope reduced
- **rework**: Completed work must be redone
- **deferred**: Logged for post-team follow-up
````
