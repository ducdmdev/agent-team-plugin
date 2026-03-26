---
name: plan
description: >
  Agent Team planning stage. Analyzes task, loads prior lessons, decomposes into
  parallel work streams, applies plan-mode gate, presents plan for user approval.
  Use independently to plan without executing.
  Triggers: "plan in parallel", "design with a team", "architect with teammates".
argument-hint: "[task description]"
allowed-tools: Read, Glob, Grep, Bash, Agent, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, TeamCreate, TeamDelete, SendMessage
---

# Plan Stage

## Overview

This skill owns Phase 1 (analyze and decompose) and Phase 2 (present plan and user approval) of the Agent Team pipeline. It analyzes the user's task, loads lessons from prior teams, scans for or creates a plan, decomposes it into parallel work streams, applies the plan-mode gate, and presents the full plan for user approval. The plan stage can be invoked independently (to plan without executing) or as part of the full `agent-team:start` pipeline.

When invoked independently, the plan stage detects the archetype itself and writes it to `progress.md`. When invoked via `agent-team:start`, the archetype is passed from the start stage.

## Team Management

The plan stage creates and manages its own planning team.

### Workspace Creation

The plan stage creates the workspace directory at the start (before Phase 1):
1. Generate team name: `MMDD-{task-slug}` (e.g., `0323-refactor-auth`)
2. Create `.agent-team/{team-name}/`
3. Initialize `progress.md` with `**Stage**: plan`, `**Archetype**: {detected type}`, and Learned Context (from prior-context loading)
4. Initialize empty `tasks.md`, `issues.md`, and `task-graph.json`
5. Add `.agent-team/` to `.gitignore` if not already excluded

> **All 4 workspace tracking files must be created**: `progress.md`, `tasks.md`, `issues.md`, `task-graph.json`. The TaskCompleted hook requires `issues.md` to exist. Omitting it will block teammates from updating task status.

### Team Creation

After workspace initialization:
1. `TeamCreate` with the team name
2. Spawn teammates:
   - 1-2 Researchers (always) — scan codebase, report findings via FINDING messages
   - 1 Analyst (complex tasks only) — evaluate complexity via ANALYSIS message
   - 1 Plan Reviewer (always) — validate plan structure via PLAN_REVIEW message
3. Researchers and Analyst work in parallel during Phase 1a/1b
4. Plan Reviewer runs after lead completes decomposition (inter-stage review)

### Team Shutdown

After plan-reviewer completes (and any fix cycles):
1. Send parallel shutdown requests to all teammates
2. `TeamDelete`
3. Lead presents plan to user for approval (team no longer needed)
4. Write `**Pipeline status**: approved` to `progress.md` after user approves

## Phase 1: Analyze

Analyze the user's task: $ARGUMENTS

### Pre-step: Load Prior Context

Before scanning for plans, load lessons and error patterns from prior teams to inform better planning. Follow the algorithm in [prior-context-loading.md](references/prior-context-loading.md).

The resulting `## Learned Context` block (if any) is:
- Held in memory during the plan stage
- Surfaced in the Phase 2 plan presentation for user visibility
- Written to `progress.md` during plan stage workspace creation (Team Management section above)

If no prior lessons or patterns exist, skip silently.

> **Team context**: Researchers scan the codebase in parallel during Phase 1a. Their FINDING messages inform the lead's plan detection and decomposition. The Analyst evaluates complexity after researchers report.

### Early Exit -- Trivial Tasks

Before entering Phase 1a, apply a quick complexity check:
- If the task obviously targets a single file with no dependencies (e.g., "fix the typo in README.md"), skip plan detection entirely and proceed to the "team not warranted" determination in Phase 1b step 4
- Signals: task mentions one file, uses words like "typo", "rename", "bump version", no cross-module impact
- When in doubt, proceed to Phase 1a -- false negatives (skipping a plan for a complex task) are worse than false positives (scanning for a simple task)

### Budget Constraints

Phase 1a should remain lightweight relative to the overall team workflow:
- **Plan scan**: Limit to scanning directory listings + reading first 20 lines of each candidate (title, status, summary). Full file reads only for the top 3 ranked candidates.
- **Plan creation**: The writing-plans skill manages its own budget. The context bundle from Step 2a should be concise -- key file paths and summaries, not full file contents.
- **Audit**: 7 checks against one plan file. The Team Lead reads the plan once and evaluates all checks in a single pass.
- **Max candidates scanned**: If a directory contains more than 20 `.md` files, rank by filename date prefix (most recent first) and keyword overlap, then read only the top 5.

