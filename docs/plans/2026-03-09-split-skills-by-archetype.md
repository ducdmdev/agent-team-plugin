# Split Agent-Team Skill by Archetype — Implementation Plan

**Status:** COMPLETED — Merged to main via `0362627` (2026-03-09)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split the monolithic `/agent-team` SKILL.md into 5 focused skills — one per archetype — plus a shared phases doc, eliminating conditional branching from each skill prompt.

**Architecture:** Extract shared logic (Phase 1 analysis, Phase 2 plan presentation, Phase 4 coordination) into `docs/shared-phases.md`. Create 4 new archetype-specific skills (`agent-research`, `agent-audit`, `agent-implement`, `agent-plan`) and slim down `agent-team` to be the Hybrid catch-all. Each skill references shared docs but contains only its archetype-specific Phase 3 and Phase 5 behavior.

**Tech Stack:** Markdown (SKILL.md frontmatter), Bash (test scripts)

---

### Task 1: Create `docs/shared-phases.md` — extract shared logic

**Files:**
- Create: `docs/shared-phases.md`

**Step 1: Write the shared phases doc**

Extract from current `skills/agent-team/SKILL.md` the sections that are identical across all archetypes:

```markdown
# Shared Phases Reference

Shared phase logic for all agent-team archetype skills. Each archetype skill references this file for Phases 1, 2, and 4.

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

**Self-check before proceeding**:
1. "Is this plan complex? Complexity signals: multi-module/area changes, architectural decisions, risky refactors, multiple implementers with cross-dependencies, security-sensitive changes, new integrations. If yes, does the teammate list include a **dedicated reviewer** AND a **dedicated tester** (separate teammates, not combined)? If no, add them before presenting."
2. "Have I presented this plan AND received user confirmation?" If no, STOP.

Wait for user confirmation before proceeding.

## Phase 3: Create Team (shared steps)

Steps shared by all archetypes. Archetype-specific overrides (file-locks, branches, roles) are in each skill's own Phase 3 section.

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

5. **Spawn teammates** using the Task tool with `team_name`, `name`, and `subagent_type` parameters. See [teammate-roles.md](teammate-roles.md) for role-specific spawn templates.

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
| COMPLETED | Update `tasks.md` status to `completed`, add file list and notes. Check: does this unblock other tasks? If yes, message the dependent teammate |
| BLOCKED | Add row to `issues.md` immediately. Acknowledge the teammate. Route to resolution |
| HANDOFF | Extract key details, forward to dependent teammate with actionable context. Log in `progress.md` Handoffs |
| QUESTION | Check if answer is in workspace files. If yes, answer with file reference. If no, investigate |

#### Plan Approval Handling

When a teammate spawned with `mode: "plan"` finishes planning, they send a `plan_approval_request` message to the lead. You must respond via SendMessage with `type: "plan_approval_response"`, the teammate as `recipient`, the `request_id` from their request, and `approve: true` or `approve: false`. If rejecting, include `content` with specific feedback so the teammate can revise their plan. The teammate cannot proceed with implementation until the plan is approved.

For high-frequency handoffs between specific teammates, you may authorize direct communication — see the Direct Handoff pattern in [coordination-patterns.md](coordination-patterns.md). The audit trail must still be maintained in `progress.md`.

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

- [teammate-roles.md](teammate-roles.md) — lead + teammate role definitions and spawn templates
- [communication-protocol.md](communication-protocol.md) — structured message formats (canonical source for spawn prompt injection)
- [coordination-patterns.md](coordination-patterns.md) — conflict resolution, handoff patterns, and communication protocol
- [report-format.md](report-format.md) — final report format and generation protocol
```

**Step 2: Verify the doc is self-consistent**

Run: `grep -c '^\(##\|###\)' docs/shared-phases.md`
Expected: Should show section headings for Prerequisites, Hooks, Phase 1, Phase 2, Phase 3 (shared), Phase 4, Phase 5 (shared), Anti-Patterns, Reference.

**Step 3: Commit**

```bash
git add docs/shared-phases.md
git commit -m "docs: extract shared phases into docs/shared-phases.md"
```

