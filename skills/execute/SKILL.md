---
name: execute
description: >
  Agent Team execution stage. Creates workspace, spawns teammates, coordinates
  parallel work, handles error recovery. Requires an approved plan (from plan stage
  or workspace). Triggers: "execute the plan", "spawn the team", "start execution".
argument-hint: "[workspace path or plan reference]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, TeamCreate, TeamDelete, SendMessage
---

# Execute Stage

Owns Phase 3 (create team, initialize workspace, spawn teammates) and Phase 4 (coordinate parallel work, error recovery, progress tracking).

## Overview

The execute stage takes an approved plan and brings it to life. It creates the team infrastructure, spawns teammates with precise role definitions and file ownership, then coordinates their parallel work through structured communication. When teammates hit errors, it applies bounded auto-recovery before escalating.

This stage reads the approved plan from the workspace (`progress.md`, `tasks.md`, `task-graph.json`) and produces a fully-executed workspace with completed tasks, resolved handoffs, and tracked issues.

## Preconditions

Before starting execution, verify:

1. **Workspace directory exists** at `.agent-team/{team-name}/` with:
   - `progress.md` containing `**Archetype**: {type}` and `**Status**: approved`
   - `tasks.md` with the task breakdown from the plan stage
   - `task-graph.json` with pending tasks and dependency graph
2. **Agent Teams feature flag** is enabled — verify TeamCreate tool is available. If not, tell the user: "Agent Teams requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your settings.json env or shell environment. Please enable it and restart."
3. **User has approved the plan** — `progress.md` status must be `approved` (set by the plan stage after user confirmation)

> **Pipeline gate**: Check `progress.md` for `**Pipeline status**: approved`. If this field is absent (legacy/manual workspace), proceed without blocking — treat absence as "not gated" for backward compatibility.

If preconditions are not met and the execute stage was invoked independently (not via `start`), inform the user what is missing and suggest running the plan stage first.

**Recommended**: Tell the user to press Shift+Tab to enable delegate mode, which restricts you to coordination-only tools. This reinforces the Zero-Code Rule.

## Orchestrator Identity

You are the **Team Lead**. Your sole job is coordination — you never write code directly. You maintain a persistent workspace that tracks everything the team does.

For your full role definition, see [../../docs/teammate-roles.md](../../docs/teammate-roles.md) under "Leader".

## Phase 3: Create Team

### Step 1a: Check for Resumable Workspace

If the `detect-resume.sh` hook surfaced a resumable workspace at session start, present the resume option to the user:

```
Existing workspace found: .agent-team/{team-name}/
  Completed (valid): {list with task IDs and subjects}
  Completed (stale): {list — output files modified since completion}
  Remaining: {list}

Options:
1. Resume — skip valid completed tasks, re-run stale tasks, continue with remaining
2. Start fresh — archive existing workspace to .agent-team/{team-name}-archived/, create new
```

If resuming: skip TeamCreate (team may still exist), reuse workspace, create only remaining + stale tasks. Update `task-graph.json` — reset stale nodes to `pending`, preserve valid completed nodes. Log in `progress.md` Decision Log. Proceed to step 5 (spawn teammates).

If starting fresh: rename existing workspace directory with `-archived` suffix, proceed normally from step 2.

### Step 1: Check for Existing Team

Read `~/.claude/teams/` to see if a team already exists. If one does, ask the user whether to clean it up first or work within it.

### Step 2: Create Team

```
TeamCreate: team-name = MMDD-{task-slug} (e.g., "0304-refactor-auth", "0304-review-pr-142")
The MMDD prefix is today's date. This prevents name collisions across sessions and makes workspaces chronologically sortable.
```

### Step 3: Initialize Workspace

> **Workspace**: If `.agent-team/{team-name}/progress.md` already exists (plan stage created it), skip workspace initialization — read and extend existing files. Only create workspace if it doesn't exist (independent invocation without plan stage).

Immediately after TeamCreate, create the workspace directory and all 3 tracking files:

```
mkdir -p .agent-team/{team-name}
```