### Phase 1a: Plan Detection & Preparation

#### Step 0 -- Archetype Context

For **dedicated stage invocation** (`/agent-team:plan`), the archetype is detected from the task description using the trigger patterns in [team-archetypes.md](../../docs/team-archetypes.md). Write the detected archetype to the workspace when it is created (plan stage writes `**Archetype**` during workspace creation).

For **pipeline invocation** via `/agent-team:start`, the archetype is passed from the start stage. This archetype context is available throughout Phase 1a and informs plan creation if needed.

#### Step 1 -- Scan for Existing Plans

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
- If multiple candidates found, present top 3 to user: "I found these plans -- which one applies, or should I create a new one?"
- If exactly one strong match, propose it: "I found `docs/plans/X.md` -- shall I use this?"
- If zero matches, proceed to plan creation (Step 2)
- Skip files with `Status: COMPLETED` or `Status: ABANDONED` in frontmatter/header
- In monorepo structures (detected by multiple `package.json`, workspace configs, etc.), scope the scan to the subdirectory relevant to the user's task

**Minimum plan structure for usability:**
A plan file must contain at minimum: (a) identifiable task descriptions (numbered or headed sections), and (b) enough specificity to map tasks to files or modules. If a found plan is unstructured prose (e.g., a high-level strategy doc), it can inform context but cannot be used as the decomposition source -- treat it as "zero matches" and proceed to plan creation, passing the prose document as a reference.

#### Step 2 -- Create Plan (No Plan Found)

**2a. Gather context and references:**
- Codebase scan: Identify relevant files, modules, and architecture related to the user's task (using Glob, Grep, Read)
- Reference discovery: Find specs, ADRs, design docs, PRs, existing tests, CLAUDE.md conventions
- Dependency mapping: Identify which files/modules are touched, what imports what, integration boundaries
- Conventions check: Read CLAUDE.md, check for existing patterns in the codebase

**2b. Invoke `superpowers:writing-plans` with context:**

Pass a context bundle to the writing-plans skill:

```
Task: {user's original task description}
Archetype: {known archetype if dedicated skill, or "to be determined" for /agent-team:start}
Context:
- Relevant files: {list of files/modules identified}
- References: {specs, ADRs, design docs found}
- Dependencies: {what touches what}
- Conventions: {from CLAUDE.md and codebase patterns}
- Constraints: {anything discovered that limits the solution}
```

The writing-plans skill produces a plan file at `docs/plans/YYYY-MM-DD-{task-slug}-plan.md`.

**2c. Proceed to audit (Step 3).**

**Fallback -- writing-plans skill unavailable:**
If `superpowers:writing-plans` is not installed or fails to invoke, the Team Lead falls back to inline plan creation:
- Use the gathered context from Step 2a to produce a plan document directly
- Follow the same output format (numbered tasks with file references, completion criteria, dependencies)
- Save to `docs/plans/YYYY-MM-DD-{task-slug}-plan.md`
- Note for execute stage: "Plan created inline (writing-plans skill unavailable)" -- this will be logged in `progress.md` Decision Log when the workspace is created
- Proceed to audit as normal

This ensures the plugin degrades gracefully, consistent with how hooks handle missing `jq`.

#### Step 3 -- Audit Plan (Common Gate)

Both paths converge here. Every plan is audited before the user sees it.