---

### Task 2: Create `skills/agent-implement/SKILL.md` — Implementation archetype

**Files:**
- Create: `skills/agent-implement/SKILL.md`

**Step 1: Write the implementation skill**

```markdown
---
name: agent-implement
description: >
  Orchestrates parallel implementation work via Agent Teams. Triggers when a task involves
  building, refactoring, fixing, or migrating code with 2+ independent work streams.
  Triggers: "implement in parallel", "build with a team", "refactor with teammates",
  "fix in parallel", "migrate with a team".
argument-hint: "[implementation task description]"
allowed-tools: TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, AskUserQuestion, Read, Write, Edit, Glob, Grep, Bash
---

# Implementation Team Orchestrator

Read [shared-phases.md](../../docs/shared-phases.md) for your identity, prerequisites, hooks, and shared phase logic (Phases 1, 2, 4, and shared steps of 3 and 5).

## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1, then:
- **Decompose by module/area** (frontend vs backend, auth vs payments) or **by layer** (data model vs API vs UI)
- **Default roles**: 1-2 Implementers + Reviewer (standard) or + Reviewer + Tester (complex)
- Detect archetype as `implementation` — show `Team type: implementation (auto-detected)` in Phase 2

## Phase 3 Override: Workspace Setup

Apply shared Phase 3 steps 1-7, plus:

### file-locks.json

Create `.agent-team/{team-name}/file-locks.json` mapping each teammate to owned files/directories. Used by PreToolUse hook. See [workspace-templates.md](../../docs/workspace-templates.md#file-locksjson) for format.

```json
{
  "teammate-name": ["src/auth/", "src/middleware/auth.ts"],
  "other-teammate": ["src/api/", "tests/api/"]
}
```

### events.log

Initially empty. Append-only JSON event log. Written by SubagentStart/Stop hooks and the lead during coordination. See [workspace-templates.md](../../docs/workspace-templates.md#eventslog) for format.

### Branch Instructions

Include in each **implementer's** spawn prompt:
- "Create branch `{team-name}/{your-name}` before starting work. If git is unavailable, skip."

### Worktree Isolation (optional)

If `isolation: worktree` was chosen in Phase 2:
- For each implementer, run `scripts/setup-worktree.sh {team-name} {teammate-name}`
- Include the worktree path in the implementer's spawn prompt as their working directory
- If worktree creation fails, fall back to shared mode and log warning in `issues.md`

## Phase 5 Override: Completion

Apply shared Phase 5 steps 1-3, then:

### Pre-Shutdown Commit

Message each **implementer** to commit their owned files:
```
Commit your owned files before shutdown.
- Stage ONLY files in your owned area: git add <your owned files>
- Commit with a descriptive message following project conventions
- Send me the commit hash when done
- If the commit fails, fix the issue and retry. Do NOT proceed without a successful commit.
```
Wait for all implementers to confirm. Log failures in `issues.md` as **high** severity.

### Merge Branches

- If worktree isolation: run `scripts/merge-worktrees.sh {team-name}`
- If auto-branching only: `git merge --no-ff {team-name}/{teammate-name}` per branch
- If merge conflicts: log in `issues.md`, assign implementer to resolve
- If neither branching nor worktrees: skip

### Completion Gate (ALL 8 checks must PASS)

Run checks in order. Items marked ★ are project-specific — PASS automatically if no tooling configured.

| # | Check | How | PASS Criteria | On FAIL |
|---|-------|-----|---------------|---------|
| 1 | **Uncommitted changes** | `git status` scoped to each implementer's owned files | All owned files committed | Message implementer to commit |
| 2 | **Build & tests** | Assign teammate: "Run build + test commands, report PASS/FAIL" | Exit 0, all tests pass | Create fix task |
| 3 | **Lint/format** ★ | Assign teammate: "Run lint, report new warnings/errors" | No new lint errors | Create fix task |
| 4 | **Integration** | Assign teammate: "Verify cross-module connections" | Cross-teammate outputs connect | Create integration fix task |
| 5 | **Security scan** ★ | Assign teammate: "Check for secrets, OWASP top 10 in changed files" | No new security issues | Create fix task (critical) |
| 6 | **Workspace issues** | Read `issues.md` | 0 OPEN issues | Route to teammate |
| 7 | **Plan completion** | Compare Phase 2 plan vs TaskList | Every stream has completed tasks | Create missing tasks |
| 8 | **Documentation sync** | Assign teammate: "Check if README/docs need updates" | No stale docs | Create doc update task |

Log gate result in `progress.md` Decision Log.

### Generate Report

Write `.agent-team/{team-name}/report.md` using the **standard report** template from [report-format.md](../../docs/report-format.md). Copy References from `progress.md`.

**Self-check**: read the file back — does it contain the Executive Summary? If not, regenerate.

Then continue with shared Phase 5 steps 4-7 (remediation gate, report to user, shutdown, cleanup).
```

