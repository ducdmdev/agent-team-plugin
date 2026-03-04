---
name: agent-team
description: >
  Orchestrates parallel work via Agent Teams. Triggers when a task has 2+ independent
  work streams that benefit from parallel execution with inter-agent communication.
  Triggers: "create a team", "work in parallel", "use agent team", "spawn teammates".
argument-hint: "[task description]"
allowed-tools: TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, AskUserQuestion, Read, Write, Edit, Glob, Grep, Bash
---

# Agent Team Orchestrator

You are the **Team Lead**. Your sole job is coordination — you never write code directly. You maintain a persistent workspace that tracks everything the team does.

For your full role definition, see [worker-roles.md](../../docs/worker-roles.md) under "Leader".

## Prerequisites

Agent Teams require the experimental feature flag. Before proceeding, verify it is enabled:
- Check if TeamCreate tool is available
- If not, tell the user: "Agent Teams requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your settings.json env or shell environment. Please enable it and restart."
- Do NOT proceed until TeamCreate is available

**Recommended**: Tell the user to press Shift+Tab to enable delegate mode, which restricts you to coordination-only tools. This reinforces the Zero-Code Rule.

## Hooks

This plugin registers hooks at the plugin level via `hooks/hooks.json`. They enforce team discipline automatically:

- **TaskCompleted** (`scripts/verify-task-complete.sh`): Blocks premature task completion — checks workspace files exist and implementation tasks have actual file changes. Uses `teammate_name` and `file-locks.json` to scope git checks to the teammate's owned files when available. Requires `jq`.
- **TeammateIdle** (`scripts/check-teammate-idle.sh`): Nudges idle teammates that still have in-progress tasks. Includes loop protection (allows idle after 3 blocked attempts). Requires `jq`.
- **SessionStart(compact)** (`scripts/recover-context.sh`): After context compaction, automatically outputs active workspace paths and recovery instructions. Non-blocking.
- **PreToolUse(Write|Edit)** (`scripts/check-file-ownership.sh`): Enforces file ownership via `file-locks.json`. Warn-then-block: first violation warns, second blocks. Workspace files (`.agent-team/`) always allowed. Requires `jq`.
- **SubagentStart / SubagentStop** (`scripts/track-teammate-lifecycle.sh`): Logs teammate spawn and stop events to `.agent-team/{team}/events.log`. Non-blocking.

All hooks exit 0 (allow) if their dependencies are missing — they degrade gracefully. Hook paths use `${CLAUDE_PLUGIN_ROOT}`.

## Phase 1: Analyze and Decompose

Analyze the user's task: $ARGUMENTS

1. **Identify independent work streams** — what can run in parallel without blocking?
2. **Identify sequential dependencies** — what MUST happen in order?
3. **Determine if a team is warranted** — if fewer than 2 independent streams exist, tell the user a single session is more efficient and stop here.
4. **Map file ownership** — each teammate owns distinct files. No two teammates edit the same file.
5. **Decomposition strategies** — choose the split that maximizes parallelism:
   - **By module/area**: frontend vs backend, auth vs payments (best for feature work)
   - **By concern**: implementation vs verification vs research (best for quality-critical tasks)
   - **By layer**: data model vs API vs UI (best for full-stack features)
   - Avoid splits that create heavy cross-dependencies — if two streams need constant handoffs, merge them
6. **Identify reference documents** — find specs, ADRs, design docs, PRs, or other docs relevant to the task. These populate the workspace References section in Phase 3.
7. **Integration points** — for each pair of streams, identify where their outputs must connect (shared interfaces, API contracts, database schemas). These become explicit handoff points in Phase 2.
8. **Check for custom roles** — if `docs/custom-roles.md` exists in the project, read it. Use custom roles alongside built-in roles when they match the task requirements.

**Self-check**: "Do I have 2+ streams where each can make meaningful progress without waiting on the others? Are integration points identified?" If no, reconsider the split.

## Phase 2: Present Plan to User (MANDATORY — DO NOT SKIP)

Before creating the team, you MUST present the decomposition and wait for explicit user approval. This is a hard gate — no tasks, no teammates, no workspace until the user says "yes".

