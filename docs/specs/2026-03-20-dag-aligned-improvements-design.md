# DAG-Aligned Improvements — Design Spec

**Date**: 2026-03-20
**Version**: v2.6.0
**Status**: DRAFT

## Summary

Add three DAG-aligned features to the agent-team-plugin: Critical Path Identification, Task-Level Resume/Caching, and Early Integration Checkpoints. All three share a centralized `task-graph.json` workspace file as their core data structure.

## Motivation

The agent-team-plugin uses DAG-like task dependencies (blocked-by relationships) but lacks explicit DAG primitives. A deep dive review against industry DAG best practices (workflow orchestration, build systems, CI/CD) identified three high-impact gaps:

1. **Critical path is implicit** — the lead treats all tasks equally rather than prioritizing the chain that determines total execution time
2. **No task-level caching** — interrupted teams restart from scratch with no way to skip completed work
3. **Integration checks come too late** — diamond dependency conflicts are only caught at the Phase 5 completion gate, after all work is done

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Scope | All 3 features in v2.6.0 | Features share `task-graph.json` — shipping together avoids partial schema |
| Implementation depth | Documentation + scripts + hooks | Full enforcement, consistent with plugin's existing hook-based discipline |
| Hook model | Separate entries per feature | Single responsibility per script, consistent with DAG atomicity principle |
| Dependency data | `task-graph.json` (scripts) + `tasks.md` CP column (humans) | JSON for reliable script computation, markdown for visual awareness |
| Resume behavior | Smart resume with staleness validation | Validates completed work via git timestamps before reuse |
| Integration trigger | Informational nudge | Consistent with TeammateIdle pattern — hooks surface info, lead decides action |

## Feature 1: Critical Path Identification

### What It Does

Computes and displays the longest dependency chain in the task graph. Focuses the lead's attention on tasks that determine total execution time.

### Where It Appears

- **Phase 2** — plan presentation shows the critical path and non-critical tasks
- **Phase 3** — `task-graph.json` created with initial critical path computed
- **Phase 4** — `compute-critical-path.sh` hook fires on every TaskCompleted, outputs remaining critical path. Lead prioritizes critical-path blockers.
- **Phase 5** — report includes critical path metrics (initial length, final length, shift count)

### Critical Path Computation

Longest-path traversal on the DAG:

1. **Cycle guard**: Before computing, validate the graph is acyclic — for each node, trace `depends_on` chains and track visited nodes. If any chain revisits a node, the graph has a cycle. Log an error and skip critical path computation (the lead must fix the cycle per the existing Circular Dependency Detection pattern in `coordination-advanced.md`).
2. For each node with no dependents (leaf/sink nodes), trace backward through `depends_on` chains
3. The longest chain (by node count) is the critical path
4. **Tie-breaking**: when multiple chains have the same length, select the chain whose first node has the lowest task ID (lexicographic order). This ensures deterministic output across recomputations.
5. Mark all nodes on this chain with `critical_path: true`
6. Recompute after every status change — the critical path can shift as tasks complete

### Phase 2 Display

Add to plan presentation after the Task breakdown:

```
Critical path: #1 → #3 → #4 (length: 3)
  Non-critical (can slip without affecting total time): #2
  Integration checkpoints: #3 (converges #1 + #2 — verify interface compatibility)
```

Add to Phase 2 self-check:

> "Have I identified the critical path? Is it displayed in the plan? Are convergence points marked?"

### Phase 4 Prioritization Rules

- **BLOCKED on critical path** → resolve immediately (highest-priority coordination action)
- **BLOCKED on non-critical path** → resolve normally (slippage has slack)
- **Teammate idle on critical path** → reassign work to keep critical chain moving
- **Teammate idle on non-critical path** → lower priority, consider assigning critical-path support

### Deadline Escalation Integration

Critical-path tasks get accelerated escalation:
- Critical-path task stalled → skip Nudge, go directly to Warn
- Non-critical task stalled → follow normal Nudge → Warn → Escalate ladder