**Step 2: Verify frontmatter**

Run: `head -10 skills/agent-implement/SKILL.md`
Expected: Valid YAML frontmatter with name, description, argument-hint, allowed-tools.

**Step 3: Commit**

```bash
git add skills/agent-implement/SKILL.md
git commit -m "feat: add agent-implement skill for implementation archetype"
```

---

### Task 3: Create `skills/agent-research/SKILL.md` — Research archetype

**Files:**
- Create: `skills/agent-research/SKILL.md`

**Step 1: Write the research skill**

```markdown
---
name: agent-research
description: >
  Orchestrates parallel research via Agent Teams. Triggers when a task involves
  investigating, analyzing, or comparing approaches with 2+ independent research angles.
  Triggers: "research in parallel", "investigate with a team", "analyze with teammates",
  "compare approaches in parallel", "explore with a team".
argument-hint: "[research question or investigation topic]"
allowed-tools: TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, AskUserQuestion, Read, Write, Edit, Glob, Grep, Bash
---

# Research Team Orchestrator

Read [shared-phases.md](../../docs/shared-phases.md) for your identity, prerequisites, hooks, and shared phase logic (Phases 1, 2, 4, and shared steps of 3 and 5).

## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1, then:
- **Decompose by research question/hypothesis**, not by module
- **Default roles**: 2-3 Researchers (different angles) + optional Analyst or Challenger
- Detect archetype as `research` — show `Team type: research (auto-detected)` in Phase 2

## Phase 3 Override: Workspace Setup

Apply shared Phase 3 steps 1-7, with these differences:
- **SKIP file-locks.json** — all teammates are read-only, no file ownership to enforce
- **SKIP branch instructions** — no code branches needed
- File ownership hook (PreToolUse) is N/A for this archetype

## Phase 5 Override: Completion

Apply shared Phase 5 steps 1-3, then:

- **SKIP pre-shutdown commit** — no files to commit (read-only team)
- **SKIP branch merge** — no branches created

### Completion Gate (2 checks only)

| # | Check | How | PASS Criteria | On FAIL |
|---|-------|-----|---------------|---------|
| 6 | **Workspace issues** | Read `issues.md` | 0 OPEN issues | Route to teammate |
| 7 | **Plan completion** | Compare Phase 2 plan vs TaskList | Every research angle has completed tasks | Create missing tasks |

Checks #1-#5 and #8 are N/A for research teams (no code changes).

Log gate result in `progress.md` Decision Log.

### Generate Report

Write `.agent-team/{team-name}/report.md` using the **findings report** variant from [report-format.md](../../docs/report-format.md#findings-report). Replace "Files Changed" with "What Was Discovered". Use "Findings" instead of "Files modified" in Per-Teammate Summaries.

**Self-check**: read the file back — does it contain the Executive Summary? If not, regenerate.

Then continue with shared Phase 5 steps 4-7 (remediation gate, report to user, shutdown, cleanup).
```

**Step 2: Verify frontmatter**

Run: `head -10 skills/agent-research/SKILL.md`
Expected: Valid YAML frontmatter.

**Step 3: Commit**