| # | Check | What it validates | Severity |
|---|-------|-------------------|----------|
| 1 | Task completeness | Every task has clear completion criteria, file references, and step-by-step instructions | High |
| 2 | Dependency coherence | No circular dependencies between tasks. Blocked-by chains resolve. | High |
| 3 | File reference validity | Files mentioned in the plan actually exist in the codebase (or are explicitly marked as "to be created") | Medium |
| 4 | Scope coverage | Plan tasks collectively cover the user's original request -- nothing major missing | High |
| 5 | Reference freshness | Referenced specs/ADRs/docs still exist and haven't been superseded | Low |
| 6 | Feasibility | Tasks are achievable -- no references to unavailable tools, APIs, or dependencies | Medium |
| 7 | Parallelizability | At least 2 tasks can run concurrently (otherwise a team isn't warranted) | High |

**Note on check #7 vs Phase 1b "team warranted" gate:** Check #7 is an early signal during audit -- if it fails, the audit status reflects it and the user is warned. If the user chooses "proceed as-is" despite a failed check #7, Phase 1b step 4 performs the definitive evaluation after full decomposition. The audit flags the risk; Phase 1b makes the final call.

**Audit output:**
- **Status**: `ready` (0 high issues), `needs-revision` (1+ high issues), `insufficient` (plan is too vague to decompose)
- **Issues list**: Each issue with severity, description, and suggested fix
- **Parallelism assessment**: How many independent streams the plan supports

The Team Lead performs the audit inline -- reading the plan file, cross-referencing codebase state, and evaluating each check. No separate skill invocation needed.

**MANDATORY: Record audit results in progress.md.** Before proceeding to Step 4 or Phase 1b, you MUST fill in this table in the workspace `progress.md`:

```markdown
## Plan Audit Result
| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1 | Task completeness | {PASS/FAIL} | {notes} |
| 2 | Dependency coherence | {PASS/FAIL} | {notes} |
| 3 | File reference validity | {PASS/FAIL} | {notes} |
| 4 | Scope coverage | {PASS/FAIL} | {notes} |
| 5 | Reference freshness | {PASS/FAIL} | {notes} |
| 6 | Feasibility | {PASS/FAIL} | {notes} |
| 7 | Parallelizability | {PASS/FAIL} | {notes} |
```

**DO NOT present the plan to the user (Phase 2) until all 7 rows are filled.** This is a hard gate — incomplete audits produce incomplete plans.

#### Step 4 -- User Decision Gate

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
1. Proceed as-is -- use this plan for team decomposition
2. Update -- fix the issues above and re-audit
3. Create new -- discard this plan, start fresh with writing-plans

Which option?
```

**Behavior per option:**

| Option | What happens |
|--------|-------------|
| Proceed as-is | Move to Phase 1b with the plan unchanged. Team Lead works around known issues during decomposition. |
| Update | Team Lead fixes the identified issues in the plan file, re-runs audit, presents again. Max 2 update cycles -- if still `insufficient` after 2 rounds, ask user whether to proceed anyway or create new. |
| Create new | Set aside the current plan. Re-enter the creation path (Step 2) from scratch. Only offered once -- if the second plan also fails audit, compare both and proceed with the plan that has fewer High-severity issues. |

**Guard rail:** For `insufficient` status, option 1 (proceed as-is) is presented but with a warning: "This plan may not have enough detail to decompose into parallel work. Proceeding may result in a weaker team structure."

### Brainstorm & Clarify Gate (Conditional)

Before decomposing, check if any of these triggers apply:

1. Analyst flagged `parallelizable=no` or `complexity=high`
2. Any researcher FINDING has `relevance=high` with risk implications
3. Plan audit status is `needs-revision` or `insufficient`
4. You see 2+ valid decomposition strategies (by module vs by concern vs by layer)
5. You have ANY concern or uncertainty about the approach

**If no triggers fire**: Skip this step — proceed directly to Phase 1b.

**If any trigger fires**: Present a Brainstorm & Clarify block to the user:

```
## Brainstorm & Clarify

Before I decompose this task, I want to discuss {N} points:

### Point 1: {title}
**Context**: {what was found, what's uncertain, why it matters}
**Options**:
  A) {approach} — {tradeoffs}
  B) {approach} — {tradeoffs}
  C) {approach} — {tradeoffs}
**My recommendation**: {which option and why}

### Point 2: ...

