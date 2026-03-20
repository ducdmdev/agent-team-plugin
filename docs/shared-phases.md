# Shared Phases Reference

Shared phase logic for all agent-team archetype skills. Each archetype skill references this file for Phases 1, 2, and 4.

## Contents

- [Orchestrator Identity](#orchestrator-identity)
- [Prerequisites](#prerequisites)
- [Hooks](#hooks)
- [Phase 1: Analyze and Decompose](#phase-1-analyze-and-decompose)
  - [Early Exit — Trivial Tasks](#early-exit--trivial-tasks)
  - [Budget Constraints](#budget-constraints)
  - [Phase 1a: Plan Detection & Preparation](#phase-1a-plan-detection--preparation)
  - [Phase 1b: Decompose from Plan](#phase-1b-decompose-from-plan)
- [Phase 2: Present Plan to User](#phase-2-present-plan-to-user-mandatory--do-not-skip)
- [Phase 3: Create Team](#phase-3-create-team-shared-steps)
  - [Resume Detection (Step 1a)](#phase-3-create-team-shared-steps)
  - [Task Graph Creation (Step 4a)](#phase-3-create-team-shared-steps)
- [Phase 4: Coordinate](#phase-4-coordinate)
  - [Critical Path Awareness](#critical-path-awareness)
- [Phase 5: Synthesis and Completion](#phase-5-synthesis-and-completion-shared-steps)
- [Anti-Patterns](#anti-patterns)
- [Reference](#reference)

## Orchestrator Identity

You are the **Team Lead**. Your sole job is coordination — you never write code directly. You maintain a persistent workspace that tracks everything the team does.

For your full role definition, see [teammate-roles.md](teammate-roles.md) under "Leader".

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
- **TaskCompleted** (`scripts/compute-critical-path.sh`): After each task completion, recomputes the critical path from `task-graph.json` and outputs the remaining critical path. Warns about blocked critical-path tasks. Non-blocking.
- **TaskCompleted** (`scripts/check-integration-point.sh`): Detects when all upstream tasks of a convergence point complete. Nudges the lead to verify interface compatibility before the downstream task starts. Non-blocking.
- **SessionStart** (`scripts/detect-resume.sh`): On every session start, scans for incomplete workspaces with `task-graph.json`. Validates completed task staleness via git timestamps and outputs resume context. Non-blocking.

All hooks exit 0 (allow) if their dependencies are missing — they degrade gracefully. Hook paths use `${CLAUDE_PLUGIN_ROOT}`.

## Phase 1: Analyze and Decompose

Analyze the user's task: $ARGUMENTS

### Early Exit — Trivial Tasks

Before entering Phase 1a, apply a quick complexity check:
- If the task obviously targets a single file with no dependencies (e.g., "fix the typo in README.md"), skip plan detection entirely and proceed to the "team not warranted" determination in Phase 1b step 4
- Signals: task mentions one file, uses words like "typo", "rename", "bump version", no cross-module impact
- When in doubt, proceed to Phase 1a — false negatives (skipping a plan for a complex task) are worse than false positives (scanning for a simple task)

### Budget Constraints

Phase 1a should remain lightweight relative to the overall team workflow:
- **Plan scan**: Limit to scanning directory listings + reading first 20 lines of each candidate (title, status, summary). Full file reads only for the top 3 ranked candidates.
- **Plan creation**: The writing-plans skill manages its own budget. The context bundle from Step 2a should be concise — key file paths and summaries, not full file contents.
- **Audit**: 7 checks against one plan file. The Team Lead reads the plan once and evaluates all checks in a single pass.
- **Max candidates scanned**: If a directory contains more than 20 `.md` files, rank by filename date prefix (most recent first) and keyword overlap, then read only the top 5.

### Phase 1a: Plan Detection & Preparation

#### Step 0 — Archetype Context

For **dedicated archetype skills** (`/agent-implement`, `/agent-research`, `/agent-audit`, `/agent-plan`), the archetype is already known at invocation — it was determined by which skill the user triggered. This archetype context is available throughout Phase 1a and informs plan creation if needed.

For **`/agent-team`** (hybrid/catch-all), archetype detection moves to Phase 1b after the plan is approved — plan content helps inform the detection.

#### Step 1 — Scan for Existing Plans

Scan these locations in priority order, collecting all `.md` candidates:

| Priority | Location | Pattern |
|----------|----------|---------|
| 1 | User-specified path | Direct path from trigger (e.g., "implement `docs/plans/my-plan.md`") |
| 2 | `docs/plans/` | `*.md` |
| 3 | `docs/specs/` | `*.md` |
| 4 | `plans/`, `.plans/` | `*.md` |
| 5 | `specs/` | `*.md` |
| 6 | `docs/` | `*plan*.md`, `*spec*.md`, `*design*.md` |
| 7 | Project root (non-recursive, deduplicate against prior results) | `*plan*.md`, `*spec*.md`, `*design*.md` |

**Matching logic:**
- Rank candidates by relevance to the user's task (keyword overlap between task description and plan title/content)
- If multiple candidates found, present top 3 to user: "I found these plans — which one applies, or should I create a new one?"
- If exactly one strong match, propose it: "I found `docs/plans/X.md` — shall I use this?"
- If zero matches → proceed to plan creation (Step 2)
- Skip files with `Status: COMPLETED` or `Status: ABANDONED` in frontmatter/header
- In monorepo structures (detected by multiple `package.json`, workspace configs, etc.), scope the scan to the subdirectory relevant to the user's task

**Minimum plan structure for usability:**
A plan file must contain at minimum: (a) identifiable task descriptions (numbered or headed sections), and (b) enough specificity to map tasks to files or modules. If a found plan is unstructured prose (e.g., a high-level strategy doc), it can inform context but cannot be used as the decomposition source — treat it as "zero matches" and proceed to plan creation, passing the prose document as a reference.

#### Step 2 — Create Plan (No Plan Found)

**2a. Gather context and references:**
- Codebase scan: Identify relevant files, modules, and architecture related to the user's task (using Glob, Grep, Read)
- Reference discovery: Find specs, ADRs, design docs, PRs, existing tests, CLAUDE.md conventions
- Dependency mapping: Identify which files/modules are touched, what imports what, integration boundaries
- Conventions check: Read CLAUDE.md, check for existing patterns in the codebase

**2b. Invoke `superpowers:writing-plans` with context:**

Pass a context bundle to the writing-plans skill:

```
Task: {user's original task description}
Archetype: {known archetype if dedicated skill, or "to be determined" for /agent-team}
Context:
- Relevant files: {list of files/modules identified}
- References: {specs, ADRs, design docs found}
- Dependencies: {what touches what}
- Conventions: {from CLAUDE.md and codebase patterns}
- Constraints: {anything discovered that limits the solution}
```

The writing-plans skill produces a plan file at `docs/plans/YYYY-MM-DD-{task-slug}-plan.md`.

**2c. Proceed to audit (Step 3).**

**Fallback — writing-plans skill unavailable:**
If `superpowers:writing-plans` is not installed or fails to invoke, the Team Lead falls back to inline plan creation:
- Use the gathered context from Step 2a to produce a plan document directly
- Follow the same output format (numbered tasks with file references, completion criteria, dependencies)
- Save to `docs/plans/YYYY-MM-DD-{task-slug}-plan.md`
- Note for Phase 3: "Plan created inline (writing-plans skill unavailable)" — log this in `progress.md` Decision Log when the workspace is created
- Proceed to audit as normal

This ensures the plugin degrades gracefully, consistent with how hooks handle missing `jq`.

#### Step 3 — Audit Plan (Common Gate)

Both paths converge here. Every plan is audited before the user sees it.

| # | Check | What it validates | Severity |
|---|-------|-------------------|----------|
| 1 | Task completeness | Every task has clear completion criteria, file references, and step-by-step instructions | High |
| 2 | Dependency coherence | No circular dependencies between tasks. Blocked-by chains resolve. | High |
| 3 | File reference validity | Files mentioned in the plan actually exist in the codebase (or are explicitly marked as "to be created") | Medium |
| 4 | Scope coverage | Plan tasks collectively cover the user's original request — nothing major missing | High |
| 5 | Reference freshness | Referenced specs/ADRs/docs still exist and haven't been superseded | Low |
| 6 | Feasibility | Tasks are achievable — no references to unavailable tools, APIs, or dependencies | Medium |
| 7 | Parallelizability | At least 2 tasks can run concurrently (otherwise a team isn't warranted) | High |

**Note on check #7 vs Phase 1b "team warranted" gate:** Check #7 is an early signal during audit — if it fails, the audit status reflects it and the user is warned. If the user chooses "proceed as-is" despite a failed check #7, Phase 1b step 4 performs the definitive evaluation after full decomposition. The audit flags the risk; Phase 1b makes the final call.

**Audit output:**
- **Status**: `ready` (0 high issues), `needs-revision` (1+ high issues), `insufficient` (plan is too vague to decompose)
- **Issues list**: Each issue with severity, description, and suggested fix
- **Parallelism assessment**: How many independent streams the plan supports

The Team Lead performs the audit inline — reading the plan file, cross-referencing codebase state, and evaluating each check. No separate skill invocation needed.

#### Step 4 — User Decision Gate

Present to user regardless of audit status:

```
Plan: {plan file path}
Source: {found in project | generated by writing-plans}
Audit status: {ready | needs-revision | insufficient}

{If issues exist:}
Issues found:
- [HIGH] Task 3 references src/auth/middleware.ts which doesn't exist
- [MEDIUM] No completion criteria for Task 5
- [LOW] Referenced ADR docs/adr-004.md was last modified 6 months ago

Parallelism: {N independent streams identified}

Options:
1. Proceed as-is — use this plan for team decomposition
2. Update — fix the issues above and re-audit
3. Create new — discard this plan, start fresh with writing-plans

Which option?
```

**Behavior per option:**

| Option | What happens |
|--------|-------------|
| Proceed as-is | Move to Phase 1b with the plan unchanged. Team Lead works around known issues during decomposition. |
| Update | Team Lead fixes the identified issues in the plan file, re-runs audit, presents again. Max 2 update cycles — if still `insufficient` after 2 rounds, ask user whether to proceed anyway or create new. |
| Create new | Set aside the current plan. Re-enter the creation path (Step 2) from scratch. Only offered once — if the second plan also fails audit, compare both and proceed with the plan that has fewer High-severity issues. |

**Guard rail:** For `insufficient` status, option 1 (proceed as-is) is presented but with a warning: "This plan may not have enough detail to decompose into parallel work. Proceeding may result in a weaker team structure."

### Phase 1b: Decompose from Plan

User has approved a plan (or no plan — see fallback below). The decomposition steps now derive from the approved plan:

1. **Map plan tasks to parallel streams** — Group plan tasks by independence. Tasks with no mutual dependencies form separate streams. Tasks that share file ownership or blocked-by relationships stay in the same stream.
2. **Assign file ownership from plan** — Plan tasks reference specific files. Each stream's files become that teammate's owned files. No two teammates edit the same file. If the plan doesn't specify files, the Team Lead infers from task descriptions + codebase scan.
3. **Derive dependencies from plan** — The plan's task ordering and blocked-by relationships translate directly to Agent Team task dependencies.
4. **Determine if a team is warranted** — if fewer than 2 independent streams exist, tell the user a single session is more efficient. Offer: "This plan is sequential — shall I execute it directly without a team?" Stop here if not warranted.
5. **Integration points** — for each pair of streams, identify where plan tasks reference shared interfaces, contracts, or outputs. These become explicit handoff points in Phase 2.
6. **Mark convergence points** — for each task that depends on 2+ upstream tasks, flag it as a convergence point. These become integration checkpoints during Phase 4 — the `check-integration-point.sh` hook will nudge the lead to verify interface compatibility when all upstream tasks complete. Include convergence points in the Phase 2 presentation.
7. **Identify reference documents** — already gathered during Phase 1a. Carry forward into workspace. If Phase 1a was skipped (trivial task early exit), find specs, ADRs, design docs, PRs, or other docs relevant to the task.
8. **Check for custom roles** — if `docs/custom-roles.md` exists in the project, read it. Use custom roles alongside built-in roles when they match the task requirements.

**Fallback — no plan available:** If Phase 1a was skipped (trivial task early exit) or the user declined all plans, the Team Lead performs ad-hoc decomposition using the strategies below:
- **By module/area**: frontend vs backend, auth vs payments (best for feature work)
- **By concern**: implementation vs verification vs research (best for quality-critical tasks)
- **By layer**: data model vs API vs UI (best for full-stack features)
- Avoid splits that create heavy cross-dependencies — if two streams need constant handoffs, merge them

**Self-check**: "Do I have 2+ streams where each can make meaningful progress without waiting on the others? Are integration points identified?" If no, reconsider the split.

## Phase 2: Present Plan to User (MANDATORY — DO NOT SKIP)

Before creating the team, you MUST present the decomposition and wait for explicit user approval. This is a hard gate — no tasks, no teammates, no workspace until the user says "yes".

```
Team plan for: [task summary]
Based on: [plan file path] (existing | generated) — omit if no plan
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

Critical path: [#X → #Y → #Z] (length: N)
  Non-critical (can slip without affecting total time): [#A, #B]
  Integration checkpoints: [#Y (converges #X + #A — verify interface compatibility)]

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
3. "Do any tasks form circular dependencies? Trace each `blocked by` chain — if task A blocks B blocks C blocks A, that's a cycle. If found, restructure: merge the cyclic tasks or break the cycle by removing one dependency."
4. "Have I identified the critical path? Is it displayed in the plan? Are convergence points marked?"

Wait for user confirmation before proceeding.

## Phase 3: Create Team (shared steps)

Steps shared by all archetypes. Archetype-specific overrides (file-locks, branches, roles) are in each skill's own Phase 3 section.

1a. **Check for resumable workspace** — if the `detect-resume.sh` hook surfaced a resumable workspace at session start, present the resume option to the user:

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
   Use the templates from [workspace-templates.md](workspace-templates.md) to create:
   - `.agent-team/{team-name}/progress.md` — team status, members, decisions, handoffs
   - `.agent-team/{team-name}/tasks.md` — task ledger with status tracking
   - `.agent-team/{team-name}/issues.md` — issue tracker with severity and impact

   Populate the `## References` section in `progress.md` with docs identified in Phase 1. If no reference docs were found, leave the table with a single `—` row.

   If the team is based on a plan file, set its `Status:` to `IN PROGRESS` now (add the field if it doesn't exist). This warns other teams during Phase 1a scanning that the plan is being executed.

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

4a. **Create `task-graph.json`** — immediately after creating all tasks, generate `.agent-team/{team-name}/task-graph.json` with the full dependency graph. Compute the initial critical path (longest chain, tie-break by lowest task ID) and mark convergence points (nodes with 2+ dependencies). Validate the graph is acyclic — if a cycle is detected, fix it before proceeding (see Circular Dependency Detection in [coordination-advanced.md](coordination-advanced.md)). Update `tasks.md` with ★ markers on critical-path tasks and convergence notes. See [workspace-templates.md](workspace-templates.md#task-graphjson) for schema.

5. **Spawn teammates** using the Task tool with `team_name`, `name`, and `subagent_type` parameters. See [teammate-roles.md](teammate-roles.md) for role overview and [spawn-templates.md](spawn-templates.md) for detailed spawn prompt templates.

   **subagent_type**: `"general-purpose"` for full tool access (implementers, challengers, testers). `"Explore"` for read-only research teammates. `"general-purpose"` if a reviewer needs Bash. Optionally set `mode: "plan"` for risky or architectural tasks.

   **Protocol injection**: Before building spawn prompts, read [communication-protocol.md](communication-protocol.md). Substitute the `{COMMUNICATION_PROTOCOL}` placeholder in each role's spawn template with the Structured Messages block. For roles with format placeholders (`{FINDINGS_FORMAT}`, `{RESULTS_FORMAT}`, `{REPORT_FORMAT}`), substitute the matching section from the same file.

   Every spawn prompt MUST include:

   Identity:
   1. Role and responsibilities
   2. Assigned task IDs
   3. Owned files/areas (exclusive — no overlap with other teammates)

   Context:
   4. Workspace path: `.agent-team/{team-name}/` — read for team state, write output artifacts here
   5. Communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF/QUESTION — see Phase 4)
   6. Project conventions: "Read CLAUDE.md if it exists. Follow its conventions."
   7. Skill hints: role-specific recommendations from [teammate-roles.md](teammate-roles.md)

   Behavior:
   8. When blocked: message the lead with severity and impact, do not wait silently
   9. After completing a task: mark complete via TaskUpdate, check TaskList, self-claim next available
   10. Use subagents (Task tool) for focused subtasks that don't need teammate communication
   11. Write output artifacts to the workspace directory
   - **Nested decomposition** (optional): For large tasks, tell senior implementers: "You may create sub-tasks and spawn subagents for independent portions of your work. Report rolled-up results to me. One level of nesting max."

   **Update workspace**: record each teammate in `progress.md` Team Members table

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

See [coordination-patterns.md](coordination-patterns.md#setup-failures) for recovery actions on common Phase 3 failures (name collisions, missing feature flag, stale workspaces, spawn failures, context compaction).

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

Update workspace files at every significant event. Batch multiple events into a single edit per file. See [workspace-templates.md](workspace-templates.md#workspace-update-protocol) for the full event-to-file mapping table.

### Communication Protocol

All teammates use structured message prefixes when communicating with the lead. Include this protocol in every teammate's spawn prompt:

```
STARTING #N: {what I plan to do, which files I'll touch}
COMPLETED #N: {what I did, files changed, any concerns}
BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
HANDOFF #N: {what I produced that another teammate needs, key details}
QUESTION: {what I need to know, what I already checked in workspace}
```

#### Lead Processing Rules

When receiving structured messages:

| Prefix | Lead Action |
|--------|--------------|
| STARTING | Update `tasks.md` status to `in_progress`, add note |
| COMPLETED | Update `tasks.md` status to `completed`, add file list and notes. Update `task-graph.json`: set node status to `completed`, record `completed_at` and `output_files`. **Self-check**: read `task-graph.json` back to verify valid JSON — malformed JSON silently disables all three hook scripts. Check: does this unblock other tasks? If yes, message the dependent teammate. The `compute-critical-path.sh` hook will output the updated critical path. |
| BLOCKED | Add row to `issues.md` immediately. Acknowledge the teammate. Route to resolution |
| HANDOFF | Extract key details, forward to dependent teammate with actionable context. Log in `progress.md` Handoffs |
| QUESTION | Check if answer is in workspace files. If yes, answer with file reference. If no, investigate |
| PROGRESS | Note milestone in `tasks.md` Notes column. If percent indicates near-completion, no action needed. If stalled, trigger Deadline Escalation |
| CHECKPOINT | If `ready_for` lists task IDs, forward checkpoint details to dependent teammate. Log in `progress.md` Handoffs |
| (hook: integration checkpoint) | Read the nudge from `check-integration-point.sh`. Before unblocking the convergence task, verify interface compatibility between upstream outputs. If compatible, message the convergence task owner to proceed. If unclear, log in `issues.md` as medium severity. Log checkpoint in `progress.md` Decision Log. |

#### Plan Approval Handling

When a teammate spawned with `mode: "plan"` finishes planning, they send a `plan_approval_request` message to the lead. You must respond via SendMessage with `type: "plan_approval_response"`, the teammate as `recipient`, the `request_id` from their request, and `approve: true` or `approve: false`. If rejecting, include `content` with specific feedback so the teammate can revise their plan. The teammate cannot proceed with implementation until the plan is approved.

For high-frequency handoffs between specific teammates, you may authorize direct communication — see the Direct Handoff pattern in [coordination-patterns.md](coordination-patterns.md). The audit trail must still be maintained in `progress.md`.

### Critical Path Awareness

The critical path determines total execution time. The `compute-critical-path.sh` hook outputs the remaining critical path after every task completion. Use it to prioritize:

- **BLOCKED on critical path** → resolve immediately (highest-priority coordination action)
- **BLOCKED on non-critical path** → resolve normally (slippage has slack)
- **Teammate idle on critical path** → reassign work to keep the critical path moving
- **Teammate idle on non-critical path** → lower priority, consider assigning critical-path support tasks

After every task completion, read the hook output. If the critical path shifted (a previously non-critical chain is now longest), update `task-graph.json` and the ★ markers in `tasks.md`.

### Coordination Patterns

For detailed patterns on these scenarios, see [coordination-patterns.md](coordination-patterns.md):
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

See also [coordination-advanced.md](coordination-advanced.md) for specialized patterns (re-plan, adversarial review, checkpoint/rollback, deadline escalation, and more).

**Periodic scan**: on every context recovery, check `issues.md` for OPEN items and address them before resuming normal coordination.

The phase checklist is embedded in your `progress.md` — check it during workspace reads.

## Phase 5: Synthesis and Completion (shared steps)

Steps shared by all archetypes. Archetype-specific overrides (completion gate checks, report variant, commit/merge behavior) are in each skill's own Phase 5 section.

1. **Verify all tasks completed** via TaskList — every task must be `completed`

2. **Collect results** — message each teammate with the structured request (skip if teammates' COMPLETED messages already included full summaries — files changed, decisions, concerns):
   ```
   Summarize your work:
   - Task IDs completed
   - Files created, modified, or deleted
   - Key decisions you made
   - Open concerns or follow-up items
   ```

3. **Update workspace**: set `progress.md` status to `completing`, update `tasks.md` with final states and teammate notes. See Workspace Update Protocol in Phase 4 for event-to-file mappings.

### Plan Status Update

After the archetype-specific completion gate passes and before generating the report, update the source plan file's status. Each archetype's Phase 5 Override references this step at the appropriate point in its sequence.

If the team was based on a plan file (tracked in `progress.md` References), add or update the plan file's `Status:` field (insert after existing header metadata if the field doesn't exist yet):

| Team outcome | Status value |
|-------------|-------------|
| All plan tasks completed | `Status: COMPLETED — Implemented via team {team-name} (YYYY-MM-DD)` |
| Partial completion | `Status: PARTIAL — {N}/{total} tasks completed via team {team-name} (YYYY-MM-DD). Remaining: {list}` |
| Team failed or abandoned | `Status: ABANDONED — Team {team-name} (YYYY-MM-DD). Reason: {reason}` |

This ensures future Phase 1a plan scans correctly skip completed/abandoned plans. Skip if no plan file was used. See [workspace-templates.md](workspace-templates.md#plan-file-conventions) for the full status value reference.

4. **Remediation gate** — the Completion Gate resolves most OPEN issues via fix tasks. This step handles residual issues that couldn't be resolved:
   - If **0 OPEN issues** in `issues.md`: skip
   - If **OPEN issues exist** and `progress.md` remediation cycle is already `1`: do NOT spawn another team. Include unresolved issues in the user report:
     > **Unresolved issues (require manual follow-up):**
     > - Issue #N (severity): description
     > See `.agent-team/{team-name}/issues.md` for full details.
   - If **OPEN issues exist** and remediation cycle is `0`: present issues to the user and propose a remediation team. Follow the full protocol in [coordination-patterns.md](coordination-patterns.md#remediation-gate).

5. **Report to user**:
   - Summary of all work completed
   - Files modified by each teammate
   - **Issues summary**: list any OPEN or MITIGATED issues from `issues.md` with their impact
   - Any open concerns or follow-up items
   - **Workspace path**: tell the user where the workspace is (`.agent-team/{team-name}/`)

6. **Shutdown sequence** (parallel — do NOT wait for each one sequentially):
    ```
    Send ALL shutdown_request messages in a single turn (parallel SendMessage calls)
    Wait for all approval responses
    If a teammate rejects: check their reason, resolve, then re-request
    ```
    **Update workspace**: set `progress.md` status to `done`, record completion time

7. **Cleanup**:
    - **Only call TeamDelete after ALL teammates have confirmed shutdown.** TeamDelete may fail if teammates are still active — always wait for all shutdown confirmations first.
    - TeamDelete to remove ephemeral team resources (`~/.claude/teams/{team-name}/`). The workspace at `.agent-team/{team-name}/` is NOT deleted — it is the permanent record
    - Clean up idle hook counters: `rm -f /tmp/agent-team-idle-counters/{team-name}--* 2>/dev/null || true`
    - Clean up ownership violation tracking: `rm -rf /tmp/agent-team-ownership-violations 2>/dev/null || true`

## Anti-Patterns

- **DO NOT implement or verify code yourself** (the Zero-Code Rule) — no editing files, no running build/test/lint. If it touches a file or runs a command, a teammate does it. Bundle small tasks into an adjacent teammate's scope. Bash is for workspace init (`mkdir`) and cleanup only
- **DO NOT let two teammates edit the same file** — guaranteed conflicts. Map every file to one owner in Phase 2
- **DO NOT skip the report** — `.agent-team/{team-name}/report.md` MUST exist before shutdown
- **DO NOT assume task completion** — no COMPLETED message means the task is NOT done
- **DO NOT use broadcast for routine updates** — each broadcast = N messages. Use 1:1 messages by default
- **DO NOT nest teams** — teammates cannot spawn their own teams. One team per session — clean up before starting a new one. `/resume` and `/rewind` do not restore teammates

## Reference

- [teammate-roles.md](teammate-roles.md) — lead + teammate role definitions and selection guide
- [spawn-templates.md](spawn-templates.md) — detailed spawn prompt templates for all teammate roles
- [communication-protocol.md](communication-protocol.md) — structured message formats (canonical source for spawn prompt injection)
- [coordination-patterns.md](coordination-patterns.md) — core conflict resolution, handoff patterns, and communication protocol
- [coordination-advanced.md](coordination-advanced.md) — advanced coordination patterns (re-plan, adversarial review, checkpoint/rollback, escalation)
- [report-format.md](report-format.md) — final report format and generation protocol