```bash
git add skills/agent-research/SKILL.md
git commit -m "feat: add agent-research skill for research archetype"
```

---

### Task 4: Create `skills/agent-audit/SKILL.md` — Audit archetype

**Files:**
- Create: `skills/agent-audit/SKILL.md`

**Step 1: Write the audit skill**

```markdown
---
name: agent-audit
description: >
  Orchestrates parallel audits via Agent Teams. Triggers when a task involves
  reviewing, assessing, or evaluating code against standards with 2+ independent audit lenses.
  Triggers: "audit in parallel", "review with a team", "assess with teammates",
  "security review with a team", "code review in parallel", "check compliance".
argument-hint: "[audit scope and standards]"
allowed-tools: TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, AskUserQuestion, Read, Write, Edit, Glob, Grep, Bash
---

# Audit Team Orchestrator

Read [shared-phases.md](../../docs/shared-phases.md) for your identity, prerequisites, hooks, and shared phase logic (Phases 1, 2, 4, and shared steps of 3 and 5).

## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1, then:
- **Decompose by audit lens/checklist area** (security, performance, compliance, style)
- **Default roles**: 2-3 Reviewers or Auditors (different lenses) + optional Challenger
- Detect archetype as `audit` — show `Team type: audit (auto-detected)` in Phase 2

## Phase 3 Override: Workspace Setup

Apply shared Phase 3 steps 1-7, with these differences:
- **SKIP file-locks.json** — all teammates are read-only
- **SKIP branch instructions** — no code branches needed
- File ownership hook (PreToolUse) is N/A for this archetype

## Phase 5 Override: Completion

Apply shared Phase 5 steps 1-3, then:

- **SKIP pre-shutdown commit** — no files to commit
- **SKIP branch merge** — no branches created

### Completion Gate (4 checks)

| # | Check | How | PASS Criteria | On FAIL |
|---|-------|-----|---------------|---------|
| 4 | **Integration** | Verify audit covered cross-module concerns | Audit comprehensiveness confirmed | Assign follow-up audit task |
| 5 | **Security** | Verify audit covered security aspects | Security coverage confirmed | Assign security audit task |
| 6 | **Workspace issues** | Read `issues.md` | 0 OPEN issues | Route to teammate |
| 7 | **Plan completion** | Compare Phase 2 plan vs TaskList | Every audit lens has completed tasks | Create missing tasks |

Checks #1-#3 and #8 are N/A for audit teams (no code changes). Note: #4 and #5 assess audit coverage, not code correctness.

Log gate result in `progress.md` Decision Log.

### Generate Report

Write `.agent-team/{team-name}/report.md` using the **audit report** variant from [report-format.md](../../docs/report-format.md#audit-report). Replace "Files Changed" with "What Was Audited". Use "Audit findings" and "Items checked" in Per-Teammate Summaries.

**Self-check**: read the file back — does it contain the Executive Summary? If not, regenerate.

Then continue with shared Phase 5 steps 4-7 (remediation gate, report to user, shutdown, cleanup).
```

**Step 2: Commit**

```bash
git add skills/agent-audit/SKILL.md
git commit -m "feat: add agent-audit skill for audit archetype"
```

---

### Task 5: Create `skills/agent-plan/SKILL.md` — Planning archetype

**Files:**
- Create: `skills/agent-plan/SKILL.md`

**Step 1: Write the planning skill**