What are your thoughts?
```

**Wait for user response before proceeding.** User can:
- Pick options ("go with A for point 1, B for point 2")
- Provide direction ("focus on safety over speed")
- Ask for more info ("can the researcher check if X exists?")
- Defer ("your call on all points")

**If user asks for more info**: Send the researcher or analyst to investigate, then re-present the brainstorm with updated findings.

**Record in progress.md**: Log each brainstorm point and the user's decision in the Decision Log section.

**Key rule**: Do NOT decompose while uncertain. If there's a concern, present it. Even a short "I have one question before decomposing" counts. The gate is cheap (one message exchange) but prevents costly wrong decompositions.

---

### Phase 1b: Decompose from Plan

User has approved a plan (or no plan -- see fallback below). The decomposition steps now derive from the approved plan:

1. **Map plan tasks to parallel streams** -- Group plan tasks by independence. Tasks with no mutual dependencies form separate streams. Tasks that share file ownership or blocked-by relationships stay in the same stream.
2. **Assign file ownership from plan** -- Plan tasks reference specific files. Each stream's files become that teammate's owned files. No two teammates edit the same file. If the plan doesn't specify files, the Team Lead infers from task descriptions + codebase scan.
3. **Derive dependencies from plan** -- The plan's task ordering and blocked-by relationships translate directly to Agent Team task dependencies.
4. **Determine if a team is warranted** -- if fewer than 2 independent streams exist, tell the user a single session is more efficient. Offer: "This plan is sequential -- shall I execute it directly without a team?" Stop here if not warranted.
5. **Integration points** -- for each pair of streams, identify where plan tasks reference shared interfaces, contracts, or outputs. These become explicit handoff points in Phase 2.
6. **Mark convergence points** -- for each task that depends on 2+ upstream tasks, flag it as a convergence point. These become integration checkpoints during Phase 4 -- the `check-integration-point.sh` hook will nudge the lead to verify interface compatibility when all upstream tasks complete. Include convergence points in the Phase 2 presentation.
7. **Identify reference documents** -- already gathered during Phase 1a. Carry forward into workspace. If Phase 1a was skipped (trivial task early exit), find specs, ADRs, design docs, PRs, or other docs relevant to the task.
8. **Check for custom roles** -- if `docs/custom-roles.md` exists in the project, read it. Use custom roles alongside built-in roles when they match the task requirements.

**Fallback -- no plan available:** If Phase 1a was skipped (trivial task early exit) or the user declined all plans, the Team Lead performs ad-hoc decomposition using the strategies below:
- **By module/area**: frontend vs backend, auth vs payments (best for feature work)
- **By concern**: implementation vs verification vs research (best for quality-critical tasks)
- **By layer**: data model vs API vs UI (best for full-stack features)
- Avoid splits that create heavy cross-dependencies -- if two streams need constant handoffs, merge them

**Self-check**: "Do I have 2+ streams where each can make meaningful progress without waiting on the others? Are integration points identified?" If no, reconsider the split.

### Populate task-graph.json

After decomposition, write the task dependency graph to `.agent-team/{team-name}/task-graph.json`. Each task becomes a node:

```json
{
  "team": "{team-name}",
  "created": "{ISO timestamp}",
  "updated": "{ISO timestamp}",
  "nodes": {
    "#1": {
      "subject": "{task description}",
      "owner": "{teammate-name}",
      "status": "pending",
      "depends_on": [],
      "completed_at": null,
      "output_files": ["{expected files}"],
      "critical_path": false,
      "convergence_point": false
    }
  }
}
```

Include `depends_on` arrays reflecting the dependency graph from step 3. Mark `convergence_point: true` for tasks identified in step 6. This graph is read by hooks (`compute-critical-path.sh`, `check-integration-point.sh`, `detect-resume.sh`) during execution.

Also populate `tasks.md` with the task ledger matching the graph nodes.

## Phase 2: Present Plan

Before creating the team, you MUST present the decomposition and wait for explicit user approval. This is a hard gate -- no tasks, no teammates, no workspace until the user says "yes".

```
Team plan for: [task summary]
Based on: [plan file path] (existing | generated) -- omit if no plan
Team type: [detected-type] (auto-detected from task -- say "change to [type]" to override)
Complexity: standard | complex
  (if complex) Reason: [why -- e.g., multi-module, risky refactor, security-sensitive]
  (if complex) Dedicated reviewer included
  (if complex) Dedicated tester included

Teammates (N total):
Team size check: [default max 4 | up to 6 if extra are read-only]
- [role-name]: [what they do] -> owns [files/area]
- [role-name]: [what they do] -> owns [files/area]