### `tasks.md` CP Column

All four tables (In Progress, Blocked, Pending, Completed) gain a CP column:

```markdown
| ID | Subject | Owner | Ref | CP | Notes |
|----|---------|-------|-----|----|-------|
| #1 | Refactor token validation | auth-impl-1 | | ★ | |
| #3 | Update middleware | auth-impl-1 | | ★ | convergence: #1, #2 |
```

`★` marks critical path tasks. `convergence: #X, #Y` in Notes indicates convergence points. Lead updates markers when critical path shifts.

## Feature 2: Task-Level Resume/Caching

### What It Does

Detects existing workspaces with incomplete tasks at session start. Validates whether completed work is still fresh by checking git timestamps on output files. Presents the user with a resume-or-start-fresh choice.

### Resume Detection (`detect-resume.sh`)

Fires on every SessionStart (no matcher — broader than the existing compact-only `recover-context.sh`):

1. Scan for `.agent-team/*/task-graph.json` files
2. Skip workspaces where all nodes are `completed`
3. For incomplete workspaces, validate each completed task:
   - Read `completed_at` from node
   - Check `git log -1 --format=%cI -- <file>` for each `output_files` entry
   - **Valid**: file unchanged since `completed_at`
   - **Stale**: file modified after `completed_at`
   - **Missing**: file no longer exists
4. Output resume context to stdout (injected into conversation context) with valid/stale/remaining breakdown

### Resume Output Format

```
Resumable workspace found: .agent-team/0319-refactor-auth/
  Tasks: 2/4 completed, 2 remaining
  Completed (valid): #1 (Refactor token validation) — output files unchanged
  Completed (stale): #2 (Extract session management) — src/auth/session.ts modified after completion
  Remaining: #3 (Update middleware), #4 (Review all changes)
  Critical path (remaining): #3 → #4

  To resume: "resume team 0319-refactor-auth"
  To start fresh: proceed normally (existing workspace will be archived)
```

### Phase 3 Resume Protocol

New step 1a before TeamCreate:

If `detect-resume.sh` surfaced a resumable workspace, present options:

```
Existing workspace found: .agent-team/{team-name}/
  Completed (valid): {list}
  Completed (stale): {list}
  Remaining: {list}

Options:
1. Resume — skip valid completed tasks, re-run stale tasks, continue with remaining
2. Start fresh — archive existing workspace, create new
```

**If resuming**:
- Skip TeamCreate if team still exists
- Reuse workspace directory and all tracking files
- Reset stale nodes to `pending` in `task-graph.json`
- Create TaskCreate entries only for remaining + stale tasks
- Spawn teammates for remaining work
- Log in `progress.md` Decision Log: "Resumed from existing workspace. {N} valid, {M} stale, {K} remaining."
- Proceed to Phase 3 step 5 (spawn teammates)

**If starting fresh**:
- Rename `.agent-team/{team-name}/` to `.agent-team/{team-name}-archived/`
- Proceed with normal Phase 3

### Staleness Validation Details

Edge cases:
- `git` not available → skip staleness check, report all completed tasks as "valid (unverified)"
- Output file doesn't exist in git history → treat as valid (file was newly created by the task)
- `completed_at` is null → task was never completed, treat as remaining
- Multiple incomplete workspaces → list all, most recent first (by `updated` timestamp in `task-graph.json`)

## Feature 3: Early Integration Checkpoints

### What It Does

Detects when two converging streams both complete (diamond pattern) and nudges the lead to verify interface compatibility before the downstream task starts.

### Convergence Point Detection

Static analysis at Phase 3 creation time:
- A node is a convergence point when `depends_on` has 2+ entries
- Set `convergence_point: true` — scripts derive the converging tasks from `depends_on`
- Convergence points don't change during execution

### Integration Checkpoint Hook (`check-integration-point.sh`)

Fires on TaskCompleted:

1. Read `task-graph.json`
2. Find all nodes where `convergence_point: true`
3. For each, check if ALL `depends_on` nodes have `status: "completed"`
4. If fully unblocked, output nudge:

```
Integration checkpoint reached: Task #3 (Update middleware)
  All upstream tasks completed: #1 (auth-impl-1), #2 (auth-impl-2)
  These streams produced independent changes that must integrate at #3.
  Recommend: verify interface compatibility before #3 starts.
  Shared interfaces: check output_files of #1 and #2 for contract alignment.
```

5. Skip if convergence point is already `in_progress` or `completed`
6. Silent when no convergence point is fully unblocked

### Lead Response Protocol

When the hook fires an integration nudge:

1. Read `output_files` from both upstream tasks
2. Quick compatibility check — do the outputs define compatible interfaces?
3. **If compatible** → message convergence task owner: "Upstream tasks complete. Interfaces verified. Proceed."
4. **If unclear or incompatible** → message upstream owners + convergence owner: "Integration issue detected." Log in `issues.md` as medium severity.
5. Log in `progress.md` Decision Log: "Integration checkpoint: #Z unblocked by #X + #Y, compatibility [verified|flagged]"

### Phase 2 Display

Convergence points shown in plan presentation:

```
Integration checkpoints: #3 (converges #1 + #2 — verify interface compatibility)
```

### Phase 5 Completion Gate Integration

For `agent-implement`: Check #4 (Integration) gains awareness — if any convergence points were flagged during Phase 4, verify they were resolved before passing.

## Shared Data Structure: `task-graph.json`

### Schema

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

### Field Reference

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
| `critical_path` | string[] | Ordered list of task IDs forming the current critical path |
| `critical_path_length` | number | Number of nodes on the critical path |

### Lifecycle

| Phase | Action |
|---|---|
| Phase 3 step 4a | Create with full graph. Compute initial critical path and convergence points |
| Phase 4 (STARTING) | Update node status to `in_progress` |
| Phase 4 (COMPLETED) | Update node status to `completed`, set `completed_at` and `output_files`. Recompute `critical_path`. **Self-check**: read the file back after editing to verify JSON is valid — malformed JSON silently disables all three hook scripts. |
| Phase 4 (BLOCKED) | Update node status to `blocked` |
| Phase 4 (re-plan) | Rebuild graph from revised task set |
| Phase 5 | Final state preserved as audit artifact |
| Resume | Read by `detect-resume.sh`, stale nodes reset to `pending` |

### Applicability by Archetype

| Archetype | Create task-graph.json? | Critical path useful? | Convergence points useful? | Resume useful? |
|---|---|---|---|---|
| Implementation | Yes | Yes — prioritize build chain | Yes — diamond deps on shared interfaces | Yes — code artifacts have output_files |
| Research | Yes | Yes — prioritize blocking research angles | Rare — research streams usually independent | Limited — no output files to validate |
| Audit | Yes | Yes — prioritize blocking audit lenses | Rare — audit lenses usually independent | Limited — no output files to validate |
| Planning | Yes | Yes — prioritize blocking planning concerns | Sometimes — design decisions may converge | Limited — workspace-only outputs |
| Hybrid | Yes | Yes | Yes — mixed streams often converge | Yes — implementation components have output_files |

Note: For read-only archetypes (Research, Audit, Planning), `output_files` will typically be empty or reference workspace files. Staleness validation in resume mode uses git-tracked files only, so resume is most valuable for Implementation and Hybrid teams.

## New Scripts

### `scripts/compute-critical-path.sh`

**Hook event**: TaskCompleted
**Timeout**: 15s
**Exit code**: Always 0 (informational)

