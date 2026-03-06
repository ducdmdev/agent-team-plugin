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

For your full role definition, see [teammate-roles.md](../../docs/teammate-roles.md) under "Leader".

## Quick Start

1. **Analyze** — identify 2+ independent streams, detect archetype
2. **Plan** — present to user, wait for approval (hard gate)
3. **Create** — team, workspace, tasks, spawn teammates
4. **Coordinate** — track progress, route messages, resolve blockers
5. **Synthesize** — completion gate, report, shutdown

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
9. **Detect team archetype** — read [team-archetypes.md](../../docs/team-archetypes.md). Match the user's task to an archetype (implementation, research, audit, planning, or hybrid) using the trigger patterns. The archetype determines which phases, completion gate checks, and report variant to use. Apply the archetype's phase profile for all subsequent phases.

**Self-check**: "Do I have 2+ streams where each can make meaningful progress without waiting on the others? Are integration points identified?" If no, reconsider the split.

## Phase 2: Present Plan to User (MANDATORY — DO NOT SKIP)

Before creating the team, you MUST present the decomposition and wait for explicit user approval. This is a hard gate — no tasks, no teammates, no workspace until the user says "yes".

```
Team plan for: [task summary]
Team type: [detected-type] (auto-detected from task — say "change to [type]" to override)
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

**Example** — "refactor the auth module":

```
Team plan for: Refactor auth module — extract token validation and session management
Team type: implementation (auto-detected)
Complexity: standard

Teammates (3 total):
- auth-impl-1 (Implementer): Refactor token validation -> owns src/auth/token.ts, src/auth/validate.ts
- auth-impl-2 (Implementer): Extract session management -> owns src/auth/session.ts, src/middleware/auth.ts
- auth-reviewer (Reviewer): Review all changes -> read-only

