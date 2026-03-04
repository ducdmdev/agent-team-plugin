# Workspace Templates

Templates for the 3 workspace tracking files initialized during Phase 3. The lead creates these immediately after TeamCreate.

## Contents

- [progress.md](#progressmd) — team status, members, phase checklist, decisions, handoffs
- [tasks.md](#tasksmd) — task ledger with status tracking
- [issues.md](#issuesmd) — issue tracker with severity and impact
- [Additional Workspace Files](#additional-workspace-files) — files created during Phase 3/4 (not template-based)

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

### file-locks.json

Created during Phase 3 after spawning teammates. Maps each teammate to their owned files/directories. Used by the PreToolUse(Write|Edit) hook to enforce file ownership.

```json
{
  "teammate-name": ["src/auth/", "src/middleware/auth.ts"],
  "other-teammate": ["src/api/", "tests/api/"]
}
```

### events.log

Created by the SubagentStart/SubagentStop hooks during Phase 4. Each line is a JSON object recording teammate spawn and stop events. Used for post-mortem analysis.

```json
{"ts":"2026-03-01T00:00:00Z","type":"spawn","agent":"backend-impl","agent_type":"general-purpose"}
{"ts":"2026-03-01T01:00:00Z","type":"stop","agent":"backend-impl"}
```

### report.md

Generated during Phase 5 using the template in [report-format.md](report-format.md). This is the final artifact written before shutdown.