Behavior:
1. Read hook JSON input. Extract `cwd` (project directory) and `team_name`. If either is empty, exit 0.
2. Resolve workspace path: `${CWD}/.agent-team/${TEAM_NAME}/task-graph.json`. Try `-fix` suffix fallback for remediation teams (matching `verify-task-complete.sh` pattern).
3. Read `task-graph.json` — exit 0 silently if not found or `jq` missing
4. Validate DAG is acyclic (track visited nodes during traversal, break on revisit)
5. Find remaining (non-completed) nodes
6. Compute longest `depends_on` chain via depth-first traversal. Tie-break by lowest task ID.
7. Output critical path status to stderr

Output when critical-path task completes:
```
Critical path update: Task #1 completed (was on critical path).
Remaining critical path: #3 → #4 (length: 2)
Next critical task: #3 (owner: auth-impl-1, status: pending, blocked by: #2)
⚠ Critical task #3 is blocked — resolve blocker #2 to maintain throughput.
```

Output when non-critical task completes:
```
Task #2 completed (not on critical path). Critical path unchanged: #1 → #3 → #4 (length: 3)
```

Output when no chains remain:
```
No critical path — all remaining tasks can run in parallel.
```

### `scripts/detect-resume.sh`

**Hook event**: SessionStart (no matcher)
**Timeout**: 15s
**Exit code**: Always 0 (informational)

Behavior:
1. Read hook JSON input. Extract `cwd` (project directory). Fall back to `.` if empty. Exit 0 if `jq` missing.
2. Scan `${CWD}/.agent-team/*/task-graph.json` — exit 0 silently if none found
3. Filter to incomplete workspaces (any node not completed)
4. For each completed node, validate output files via `git log` timestamps
5. Output resume context to **stdout** (injected into conversation context, matching `recover-context.sh` pattern)

Staleness check:
- Compare `completed_at` timestamp with `git log -1 --format=%cI -- <file>`
- File modified after completion → stale
- File missing from git → valid (newly created)
- `git` unavailable → "valid (unverified)"

### `scripts/check-integration-point.sh`

**Hook event**: TaskCompleted
**Timeout**: 15s
**Exit code**: Always 0 (informational)

Behavior:
1. Read hook JSON input. Extract `cwd` (project directory) and `team_name`. If either is empty, exit 0.
2. Resolve workspace path: `${CWD}/.agent-team/${TEAM_NAME}/task-graph.json`. Try `-fix` suffix fallback for remediation teams.
3. Read `task-graph.json` — exit 0 silently if not found or `jq` missing
4. Find convergence points (`convergence_point: true`)
5. Check if all `depends_on` nodes are `completed`
6. If fully unblocked and convergence node is still `pending`, output nudge to stderr
7. Silent when no convergence point is fully unblocked

## hooks.json Changes

Add three new entries. Full TaskCompleted and SessionStart sections after changes:

```json
{
  "TaskCompleted": [
    {
      "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/verify-task-complete.sh", "timeout": 30 }]
    },
    {
      "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/compute-critical-path.sh", "timeout": 15 }]
    },
    {
      "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/check-integration-point.sh", "timeout": 15 }]
    }
  ],
  "SessionStart": [
    {
      "matcher": "compact",
      "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/recover-context.sh", "timeout": 10 }]
    },
    {
      "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/detect-resume.sh", "timeout": 15 }]
    }
  ]
}
```

Note: `detect-resume.sh` has no matcher (fires on all session starts). `recover-context.sh` keeps its `compact` matcher.

## Documentation Changes

### `docs/shared-phases.md`

- **Phase 1b**: New step 5a — "Mark convergence points" inserted after existing step 5 ("Integration points — for each pair of streams, identify where plan tasks reference shared interfaces, contracts, or outputs")
- **Phase 2**: Add critical path display and integration checkpoints to plan template. Add self-check item 4 for critical path verification.
- **Phase 3**: New step 1a — resume detection and user choice. New step 4a — create `task-graph.json`.
- **Phase 4**: Add `task-graph.json` update to COMPLETED processing rule (include JSON self-check: read file back after editing to verify valid JSON — malformed JSON silently disables all three hook scripts). New "Critical Path Awareness" subsection. New integration checkpoint processing row in Lead Processing Rules. Add note to scripts: log a specific warning to stderr when `task-graph.json` exists but fails to parse (not just silent exit 0).

