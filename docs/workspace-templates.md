# Workspace Templates

Templates for the 3 workspace tracking files initialized during Phase 3. The lead creates these immediately after TeamCreate.

## Contents

- [progress.md](#progressmd) — team status, members, phase checklist, decisions, handoffs
- [tasks.md](#tasksmd) — task ledger with status tracking
- [issues.md](#issuesmd) — issue tracker with severity and impact
- [Additional Workspace Files](#additional-workspace-files) — files created during Phase 3/4 (not template-based)
- [Workspace Update Protocol](#workspace-update-protocol) — event-to-file mapping table

## progress.md

````markdown
# Team: {team-name}

**Task**: {one-line description of the overall task}
**Status**: active | completing | done
**Created**: {timestamp}
**Last updated**: {timestamp}
**Remediation cycle**: 0

## References

Source documents for this team's work.

| Type | Path/URL | Description |
|------|----------|-------------|
| {spec/ADR/design/PR/doc} | {path or URL} | {one-line description} |

## Team Members

| Name | Role | Status | Current Task |
|------|------|--------|-------------|
| {name} | {role} | active / idle / shutdown | {task ID or "—"} |

## Phase Checklist

- [ ] Phase 1a: Plan detected/created, audited, user approved plan
- [ ] Phase 1b: Decomposed plan into 2+ independent streams
- [ ] Phase 2: Presented team decomposition, received user confirmation
- [ ] Phase 3: TeamCreate, workspace initialized, tasks created, teammates spawned
- [ ] Phase 4: All teammates sent STARTING, coordination active
- [ ] Phase 5a: Completion Gate passed (uncommitted, build, lint, integration, security, issues, plan, docs)
- [ ] Phase 5b: Plan status updated, report generated, teammates shut down, cleanup done

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

| ID | Subject | Owner | Ref | Notes |
|----|---------|-------|-----|-------|

## Blocked

| ID | Subject | Owner | Ref | Blocked By | Notes |
|----|---------|-------|-----|-----------|-------|

## Pending

| ID | Subject | Owner | Ref | Blocked By | Notes |
|----|---------|-------|-----|-----------|-------|

## Completed

| ID | Subject | Owner | Ref | Notes |
|----|---------|-------|-----|-------|
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

## Additional Workspace Files

These files are created during Phase 3/4 but are not template-based — they are generated from runtime data.

## Workspace Update Protocol

The lead updates workspace files at every significant event. When multiple events arrive close together, batch them into a single edit per file.

| Event | File | What to update |
|-------|------|---------------|
| Team created | All 3 files | Initialize from templates |
| Tasks created | tasks.md | Fill task ledger |
| Teammate spawned | progress.md | Add row to Team Members |
| Task started | tasks.md | Status -> `in_progress` |
| Task completed | tasks.md | Status -> `completed`, add notes |
| Decision made | progress.md | Append to Decision Log |
| Handoff occurs | progress.md | Append to Handoffs |
| Issue found | issues.md | Append row, update Open count |
| Issue resolved | issues.md | Status -> RESOLVED/MITIGATED, update counts |
| Teammate status change | progress.md | Update Team Members table |
| All work done | progress.md | Status -> `done` |
| Teammate spawned | events.log | Append spawn event (also auto-logged by SubagentStart hook) |
| Task started | events.log | Append task_start event |
| Task completed | events.log | Append task_complete event |
| Blocked event | events.log | Append blocked event |
| Handoff occurs | events.log | Append handoff event |
| Decision made | events.log | Append decision event |

### file-locks.json

Created during Phase 3 after spawning teammates. Maps each teammate to their owned files/directories. Used by the PreToolUse(Write|Edit) hook to enforce file ownership.

**When to create**: Only for archetypes with teammates that write project files (Implementation, Hybrid with implementers). **SKIP for read-only archetypes** (Research, Audit, Planning) — these teams have no file ownership to enforce.

```json
{
  "teammate-name": ["src/auth/", "src/middleware/auth.ts"],
  "other-teammate": ["src/api/", "tests/api/"]
}
```

### events.log

Created by the SubagentStart/SubagentStop hooks during Phase 4. Each line is a JSON object recording teammate spawn and stop events. Used for post-mortem analysis.

Event types: `spawn`, `stop`, `task_start`, `task_complete`, `blocked`, `handoff`, `decision`, `replan`.

```json
{"ts":"2026-03-01T00:00:00Z","type":"spawn","agent":"backend-impl","agent_type":"general-purpose"}
{"ts":"2026-03-01T01:00:00Z","type":"stop","agent":"backend-impl"}
```

### report.md

Generated during Phase 5 using the template in [report-format.md](report-format.md). This is the final artifact written before shutdown.

## Plan File Conventions

Plan files used by Agent Team Phase 1a follow these conventions. The Team Lead reads and writes these status values during plan scanning and Phase 5 completion.

### Status Values

| Status | Meaning | Set by |
|--------|---------|--------|
| (none) | Plan has not been started | — |
| `IN PROGRESS` | Plan is currently being executed | Team Lead at Phase 3 start |
| `COMPLETED — Implemented via team {team-name} (YYYY-MM-DD)` | All plan tasks finished | Team Lead at Phase 5 |
| `PARTIAL — {N}/{total} tasks completed via team {team-name} (YYYY-MM-DD). Remaining: {list}` | Some tasks incomplete | Team Lead at Phase 5 |
| `ABANDONED — Team {team-name} (YYYY-MM-DD). Reason: {reason}` | Team failed or was stopped | Team Lead at Phase 5 |

### Scan Behavior

- Phase 1a Step 1 skips files with `COMPLETED` or `ABANDONED` status
- `PARTIAL` plans are eligible for re-use — they appear in scan results with their remaining tasks highlighted
- `IN PROGRESS` plans trigger a warning: "This plan is being executed by another team"

### Minimum Structure

A plan file must contain:
1. Identifiable task descriptions (numbered sections or markdown headings)
2. Enough specificity to map tasks to files or modules
3. A `Status:` field in the header (recommended but not required — absence is treated as "not started")

## See Also

- [team-archetypes.md](team-archetypes.md) — defines which workspace files are created per team type
