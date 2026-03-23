# Workspace Templates

Templates for the 3 workspace tracking files initialized during Phase 3. The lead creates these immediately after TeamCreate.

## Contents

- [progress.md](#progressmd) — team status, members, phase checklist, decisions, handoffs
- [tasks.md](#tasksmd) — task ledger with status tracking
- [issues.md](#issuesmd) — issue tracker with severity and impact
- [Additional Workspace Files](#additional-workspace-files) — files created during Phase 3/4 (not template-based)
- [Workspace Update Protocol](#workspace-update-protocol) — event-to-file mapping table
- [lessons.md](#lessonsmd) — team execution insights captured during audit
- [error-patterns.json (Global)](#error-patternsjson-global) — cross-project error pattern library

## progress.md

````markdown
# Team: {team-name}

**Task**: {one-line description of the overall task}
**Status**: active | completing | done
**Created**: {timestamp}
**Last updated**: {timestamp}
**Remediation cycle**: 0
**Recovery cycles**: 0

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

## Plan Proposals

| Teammate | Task | Proposal | Status | Revisions |
|----------|------|----------|--------|-----------|

## Handoffs

Cross-teammate information transfers.

- [{timestamp}] {source} → {target}: {what was handed off}
````

## tasks.md

````markdown
# Tasks: {team-name}

**Last updated**: {timestamp}

## In Progress

| ID | Subject | Owner | Ref | CP | Notes |
|----|---------|-------|-----|----|-------|

## Blocked

| ID | Subject | Owner | Ref | CP | Blocked By | Notes |
|----|---------|-------|-----|----|-----------|-------|

## Pending

| ID | Subject | Owner | Ref | CP | Blocked By | Notes |
|----|---------|-------|-----|----|-----------|-------|

## Completed

| ID | Subject | Owner | Ref | CP | Notes |
|----|---------|-------|-----|----|-------|
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

## Issue Detail Fields

Per-issue fields appended below the table row when relevant:

- **Error type**: {retry|recoverable|design_flaw|unknown}
- **Recovery attempts**:
  1. {strategy} — {SUCCEEDED|FAILED}
- **Pattern captured**: {Yes (pattern-NNN)|No}
````

## Additional Workspace Files

These files are created during Phase 3/4 but are not template-based — they are generated from runtime data.

## Workspace Update Protocol

The lead updates workspace files at every significant event. When multiple events arrive close together, batch them into a single edit per file.

| Event | File | What to update |
|-------|------|---------------|
| Team created | All 3 files | Initialize from templates |
| Tasks created | tasks.md | Fill task ledger |
| Tasks created | task-graph.json | Initialize full graph with nodes, compute critical path and convergence points |
| Teammate spawned | progress.md | Add row to Team Members |
| Task started | tasks.md | Status -> `in_progress` |
| Task started | task-graph.json | Node status → `in_progress` |
| Task completed | tasks.md | Status -> `completed`, add notes |
| Task completed | task-graph.json | Node status → `completed`, set `completed_at` and `output_files`, recompute `critical_path`. Self-check: read back to verify valid JSON. |
| Task blocked | task-graph.json | Node status → `blocked` |
| Re-plan occurs | task-graph.json | Rebuild graph from revised tasks |
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

### task-graph.json

Created during Phase 3 step 4a immediately after creating all tasks. Contains the full dependency graph as a DAG with critical path and convergence point metadata. Read by `compute-critical-path.sh`, `detect-resume.sh`, and `check-integration-point.sh` hooks.

**When to create**: ALL archetypes.

> After updating, read the file back to verify valid JSON — malformed JSON silently disables all three hook scripts.

#### Schema

```json
{
  "team": "{team-name}",
  "created": "{ISO 8601 timestamp}",
  "updated": "{ISO 8601 timestamp}",
  "nodes": {
    "#{id}": {
      "subject": "{task subject line}",
      "owner": "{teammate-name}",
      "status": "pending|in_progress|completed|blocked",
      "depends_on": ["#{id}"],
      "completed_at": "{ISO 8601 timestamp}|null",
      "output_files": ["{relative file paths}"],
      "critical_path": true,
      "convergence_point": true
    }
  },
  "critical_path": ["#{id}"],
  "critical_path_length": 0
}
```

#### Field Reference

| Field | Type | Description |
|---|---|---|
| `team` | string | Team name matching TeamCreate |
| `created` | ISO timestamp | When the graph was first created |
| `updated` | ISO timestamp | Last modification time |
| `nodes` | object | Map of task ID → node data |
| `nodes.*.subject` | string | Task subject line |
| `nodes.*.owner` | string | Assigned teammate name |
| `nodes.*.status` | enum | `pending`, `in_progress`, `completed`, `blocked` |
| `nodes.*.depends_on` | string[] | Task IDs this node depends on |
| `nodes.*.completed_at` | timestamp/null | When the task was completed (null if not yet) |
| `nodes.*.output_files` | string[] | Relative file paths produced by this task |
| `nodes.*.critical_path` | boolean | Whether this node is on the current critical path |
| `nodes.*.convergence_point` | boolean | Whether this node has 2+ upstream dependencies. Scripts derive converging task IDs from `depends_on` when this is `true` — no separate `converges_from` field needed. |
| `nodes.*.approach` | string (optional) | Description of the planned implementation approach |
| `nodes.*.fallback_approach` | string (optional) | Alternative approach if primary fails |
| `nodes.*.fallback_reason` | string (optional) | When to activate the fallback (e.g., "Use if JWT library has compatibility issues") |
| `critical_path` | string[] | Ordered list of task IDs forming the current critical path |
| `critical_path_length` | number | Number of nodes on the critical path |

#### Lifecycle

| Phase | Action |
|---|---|
| Phase 3 step 4a | Create with full graph. Compute initial critical path and convergence points |
| Phase 4 (STARTING) | Update node status to `in_progress` |
| Phase 4 (COMPLETED) | Update node status to `completed`, set `completed_at` and `output_files`. Recompute `critical_path`. **Self-check**: read the file back after editing to verify JSON is valid — malformed JSON silently disables all three hook scripts. |
| Phase 4 (BLOCKED) | Update node status to `blocked` |
| Phase 4 (re-plan) | Rebuild graph from revised task set |
| Phase 5 | Final state preserved as audit artifact |
| Resume | Read by `detect-resume.sh`, stale nodes reset to `pending` |

#### Applicability by Archetype

| Archetype | Create task-graph.json? | Critical path useful? | Convergence points useful? | Resume useful? |
|---|---|---|---|---|
| Implementation | Yes | Yes — prioritize build chain | Yes — diamond deps on shared interfaces | Yes — code artifacts have output_files |
| Research | Yes | Yes — prioritize blocking research angles | Rare — research streams usually independent | Limited — no output files to validate |
| Audit | Yes | Yes — prioritize blocking audit lenses | Rare — audit lenses usually independent | Limited — no output files to validate |
| Planning | Yes | Yes — prioritize blocking planning concerns | Sometimes — design decisions may converge | Limited — workspace-only outputs |
| Hybrid | Yes | Yes | Yes — mixed streams often converge | Yes — implementation components have output_files |

Note: For read-only archetypes (Research, Audit, Planning), `output_files` will typically be empty or reference workspace files. Staleness validation in resume mode uses git-tracked files only, so resume is most valuable for Implementation and Hybrid teams.

### lessons.md

Created by the audit stage (`agent-team:audit`) during Phase 5 post-step. Captures team execution insights for future teams.

````markdown
# Lessons Learned — {team-name}

## What Worked
- {lesson}

## What Failed
- {lesson}: **Root cause**: {why}

## Estimation Accuracy
| Task | Estimated | Actual | Delta |
|------|-----------|--------|-------|
| {task} | {est} | {actual} | {+/-} |

## Integration Friction Points
- {point}: {resolution}

## Recommendations for Future Teams
- {recommendation}
````

**Fields:**
- **What Worked**: Patterns, tools, approaches that saved time or prevented issues
- **What Failed**: Problems encountered + root cause analysis (not just symptoms)
- **Estimation Accuracy**: Compare task-graph.json `created_at` vs `completed_at` timestamps
- **Integration Friction Points**: Where handoffs or convergence caused delays
- **Recommendations**: Concrete, actionable advice for future teams with similar scope

### error-patterns.json (Global)

Stored at `~/.claude/agent-team-patterns.json`. Created at runtime by the audit stage if not present. Shared across all projects.

```json
{
  "patterns": [
    {
      "id": "pattern-001",
      "error_regex": "Cannot find module",
      "error_type": "recoverable",
      "context": "import resolution",
      "strategies": ["check_tsconfig_paths", "verify_package_installed"],
      "success_rate": { "attempts": 10, "successes": 8 },
      "last_seen": "2026-03-20",
      "source_team": "0320-refactor-imports"
    }
  ]
}
```

**Fields:**
- **id**: Unique pattern identifier (pattern-NNN)
- **error_regex**: Regex matching the error message
- **error_type**: One of `retry`, `recoverable`, `design_flaw`
- **context**: Short description of when this error occurs
- **strategies**: Ordered list of recovery actions to try
- **success_rate**: Attempts and successes for tracking effectiveness
- **last_seen**: ISO date of last occurrence
- **source_team**: Team that first captured this pattern

**Lifecycle:**
- Created by audit stage Sub-step 3 (only from resolved issues)
- Max 5 new patterns per team (highest severity first)
- Global cap: 200 patterns. Evict lowest `success_rate` when full
- Deduplication by `error_regex` similarity
- If `~/.claude/` doesn't exist, create with `mkdir -p`

### events.log

Created by the SubagentStart/SubagentStop hooks during Phase 4. Each line is a JSON object recording teammate spawn and stop events. Used for post-mortem analysis.

Event types: `spawn`, `stop`, `task_start`, `task_complete`, `blocked`, `handoff`, `decision`, `replan`.

```json
{"ts":"2026-03-01T00:00:00Z","type":"spawn","agent":"backend-impl","agent_type":"general-purpose"}
{"ts":"2026-03-01T01:00:00Z","type":"stop","agent":"backend-impl"}
```

### report.md

Generated during Phase 5 using the template in [report-format.md](../skills/audit/references/report-format.md). This is the final artifact written before shutdown.

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
