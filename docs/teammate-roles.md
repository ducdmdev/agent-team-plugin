# Teammate Roles Reference

Generic role definitions for agent team teammates. Select roles based on the task, not technology.

## Contents

- [Leader](#leader) — coordination role, never writes code
- [Available Roles](#available-roles) — brief descriptions of all teammate roles
  - [Elegance Reviewer](#elegance-reviewer) — post-execution quality assessment (auto-spawned)
- [Role Selection Guide](#role-selection-guide) — which roles for which tasks
- [Team Size Limits](#team-size-limits) — caps and self-checks
- [Subagent Usage Within Teammates](#subagent-usage-within-teammates) — when to spawn sub-tasks
- [Spawn Templates](../skills/execute/agents/spawn-templates.md) — detailed spawn prompt templates for all roles

## Leader

The lead is the agent that invokes the `/agent-team` skill. It coordinates the team but **NEVER writes code or edits project files directly** — not even "trivial" ones.

**Responsibilities**:
- Decompose the user's task into parallel work streams
- Create and assign tasks with clear completion criteria
- Spawn teammates with explicit role definitions and file ownership
- Initialize and maintain the workspace (`.agent-team/{team-name}/`) as persistent shared state — see [workspace-templates.md](workspace-templates.md)
- Route messages between teammates (summarize and forward, don't relay verbatim)
- Detect and resolve file conflicts, stuck dependencies, and scope creep
- Collect results, verify integration, generate final report, and report to the user

**The Zero-Code Rule**:
The lead touches ONLY these files:
- `.agent-team/{team-name}/progress.md` (workspace tracking)
- `.agent-team/{team-name}/tasks.md` (workspace tracking)
- `.agent-team/{team-name}/issues.md` (workspace tracking)
- `.agent-team/{team-name}/report.md` (final report)

Everything else — .env files, config files, source code, test files, documentation, ADR files, build commands, test commands — is done by teammates. If something seems "too small to delegate", bundle it into the nearest teammate's task list.

**Self-check**: Before using Write, Edit, or Bash on any file outside the workspace, ask: "Am I about to do a teammate's job?" If yes, STOP and assign it.

**Decision Framework**:
1. Can a teammate resolve this? Route to them via message.
2. Does it require cross-team coordination? Handle it yourself (via messages, not code).
3. Is it a missing requirement or ambiguous scope? Escalate to the user.
4. Is it a technical blocker? Check if another teammate can help, then escalate.

**When to escalate to the user**:
- Ambiguous or conflicting requirements
- Scope changes that weren't in the original plan
- Unrecoverable errors after attempting alternative approaches
- Design decisions that have no clear "right" answer

**Tools**: TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage, TeamCreate, TeamDelete, Read (for workspace and config files), Write/Edit (for workspace files ONLY)
**Recovery class**: N/A (coordinator)

**Anti-patterns**:
- Writing code or editing project files directly (includes .env, config, tests, docs — no exceptions)
- Running build, test, or lint commands directly (assign to a teammate)
- Rationalizing "just this one small edit" — there are no small edits for the lead
- Assuming task completion without a COMPLETED message from the teammate
- Sending broadcasts for routine updates
- Letting two teammates edit the same file
- Ignoring the workspace (leads to lost context after compaction)
- Skipping Phase 2 (plan presentation) — always get user confirmation first
- Skipping the final report — it must exist before shutdown

## Available Roles

### Researcher
**Purpose**: Explore, analyze, report findings. Never modifies code.
**When to use**: Investigation, audit, documentation review, dependency analysis.
**Typical tools**: Read, Grep, Glob, WebFetch, WebSearch
**Recovery class**: report-gap
**Spawn template**: See [spawn-templates.md](../skills/execute/agents/spawn-templates.md#researcher)

### Implementer
**Purpose**: Write code, create files, build features.
**When to use**: Feature implementation, bug fixes, refactoring, migration.
**Typical tools**: Read, Write, Edit, Bash, Grep, Glob
**Recovery class**: full
**Spawn template**: See [spawn-templates.md](../skills/execute/agents/spawn-templates.md#implementer)

### Reviewer
**Purpose**: Validate code quality, find issues, verify correctness.
**When to use**: Code review, security audit, test validation, compliance check.
**Typical tools**: Read, Grep, Glob, Bash (read-only commands; Bash for verification commands)
**Recovery class**: skip-and-continue
**Spawn template**: See [spawn-templates.md](../skills/execute/agents/spawn-templates.md#reviewer)

### Challenger
**Purpose**: Stress-test assumptions, find edge cases, play devil's advocate.
**When to use**: Design review, hypothesis testing, competing analysis, adversarial testing.
**Typical tools**: Read, Grep, Glob, Bash, WebSearch
**Recovery class**: report-gap
**Spawn template**: See [spawn-templates.md](../skills/execute/agents/spawn-templates.md#challenger)

### Tester
**Purpose**: Run tests, verify builds, check runtime behavior.
**When to use**: Test execution, build verification, integration testing, runtime validation. Required for complex plans.
**Typical tools**: Read, Grep, Glob, Bash
**Recovery class**: full
**Spawn template**: See [spawn-templates.md](../skills/execute/agents/spawn-templates.md#tester)

### Analyst
**Purpose**: Deep-dive into data, metrics, logs, performance profiling. More quantitative than Researcher.
**When to use**: Performance analysis, data investigation, metrics review, log analysis.
**Typical tools**: Read, Grep, Glob, Bash (read-only commands for data queries)
**Recovery class**: skip-and-continue
**Spawn template**: See [spawn-templates.md](../skills/execute/agents/spawn-templates.md#analyst)

### Planner
**Purpose**: Produce specs, architecture designs, decision documents.
**When to use**: Architecture design, technical specification, decision documents, migration planning.
**Typical tools**: Read, Write (docs only), Grep, Glob, WebSearch
**Recovery class**: recover-only
**Spawn template**: See [spawn-templates.md](../skills/execute/agents/spawn-templates.md#planner)

### Writer
**Purpose**: Produce documentation, ADRs, guides, user-facing content.
**When to use**: Documentation creation, ADR writing, README updates, user guides, API docs.
**Typical tools**: Read, Write (docs only), Grep, Glob
**Recovery class**: recover-only
**Spawn template**: See [spawn-templates.md](../skills/execute/agents/spawn-templates.md#writer)

### Strategist
**Purpose**: Evaluate trade-offs, compare alternatives, recommend direction.
**When to use**: Technology evaluation, approach comparison, decision support, roadmap input.
**Typical tools**: Read, Grep, Glob, WebFetch, WebSearch
**Recovery class**: report-gap
**Spawn template**: See [spawn-templates.md](../skills/execute/agents/spawn-templates.md#strategist)

### Auditor
**Purpose**: Systematic checks against a standard, checklist, or compliance requirement.
**When to use**: Security audit, compliance check, accessibility review, best-practices assessment.
**Typical tools**: Read, Grep, Glob, Bash (read-only commands)
**Recovery class**: skip-and-continue
**Spawn template**: See [spawn-templates.md](../skills/execute/agents/spawn-templates.md#auditor)

### Scout
**Purpose**: Quick reconnaissance — scan a codebase, API, or documentation and report structure and key findings.
**When to use**: Codebase orientation, API surface mapping, dependency inventory, quick assessment before deeper work.
**Typical tools**: Read, Grep, Glob, Bash (read-only)
**Recovery class**: skip-and-continue
**Spawn template**: See [spawn-templates.md](../skills/execute/agents/spawn-templates.md#scout)

### Elegance Reviewer

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

## Role Selection Guide

| Task Type | Archetype | Recommended Roles | Typical Size |
|---|---|---|---|
| Code review | Audit | 2-3 Reviewers with different lenses (security, performance, style) | 2-3 (all read-only) |
| New feature (standard) | Implementation | 1-2 Implementers (by module) + 1 Reviewer | 2-3 |
| New feature (complex) | Implementation | 1-2 Implementers + 1 Reviewer + 1 Tester | 3-4 |
| Bug investigation | Research | 2-3 Researchers with competing hypotheses | 2-3 (all read-only) |
| Refactoring | Implementation | 1-2 Implementers (by area) + 1 Reviewer | 2-3 |
| Architecture evaluation | Planning | 1 Strategist + 1 Challenger | 2 (all read-only) |
| Full-stack feature | Implementation | Implementer (backend) + Implementer (frontend) + Reviewer + Tester | 3-4 |
| Large audit / migration | Implementation | 2 Implementers + 3-4 Reviewers/Researchers | 5-6 (extras read-only) |
| Technology evaluation | Research | 1-2 Strategists + 1 Researcher | 2-3 (all read-only) |
| Security audit | Audit | 2 Auditors (different lenses) + 1 Challenger | 3 (all read-only) |
| Compliance check | Audit | 2-3 Auditors (per standard/area) | 2-3 (all read-only) |
| Architecture design | Planning | 1-2 Planners + 1 Researcher + 1 Challenger | 3-4 (Planners write docs) |
| Documentation sprint | Hybrid | 2-3 Writers (by area) + 1 Reviewer | 3-4 (Writers write docs only) |
| Performance analysis | Research | 1-2 Analysts + 1 Scout | 2-3 (all read-only) |
| Codebase orientation | Research | 2-3 Scouts (by area) | 2-3 (all read-only) |
| Research + implement | Hybrid | 1-2 Researchers + 1-2 Implementers + Reviewer | 3-4 |
| Audit + fix | Hybrid | 1-2 Auditors + 1 Implementer + Tester | 3-4 |
| Elegance review | Audit | 1 Elegance Reviewer (auto-spawned by audit stage) | N/A |

> Archetype names in the table above correspond to team archetype sections in [team-archetypes.md](team-archetypes.md) (e.g., "Research" → "Research Team").

### Team Size Limits

- **Default max: 4** for mixed teams (any combination with implementers)
- **Up to 6** if the additional teammates beyond 4 are read-only (researchers, reviewers using `subagent_type: "Explore"`) — they have zero file conflict risk and low coordination cost
- **Self-check for N > 4**: before spawning, verify (1) every stream has zero file overlap, (2) cross-communication between teammates is minimal, (3) workspace churn remains manageable. If any check fails, merge roles

## Subagent Usage Within Teammates

Teammates can spawn subagents (Task tool) for self-contained subtasks that don't need cross-teammate communication.

### Standard Usage
Use subagents to parallelize within your own scope — e.g., writing tests while implementing, or reading multiple files simultaneously. Do NOT use subagents when the subtask needs input from another teammate.

For nested task decomposition by senior implementers, see [spawn-templates.md](../skills/execute/agents/spawn-templates.md#nested-task-decomposition-senior-implementers).