```markdown
---
name: agent-plan
description: >
  Orchestrates parallel planning via Agent Teams. Triggers when a task involves
  designing, architecting, or producing specs with 2+ independent planning concerns.
  Triggers: "plan in parallel", "design with a team", "architect with teammates",
  "produce specs in parallel", "strategy with a team".
argument-hint: "[planning scope or design question]"
allowed-tools: TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, AskUserQuestion, Read, Write, Edit, Glob, Grep, Bash
---

# Planning Team Orchestrator

Read [shared-phases.md](../../docs/shared-phases.md) for your identity, prerequisites, hooks, and shared phase logic (Phases 1, 2, 4, and shared steps of 3 and 5).

## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1, then:
- **Decompose by planning concern** (architecture, data model, API design, etc.)
- **Default roles**: 1-2 Planners or Strategists + Researcher + optional Challenger
- Detect archetype as `planning` — show `Team type: planning (auto-detected)` in Phase 2

## Phase 3 Override: Workspace Setup

Apply shared Phase 3 steps 1-7, with these differences:
- **SKIP file-locks.json** — Planners write docs to workspace, not project files
- **SKIP branch instructions** — no code branches
- If multiple Planners, assign distinct workspace sub-paths (e.g., `{workspace}/planner-1/`) to avoid write conflicts
- File ownership hook (PreToolUse) is N/A for this archetype

## Phase 5 Override: Completion

Apply shared Phase 5 steps 1-3, then:

- **SKIP pre-shutdown commit** — planners write to workspace, not project files
- **SKIP branch merge** — no branches created

### Completion Gate (2 checks only)

| # | Check | How | PASS Criteria | On FAIL |
|---|-------|-----|---------------|---------|
| 6 | **Workspace issues** | Read `issues.md` | 0 OPEN issues | Route to teammate |
| 7 | **Plan completion** | Compare Phase 2 plan vs TaskList | Every planning concern has completed tasks | Create missing tasks |

Checks #1-#5 and #8 are N/A for planning teams.

Log gate result in `progress.md` Decision Log.

### Generate Report

Write `.agent-team/{team-name}/report.md` using the **plan report** variant from [report-format.md](../../docs/report-format.md#plan-report). Replace "Files Changed" with "What Was Planned". Use "Design contributions" and "Decisions proposed" in Per-Teammate Summaries.

**Self-check**: read the file back — does it contain the Executive Summary? If not, regenerate.

Then continue with shared Phase 5 steps 4-7 (remediation gate, report to user, shutdown, cleanup).
```

**Step 2: Commit**

```bash
git add skills/agent-plan/SKILL.md
git commit -m "feat: add agent-plan skill for planning archetype"
```

---

### Task 6: Rewrite `skills/agent-team/SKILL.md` — Hybrid catch-all

**Files:**
- Modify: `skills/agent-team/SKILL.md` (full rewrite)

**Step 1: Rewrite SKILL.md as the Hybrid/catch-all skill**

The new SKILL.md should:
- Keep the existing `name: agent-team` and existing trigger phrases
- Add archetype auto-detection that recommends the specific skill when a clear match exists
- Handle Hybrid archetype (mixed work types) natively
- Reference `shared-phases.md` for shared logic
- Contain Hybrid-specific Phase 3/5 overrides (conditional file-locks, strictest gate rule)

