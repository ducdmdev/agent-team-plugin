# Workflow Orchestration Integration — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace 5 archetype-based skills with 4 pipeline-stage skills (`start`, `plan`, `execute`, `audit`) and integrate 4 workflow orchestration extensions: prior context loading, plan-mode gate, error recovery loop, and quality-and-learning post-step.

**Architecture:** Each pipeline stage owns a subset of the existing 5-phase logic. Stage-specific docs move into skill subfolders (`references/`, `examples/`, `agents/`). Shared docs stay in plugin-root `docs/`. Archetype becomes configuration written to `progress.md`, not a separate skill. Each stage has a mandatory review agent that validates output before handoff.

**Tech Stack:** Markdown documentation, bash test scripts, jq for JSON (existing). No new runtime dependencies.

**Spec:** `docs/specs/2026-03-23-workflow-orchestration-integration-design.md`

---

## Chunk 1: Foundation — Shared Docs Updates

Updates to `docs/` files that all stages depend on. Must complete before creating stage skills.

### Task 1: Update workspace-templates.md with new templates

**Files:**
- Modify: `docs/workspace-templates.md`

- [ ] **Step 1: Add `lessons.md` template section**

Add after the existing `task-graph.json` section. Follow the existing pattern (H2 header, fenced markdown template, field docs):

```markdown
## lessons.md

Created by the audit stage (`agent-team:audit`) during Phase 5 post-step. Captures team execution insights for future teams.

\`\`\`markdown
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
\`\`\`

**Fields:**
- **What Worked**: Patterns, tools, approaches that saved time or prevented issues
- **What Failed**: Problems encountered + root cause analysis (not just symptoms)
- **Estimation Accuracy**: Compare task-graph.json `created_at` vs `completed_at` timestamps
- **Integration Friction Points**: Where handoffs or convergence caused delays
- **Recommendations**: Concrete, actionable advice for future teams with similar scope
```

- [ ] **Step 2: Add `error-patterns.json` schema section**

Add after `lessons.md` section:

```markdown
## error-patterns.json (Global)

Stored at `~/.claude/agent-team-patterns.json`. Created at runtime by the audit stage if not present. Shared across all projects.

\`\`\`json
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
\`\`\`

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
```

- [ ] **Step 3: Add `fallback_approach` and `fallback_reason` to task-graph.json schema**

In the existing `task-graph.json` section, add these optional fields to the node schema docs:

```markdown
- **approach** (optional): Description of the planned implementation approach
- **fallback_approach** (optional): Alternative approach if primary fails
- **fallback_reason** (optional): When to activate the fallback (e.g., "Use if JWT library has compatibility issues")
```

- [ ] **Step 4: Add Plan Proposals section to progress.md template**

In the existing `progress.md` template section, add after the Decisions table:

```markdown
## Plan Proposals
| Teammate | Task | Proposal | Status | Revisions |
|----------|------|----------|--------|-----------|
```

- [ ] **Step 5: Add Recovery cycles field to progress.md template**

In the `progress.md` template, add after the existing `**Remediation cycle**` field:

```markdown
**Recovery cycles**: 0
```

- [ ] **Step 6: Add Recovery attempts to issues.md template**

In the `issues.md` template, extend the issue format with:

```markdown
- **Error type**: {retry|recoverable|design_flaw|unknown}
- **Recovery attempts**:
  1. {strategy} — {SUCCEEDED|FAILED}
- **Pattern captured**: {Yes (pattern-NNN)|No}
```

- [ ] **Step 7: Update Contents TOC**

Add links for new sections to the `## Contents` list at the top of the file.

- [ ] **Step 8: Commit**

```bash
git add docs/workspace-templates.md
git commit -m "docs: add lessons.md, error-patterns.json, and recovery tracking templates"
```

---

### Task 2: Update teammate-roles.md with Elegance Reviewer and recovery_class

**Files:**
- Modify: `docs/teammate-roles.md`

- [ ] **Step 1: Add `recovery_class` field to all existing roles**

For each of the 12 existing roles, add a bold field after the existing `**Tools**:` field. Follow the existing format:

| Role | recovery_class |
|------|---------------|
| Leader | N/A (coordinator) |
| Implementer | full |
| Reviewer | skip-and-continue |
| Researcher | report-gap |
| Challenger | report-gap |
| Tester | full |
| Analyst | skip-and-continue |
| Planner | recover-only |
| Writer | recover-only |
| Strategist | report-gap |
| Auditor | skip-and-continue |
| Scout | skip-and-continue |

Format per role section:
```markdown
**Recovery class**: full
```

- [ ] **Step 2: Add Elegance Reviewer role section**

Add as new H2 section after Scout (the last current role). Follow the existing role pattern:

```markdown
## Elegance Reviewer

**Purpose**: Post-execution quality assessment. Reviews code changes for simplicity, consistency, readability, testability, and minimal impact. Advisory only — findings inform the report but do not block completion.

**Tools**: Read, Grep, Glob, Bash (read-only — verification commands like `npm test`, `npm run lint`, `tsc --noEmit` only)

**Recovery class**: skip-and-continue

**Scope**: Only files touched by implementers (determined from `file-locks.json`). Does not review workspace files or unchanged code.

**Rubric** (scored 1-5 per dimension):

| Dimension | What it checks |
|-----------|----------------|
| **Simplicity** | Could this be simpler? Unnecessary abstractions? |
| **Consistency** | Follows existing codebase patterns and conventions? |
| **Readability** | Clear naming, logical structure, self-documenting? |
| **Testability** | Easy to test? Proper separation of concerns? |
| **Minimal impact** | Only touches what's necessary? No scope creep? |

**Lifecycle**: Spawned during audit stage Phase 5 post-step (after remediation gate, before report). Does NOT count toward the initial team size limit. Shut down with the rest of the team.

**Output**: Sends `ELEGANCE_REVIEW` message to lead (see communication protocol in `skills/execute/references/communication-protocol.md`).
```

- [ ] **Step 3: Update Role Selection Guide table**

Add Elegance Reviewer row to the selection guide table. Mark it as "Auto-spawned by audit stage" (not manually assigned).

- [ ] **Step 4: Update Contents TOC**

Add Elegance Reviewer link.

- [ ] **Step 5: Commit**

```bash
git add docs/teammate-roles.md
git commit -m "docs: add Elegance Reviewer role and recovery_class field to all roles"
```

---

### Task 3: Update team-archetypes.md with plan-mode defaults

**Files:**
- Modify: `docs/team-archetypes.md`

- [ ] **Step 1: Add plan-mode defaults table**

Add a new H2 section `## Plan-Mode Defaults` after the archetype detection section:

```markdown
## Plan-Mode Defaults

Each archetype has a default plan-mode setting. The user can override during Phase 2 approval.

| Archetype | Plan-mode default | Rationale |
|-----------|-------------------|-----------|
| Implementation | ON for complexity ≥ standard | Prevents wasted coding effort on wrong approach |
| Research | OFF | Researchers explore freely; constraining defeats purpose |
| Audit | OFF | Auditors follow checklists; proposals add overhead |
| Planning | ON always | Planners should propose before drafting |
| Hybrid | Follows detected archetype rules | Mixed teams use the most relevant default |
```

- [ ] **Step 2: Fix cross-references to migrated docs**

Search for references to `coordination-advanced.md` and update to `skills/execute/references/coordination-patterns.md`. Search for references to `communication-protocol.md` and update to `skills/execute/references/communication-protocol.md`.

- [ ] **Step 3: Update See Also section**

Replace old skill references:
- `/agent-implement` → `/agent-team:execute` (with note: "for implementation teams")
- `/agent-research` → `/agent-team:start` (with note: "specify research archetype")
- `/agent-audit` → `/agent-team:audit` (with note: "for re-running verification")
- `/agent-plan` → `/agent-team:plan` (with note: "for standalone planning")
- `/agent-team` → `/agent-team:start`

- [ ] **Step 4: Commit**

```bash
git add docs/team-archetypes.md
git commit -m "docs: add plan-mode defaults and update references for pipeline skills"
```

---

### Task 4: Update custom-roles.md reference

**Files:**
- Modify: `docs/custom-roles.md`

- [ ] **Step 1: Update skill reference**

Find `When invoking /agent-team` and replace with `When invoking /agent-team:start`.

- [ ] **Step 2: Commit**

```bash
git add docs/custom-roles.md
git commit -m "docs: update custom-roles.md skill reference to agent-team:start"
```

---

## Chunk 2: Plan Stage Skill

Create `skills/plan/` with SKILL.md and all supporting files. This stage owns Phase 1 (analyze + decompose) and Phase 2 (present plan + user approval).

### Task 5: Create plan stage directory structure

**Files:**
- Create: `skills/plan/SKILL.md`
- Create: `skills/plan/references/plan-mode-protocol.md`
- Create: `skills/plan/references/prior-context-loading.md`
- Create: `skills/plan/examples/plan-proposal-example.md`
- Create: `skills/plan/agents/plan-reviewer.md`

- [ ] **Step 1: Create directories**

```bash
mkdir -p skills/plan/references skills/plan/examples skills/plan/agents
```

- [ ] **Step 2: Create plan SKILL.md**

Read the current `skills/agent-team/SKILL.md` and `skills/agent-plan/SKILL.md` for Phase 1 and Phase 2 content. Read `docs/shared-phases.md` Phase 1 and Phase 2 sections.

Create `skills/plan/SKILL.md` with:

```yaml
---
name: plan
description: >
  Agent Team planning stage. Analyzes task, loads prior lessons, decomposes into
  parallel work streams, applies plan-mode gate, presents plan for user approval.
  Use independently to plan without executing.
  Triggers: "plan in parallel", "design with a team", "architect with teammates".
argument-hint: "[task description]"
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet
---
```