### `docs/workspace-templates.md`

- New `task-graph.json` section with schema, field reference, and lifecycle
- New rows in Workspace Update Protocol table for task-graph.json events
- Updated `tasks.md` template with CP column in all four tables

### `docs/coordination-patterns.md`

- New "Resume from Existing Workspace" section — valid/stale/remaining protocol, archive protocol
- New "Integration Checkpoint Response" section — lead response protocol for convergence nudges

### `docs/coordination-advanced.md`

- Updated "Deadline Escalation" — critical-path tasks get accelerated escalation (skip Nudge, go to Warn)

### `docs/report-format.md`

- Team Metrics table gains: critical path length, integration checkpoints, resumed tasks
- Task Ledger gains CP column with ★ markers

### Archetype SKILL.md files (all 5)

- Phase 3 Override: reference step 4a (create `task-graph.json`)
- `agent-implement`: Completion Gate check #4 gains convergence-point awareness

### `README.md`

- Workspace section: add `task-graph.json` to file tree
- Hooks section: add three new hooks with descriptions
- Plugin Structure: add three new scripts

### `CLAUDE.md`

- File Ownership table: add `task-graph.json` row
- hooks.json row: update hook entry count from "6 hooks" → "9 hook entries" (6 event types unchanged, 3 new entries on existing events). Note: CLAUDE.md currently says "6 hooks" counting entries — maintain that convention but clarify in parenthetical.
- scripts row: fix baseline from "7 scripts" → "12 scripts" (actual current count is 9 — includes `record-demo.sh` and `generate-demo-cast.sh` — plus 3 new)
- Verify Hooks: add three new verification scenarios

### `CHANGELOG.md`

Add v2.6.0 entry with:
- **Added**: `task-graph.json` workspace file (DAG with critical path and convergence points), `compute-critical-path.sh` hook, `detect-resume.sh` hook, `check-integration-point.sh` hook, Critical Path Awareness in Phase 4, Resume from Existing Workspace coordination pattern, Integration Checkpoint Response coordination pattern, CP column in `tasks.md`
- **Changed**: Phase 1b gains convergence point marking, Phase 2 gains critical path display, Phase 3 gains resume detection and `task-graph.json` creation, Phase 4 gains critical-path-weighted prioritization, Deadline Escalation gains critical-path acceleration, report gains critical path metrics

### `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`

Bump version from `2.5.1` to `2.6.0` in both files (must stay in sync per CLAUDE.md conventions).

## Tests

### New Test Files

**`tests/hooks/test-compute-critical-path.sh`** (~8-9 assertions):
- Exits 0 when no `task-graph.json` exists
- Exits 0 when `jq` is missing
- Correct critical path output when critical-path task completes
- "Not on critical path" output when non-critical task completes
- "No critical path — all parallel" when no chains remain

**`tests/hooks/test-detect-resume.sh`** (~8-9 assertions):
- Exits 0 when no `.agent-team/` directories exist
- Silent when all workspaces fully completed
- Resume context output when incomplete workspace found
- Staleness detection (touch file after `completed_at`)
- "Valid (unverified)" when `git` unavailable
- Multiple incomplete workspaces listed (most recent first)

**`tests/hooks/test-check-integration-point.sh`** (~8-9 assertions):
- Exits 0 when no `task-graph.json` exists
- Silent when no convergence points fully unblocked
- Nudge output when all `depends_on` tasks of a convergence point are completed
- Skip when convergence point already `in_progress` or `completed`

### Existing Test Updates

- `tests/structure/test-plugin-structure.sh`: assert 3 new scripts exist and are executable, update hook count 6 → 9
- `tests/structure/test-doc-references.sh`: assert `task-graph.json` is referenced in `workspace-templates.md`, assert all 5 `skills/*/SKILL.md` files reference step 4a, assert `compute-critical-path.sh` and `check-integration-point.sh` and `detect-resume.sh` are referenced in `shared-phases.md` or `coordination-patterns.md`
- `tests/run-tests.sh`: include 3 new test files