Task breakdown:
1. Refactor token validation logic -> auth-impl-1
2. Extract session management to dedicated module -> auth-impl-2
3. Update middleware to use new session API -> auth-impl-2 (blocked by #2)
4. Review all changes across both scopes -> auth-reviewer (blocked by #1, #2)

Isolation: shared (default)
Workspace: .agent-team/0306-refactor-auth/
Estimated teammates: 3
```

**Self-check before proceeding**:
1. "Is this plan complex? Complexity signals: multi-module/area changes, architectural decisions, risky refactors, multiple implementers with cross-dependencies, security-sensitive changes, new integrations. If yes, does the teammate list include a **dedicated reviewer** AND a **dedicated tester** (separate teammates, not combined)? If no, add them before presenting."
2. "Have I presented this plan AND received user confirmation?" If no, STOP.

Wait for user confirmation before proceeding.

If the user requests a different team type during approval, re-apply the new archetype's phase profile: adjust roles, phase overrides, completion gate, and report variant before proceeding to Phase 3.

## Phase 3: Create Team

> **Archetype overrides**: Check [team-archetypes.md](../../docs/team-archetypes.md) for Phase 3 overrides. Key differences: read-only archetypes (research, audit, planning) SKIP file-locks.json and branch instructions. Hybrid teams create file-locks.json only if ANY teammate writes project files.

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

   Maps teammates to owned files/directories. Used by PreToolUse hook. See [workspace-templates.md](../../docs/workspace-templates.md#file-locksjson) for format and creation rules.

   #### events.log

   Initially empty. Append-only JSON event log. Written by SubagentStart/Stop hooks and the lead during coordination. See [workspace-templates.md](../../docs/workspace-templates.md#eventslog) for format and event types.

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

5. **Spawn teammates** using the Task tool with `team_name`, `name`, and `subagent_type` parameters. See [teammate-roles.md](../../docs/teammate-roles.md) for role-specific spawn templates.

   **subagent_type**: `"general-purpose"` for full tool access (implementers, challengers, testers). `"Explore"` for read-only research teammates. `"general-purpose"` if a reviewer needs Bash. Optionally set `mode: "plan"` for risky or architectural tasks.

   **Protocol injection**: Before building spawn prompts, read [communication-protocol.md](../../docs/communication-protocol.md). Substitute the `{COMMUNICATION_PROTOCOL}` placeholder in each role's spawn template with the Structured Messages block. For roles with format placeholders (`{FINDINGS_FORMAT}`, `{RESULTS_FORMAT}`, `{REPORT_FORMAT}`), substitute the matching section from the same file.

   Every spawn prompt MUST include:

   Identity:
   1. Role and responsibilities
   2. Assigned task IDs
   3. Owned files/areas (exclusive — no overlap with other teammates)

   Context:
   4. Workspace path: `.agent-team/{team-name}/` — read for team state, write output artifacts here
   5. Communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF/QUESTION — see Phase 4)
   6. Project conventions: "Read CLAUDE.md if it exists. Follow its conventions."
   7. Skill hints: role-specific recommendations from [teammate-roles.md](../../docs/teammate-roles.md)

   Behavior:
   8. When blocked: message the lead with severity and impact, do not wait silently
   9. After completing a task: mark complete via TaskUpdate, check TaskList, self-claim next available
   10. Use subagents (Task tool) for focused subtasks that don't need teammate communication
   11. Write output artifacts to the workspace directory
   - **Branch instruction** (implementers only): "Create branch `{team-name}/{your-name}` before starting work. If git is unavailable, skip."
   - **Nested decomposition** (optional): For large tasks, tell senior implementers: "You may create sub-tasks and spawn subagents for independent portions of your work. Report rolled-up results to me. One level of nesting max."

   **Example — assembling a spawn prompt**:

   The lead reads `docs/communication-protocol.md`, then substitutes into the role template:

   ```
   # 1. Read the protocol
   Read: docs/communication-protocol.md → get COMMUNICATION_PROTOCOL block

   # 2. Build prompt from teammate-roles.md template
   Task tool call:
     subagent_type: "general-purpose"
     team_name: "0306-refactor-auth"
     name: "auth-impl-1"
     prompt: |
       You are an implementer on this team. Your job is to write code...

       Your assigned tasks: #1
       Your file ownership: src/auth/token.ts, src/auth/validate.ts

       Workspace: .agent-team/0306-refactor-auth/
       Project conventions: Read CLAUDE.md if it exists.

       Communication protocol — send structured messages to the lead:
       - STARTING #N: {what I plan to do, which files I'll touch}
       - COMPLETED #N: {what I did, files changed, any concerns}
       - BLOCKED #N: severity={level}, {what's blocking}, impact={what can't proceed}
       - HANDOFF #N: {what I produced that another teammate needs}
       - QUESTION: {what I need to know}

       Rules: [... rest of implementer template ...]
   ```

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

See [coordination-patterns.md](../../docs/coordination-patterns.md#setup-failures) for recovery actions on common Phase 3 failures (name collisions, missing feature flag, stale workspaces, spawn failures, context compaction).

## Phase 4: Coordinate

> **Archetype overrides**: Check [team-archetypes.md](../../docs/team-archetypes.md) for Phase 4 overrides. Key difference: file ownership enforcement is N/A for archetypes without file-locks.json.

### Context Recovery
If your context was compacted or you feel disoriented, **read the workspace first**:
```
Read: .agent-team/{team-name}/progress.md
Read: .agent-team/{team-name}/tasks.md
Read: .agent-team/{team-name}/issues.md
```
This restores your full awareness of team state, decisions, and history. Then read `~/.claude/teams/{team-name}/config.json` for live team members and call TaskList for live task state.

### Workspace Updates

Update workspace files at every significant event. Batch multiple events into a single edit per file. See [workspace-templates.md](../../docs/workspace-templates.md#workspace-update-protocol) for the full event-to-file mapping table.

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

> **Archetype overrides**: Check [team-archetypes.md](../../docs/team-archetypes.md) for Phase 5 overrides. Key differences: read-only archetypes SKIP pre-shutdown commit, branch merge, and most completion gate checks. Use the archetype's report variant.

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

5. **Completion Gate** (hard gate — ALL must PASS before proceeding to report generation):

   Run checks in order. Items marked ★ are project-specific — PASS automatically if the project has no configured tooling for that check.

   | # | Check | How | PASS Criteria | On FAIL |
   |---|-------|-----|---------------|---------|
   | 1 | **Uncommitted changes** | Run `git status` scoped to each implementer's owned files | All owned files committed. Working tree clean for owned paths | Message the implementer to commit. Re-run after confirmation |
   | 2 | **Build & tests** | Assign a teammate: "Run `[build cmd]` and `[test cmd]`, report PASS/FAIL with output" | Build exits 0, all tests pass | Create fix task, assign to relevant implementer, re-run gate |
   | 3 | **Lint/format** ★ | Assign a teammate: "Run `[lint cmd]`, report new warnings/errors" | No new lint errors (pre-existing are acceptable) | Create fix task, assign to implementer who owns the file, re-run gate |
   | 4 | **Integration** | Assign a teammate: "Verify [module A] correctly calls [module B] after changes. Check shared interfaces, imports, API contracts" | Cross-teammate outputs connect correctly | Create integration fix task, assign to the implementer closest to the boundary, re-run gate |
   | 5 | **Security scan** ★ | Assign a teammate: "Check for hardcoded secrets, common vulnerabilities (OWASP top 10) in changed files" | No new security issues in changed files | Create fix task as **critical** severity, assign to implementer, re-run gate |
   | 6 | **Workspace issues** | Read `issues.md`, count OPEN items | 0 OPEN issues (all RESOLVED or MITIGATED) | Route each OPEN issue to a teammate for resolution, re-run gate |
   | 7 | **Plan completion** | Compare Phase 2 plan streams against TaskList + teammate summaries | Every planned stream has completed tasks. No orphaned streams | Create tasks for missing streams, assign, re-run gate |
   | 8 | **Documentation sync** | Assign a teammate: "Check if README, ADRs, or docs need updates based on changes made" | No stale docs, or update tasks completed | Create doc update task, assign, re-run gate |

   ★ = Project-specific. If no lint/security tooling exists, mark PASS and note "N/A — no tooling configured" in the gate log.

   Log gate result in `progress.md` Decision Log: "Completion Gate: PASS" or "Completion Gate: FAIL — [items], fix tasks created"

   **Self-check**: "Have all 8 checks passed? If any failed, have I created fix tasks and re-run?" If no, STOP.

6. **Update workspace**: set `progress.md` status to `completing`, update `tasks.md` with final states and teammate notes. See Workspace Update Protocol in Phase 4 for event-to-file mappings.

7. **Generate final report** (MANDATORY — do not skip):
   - Read all workspace files for full history
   - Read TaskList for final task states
   - Write `.agent-team/{team-name}/report.md` using the format in [report-format.md](../../docs/report-format.md)
   - Copy References from `progress.md` into the report's References section
   - **Self-check**: "Does `.agent-team/{team-name}/report.md` exist and contain the executive summary?" If no, generate it now

8. **Remediation gate** — the Completion Gate (step 5) resolves most OPEN issues via fix tasks. This step handles residual issues that couldn't be resolved:
   - If **0 OPEN issues** in `issues.md`: skip to step 9
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

- [teammate-roles.md](../../docs/teammate-roles.md) — lead + teammate role definitions and spawn templates
- [communication-protocol.md](../../docs/communication-protocol.md) — structured message formats (canonical source for spawn prompt injection)
- [coordination-patterns.md](../../docs/coordination-patterns.md) — conflict resolution, handoff patterns, and communication protocol
- [report-format.md](../../docs/report-format.md) — final report format and generation protocol
- [team-archetypes.md](../../docs/team-archetypes.md) — team type detection, phase profiles, and completion gate overrides

## Anti-Patterns

- **DO NOT implement or verify code yourself** (the Zero-Code Rule) — no editing files, no running build/test/lint. If it touches a file or runs a command, a teammate does it. Bundle small tasks into an adjacent teammate's scope. Bash is for workspace init (`mkdir`) and cleanup only
- **DO NOT let two teammates edit the same file** — guaranteed conflicts. Map every file to one owner in Phase 2
- **DO NOT skip the report** — `.agent-team/{team-name}/report.md` MUST exist before shutdown
- **DO NOT assume task completion** — no COMPLETED message means the task is NOT done
- **DO NOT use broadcast for routine updates** — each broadcast = N messages. Use 1:1 messages by default
- **DO NOT nest teams** — teammates cannot spawn their own teams. One team per session — clean up before starting a new one. `/resume` and `/rewind` do not restore teammates