Use the templates from [../../docs/workspace-templates.md](../../docs/workspace-templates.md) to create:
- `.agent-team/{team-name}/progress.md` — team status, members, decisions, handoffs
- `.agent-team/{team-name}/tasks.md` — task ledger with status tracking
- `.agent-team/{team-name}/issues.md` — issue tracker with severity and impact

Populate the `## References` section in `progress.md` with docs identified during planning. If no reference docs were found, leave the table with a single `—` row.

If the team is based on a plan file, set its `Status:` to `IN PROGRESS` now (add the field if it doesn't exist). This warns other teams during plan scanning that the plan is being executed.

The workspace is your persistent memory AND the team's shared state. It MUST exist before any tasks are created.

If a `.gitignore` exists and doesn't already exclude `.agent-team/`, add it. Workspace files are coordination artifacts, not project deliverables.

### Step 4: Create ALL Tasks Upfront

Create all tasks with dependencies:
- Use TaskCreate for each work item
- Use TaskUpdate to set blockedBy relationships
- Target 2-6 tasks per teammate (2-3 for focused reviews, 4-6 for implementation). 1:1 is acceptable when each stream is a single cohesive investigation (audit, deep research)
- Every task must have clear completion criteria in its description
- A good task is **completable in one focused session** and produces a **verifiable artifact** (a file changed, a test passing, a report written). If a task requires "implement the whole backend", it's too broad — split it. If a task is "add one import statement", it's too narrow — bundle it into an adjacent task.
- **Update workspace**: record all tasks in `tasks.md`
- **Self-check**: "Does every task have a verifiable completion criterion — something a teammate can confirm as done or not done?" If any task says just "implement X" without a success condition, rewrite it.

### Step 4a: Create task-graph.json

Immediately after creating all tasks, generate `.agent-team/{team-name}/task-graph.json` with the full dependency graph. Compute the initial critical path (longest chain, tie-break by lowest task ID) and mark convergence points (nodes with 2+ dependencies). Validate the graph is acyclic — if a cycle is detected, fix it before proceeding (see Circular Dependency Detection in [references/coordination-patterns.md](references/coordination-patterns.md)). Update `tasks.md` with star markers on critical-path tasks and convergence notes. See [../../docs/workspace-templates.md](../../docs/workspace-templates.md#task-graphjson) for schema.

### Step 5: Spawn Teammates

Spawn teammates using the Task tool with `team_name`, `name`, and `subagent_type` parameters. See [../../docs/teammate-roles.md](../../docs/teammate-roles.md) for role overview and [agents/spawn-templates.md](agents/spawn-templates.md) for detailed spawn prompt templates.

**subagent_type**: `"general-purpose"` for full tool access (implementers, challengers, testers). `"Explore"` for read-only research teammates. `"general-purpose"` if a reviewer needs Bash. Optionally set `mode: "plan"` for risky or architectural tasks.

**Protocol injection**: Before building spawn prompts, read [references/communication-protocol.md](references/communication-protocol.md). Substitute the `{COMMUNICATION_PROTOCOL}` placeholder in each role's spawn template with the Structured Messages block. For roles with format placeholders (`{FINDINGS_FORMAT}`, `{RESULTS_FORMAT}`, `{REPORT_FORMAT}`), substitute the matching section from the same file.

**Plan-mode directive injection**: If a teammate was marked for plan-mode during the plan stage, inject the following into their spawn prompt:

```
PLAN-MODE ACTIVE: Before writing any code, send a PLAN_PROPOSAL message to the lead.
Do NOT write/edit files until you receive PLAN_APPROVED.

PLAN_PROPOSAL format:
  PLAN_PROPOSAL #N:
    approach={description of proposed approach}
    alternatives_considered={what else was evaluated and why rejected}
    files_to_touch={list}
    estimated_complexity={low|medium|high}
    risks={potential issues}
```

Every spawn prompt MUST include:

Identity:
1. Role and responsibilities
2. Assigned task IDs
3. Owned files/areas (exclusive — no overlap with other teammates)

Context:
4. Workspace path: `.agent-team/{team-name}/` — read for team state, write output artifacts here
5. Communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF/QUESTION — see Phase 4)
6. Project conventions: "Read CLAUDE.md if it exists. Follow its conventions."
7. Skill hints: role-specific recommendations from [../../docs/teammate-roles.md](../../docs/teammate-roles.md)

Behavior:
8. When blocked: message the lead with severity, error_type, and impact — do not wait silently
9. After completing a task: mark complete via TaskUpdate, check TaskList, self-claim next available
10. Use subagents (Task tool) for focused subtasks that don't need teammate communication
11. Write output artifacts to the workspace directory
- **Nested decomposition** (optional): For large tasks, tell senior implementers: "You may create sub-tasks and spawn subagents for independent portions of your work. Report rolled-up results to me. One level of nesting max."

**Update workspace**: record each teammate in `progress.md` Team Members table

### Step 6: Team Size Gate

Explicitly count before spawning: "I am spawning N teammates: [list names]."
- **Default max: 4** for mixed teams (implementers + reviewers/challengers)
- **Up to 6** if the additional teammates beyond 4 are **read-only** (researchers, reviewers using `subagent_type: "Explore"`) — read-only agents have zero file conflict risk and minimal coordination cost
- **Self-check for N > 4**: (1) every stream has zero file overlap, (2) cross-communication between teammates is minimal, (3) the lead can track all streams without excessive workspace churn
- If the self-check fails on any point, merge roles until it passes

### Step 7: Assign ALL Work to Teammates

Every phase of the task must have a teammate owner. This includes:
- Setup work (env files, config) — assign to an implementer
- Verification (build, test, lint) — assign to a reviewer or create verification tasks for an implementer
- Finalization (status updates, cleanup edits) — assign to the nearest teammate
- If a phase seems too small for a dedicated teammate, bundle it into an adjacent teammate's task list

### file-locks.json (conditional)

Create **only if ANY teammate writes project files** (implementers, writers with file ownership). Skip if all teammates are read-only.

See [../../docs/workspace-templates.md](../../docs/workspace-templates.md#file-locksjson) for format.

### events.log

Initially empty. Append-only JSON event log. Written by SubagentStart/Stop hooks and the lead during coordination. See [../../docs/workspace-templates.md](../../docs/workspace-templates.md#eventslog) for format.

### Branch Instructions (implementers only)

Include branch instruction in each **implementer's** spawn prompt only:
- "Create branch `{team-name}/{your-name}` before starting work. If git is unavailable, skip."

### Worktree Isolation (optional, implementers only)

If `isolation: worktree` was chosen in Phase 2, apply only to implementers:
- For each implementer, run `scripts/setup-worktree.sh {team-name} {teammate-name}`
- Include the worktree path in the implementer's spawn prompt as their working directory
- If worktree creation fails, fall back to shared mode and log warning in `issues.md`

### Setup Failures

See [references/coordination-patterns.md](references/coordination-patterns.md#setup-failures) for recovery actions on common Phase 3 failures (name collisions, missing feature flag, stale workspaces, spawn failures, context compaction).

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

Update workspace files at every significant event. Batch multiple events into a single edit per file. See [../../docs/workspace-templates.md](../../docs/workspace-templates.md#workspace-update-protocol) for the full event-to-file mapping table.

### Communication Protocol

All teammates use structured message prefixes when communicating with the lead. Include this protocol in every teammate's spawn prompt. See [references/communication-protocol.md](references/communication-protocol.md) for the canonical protocol definition.

```
STARTING #N: {what I plan to do, which files I'll touch}
COMPLETED #N: {what I did, files changed, any concerns}
BLOCKED #N: severity={critical|high|medium|low}, error_type={retry|recoverable|design_flaw|unknown}, {what's blocking}, impact={what can't proceed}
HANDOFF #N: {what I produced that another teammate needs, key details}
QUESTION: {what I need to know, what I already checked in workspace}
```

#### Lead Processing Rules

When receiving structured messages:

| Prefix | Lead Action |
|--------|--------------|
| STARTING | Update `tasks.md` status to `in_progress`, add note |
| COMPLETED | Update `tasks.md` status to `completed`, add file list and notes. Update `task-graph.json`: set node status to `completed`, record `completed_at` and `output_files`. **Self-check**: read `task-graph.json` back to verify valid JSON — malformed JSON silently disables all three hook scripts. Check: does this unblock other tasks? If yes, message the dependent teammate. The `compute-critical-path.sh` hook will output the updated critical path. |
| BLOCKED | Add row to `issues.md` immediately. Acknowledge the teammate. Enter the **Error Recovery Loop** (see below). Route to resolution. |
| HANDOFF | Extract key details, forward to dependent teammate with actionable context. Log in `progress.md` Handoffs |
| QUESTION | Check if answer is in workspace files. If yes, answer with file reference. If no, investigate |
| PROGRESS | Note milestone in `tasks.md` Notes column. If percent indicates near-completion, no action needed. If stalled, trigger Deadline Escalation |
| CHECKPOINT | If `ready_for` lists task IDs, forward checkpoint details to dependent teammate. Log in `progress.md` Handoffs |
| PLAN_PROPOSAL | Evaluate the teammate's proposed approach. If acceptable, respond with `PLAN_APPROVED #N`. If needs revision, respond with `PLAN_REVISION #N: {feedback}` — max 2 rounds, then lead decides. Track in `progress.md` Plan Proposals table. |
| (hook: integration checkpoint) | Read the nudge from `check-integration-point.sh`. Before unblocking the convergence task, verify interface compatibility between upstream outputs. If compatible, message the convergence task owner to proceed. If unclear, log in `issues.md` as medium severity. Log checkpoint in `progress.md` Decision Log. |

#### Plan Approval Handling

When a teammate spawned with `mode: "plan"` finishes planning, they send a `plan_approval_request` message to the lead. You must respond via SendMessage with `type: "plan_approval_response"`, the teammate as `recipient`, the `request_id` from their request, and `approve: true` or `approve: false`. If rejecting, include `content` with specific feedback so the teammate can revise their plan. The teammate cannot proceed with implementation until the plan is approved.

For high-frequency handoffs between specific teammates, you may authorize direct communication — see the Direct Handoff pattern in [references/coordination-patterns.md](references/coordination-patterns.md). The audit trail must still be maintained in `progress.md`.

### Error Recovery Loop

When receiving a BLOCKED message, apply the error recovery protocol. See [references/error-recovery-protocol.md](references/error-recovery-protocol.md) for the full decision tree, classification guide, and bounds.

Summary:
1. **Classify** the error using the `error_type` field (retry, recoverable, design_flaw, unknown)
2. **Check pattern library** — scan `~/.claude/agent-team-patterns.json` for matching patterns with known strategies
3. **Apply recovery** per the decision tree: retry (max 2), recover (max 1), fallback (if defined in task-graph.json), or escalate
4. **Track** all recovery attempts in `issues.md` with the extended recovery format
5. **Enforce bounds** — max 3 total recovery cycles per team, tracked in `progress.md` as `**Recovery cycles**: N`

If the error is a `design_flaw` with no fallback, trigger the Re-plan on Block pattern from [references/coordination-patterns.md](references/coordination-patterns.md#re-plan-on-block).

### Critical Path Awareness

The critical path determines total execution time. The `compute-critical-path.sh` hook outputs the remaining critical path after every task completion. Use it to prioritize:

- **BLOCKED on critical path** -> resolve immediately (highest-priority coordination action)
- **BLOCKED on non-critical path** -> resolve normally (slippage has slack)
- **Teammate idle on critical path** -> reassign work to keep the critical path moving
- **Teammate idle on non-critical path** -> lower priority, consider assigning critical-path support tasks

After every task completion, read the hook output. If the critical path shifted (a previously non-critical chain is now longest), update `task-graph.json` and the star markers in `tasks.md`.

### Coordination Patterns

For detailed patterns on coordination scenarios, see [references/coordination-patterns.md](references/coordination-patterns.md):
- **Batch updates** — collect pending updates and apply in a single pass per file
- **First contact verification** — confirming teammates are active after spawn
- **Parallel shutdown** — send all shutdown requests in a single turn, not sequentially
- **Pre-shutdown commit** — ensure implementers commit owned files before shutdown
- **Remediation gate** — spawn a fix team for unresolved issues (max 1 cycle)
- **Idle teammates** — the TeammateIdle hook nudges automatically; assign new work or confirm done
- **Blocked teammates** — log to `issues.md`, acknowledge, route to resolution via Error Recovery Loop
- **File conflicts** — stop both teammates, reassign ownership, log as **high** issue
- **Stuck dependencies** — check blocking task status, message assigned teammate, reassign if needed
- **Result handoff between teammates** — lead summarizes and forwards cross-teammate outputs
- **Teammate not responding** — status check, investigate, respawn if unrecoverable
- **Scope creep** — redirect teammates to assigned tasks
- **Synthesis pattern** — collect structured summaries from all teammates at completion
- **Error recovery** — classify, match patterns, apply bounded recovery, track in issues.md
- **Issue triage after context recovery** — review OPEN issues in issues.md after compaction
- **Re-plan on Block** — when a critical blocker invalidates the original plan, re-plan with user approval
- **Adversarial review rounds** — multi-round cross-review for high-stakes changes
- **Quality gate** — final validation pass before synthesis
- **Auto-block on repeated failures** — auto-escalation after 3 blocked attempts
- **Direct handoff** — authorized peer-to-peer messaging with audit trail
- **Plan-Mode Coordination** — handling PLAN_PROPOSAL messages, approval/revision flow
- **Error Recovery** — extended protocol with classification, pattern matching, and bounded retries

**Periodic scan**: on every context recovery, check `issues.md` for OPEN items and address them before resuming normal coordination.

The phase checklist is embedded in your `progress.md` — check it during workspace reads.

## Inter-Stage Review: Execute Review Agent

**When**: Mandatory — runs after all tasks complete (or are abandoned), BEFORE handoff to the audit stage.

**Purpose**: Quick smoke test to catch obvious failures before the full audit. Saves the audit stage from reviewing obviously broken output.

Spawn the execute review agent using the prompt in [agents/execute-reviewer.md](agents/execute-reviewer.md).

**Behavior**:
- If `status=ready_for_audit` -> proceed to audit stage
- If `status=issues_found` with warnings only -> proceed to audit with warnings forwarded
- If `status=issues_found` with blocking issues -> lead attempts remediation (one cycle: fix and re-review). If still blocking after remediation, proceed to audit anyway with blocking issues flagged — the audit stage will capture them in the report

### Team Shutdown

After execute-reviewer passes (or one remediation cycle completes):
1. Send parallel shutdown requests to all teammates
2. Wait for confirmations
3. Write `**Pipeline status**: executed` to `progress.md`
4. Write `**Stage**: execute` to `progress.md`
5. `TeamDelete`

## References

- [../../docs/workspace-templates.md](../../docs/workspace-templates.md) — workspace file templates and task-graph.json schema
- [../../docs/teammate-roles.md](../../docs/teammate-roles.md) — lead + teammate role definitions and selection guide
- [../../docs/team-archetypes.md](../../docs/team-archetypes.md) — team type definitions and phase profiles
- [agents/spawn-templates.md](agents/spawn-templates.md) — detailed spawn prompt templates for all teammate roles
- [references/communication-protocol.md](references/communication-protocol.md) — structured message formats (canonical source for spawn prompt injection)
- [references/coordination-patterns.md](references/coordination-patterns.md) — conflict resolution, handoff patterns, error recovery, and advanced coordination
- [references/error-recovery-protocol.md](references/error-recovery-protocol.md) — error classification, decision tree, bounds, and tracking
- [agents/execute-reviewer.md](agents/execute-reviewer.md) — execute review agent prompt

## Anti-Patterns

- **DO NOT implement or verify code yourself** (the Zero-Code Rule) — no editing files, no running build/test/lint. If it touches a file or runs a command, a teammate does it. Bundle small tasks into an adjacent teammate's scope. Bash is for workspace init (`mkdir`) and cleanup only
- **DO NOT let two teammates edit the same file** — guaranteed conflicts. Map every file to one owner in Phase 2
- **DO NOT assume task completion** — no COMPLETED message means the task is NOT done
- **DO NOT use broadcast for routine updates** — each broadcast = N messages. Use 1:1 messages by default
- **DO NOT nest teams** — teammates cannot spawn their own teams. One team per session — clean up before starting a new one. `/resume` and `/rewind` do not restore teammates