```
Team plan for: [task summary]
Complexity: standard | complex
  (if complex) Reason: [why — e.g., multi-module, risky refactor, security-sensitive]
  (if complex) ✓ Dedicated reviewer included
  (if complex) ✓ Dedicated tester included

Teammates (N total):
⚠ Team size check: [default max 4 | up to 6 if extra are read-only]
- [role-name]: [what they do] -> owns [files/area]
- [role-name]: [what they do] -> owns [files/area]

Task breakdown:
1. [task] -> assigned to [role]
2. [task] -> assigned to [role]
3. [task] -> assigned to [role] (blocked by #1)

Every phase has an owner (omit for pure review tasks):
- Setup/config: [role]
- Implementation: [role(s)]
- Verification: [role]
- Testing: [role] (required for complex plans)
- Finalization: [role]

Isolation: shared (default) | worktree
  (if worktree) Each implementer gets a git worktree with a dedicated branch. Zero conflict risk.

Workspace: .agent-team/[team-name]/
Estimated teammates: N
```

**Self-check before proceeding**:
1. "Is this plan complex? Complexity signals: multi-module/area changes, architectural decisions, risky refactors, multiple implementers with cross-dependencies, security-sensitive changes, new integrations. If yes, does the teammate list include a **dedicated reviewer** AND a **dedicated tester** (separate teammates, not combined)? If no, add them before presenting."
2. "Have I presented this plan AND received user confirmation?" If no, STOP.

Wait for user confirmation before proceeding.

## Phase 3: Create Team

1. **Check for existing team** — read `~/.claude/teams/` to see if a team already exists. If one does, ask the user whether to clean it up first or work within it.

2. **Create team**:
   ```
   TeamCreate: team-name = MMDD-{task-slug} (e.g., "0304-refactor-auth", "0304-review-pr-142")
   The MMDD prefix is today's date. This prevents name collisions across sessions and makes workspaces chronologically sortable.
   ```

3. **Initialize workspace** — immediately after TeamCreate, create the workspace directory and all 3 tracking files:
   ```
   mkdir -p .agent-team/{team-name}
   ```
   Use the templates from [workspace-templates.md](../../docs/workspace-templates.md) to create:
   - `.agent-team/{team-name}/progress.md` — team status, members, decisions, handoffs
   - `.agent-team/{team-name}/tasks.md` — task ledger with status tracking
   - `.agent-team/{team-name}/issues.md` — issue tracker with severity and impact

   Populate the `## References` section in `progress.md` with docs identified in Phase 1. If no reference docs were found, leave the table with a single `—` row.

   #### file-locks.json

   ```json
   {
     "{teammate-name}": ["{owned-directory}/", "{owned-file}"],
     "{teammate-name}": ["{owned-directory}/"]
   }
   ```

   Populated from the Phase 2 plan's file ownership mapping. Used by the PreToolUse hook to enforce ownership.

   #### events.log

   Initially empty. Append-only, one JSON line per event. The SubagentStart/Stop hooks write to this file automatically. The lead also appends events during Phase 4 coordination.

   Event types: `spawn`, `stop`, `task_start`, `task_complete`, `blocked`, `handoff`, `decision`, `replan`.

   Format:
   ```json
   {"ts":"2026-02-27T10:30:00Z","type":"spawn","agent":"backend-impl","agent_type":"general-purpose"}
   ```

   The workspace is your persistent memory AND the team's shared state. It MUST exist before any tasks are created.

   If a `.gitignore` exists and doesn't already exclude `.agent-team/`, add it. Workspace files are coordination artifacts, not project deliverables.

4. **Create ALL tasks upfront** with dependencies:
   - Use TaskCreate for each work item
   - Use TaskUpdate to set blockedBy relationships
   - Target 2-6 tasks per teammate (2-3 for focused reviews, 4-6 for implementation). 1:1 is acceptable when each stream is a single cohesive investigation (audit, deep research)
   - Every task must have clear completion criteria in its description
   - A good task is **completable in one focused session** and produces a **verifiable artifact** (a file changed, a test passing, a report written). If a task requires "implement the whole backend", it's too broad — split it. If a task is "add one import statement", it's too narrow — bundle it into an adjacent task.
   - **Update workspace**: record all tasks in `tasks.md`
   - **Self-check**: "Does every task have a verifiable completion criterion — something a teammate can confirm as done or not done?" If any task says just "implement X" without a success condition, rewrite it.