```markdown
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

Read [shared-phases.md](../../docs/shared-phases.md) for your identity, prerequisites, hooks, and shared phase logic (Phases 1, 2, 4, and shared steps of 3 and 5).

## Archetype Detection

Before proceeding with Phase 1, determine the team archetype from the user's task. Match against trigger patterns from [team-archetypes.md](../../docs/team-archetypes.md):

| Archetype | Trigger Patterns | Dedicated Skill |
|-----------|-----------------|-----------------|
| Implementation | "implement", "build", "create", "refactor", "fix", "migrate" | `/agent-implement` |
| Research | "research", "investigate", "explore", "analyze", "compare" | `/agent-research` |
| Audit | "audit", "review", "assess", "evaluate", "check compliance" | `/agent-audit` |
| Planning | "plan", "design", "architect", "spec", "propose", "strategy" | `/agent-plan` |
| Hybrid | Task combines 2+ of the above | This skill (`/agent-team`) |

**If a single archetype matches clearly**: Inform the user that a dedicated skill exists and proceed using that archetype's logic. Example: "This is an implementation task — I'll use the implementation team workflow."

**If the task combines types** (e.g., "research X then implement Y"): This is a Hybrid — proceed below.

**If no clear match**: Default to Implementation workflow.

## Phase 1 Override: Hybrid Decomposition

Apply shared Phase 1, then:
- **Identify which parts map to which archetype** (e.g., research streams vs implementation streams)
- **Compose roles from the full catalog** based on combined task types
- Show `Team type: hybrid ([component types])` in Phase 2 (e.g., `hybrid (research + implementation)`)

## Phase 3 Override: Hybrid Workspace Setup

Apply shared Phase 3 steps 1-7, plus:

### file-locks.json (conditional)

Create **only if ANY teammate writes project files** (implementers, writers with file ownership). Skip if all teammates are read-only.

See [workspace-templates.md](../../docs/workspace-templates.md#file-locksjson) for format.

### events.log

Initially empty. Append-only JSON event log.

### Branch Instructions (implementers only)

Include branch instruction in each **implementer's** spawn prompt only:
- "Create branch `{team-name}/{your-name}` before starting work. If git is unavailable, skip."

### Worktree Isolation (optional, implementers only)

If chosen in Phase 2, apply only to implementers. See implementation archetype for details.

## Phase 5 Override: Hybrid Completion

Apply shared Phase 5 steps 1-3, then:

### Pre-Shutdown Commit (conditional)

Only if implementers or writers with file ownership exist. Message each to commit their owned files. See implementation archetype for the commit protocol.

### Merge Branches (conditional)

Only if branching or worktrees were used. See implementation archetype for merge protocol.

### Completion Gate — Strictest Gate Rule

Include any check required by ANY component archetype present in the team:

| # | Check | Required if... |
|---|-------|---------------|
| 1 | **Uncommitted changes** | Any Implementer present |
| 2 | **Build & tests** | Any Implementer present |
| 3 | **Lint/format** ★ | Any Implementer present |
| 4 | **Integration** | Any Implementer present OR Audit component |
| 5 | **Security scan** ★ | Any Implementer present OR Audit component |
| 6 | **Workspace issues** | Always |
| 7 | **Plan completion** | Always |
| 8 | **Documentation sync** | Any Implementer present |

★ = Project-specific. PASS automatically if no tooling configured.

> **Lead judgment**: When the implementation component is minor (e.g., a single config change), mark checks as N/A with a brief note in `progress.md`.

Log gate result in `progress.md` Decision Log.

### Generate Report

Write `.agent-team/{team-name}/report.md` using the **standard report** template from [report-format.md](../../docs/report-format.md). If the Hybrid has no Implementation component, omit "Files Changed" and substitute the appropriate variant section (e.g., "What Was Discovered" or "What Was Audited").

**Self-check**: read the file back — does it contain the Executive Summary? If not, regenerate.

Then continue with shared Phase 5 steps 4-7 (remediation gate, report to user, shutdown, cleanup).
```

**Step 2: Verify line count reduction**

