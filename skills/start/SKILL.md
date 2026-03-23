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

# Agent Team — Start

Entry point for Agent Team orchestration. Detects the team archetype from the user's task, then chains three pipeline stages in sequence: **plan**, **execute**, and **audit**.

## Overview

The start skill is the default entry point when a user asks for parallel work. It does not contain phase logic itself — it detects the archetype, then reads and follows each stage skill's instructions in order.

**Full pipeline**:

```
plan → [plan-review] → user approval → execute → [execute-review] → audit → [audit-review] → report to user
```

- If any stage fails or the user cancels, the pipeline stops.
- The workspace (`.agent-team/{team-name}/`) persists across stages and enables resumption.

## Archetype Detection

Before invoking the plan stage, determine the team archetype from the user's task description. Match against trigger patterns from [team-archetypes.md](../../docs/team-archetypes.md):

| Archetype | Trigger Patterns |
|-----------|-----------------|
| Implementation | "implement", "build", "create", "refactor", "fix", "migrate", "add feature", "update", "write code" |
| Research | "research", "investigate", "explore", "analyze", "compare", "understand", "find out", "study" |
| Audit | "audit", "review", "assess", "evaluate", "check compliance", "security review", "code review", "inspect" |
| Planning | "plan", "design", "architect", "spec", "propose", "strategy", "roadmap", "decide" |
| Hybrid | Task combines 2+ of the above (e.g., "research and implement", "audit and fix") |

**Detection rules**:

1. **Single archetype match**: Use that archetype. Inform the user: "This is a {type} task — I'll use the {type} team workflow."
2. **Multiple archetypes match**: Use the **primary intent** — the first verb/action in the request determines the archetype. If the task clearly combines types (e.g., "research X then implement Y"), classify as Hybrid.
3. **No clear match**: Default to Implementation (the most common case).

**Plan-aware detection**: When a plan file is available, plan content takes precedence over trigger word matching — the plan represents the user's confirmed intent.

**Disambiguation**:
- "evaluate against a standard/checklist" → Audit. "Evaluate alternatives/options" → Research or Planning.
- "write code/feature" → Implementation. "Write documentation" → Planning or Hybrid.

**Record the archetype**: Write the detected archetype to the workspace `progress.md` as `**Archetype**: {type}`. Each downstream stage reads this field to configure its behavior.

## Pipeline Flow

Execute the following stages sequentially. Each stage's logic is defined in its own SKILL.md — read and follow that file inline.

### Stage 1: Plan (Phase 1 + Phase 2)

1. Read and follow [../plan/SKILL.md](../plan/SKILL.md).
2. This covers: prior context loading, task analysis, decomposition, plan-mode marking, plan review agent validation, and user approval.
3. **Gate**: The user must approve the plan before proceeding. If the user cancels or rejects, stop the pipeline. The workspace persists for later resumption.

### Stage 2: Execute (Phase 3 + Phase 4)

1. Read and follow [../execute/SKILL.md](../execute/SKILL.md).
2. This covers: workspace creation, teammate spawning, coordination, error recovery, progress tracking, and execute review agent smoke test.
3. **Gate**: All tasks must reach a terminal state (completed or abandoned) before proceeding. The execute review agent validates readiness for audit.

### Stage 3: Audit (Phase 5)

1. Read and follow [../audit/SKILL.md](../audit/SKILL.md).
2. This covers: completion gates, elegance review, lessons capture, pattern library update, report generation, audit review agent validation, and team shutdown.
3. **Output**: Final report presented to the user.

### Failure Handling

- If any stage encounters a fatal error, stop the pipeline and report the failure to the user.
- The workspace at `.agent-team/{team-name}/` persists with the current state. The user can resume by invoking the failed stage independently.
- Partial results are preserved — completed tasks and their outputs remain available.

## Independent Stage Invocation

Each pipeline stage can be invoked alone with its own preconditions. This enables partial runs, resumption, and re-verification.

| Command | What It Does | Preconditions |
|---------|-------------|---------------|
| `/agent-team:plan [task]` | Just planning — analyze, decompose, get user approval. Stops after Phase 2. | None (starts fresh) |
| `/agent-team:execute` | Resume from existing plan. Spawns teammates and coordinates. | Workspace exists at `.agent-team/{name}/` with `progress.md` (containing `**Archetype**` and `**Status**: approved`), `tasks.md` (with task breakdown), and `task-graph.json` (with pending tasks) |
| `/agent-team:audit` | Run or re-run verification, elegance review, and reporting. | Workspace exists with `task-graph.json` where at least one task has `status: completed`. Incomplete tasks are flagged as ABANDONED in the report. If all tasks are incomplete, audit exits with "nothing to audit" |

**Typical independent use cases**:
- Run `/agent-team:plan` to get a plan reviewed and approved, then later run `/agent-team:execute` to start work.
- Re-run `/agent-team:audit` after fixing issues flagged in the first audit.
- Run `/agent-team:execute` to resume a team that was interrupted mid-execution.

## References

- [Plan stage](../plan/SKILL.md) — Phase 1 (analyze + decompose) and Phase 2 (plan-mode gate + user approval)
- [Execute stage](../execute/SKILL.md) — Phase 3 (workspace + spawn) and Phase 4 (coordinate + error recovery)
- [Audit stage](../audit/SKILL.md) — Phase 5 (gates + elegance + lessons + report)
- [Team archetypes](../../docs/team-archetypes.md) — archetype definitions and trigger patterns
- [Teammate roles](../../docs/teammate-roles.md) — role catalog and selection guide
- [Workspace templates](../../docs/workspace-templates.md) — workspace file formats and schemas