### Expected Counts

Before: 9 test files, 78 assertions
After: 12 test files, ~103 assertions

## File Inventory

### New Files (6)

| File | Purpose |
|---|---|
| `scripts/compute-critical-path.sh` | TaskCompleted hook — recompute and display critical path |
| `scripts/detect-resume.sh` | SessionStart hook — detect resumable workspaces with staleness validation |
| `scripts/check-integration-point.sh` | TaskCompleted hook — detect and nudge on convergence point completion |
| `tests/hooks/test-compute-critical-path.sh` | Tests for critical path hook |
| `tests/hooks/test-detect-resume.sh` | Tests for resume detection hook |
| `tests/hooks/test-check-integration-point.sh` | Tests for integration checkpoint hook |

### Modified Files (19)

| File | Changes |
|---|---|
| `hooks/hooks.json` | Add 3 new hook entries (TaskCompleted ×2, SessionStart ×1) |
| `docs/shared-phases.md` | Phase 1b step 5a, Phase 2 critical path display, Phase 3 steps 1a + 4a, Phase 4 critical path awareness + integration processing |
| `docs/workspace-templates.md` | `task-graph.json` section, update protocol rows, `tasks.md` CP column |
| `docs/coordination-patterns.md` | Resume from Existing Workspace section, Integration Checkpoint Response section |
| `docs/coordination-advanced.md` | Deadline Escalation critical-path integration |
| `docs/report-format.md` | Team Metrics additions, Task Ledger CP column |
| `skills/agent-team/SKILL.md` | Phase 3 step 4a reference |
| `skills/agent-implement/SKILL.md` | Phase 3 step 4a reference, completion gate #4 update |
| `skills/agent-research/SKILL.md` | Phase 3 step 4a reference |
| `skills/agent-audit/SKILL.md` | Phase 3 step 4a reference |
| `skills/agent-plan/SKILL.md` | Phase 3 step 4a reference |
| `README.md` | Workspace tree, hooks section, plugin structure |
| `CLAUDE.md` | File ownership, hook/script counts, verification scenarios |
| `CHANGELOG.md` | Add v2.6.0 entry |
| `.claude-plugin/plugin.json` | Bump version to 2.6.0 |
| `.claude-plugin/marketplace.json` | Bump version to 2.6.0 |
| `tests/structure/test-plugin-structure.sh` | New script assertions, hook count update |
| `tests/structure/test-doc-references.sh` | Add `task-graph.json`, step 4a, and new script reference assertions |
| `tests/run-tests.sh` | Include 3 new test files |

## Non-Goals

- **Automated task-graph.json maintenance by hooks** — the lead maintains this file, not the hooks. Hooks read it; the lead writes it. This matches the existing pattern (lead writes `tasks.md`, hooks read it).
- **Weighted critical path** — using estimated task duration instead of node count. This would require effort estimation, which the plugin deliberately avoids. Node-count critical path is a good-enough heuristic.
- **Automatic resume without user choice** — the user always gets to choose resume vs start fresh. Automatic behavior risks silently reusing stale work.
- **Hook-enforced integration gates** — integration checkpoints are informational nudges, not blocking gates. The lead decides whether to verify. This matches the TeammateIdle pattern.

## Forward Compatibility

Pre-v2.6.0 workspaces (created without `task-graph.json`) will gracefully degrade:
- All three new hook scripts check for `task-graph.json` existence and exit 0 silently if not found
- Existing workspaces continue to function with the original 3 tracking files (`progress.md`, `tasks.md`, `issues.md`)
- No migration is required — old workspaces simply don't benefit from critical path tracking, resume validation, or integration checkpoints
- If a user wants to add DAG features to an existing workspace, the lead can manually create `task-graph.json` from the current `tasks.md` state