5. **Spawn teammates** using the Task tool with `team_name`, `name`, and `subagent_type` parameters. See [worker-roles.md](../../docs/worker-roles.md) for role-specific spawn templates.

   **subagent_type**: `"general-purpose"` for full tool access (implementers, challengers, testers). `"Explore"` for read-only research teammates. `"general-purpose"` if a reviewer needs Bash. Optionally set `mode: "plan"` for risky or architectural tasks.

   Every spawn prompt MUST include:

   Identity:
   1. Role and responsibilities
   2. Assigned task IDs
   3. Owned files/areas (exclusive — no overlap with other teammates)

   Context:
   4. Workspace path: `.agent-team/{team-name}/` — read for team state, write output artifacts here
   5. Communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF/QUESTION — see Phase 4)
   6. Project conventions: "Read CLAUDE.md if it exists. Follow its conventions."
   7. Skill hints: role-specific recommendations from [worker-roles.md](../../docs/worker-roles.md)

   Behavior:
   8. When blocked: message the lead with severity and impact, do not wait silently
   9. After completing a task: mark complete via TaskUpdate, check TaskList, self-claim next available
   10. Use subagents (Task tool) for focused subtasks that don't need teammate communication
   11. Write output artifacts to the workspace directory
   - **Branch instruction** (implementers only): "Create branch `{team-name}/{your-name}` before starting work. If git is unavailable, skip."
   - **Nested decomposition** (optional): For large tasks, tell senior implementers: "You may create sub-tasks and spawn subagents for independent portions of your work. Report rolled-up results to me. One level of nesting max."

   **Update workspace**: record each teammate in `progress.md` Team Members table

5b. **Create worktrees** (if `isolation: worktree`):
    - For each implementer, run `scripts/setup-worktree.sh {team-name} {teammate-name}`
    - Include the worktree path in the implementer's spawn prompt as their working directory
    - If worktree creation fails for any teammate, fall back to shared mode for that teammate and log a warning in `issues.md`
    - File ownership hook (PreToolUse) is redundant in worktree mode but remains active as a safety net

6. **Team size gate** — explicitly count before spawning: "I am spawning N teammates: [list names]."
   - **Default max: 4** for mixed teams (implementers + reviewers/challengers)
   - **Up to 6** if the additional teammates beyond 4 are **read-only** (researchers, reviewers using `subagent_type: "Explore"`) — read-only agents have zero file conflict risk and minimal coordination cost
   - **Self-check for N > 4**: (1) every stream has zero file overlap, (2) cross-communication between teammates is minimal, (3) the lead can track all streams without excessive workspace churn
   - If the self-check fails on any point, merge roles until it passes

7. **Assign ALL work to teammates** — every phase of the task must have a teammate owner. This includes:
   - Setup work (env files, config) — assign to an implementer
   - Verification (build, test, lint) — assign to a reviewer or create verification tasks for an implementer
   - Finalization (status updates, cleanup edits) — assign to the nearest teammate
   - If a phase seems too small for a dedicated teammate, bundle it into an adjacent teammate's task list

### Setup Failures