Body structure (H2 sections):
1. `## Overview` — one paragraph: this skill owns Phase 1+2
2. `## Phase 1: Analyze` — migrated from `shared-phases.md` Phase 1 content
   - Include Phase 1a (plan detection) and Phase 1b (decomposition)
   - Add **Pre-step: Load Prior Context** before Phase 1a — reference `references/prior-context-loading.md`
3. `## Phase 2: Present Plan` — migrated from `shared-phases.md` Phase 2 content
   - Include plan presentation format, user approval gate
   - Add **Plan-Mode Gate** after plan presentation — reference `references/plan-mode-protocol.md`
   - Include archetype defaults table (from `../../docs/team-archetypes.md`)
4. `## Inter-Stage Review: Plan Review Agent` — reference `agents/plan-reviewer.md`
   - Mandatory: runs after decomposition, before presenting to user
   - Max 2 fix cycles for blocking issues
5. `## References` — links to all local files + shared docs (`../../docs/teammate-roles.md`, `../../docs/team-archetypes.md`, `../../docs/workspace-templates.md`)

- [ ] **Step 3: Create prior-context-loading.md**

Create `skills/plan/references/prior-context-loading.md`:

```markdown
# Prior Context Loading

## Purpose

Load lessons and error patterns from prior teams to inform better planning.

## Algorithm

1. Scan `.agent-team/*/lessons.md` — find all completed teams' lessons files
2. Sort by date (newest first, using MMDD prefix in directory name)
3. Scan global `~/.claude/agent-team-patterns.json`
4. Relevance filter: match by keyword overlap with current task description
5. Select top 3 most relevant lessons

## Relevance Filtering

Match prior lessons by:
- File path overlap (tasks touching same files/directories)
- Keyword overlap (task description terms matching lesson content)
- Archetype match (same team type gets priority)

## Output

Collect a `## Learned Context` block in memory:

\`\`\`markdown
## Learned Context

**Prior lessons** (from {N} previous teams):
- [{team-name}]: {lesson summary}
- [{team-name}]: {lesson summary}

**Known error patterns** for files in scope:
- {pattern description}: try {strategy} (success rate: {N/M})

**Estimation adjustments**:
- {adjustment based on prior team data}
\`\`\`

This block is:
- Held in memory during the plan stage
- Written to `progress.md` after workspace creation (execute stage)
- Surfaced in the Phase 2 plan presentation for user visibility

## No-Op Conditions

If no prior lessons or patterns exist, skip silently. Do not add an empty Learned Context block.
```

- [ ] **Step 4: Create plan-mode-protocol.md**

Create `skills/plan/references/plan-mode-protocol.md`:

```markdown
# Plan-Mode Protocol

## Purpose

For non-trivial tasks, teammates propose their approach before executing.
The lead reviews and approves, preventing wasted work.

## Activation

Plan-mode activates per-teammate when task complexity ≥ standard (3+ steps
or architectural decisions). The lead marks plan-mode teammates in the Phase 2
plan presentation. User can override: "make all teammates plan-mode" or
"skip plan-mode".

## Ownership Boundary

- **Plan stage** (`agent-team:plan`): MARKS which teammates get plan-mode
- **Execute stage** (`agent-team:execute`): INJECTS the directive into spawn prompts
  and handles PLAN_PROPOSAL evaluation during Phase 4 coordination

## Spawn Directive

Injected by execute stage into plan-mode teammates' spawn prompts:

\`\`\`
PLAN-MODE ACTIVE: Before writing any code, send a PLAN_PROPOSAL message to the lead.
Do NOT write/edit files until you receive PLAN_APPROVED.
\`\`\`

## Message Types

### PLAN_PROPOSAL

\`\`\`
PLAN_PROPOSAL #N:
  approach={description of proposed approach}
  alternatives_considered={what else was evaluated and why rejected}
  files_to_touch={list}
  estimated_complexity={low|medium|high}
  risks={potential issues}
\`\`\`

### PLAN_APPROVED

\`\`\`
PLAN_APPROVED #N
\`\`\`

### PLAN_REVISION

\`\`\`
PLAN_REVISION #N: {feedback on what needs to change}
\`\`\`

## Revision Limits

Max 2 revision rounds per teammate. After 2 rounds, the lead decides
(accept current proposal or reassign the task).

## Workspace Tracking

Proposals logged in `progress.md`:

\`\`\`markdown
## Plan Proposals
| Teammate | Task | Proposal | Status | Revisions |
|----------|------|----------|--------|-----------|
| auth-impl-1 | #1 | Refactor via adapter pattern | Approved | 0 |
\`\`\`

## Relationship to Platform mode: "plan"

This plan-mode gate is an orchestration-level pattern (teammate proposes
overall approach via messages). It is DISTINCT from the Claude Code platform
`mode: "plan"` parameter (which gates individual tool use). Both can be
used together but serve different purposes.
```

- [ ] **Step 5: Create plan-proposal-example.md**

Create `skills/plan/examples/plan-proposal-example.md` with a sample exchange showing a PLAN_PROPOSAL → PLAN_REVISION → revised PLAN_PROPOSAL → PLAN_APPROVED flow.

- [ ] **Step 6: Create plan-reviewer.md**

Create `skills/plan/agents/plan-reviewer.md`:

```markdown
# Plan Review Agent

## Role

Validates plan quality before presenting to the user. Mandatory inter-stage gate.

## Tools

Read, Grep, Glob (read-only)

## Scope

Reads draft plan from workspace: `progress.md`, `tasks.md`, `task-graph.json`

## Checks

| Check | What it validates | Severity if failed |
|-------|-------------------|--------------------|
| Completeness | Every task has owner, description, dependencies | blocking |
| Dependency integrity | No circular deps, no orphaned tasks, convergence points identified | blocking |
| File ownership | No overlapping file assignments between teammates | blocking |
| Scope sanity | Task count vs team size reasonable | warning |
| Missing coverage | No test task, no review task, no integration verification | warning |
| Estimate plausibility | Flags tasks with no estimate or unrealistic estimates | warning |

## Output

\`\`\`
PLAN_REVIEW:
  status={approved|issues_found}
  issues=[{check, severity=blocking|warning, description, suggestion}]
\`\`\`

## Behavior

- `status=approved` → lead presents plan to user
- `status=issues_found` (warnings only) → present plan with warnings noted
- `status=issues_found` (blocking) → lead fixes plan, re-runs review (max 2 cycles)
- After 2 failed cycles → present plan with caveats noted to user
```

- [ ] **Step 7: Commit**

```bash
git add skills/plan/
git commit -m "feat: create plan stage skill with prior-context loading and plan-mode gate"
```

---

## Chunk 3: Execute Stage Skill

Create `skills/execute/` with SKILL.md and supporting files. Migrate existing docs. This stage owns Phase 3 (create workspace, spawn) and Phase 4 (coordinate, error recovery).

### Task 6: Create execute stage — SKILL.md and new files

**Files:**
- Create: `skills/execute/SKILL.md`
- Create: `skills/execute/references/error-recovery-protocol.md`
- Create: `skills/execute/agents/execute-reviewer.md`

- [ ] **Step 1: Create directories**

```bash
mkdir -p skills/execute/references skills/execute/agents
```

- [ ] **Step 2: Create execute SKILL.md**

Read the current `skills/agent-team/SKILL.md` Phase 3+4, `skills/agent-implement/SKILL.md` Phase 3, and `docs/shared-phases.md` Phase 3+4 sections.

Create `skills/execute/SKILL.md` with:

```yaml
---
name: execute
description: >
  Agent Team execution stage. Creates workspace, spawns teammates, coordinates
  parallel work, handles error recovery. Requires an approved plan (from plan stage
  or workspace). Triggers: "execute the plan", "spawn the team", "start execution".
argument-hint: "[workspace path or plan reference]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, TeamCreate, TeamDelete, SendMessage
---
```

Body structure (H2 sections):
1. `## Overview` — one paragraph: this skill owns Phase 3+4
2. `## Preconditions` — workspace with `progress.md` (containing `**Archetype**` and `**Status**: approved`), `tasks.md`, `task-graph.json` with pending tasks
3. `## Phase 3: Create Team` — migrated from `shared-phases.md` Phase 3
   - Workspace setup, teammate spawning, file-locks
   - Inject plan-mode directive for marked teammates (read from `progress.md`)
   - Reference `agents/spawn-templates.md` for spawn prompts
4. `## Phase 4: Coordinate` — migrated from `shared-phases.md` Phase 4
   - Message processing, handoffs, workspace updates
   - Reference `references/communication-protocol.md`
   - Reference `references/coordination-patterns.md`
   - Add **Error Recovery Loop** — reference `references/error-recovery-protocol.md`
5. `## Inter-Stage Review: Execute Review Agent` — reference `agents/execute-reviewer.md`
6. `## References` — links to all local files + shared docs

- [ ] **Step 3: Create error-recovery-protocol.md**

Create `skills/execute/references/error-recovery-protocol.md` with the full content from the spec Section 3: error_type classification guide, recovery decision tree, fallback approaches, recovery tracking format, role-based recovery behavior table, bounds and safety rules.

- [ ] **Step 4: Create execute-reviewer.md**

Create `skills/execute/agents/execute-reviewer.md`:

```markdown
# Execute Review Agent

## Role

Smoke test after all tasks complete, before handoff to audit. Mandatory inter-stage gate.

## Tools

Read, Grep, Glob, Bash (read-only — `git status`, `git diff`, test runners)

## Scope

Workspace files + all files owned by teammates (from `file-locks.json`)

## Checks

| Check | What it validates | Severity if failed |
|-------|-------------------|--------------------|
| Files exist | All files in `file-locks.json` exist on disk | blocking |
| No uncommitted changes | `git status` clean for owned files | blocking |
| Build passes | `npm run build` / `tsc` / equivalent exits 0 | blocking |
| Tests pass | `npm test` / equivalent exits 0 | blocking |
| No merge conflicts | No `<<<<<<<` markers in owned files | blocking |
| Handoffs resolved | All HANDOFF messages have corresponding COMPLETED | warning |
| Open issues | Count of OPEN issues in `issues.md` | warning |

## Output

\`\`\`
EXECUTE_REVIEW:
  status={ready_for_audit|issues_found}
  issues=[{check, severity=blocking|warning, description}]
  summary={N tasks completed, M files changed, K open issues}
\`\`\`

## Behavior

- `status=ready_for_audit` → proceed to audit stage
- `status=issues_found` (warnings only) → proceed with warnings forwarded
- `status=issues_found` (blocking) → lead attempts one remediation cycle, then proceeds to audit anyway with issues flagged
```

- [ ] **Step 5: Commit**

```bash
git add skills/execute/SKILL.md skills/execute/references/error-recovery-protocol.md skills/execute/agents/execute-reviewer.md
git commit -m "feat: create execute stage skill with error recovery and execute reviewer"
```

---

### Task 7: Migrate existing docs to execute stage

**Files:**
- Create: `skills/execute/references/coordination-patterns.md` (migrated + merged from `docs/coordination-patterns.md` + `docs/coordination-advanced.md`)
- Create: `skills/execute/references/communication-protocol.md` (migrated + extended from `docs/communication-protocol.md`)
- Create: `skills/execute/agents/spawn-templates.md` (migrated from `docs/spawn-templates.md`)

- [ ] **Step 1: Migrate and merge coordination patterns**

Copy `docs/coordination-patterns.md` to `skills/execute/references/coordination-patterns.md`. Append the content from `docs/coordination-advanced.md` as a new `## Advanced Patterns` section. Add two new patterns:
- `### Plan-Mode Coordination` — evaluate → approve/revise → unblock protocol
- `### Error Recovery` — retry/recover/escalate protocol (reference error-recovery-protocol.md)

- [ ] **Step 2: Migrate and extend communication protocol**

Copy `docs/communication-protocol.md` to `skills/execute/references/communication-protocol.md`. Add new message types following the existing format (code block with key=value, then processing rules):
- `PLAN_PROPOSAL #N:` — proposal format with approach, alternatives, files, complexity, risks
- `PLAN_APPROVED #N` — approval response
- `PLAN_REVISION #N:` — revision request with feedback
- `ELEGANCE_REVIEW:` — overall_score, dimensions, findings
- `PLAN_REVIEW:` — status, issues
- `EXECUTE_REVIEW:` — status, issues, summary
- `AUDIT_REVIEW:` — status, issues
- Extend `BLOCKED` format with `error_type={retry|recoverable|design_flaw|unknown}` field

- [ ] **Step 3: Migrate spawn templates**

Copy `docs/spawn-templates.md` to `skills/execute/agents/spawn-templates.md`. Add:
- Plan-mode directive block (injected conditionally per teammate)
- Elegance Reviewer spawn template

- [ ] **Step 4: Commit**

```bash
git add skills/execute/references/ skills/execute/agents/spawn-templates.md
git commit -m "feat: migrate coordination, communication, and spawn docs to execute stage"
```

---

## Chunk 4: Audit Stage Skill

Create `skills/audit/` with SKILL.md and supporting files. Migrate report format. This stage owns Phase 5 (completion gate, elegance, lessons, patterns, report, shutdown).

### Task 8: Create audit stage — SKILL.md and new files

**Files:**
- Create: `skills/audit/SKILL.md`
- Create: `skills/audit/references/completion-gates.md`
- Create: `skills/audit/references/elegance-rubric.md`
- Create: `skills/audit/examples/lessons-example.md`
- Create: `skills/audit/agents/elegance-reviewer.md`
- Create: `skills/audit/agents/audit-reviewer.md`

- [ ] **Step 1: Create directories**

```bash
mkdir -p skills/audit/references skills/audit/examples skills/audit/agents
```

- [ ] **Step 2: Create audit SKILL.md**

Read the current `skills/agent-implement/SKILL.md` Phase 5, `skills/agent-research/SKILL.md` Phase 5, `skills/agent-audit/SKILL.md` Phase 5, `skills/agent-plan/SKILL.md` Phase 5, and `docs/shared-phases.md` Phase 5 section.

Create `skills/audit/SKILL.md` with:

```yaml
---
name: audit
description: >
  Agent Team audit stage. Runs completion gates, elegance review, captures
  lessons learned, updates error pattern library, generates final report.
  Requires completed workspace. Triggers: "audit the team work", "review team results",
  "run verification", "check team output".
argument-hint: "[workspace path]"
allowed-tools: Read, Write, Glob, Grep, Bash, Agent, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, TeamCreate, SendMessage
---
```

Body structure (H2 sections):
1. `## Overview` — owns Phase 5
2. `## Preconditions` — workspace with `task-graph.json` where at least one task has `status: completed`. Incomplete tasks flagged as ABANDONED. All tasks incomplete → exit with "nothing to audit"
3. `## Phase 5: Synthesize` — migrated from `shared-phases.md` Phase 5
   - Full 10-step ordering (spec Section 4)
   - Pre-shutdown commit, completion gate, remediation gate (existing)
   - Elegance gate, lessons capture, pattern library update (new)
   - Report generation, audit review, shutdown, cleanup
4. `## Completion Gates` — reference `references/completion-gates.md`
5. `## Elegance Gate` — reference `references/elegance-rubric.md` and `agents/elegance-reviewer.md`
6. `## Lessons Capture` — inline (uses template from `../../docs/workspace-templates.md`)
7. `## Pattern Library Update` — inline (rules from spec Section 4 Sub-step 3)
8. `## Inter-Stage Review: Audit Review Agent` — reference `agents/audit-reviewer.md`
9. `## References`

- [ ] **Step 3: Create completion-gates.md**

Create `skills/audit/references/completion-gates.md` — consolidate ALL archetype-specific gate checks from the 4 old archetype skills:

```markdown
# Completion Gates by Archetype

## Implementation (8 checks)

| # | Check | Required | How to verify |
|---|-------|----------|---------------|
| 1 | Uncommitted changes | Yes | git status for owned files |
| 2 | Build & tests | Yes | npm test / equivalent |
| 3 | Lint/format | Yes ★ | npm run lint / equivalent |
| 4 | Integration | Yes | Cross-module connections verified |
| 5 | Security scan | Yes ★ | npm audit / equivalent |
| 6 | Workspace issues | Yes | 0 OPEN issues in issues.md |
| 7 | Plan completion | Yes | All streams have completed tasks |
| 8 | Documentation sync | Yes ★ | No stale docs |

★ = project-specific, auto-pass if no tooling configured

## Research (2 checks)
...

## Audit (4 checks)
...

## Planning (2 checks)
...

## Hybrid (strictest gate rule)
...
```

Extract exact checks from each existing archetype SKILL.md Phase 5 section.

- [ ] **Step 4: Create elegance-rubric.md**

Create `skills/audit/references/elegance-rubric.md` with the 5-dimension scoring guide, examples of each score level (1-5), and guidance on when to flag nitpick vs improve vs refactor.

- [ ] **Step 5: Create lessons-example.md**

Create `skills/audit/examples/lessons-example.md` — a filled-in example of `lessons.md` from a hypothetical completed team (e.g., "0315-refactor-auth"). Show realistic lessons, estimation deltas, and recommendations.

- [ ] **Step 6: Create elegance-reviewer.md**

Create `skills/audit/agents/elegance-reviewer.md` — spawn prompt for the Elegance Reviewer. Include: role, tools, scope (files from file-locks.json), rubric reference, output format (`ELEGANCE_REVIEW` message), and advisory-only caveat.

- [ ] **Step 7: Create audit-reviewer.md**

Create `skills/audit/agents/audit-reviewer.md`:

```markdown
# Audit Review Agent

## Role

Meta-review of audit output. Validates report quality before presenting to user. Mandatory inter-stage gate.

## Tools

Read, Grep, Glob (read-only)

## Scope

Workspace files: `report.md`, `lessons.md`, `issues.md`, `progress.md`

## Checks

| Check | What it validates | Severity if failed |
|-------|-------------------|--------------------|
| Report completeness | All required sections present per archetype template | blocking |
| Evidence backing | Every finding has a file reference or example | warning |
| Lessons actionability | Lessons are specific and reusable (not vague) | warning |
| Consistency | No contradictions between report sections | blocking |
| Metrics accuracy | Task/file/duration counts match workspace data | warning |
| Elegance included | If elegance gate ran, findings appear in report | warning |

## Output

\`\`\`
AUDIT_REVIEW:
  status={approved|revisions_needed}
  issues=[{check, severity=blocking|warning, description, fix_suggestion}]
\`\`\`

## Behavior

- `status=approved` → shutdown and present report
- `status=revisions_needed` → lead fixes, re-runs review (max 2 cycles)
- After 2 failed cycles → finalize as-is with quality note
```

- [ ] **Step 8: Commit**

```bash
git add skills/audit/
git commit -m "feat: create audit stage skill with elegance gate, lessons capture, and review agents"
```

---

### Task 9: Migrate report format to audit stage

**Files:**
- Create: `skills/audit/references/report-format.md` (migrated + extended from `docs/report-format.md`)

- [ ] **Step 1: Migrate and extend report format**

Copy `docs/report-format.md` to `skills/audit/references/report-format.md`. Add two new sections to the report template:

```markdown
## Elegance Review

**Overall score**: {1-5}

| Dimension | Score |
|-----------|-------|
| Simplicity | {1-5} |
| Consistency | {1-5} |
| Readability | {1-5} |
| Testability | {1-5} |
| Minimal impact | {1-5} |

**Findings** ({N} total: {X} nitpick, {Y} improve, {Z} refactor):
- [{file}:{lines}] ({dimension}, {severity}): {suggestion}

## Lessons Summary

See full lessons at `lessons.md` in workspace.

**Key takeaways**:
- {top 3 lessons}

**Estimation accuracy**: {overall delta summary}
```

- [ ] **Step 2: Commit**

```bash
git add skills/audit/references/report-format.md
git commit -m "feat: migrate report format to audit stage with elegance and lessons sections"
```

---

## Chunk 5: Start Entry Point + Migration Cleanup

### Task 10: Create start entry point skill

**Files:**
- Create: `skills/start/SKILL.md`

- [ ] **Step 1: Create directory**

```bash
mkdir -p skills/start
```

- [ ] **Step 2: Create start SKILL.md**

Read the current `skills/agent-team/SKILL.md` for archetype detection logic.

Create `skills/start/SKILL.md` with:

```yaml
---
name: start
description: >
  Orchestrate parallel work via Agent Teams. Triggers when a task has 2+
  independent work streams. Chains plan → execute → audit stages.
  Triggers: "create a team", "work in parallel", "use agent team",
  "spawn teammates", "implement in parallel", "research with a team",
  "audit with a team", "plan with a team".
argument-hint: "[task description]"
allowed-tools: Read, Glob, Grep, Bash, Agent, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, TeamCreate, TeamDelete, SendMessage
---
```

Body structure:
1. `## Overview` — entry point that chains plan → execute → audit
2. `## Archetype Detection` — migrated from `agent-team/SKILL.md` detection table + logic
3. `## Pipeline Flow` — sequential orchestration:
   - Detect archetype, write to workspace `progress.md` as `**Archetype**: {type}`
   - Read and follow `../plan/SKILL.md` (Phase 1+2)
   - Read and follow `../execute/SKILL.md` (Phase 3+4)
   - Read and follow `../audit/SKILL.md` (Phase 5)
   - Full pipeline diagram: `plan → [plan-review] → user → execute → [execute-review] → audit → [audit-review] → report`
4. `## Independent Stage Invocation` — document that each stage can be invoked alone with preconditions

- [ ] **Step 3: Commit**

```bash
git add skills/start/
git commit -m "feat: create start entry point skill with archetype detection and pipeline chaining"
```

---

### Task 11: Delete old skill folders

**Files:**
- Delete: `skills/agent-team/SKILL.md` (and folder)
- Delete: `skills/agent-implement/SKILL.md` (and folder)
- Delete: `skills/agent-research/SKILL.md` (and folder)
- Delete: `skills/agent-audit/SKILL.md` (and folder)
- Delete: `skills/agent-plan/SKILL.md` (and folder)

- [ ] **Step 1: Delete old skill folders**

```bash
rm -rf skills/agent-team skills/agent-implement skills/agent-research skills/agent-audit skills/agent-plan
```

- [ ] **Step 2: Commit**

```bash
git commit -am "refactor: remove old archetype-based skill folders"
```

---

### Task 12: Delete migrated docs

**Files:**
- Delete: `docs/shared-phases.md`
- Delete: `docs/spawn-templates.md`
- Delete: `docs/communication-protocol.md`
- Delete: `docs/coordination-patterns.md`
- Delete: `docs/coordination-advanced.md`
- Delete: `docs/report-format.md`

- [ ] **Step 1: Delete migrated docs**

```bash
rm docs/shared-phases.md docs/spawn-templates.md docs/communication-protocol.md docs/coordination-patterns.md docs/coordination-advanced.md docs/report-format.md
```

- [ ] **Step 2: Commit**

```bash
git commit -am "refactor: remove docs migrated to pipeline stage skills"
```

---

## Chunk 6: Meta Updates — Tests, README, CLAUDE.md, Version

### Task 13: Update test suite

**Files:**
- Modify: `tests/structure/test-doc-references.sh`
- Modify: `tests/run-tests.sh` (if needed)

- [ ] **Step 1: Update test-doc-references.sh**

Key changes:
- Remove: assertion that `docs/shared-phases.md` exists
- Remove: assertions for `skills/agent-*/SKILL.md` glob (old skills deleted)
- Add: assertions for `skills/start/SKILL.md`, `skills/plan/SKILL.md`, `skills/execute/SKILL.md`, `skills/audit/SKILL.md`
- Add: assertions that each stage skill's `references/`, `examples/`, `agents/` subfolders exist (where applicable)
- Add: assertions that relative refs in new SKILL.md files resolve to existing files
- Update: `docs/*.md` reference checks to exclude deleted files
- Add: `recovery_class` field validation — grep each role section in `teammate-roles.md` for the field
- Add: Elegance Reviewer role exists in `teammate-roles.md`
- Add: Plan-mode defaults table exists in `team-archetypes.md`
- Add: New message types exist in `skills/execute/references/communication-protocol.md`

- [ ] **Step 2: Run tests**

```bash
bash tests/run-tests.sh
```

Expected: All tests pass. Fix any failures before continuing.

- [ ] **Step 3: Commit**

```bash
git add tests/
git commit -m "test: update structure tests for pipeline stage skills"
```

---

### Task 14: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update skill commands table**

Replace the "Archetype-Specific Commands" table with:

```markdown
### Pipeline Commands

| Command | When to Use | Example |
|---------|------------|---------|
| `/agent-team:start` | Full pipeline for any task type | "use agent team to refactor auth" |
| `/agent-team:plan` | Plan only, without executing | "plan the API redesign with a team" |
| `/agent-team:execute` | Resume from an approved plan | "execute the plan" |
| `/agent-team:audit` | Re-run verification on completed work | "audit the team output" |
```

- [ ] **Step 2: Update Plugin Structure tree**

Replace the `skills/` section with the new 4-skill pipeline structure matching the spec's directory tree.

- [ ] **Step 3: Update Teammate Roles table**

Add Elegance Reviewer row (13 entries total: Leader + 12 teammate roles).

- [ ] **Step 4: Update How It Works section**

Update the phase flow to show the pipeline:
```
plan → [plan-review] → user approval → execute → [execute-review] → audit → [audit-review] → report
```

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: update README for pipeline stage skills and new features"
```

---

### Task 15: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update Architecture section**

Replace the architecture tree with the new pipeline structure.

- [ ] **Step 2: Update File Ownership table**

Replace the 5 archetype skill rows with 4 pipeline stage rows:

| Area | Purpose | Edit Guidelines |
|------|---------|----------------|
| `skills/start/SKILL.md` | Entry point skill | Archetype detection + stage chaining |
| `skills/plan/SKILL.md` + `references/` + `agents/` | Plan stage | Phase 1+2, prior context, plan-mode |
| `skills/execute/SKILL.md` + `references/` + `agents/` | Execute stage | Phase 3+4, error recovery, coordination |
| `skills/audit/SKILL.md` + `references/` + `agents/` | Audit stage | Phase 5, elegance, lessons, report |

Remove rows for deleted docs (shared-phases.md, spawn-templates.md, etc.).

- [ ] **Step 3: Update hook count and test counts**

Update test count to reflect new assertions.

- [ ] **Step 4: Update Common Tasks sections**

Update "Adding a New Archetype Skill" → "Adding a New Pipeline Stage" (or remove if not applicable). Update SKILL.md editing guidelines for new structure.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for pipeline stage architecture"
```

---

### Task 16: Version bump and CHANGELOG

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Read current version**

```bash
grep '"version"' .claude-plugin/plugin.json
```

- [ ] **Step 2: Bump major version in plugin.json**

Update version (e.g., `2.6.0` → `3.0.0`).

- [ ] **Step 3: Bump major version in marketplace.json**

Same version as plugin.json.

- [ ] **Step 4: Add CHANGELOG entry**

Add at the top of CHANGELOG.md:

```markdown
## [3.0.0] — 2026-03-23

### Breaking Changes
- **Skill restructure**: Replaced 5 archetype-based skills (`agent-team`, `agent-implement`, `agent-research`, `agent-audit`, `agent-plan`) with 4 pipeline-stage skills (`agent-team:start`, `agent-team:plan`, `agent-team:execute`, `agent-team:audit`)
- Archetype is now configuration, not a separate skill
- Migrated stage-specific docs into skill subfolders

### Added
- **Prior context loading**: Plan stage loads lessons and error patterns from prior teams
- **Plan-mode gate**: Teammates propose approach before executing (configurable per-teammate)
- **Error recovery loop**: Classifies errors (retry/recoverable/design_flaw), attempts bounded recovery
- **Elegance review**: 5-dimension quality assessment (advisory, not blocking)
- **Lessons capture**: Post-execution lessons written to workspace for future teams
- **Global error pattern library**: `~/.claude/agent-team-patterns.json` shared across projects
- **Inter-stage review agents**: Plan reviewer, execute reviewer, audit reviewer validate output at each pipeline stage
- **Elegance Reviewer role**: New teammate role (13 total)
- **recovery_class field**: All roles now have a recovery behavior classification

### Removed
- `docs/shared-phases.md` — content distributed across pipeline stage skills
- `docs/spawn-templates.md`, `docs/communication-protocol.md`, `docs/coordination-patterns.md`, `docs/coordination-advanced.md`, `docs/report-format.md` — migrated to skill subfolders
```

- [ ] **Step 5: Run tests and validate**

```bash
bash tests/run-tests.sh
```

All tests must pass.

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "chore: bump version to 3.0.0"
```

- [ ] **Step 7: Tag release**

```bash
git tag v3.0.0
```