Task breakdown:
1. [task] -> assigned to [role]
2. [task] -> assigned to [role]
3. [task] -> assigned to [role] (blocked by #1)

Critical path: [#X -> #Y -> #Z] (length: N)
  Non-critical (can slip without affecting total time): [#A, #B]
  Integration checkpoints: [#Y (converges #X + #A -- verify interface compatibility)]

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

**If prior context was loaded** (see Pre-step), append a Learned Context summary:
```
Learned context (from N prior teams):
- [team-name]: [lesson summary]
- Known patterns: [count] error patterns matched for files in scope
```

### Plan-Mode Gate

After presenting the plan, determine which teammates should use plan-mode. Plan-mode requires teammates to propose their approach before executing, preventing wasted work on the wrong approach.

**Archetype defaults** (from [team-archetypes.md](../../docs/team-archetypes.md)):

| Archetype | Plan-mode default | Rationale |
|-----------|-------------------|-----------|
| Implementation | ON for complexity >= standard | Prevents wasted coding effort on wrong approach |
| Research | OFF | Researchers explore freely; constraining defeats purpose |
| Audit | OFF | Auditors follow checklists; proposals add overhead |
| Planning | ON always | Planners should propose before drafting |
| Hybrid | Follows detected archetype rules | Mixed teams use the most relevant default |

The user can override during plan approval: "make all teammates plan-mode" or "skip plan-mode".

Mark plan-mode teammates in the plan presentation. The execute stage reads these marks and injects the plan-mode directive into spawn prompts. See [plan-mode-protocol.md](references/plan-mode-protocol.md) for the full protocol including message types and revision limits.

### Self-checks Before Proceeding

1. "Is this plan complex? Complexity signals: multi-module/area changes, architectural decisions, risky refactors, multiple implementers with cross-dependencies, security-sensitive changes, new integrations. If yes, does the teammate list include a **dedicated reviewer** AND a **dedicated tester** (separate teammates, not combined)? If no, add them before presenting."
2. "Have I presented this plan AND received user confirmation?" If no, STOP.
3. "Do any tasks form circular dependencies? Trace each `blocked by` chain -- if task A blocks B blocks C blocks A, that's a cycle. If found, restructure: merge the cyclic tasks or break the cycle by removing one dependency."
4. "Have I identified the critical path? Is it displayed in the plan? Are convergence points marked?"

Wait for user confirmation before proceeding. If invoked independently (not via `agent-team:start`), the plan stage stops here after user approval.

### Stage Complete — Next Steps

After user approves and the planning team is shut down, present:

```
✓ Plan approved. Workspace: .agent-team/{team-name}/

Next steps:
  → /agent-team:execute    Start the execution team
  → Review the plan at {plan-file-path}
  → Edit tasks in .agent-team/{team-name}/tasks.md before executing
```

When chained via `/agent-team:start`, the pipeline continues automatically to the execute stage. When invoked independently, this is the final output.

## Inter-Stage Review: Plan Review Agent

After decomposition (Phase 1b) and before presenting the plan to the user (Phase 2), run the plan review agent. This is a mandatory inter-stage gate.

Spawn a subagent using the prompt from [plan-reviewer.md](agents/plan-reviewer.md). The reviewer validates plan quality across 6 checks: completeness, dependency integrity, file ownership, scope sanity, missing coverage, and estimate plausibility.

**Processing the review output:**

| Review status | Action |
|---------------|--------|
| `approved` | Present plan to user (Phase 2) |
| `issues_found` (warnings only) | Present plan to user with warnings noted |
| `issues_found` (blocking issues) | Fix the blocking issues, re-run review. Max 2 fix cycles. |

After 2 failed fix cycles with blocking issues, present the plan to the user with caveats noted: "The plan review found unresolved issues: [list]. Proceeding with known limitations."

Log the review result in memory for inclusion in the Phase 2 presentation.

## References

### Local files
- [references/prior-context-loading.md](references/prior-context-loading.md) -- Algorithm for loading lessons from prior teams
- [references/plan-mode-protocol.md](references/plan-mode-protocol.md) -- Plan-mode activation, message types, revision limits
- [examples/plan-proposal-example.md](examples/plan-proposal-example.md) -- Sample PLAN_PROPOSAL exchange
- [agents/plan-reviewer.md](agents/plan-reviewer.md) -- Plan review agent prompt and checks

### Shared docs
- [../../docs/teammate-roles.md](../../docs/teammate-roles.md) -- Role definitions and selection guide
- [../../docs/team-archetypes.md](../../docs/team-archetypes.md) -- Archetype detection and plan-mode defaults
- [../../docs/workspace-templates.md](../../docs/workspace-templates.md) -- Workspace file templates and task-graph.json schema
- [../../docs/custom-roles.md](../../docs/custom-roles.md) -- Project-specific role definitions