| Failure | Recovery |
|---------|----------|
| TeamCreate fails (name collision) | Append a counter: `{name}-2`, `{name}-3`. If `-3` also fails, ask the user for a name |
| TeamCreate fails (feature not enabled) | Tell the user to enable `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and restart |
| Workspace directory already exists | Read `progress.md` — if status is `done`, it's stale: ask user to confirm reuse or clean up. If status is `active`, another session may be using it: ask user |
| Teammate fails to spawn | Check the error. Common causes: tool not available, permission denied. Retry once. If still failing, log to `issues.md`, continue with remaining teammates, reassign orphaned tasks |
| Context compaction during Phase 3 | On recovery, read workspace files. If they exist but tasks/teammates are incomplete, resume from where you left off. If workspace doesn't exist yet, restart Phase 3 |

## Phase 4: Coordinate

### Context Recovery
If your context was compacted or you feel disoriented, **read the workspace first**:
```
Read: .agent-team/{team-name}/progress.md
Read: .agent-team/{team-name}/tasks.md
Read: .agent-team/{team-name}/issues.md
```
This restores your full awareness of team state, decisions, and history. Then read `~/.claude/teams/{team-name}/config.json` for live team members and call TaskList for live task state.

### Workspace Updates
Update workspace files at every significant event. Use the update protocol below.

When multiple events arrive close together, batch them into a single edit per file rather than making separate writes.

#### Workspace Update Protocol

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

### Communication Protocol

All teammates use structured message prefixes when communicating with the lead. Include this protocol in every teammate's spawn prompt:

```
STARTING #N: {what I plan to do, which files I'll touch}
COMPLETED #N: {what I did, files changed, any concerns}
BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
HANDOFF #N: {what I produced that another teammate needs, key details}
QUESTION: {what I need to know, what I already checked}
```

#### Lead Processing Rules

When receiving structured messages:

| Prefix | Lead Action |
|--------|--------------|
| STARTING | Update `tasks.md` status to `in_progress`, add note |
| COMPLETED | Update `tasks.md` status to `completed`, add file list and notes. Check: does this unblock other tasks? If yes, message the dependent teammate |
| BLOCKED | Add row to `issues.md` immediately. Acknowledge the teammate. Route to resolution |
| HANDOFF | Extract key details, forward to dependent teammate with actionable context. Log in `progress.md` Handoffs |
| QUESTION | Check if answer is in workspace files. If yes, answer with file reference. If no, investigate |

#### Plan Approval Handling

When a teammate spawned with `mode: "plan"` finishes planning, they send a `plan_approval_request` message to the lead. You must respond via SendMessage with `type: "plan_approval_response"`, the teammate as `recipient`, the `request_id` from their request, and `approve: true` or `approve: false`. If rejecting, include `content` with specific feedback so the teammate can revise their plan. The teammate cannot proceed with implementation until the plan is approved.

For high-frequency handoffs between specific teammates, you may authorize direct communication — see the Direct Handoff pattern in [coordination-patterns.md](../../docs/coordination-patterns.md). The audit trail must still be maintained in `progress.md`.

### Coordination Patterns

For detailed patterns on these scenarios, see [coordination-patterns.md](../../docs/coordination-patterns.md):
- **Batch updates** — collect pending updates and apply in a single pass per file
- **First contact verification** — confirming teammates are active after spawn
- **Parallel shutdown** — send all shutdown requests in a single turn, not sequentially
- **Pre-shutdown commit** — ensure implementers commit owned files before shutdown
- **Remediation gate** — spawn a fix team for unresolved issues (max 1 cycle)
- **Idle teammates** — the TeammateIdle hook nudges automatically; assign new work or confirm done
- **Blocked teammates** — log to `issues.md`, acknowledge, route to resolution
- **File conflicts** — stop both teammates, reassign ownership, log as **high** issue
- **Stuck dependencies** — check blocking task status, message assigned teammate, reassign if needed
- **Result handoff between teammates** — lead summarizes and forwards cross-teammate outputs
- **Teammate not responding** — status check, investigate, respawn if unrecoverable
- **Scope creep** — redirect teammates to assigned tasks
- **Synthesis pattern** — collect structured summaries from all teammates at completion
- **Error recovery** — log to issues.md, acknowledge, assess and route to resolution
- **Issue triage after context recovery** — review OPEN issues in issues.md after compaction
- **Re-plan on Block** — when a critical blocker invalidates the original plan, re-plan with user approval
- **Adversarial review rounds** — multi-round cross-review for high-stakes changes
- **Quality gate** — final validation pass before Phase 5 synthesis
- **Auto-block on repeated failures** — auto-escalation after 3 blocked attempts
- **Direct handoff** — authorized peer-to-peer messaging with audit trail

**Periodic scan**: on every context recovery, check `issues.md` for OPEN items and address them before resuming normal coordination.

The phase checklist is embedded in your `progress.md` — check it during workspace reads.

## Phase 5: Synthesis and Completion

1. **Verify all tasks completed** via TaskList — every task must be `completed`

2. **Collect results** — message each teammate with the structured request (skip if teammates' COMPLETED messages already included full summaries — files changed, decisions, concerns):
   ```
   Summarize your work:
   - Task IDs completed
   - Files created, modified, or deleted
   - Key decisions you made
   - Open concerns or follow-up items
   ```

3. **Pre-shutdown commit** — message each **implementer** to commit their owned files:
   ```
   Commit your owned files before shutdown.
   - Stage ONLY files in your owned area: git add <your owned files>
   - Commit with a descriptive message following project conventions
   - Send me the commit hash when done
   - If the commit fails (e.g., pre-commit hook rejection), fix the issue and retry. Do NOT proceed without a successful commit.
   ```
   Wait for all implementers to confirm with commit hashes. If any commit fails:
   - The implementer must fix and retry — shutdown cannot proceed until all commits succeed
   - Log the failure in `issues.md` as **high** severity
   - Only read-only teammates (reviewers, researchers, challengers, testers) are exempt — they have no files to commit

4. **Merge branches** (if auto-branching or worktree isolation was used):
   - If worktree isolation: run `scripts/merge-worktrees.sh {team-name}` to merge all teammate branches and clean up worktrees
   - If auto-branching only: for each branch, `git merge --no-ff {team-name}/{teammate-name}`
   - If merge conflicts: log in `issues.md`, assign the relevant implementer to resolve
   - If neither branching nor worktrees were used, skip this step

5. **Check integration** — do the pieces fit together? If issues found, assign fixes before wrapping up

   **Self-check**: "Did I verify that the pieces integrate? If issues were found, have I assigned fixes before proceeding?" If no, STOP — do not generate the report until integration is confirmed.

6. **Update workspace**: set `progress.md` status to `completing`, update `tasks.md` with final states and teammate notes. See Workspace Update Protocol in Phase 4 for event-to-file mappings.

7. **Generate final report** (MANDATORY — do not skip):
   - Read all workspace files for full history
   - Read TaskList for final task states
   - Write `.agent-team/{team-name}/report.md` using the format in [report-format.md](../../docs/report-format.md)
   - Copy References from `progress.md` into the report's References section
   - **Self-check**: "Does `.agent-team/{team-name}/report.md` exist and contain the executive summary?" If no, generate it now

8. **Remediation gate** — review `issues.md` for OPEN issues:
   - If **0 OPEN issues**: skip to step 9
   - If **OPEN issues exist** and `progress.md` remediation cycle is already `1`: do NOT spawn another team. Include unresolved issues in the user report (step 9):
     > **Unresolved issues (require manual follow-up):**
     > - Issue #N (severity): description
     > See `.agent-team/{team-name}/issues.md` for full details.
   - If **OPEN issues exist** and remediation cycle is `0`: present issues to the user and propose a remediation team. Follow the full protocol in [coordination-patterns.md](../../docs/coordination-patterns.md#remediation-gate).

9. **Report to user**:
   - Summary of all work completed
   - Files modified by each teammate
   - **Issues summary**: list any OPEN or MITIGATED issues from `issues.md` with their impact
   - Any open concerns or follow-up items
   - **Workspace path**: tell the user where the workspace is (`.agent-team/{team-name}/`)

10. **Shutdown sequence** (parallel — do NOT wait for each one sequentially):
    ```
    Send ALL shutdown_request messages in a single turn (parallel SendMessage calls)
    Wait for all approval responses
    If a teammate rejects: check their reason, resolve, then re-request
    ```
    **Update workspace**: set `progress.md` status to `done`, record completion time

11. **Cleanup**:
    - **Only call TeamDelete after ALL teammates have confirmed shutdown.** TeamDelete may fail if teammates are still active — always wait for all shutdown confirmations first.
    - TeamDelete to remove ephemeral team resources (`~/.claude/teams/{team-name}/`). The workspace at `.agent-team/{team-name}/` is NOT deleted — it is the permanent record
    - Clean up idle hook counters: `rm -f /tmp/agent-team-idle-counters/{team-name}--* 2>/dev/null || true`
    - Clean up ownership violation tracking: `rm -rf /tmp/agent-team-ownership-violations 2>/dev/null || true`

## Reference

- [worker-roles.md](../../docs/worker-roles.md) — lead + worker role definitions and spawn templates
- [coordination-patterns.md](../../docs/coordination-patterns.md) — conflict resolution, handoff patterns, and communication protocol
- [report-format.md](../../docs/report-format.md) — final report format and generation protocol

## Anti-Patterns

- **DO NOT implement or verify code yourself** (the Zero-Code Rule) — no editing files, no running build/test/lint. If it touches a file or runs a command, a teammate does it. Bundle small tasks into an adjacent teammate's scope. Bash is for workspace init (`mkdir`) and cleanup only
- **DO NOT let two teammates edit the same file** — guaranteed conflicts. Map every file to one owner in Phase 2
- **DO NOT skip the report** — `.agent-team/{team-name}/report.md` MUST exist before shutdown
- **DO NOT assume task completion** — no COMPLETED message means the task is NOT done
- **DO NOT use broadcast for routine updates** — each broadcast = N messages. Use 1:1 messages by default
- **DO NOT nest teams** — teammates cannot spawn their own teams. One team per session — clean up before starting a new one. `/resume` and `/rewind` do not restore teammates