Run: `wc -l skills/agent-team/SKILL.md`
Expected: ~120-140 lines (down from 443)

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "refactor: slim agent-team SKILL.md to hybrid catch-all, reference shared-phases.md"
```

---

### Task 7: Update `docs/team-archetypes.md` — simplify

**Files:**
- Modify: `docs/team-archetypes.md`

**Step 1: Simplify the archetypes doc**

Now that each archetype has its own skill, `team-archetypes.md` no longer needs to carry the full phase profile overrides. It becomes a detection reference only.

Remove the detailed phase profile tables from each archetype section (Implementation, Research, Audit, Planning, Hybrid). Keep:
- Archetype Detection table (trigger patterns)
- Purpose and default roles for each archetype
- Strictest Gate Rule table (used by Hybrid)
- Design Notes
- Add a "See Also" linking to each archetype skill

Remove:
- Phase profile tables (moved into each skill)
- Completion gate details per archetype (moved into each skill)
- Report variant references per archetype (moved into each skill)

**Step 2: Commit**

```bash
git add docs/team-archetypes.md
git commit -m "refactor: simplify team-archetypes.md, phase profiles moved to archetype skills"
```

---

### Task 8: Update tests — doc reference validation for new skills

**Files:**
- Modify: `tests/structure/test-doc-references.sh`

**Step 1: Extend doc reference tests to cover all skills**

The current test only checks `skills/agent-team/SKILL.md`. Update to check all `skills/*/SKILL.md`:

Replace the hardcoded `SKILL_MD="skills/agent-team/SKILL.md"` with a loop over all skills. For each skill:
- Test: has `name` field in frontmatter
- Test: `allowed-tools` is comma-separated (no brackets)
- Test: all relative doc refs resolve

Add a test verifying `docs/shared-phases.md` exists and all its relative refs resolve.

**Step 2: Run the test suite**

Run: `bash tests/run-tests.sh`
Expected: All tests pass including the new multi-skill checks.

**Step 3: Commit**

```bash
git add tests/structure/test-doc-references.sh
git commit -m "test: extend doc reference tests to cover all archetype skills"
```

---

### Task 9: Update `README.md` — document new skills

**Files:**
- Modify: `README.md`

**Step 1: Update the Usage section**

Add a section showing the archetype-specific commands:

```markdown
### Archetype-Specific Commands

| Command | When to Use | Example |
|---------|------------|---------|
| `/agent-implement` | Build, refactor, fix, migrate code | "implement the new auth module in parallel" |
| `/agent-research` | Investigate, analyze, compare | "research database options with a team" |
| `/agent-audit` | Review, assess, evaluate | "audit security with parallel reviewers" |
| `/agent-plan` | Design, architect, produce specs | "design the API with a planning team" |
| `/agent-team` | Mixed work types or unsure | "research then implement the caching layer" |
```

**Step 2: Update the Plugin Structure section**

Add the new skill directories to the tree:

```
skills/
├── agent-team/SKILL.md           # Hybrid/catch-all orchestrator
├── agent-implement/SKILL.md      # Implementation teams
├── agent-research/SKILL.md       # Research teams
├── agent-audit/SKILL.md          # Audit teams
└── agent-plan/SKILL.md           # Planning teams
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document archetype-specific skills in README"
```

---

### Task 10: Update `CLAUDE.md` — reflect new structure

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update File Ownership table**

Add rows for the new skills and `docs/shared-phases.md`:

| Area | Purpose | Edit Guidelines |
|------|---------|----------------|
| `skills/agent-team/SKILL.md` | Hybrid/catch-all skill | Archetype detection + hybrid-specific overrides |
| `skills/agent-implement/SKILL.md` | Implementation skill | Implementation-specific Phase 3/5 |
| `skills/agent-research/SKILL.md` | Research skill | Research-specific Phase 3/5 |
| `skills/agent-audit/SKILL.md` | Audit skill | Audit-specific Phase 3/5 |
| `skills/agent-plan/SKILL.md` | Planning skill | Planning-specific Phase 3/5 |
| `docs/shared-phases.md` | Shared phase logic | Changes here affect ALL archetype skills |

**Step 2: Update "Common Tasks" section**

Add a note about adding new archetypes:
- Create a new `skills/agent-{name}/SKILL.md`
- Add the archetype to the detection table in `skills/agent-team/SKILL.md`
- Add trigger patterns to `docs/team-archetypes.md`
- Update tests, README, CLAUDE.md

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for archetype skill split"
```

---

### Task 11: Final validation

**Step 1: Run full test suite**

Run: `bash tests/run-tests.sh`
Expected: All tests pass.

**Step 2: Verify all doc cross-references resolve**

Run: `for skill in skills/*/SKILL.md; do echo "=== $skill ==="; grep -oE '\]\([^)]*\.md[^)]*\)' "$skill" | sed 's/\](//;s/)$//' | while read ref; do dir=$(dirname "$skill"); resolved="$dir/$ref"; [ -f "$resolved" ] && echo "  OK: $ref" || echo "  MISSING: $ref -> $resolved"; done; done`
Expected: All refs show OK.

**Step 3: Verify line counts**

Run: `wc -l skills/*/SKILL.md docs/shared-phases.md`
Expected: Each archetype skill ~60-100 lines, agent-team ~120 lines, shared-phases ~200 lines.

**Step 4: Commit any fixes, then final commit if needed**

---

Plan complete and saved to `docs/plans/2026-03-09-split-skills-by-archetype.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?