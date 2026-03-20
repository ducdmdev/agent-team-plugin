# Advanced Coordination Patterns

Advanced and specialized coordination patterns. For core patterns, see [coordination-patterns.md](coordination-patterns.md).

## Contents

- [Re-plan on Block](#re-plan-on-block) — revising the plan when a critical block invalidates it
- [Adversarial Review Rounds](#adversarial-review-rounds) — multi-round cross-review for critical changes
- [Quality Gate](#quality-gate) — final validation pass before synthesis
- [Checkpoint/Rollback](#checkpointrollback) — save and resume long-running tasks
- [Deadline Escalation](#deadline-escalation) — time-based proactive escalation
- [Circular Dependency Detection](#circular-dependency-detection) — prevent deadlocks in Phase 2
- [Graceful Degradation](#graceful-degradation) — scope reduction under resource pressure
- [Auto-Block on Repeated Failures](#auto-block-on-repeated-failures) — escalation after repeated failures
- [Anti-Pattern Catalog](#anti-pattern-catalog) — known coordination pitfalls to avoid

## Re-plan on Block

When a critical or high-severity BLOCKED message arrives and the original plan may no longer be viable:

### Detection

The lead should consider re-planning when:
- A critical BLOCKED affects 2+ tasks or teammates
- A key assumption in the original Phase 2 plan turns out to be wrong
- An external dependency (API, library, service) is unavailable
- The blocking issue requires a fundamentally different approach

### Protocol

1. **Assess viability** — can the original plan still work with minor adjustments?
   - If yes: resolve the block normally (stuck dependency resolution, reassignment)
   - If no: proceed to re-plan
2. **Pause affected work** — message affected teammates: "Pause work on [tasks]. Re-planning in progress."
3. **Draft revised plan** — identify what changes: task decomposition, file ownership, teammate roles, dependencies
4. **Present to user** — this is a mandatory gate, same as Phase 2:
   ```
   Re-plan needed: [reason]

   Original plan: [summary]
   Revised plan: [summary of changes]

   Changes:
   - [task/role/ownership changes]

   Approve revised plan?
   ```
5. **If approved**: update workspace (tasks.md, progress.md Decision Log), reassign tasks, message affected teammates with new scope
6. **If declined**: user provides alternative direction. Adjust accordingly.

### Logging

- Log re-plan decision in `progress.md` Decision Log with reasoning
- Update `tasks.md` with any new/modified/removed tasks
- Log the block that triggered re-planning in `issues.md`

## Adversarial Review Rounds

When review quality is critical (security-sensitive code, architectural decisions, complex refactors), use multi-round adversarial review instead of single-pass:

### When to Use

- Security-sensitive changes
- Architectural decisions with long-term implications
- Complex refactors touching multiple modules
- When the first reviewer's findings seem superficially clean (early agreement is suspicious)

### Protocol

1. **Round 1 — Primary review**: Reviewer A reviews the implementation and reports findings using the standard findings format (H/M/L severity with file:line references)
2. **Round 2 — Cross-review**: Reviewer B receives Reviewer A's findings and is tasked with:
   - Verifying each finding (agree/disagree with evidence)
   - Finding issues Reviewer A missed
   - Challenging any "PASS" assessments that seem too lenient
3. **Round 3 — Synthesis**: Lead collects both reviews and:
   - Identifies agreements (high confidence findings)
   - Identifies disagreements (need resolution)
   - For disagreements: asks the dissenting reviewer to provide specific evidence
4. **Resolution**: If disagreements persist after Round 3, escalate to user with both positions and evidence

### Lead Coordination

- Route findings between reviewers via summarized messages (don't relay verbatim — extract actionable points)
- Log the review rounds in `progress.md` Decision Log: "Adversarial review: Round N complete, X agreements, Y disagreements"
- Create separate review tasks for each round (e.g., #5 "Primary security review", #6 "Cross-review of #5 findings")
- Reviewers can use subagents (Task tool with Explore) to parallelize file reads within their review scope

### Team Composition

- Minimum: 2 reviewers + lead
- Reviewers should have different review lenses when possible (e.g., security + performance, correctness + maintainability)
- Do NOT have the original implementer serve as a reviewer in adversarial rounds

## Quality Gate

A final validation pass before Phase 5 synthesis. Catches integration issues that per-task checks miss.

> **Note**: The Completion Gate in SKILL.md Phase 5 step 5 provides mandatory quality checks (build, tests, lint, integration, security, issues, plan completion, doc sync) for ALL teams. This pattern describes extended verification options for complex plans that go beyond the standard gate.

### When to Use

- Complex plans with 3+ implementers
- Cross-module changes where integration bugs are likely
- Plans marked as "complex" in Phase 2

### Protocol

1. **Trigger**: All implementation tasks are completed. Before starting Phase 5.
2. **Assign quick verification tasks** to remaining active teammates:
   - Build verification: "Run `[build command]` and report result"
   - Test verification: "Run `[test command]` and report result"
   - Integration check: "Verify [module A] correctly calls [module B] after both teammates' changes"
   - Lint/format check: "Run linter and report any new warnings"
3. **Gate decision**:
   - All checks pass → proceed to Phase 5
   - Failures found → create fix tasks, assign to relevant implementers, re-run gate after fixes
4. **Log**: Record gate result in `progress.md` Decision Log: "Quality gate: PASS" or "Quality gate: FAIL — [issues], fix tasks created"

### Implementation

The lead creates verification tasks with clear pass/fail criteria:

```
Task: "Quality gate — build verification"
Description: Run the project build command. Report PASS if it succeeds, FAIL with error output if it fails.
Completion criteria: Build exits 0 with no errors.
```

Assign to the nearest available teammate (reviewer or tester preferred, implementer if no others are available).

## Checkpoint/Rollback

Save consistent state at natural breakpoints during long-running tasks. Enables recovery from mid-task failures without losing completed work.

### When to Use

- Tasks expected to take >10 minutes
- Multi-step migrations, large refactors, or batch operations
- Any task where partial failure is possible and rework is expensive

### Protocol

1. **Lead instructs** in spawn prompt: "For long tasks, send CHECKPOINT messages at natural breakpoints (after each module, after each migration step, etc.)"
2. **Teammate sends** CHECKPOINT at each breakpoint:
   ```
   CHECKPOINT #N: {what was completed}, artifacts={file references}, ready_for=[task IDs]
   ```
3. **Lead logs** checkpoint in `progress.md` Decision Log: "Checkpoint: task #N at [milestone]"
4. **On failure**: Lead messages teammate with last checkpoint context:
   ```
   Resume from checkpoint. Last known state:
   - Completed: {checkpoint description}
   - Artifacts: {file references}
   - Remaining: {what's left to do}
   ```
5. **If teammate is unrecoverable**: spawn replacement with checkpoint context in prompt

### Workspace Integration

- Checkpoints are logged in `progress.md` Decision Log (not a separate file)
- Checkpoint artifacts live in the workspace directory: `.agent-team/{team}/checkpoint-{task-id}.md`
- On task completion, checkpoint artifacts can be cleaned up or kept for audit

### Key Rule

Checkpoints are lightweight — a one-line CHECKPOINT message, not a full state dump. The workspace files (`tasks.md`, `issues.md`) already track team-level state. Checkpoints track task-level progress within a single teammate's scope.

## Deadline Escalation

Proactive time-based escalation to prevent tasks from exceeding the user's time budget.

### When to Use

- User has an implicit or explicit time constraint
- A task has been in_progress for an extended period with no PROGRESS or COMPLETED message
- The team session is approaching context limits

### Protocol

1. **Lead tracks** estimated task duration in `progress.md`:
   ```
   **Session started**: {timestamp}
   ```
2. **Lead proactively checks** tasks that have been in_progress without updates:
   ```
   Status check on task #N — it's been [duration] since your last update.
   What's your progress? Use PROGRESS or COMPLETED format.
   If blocked, use BLOCKED so I can log and route it.
   ```

   When checking stalled tasks, prioritize **critical-path tasks** (marked with `critical_path: true` in `task-graph.json`). A stalled critical-path task directly delays total completion. A stalled non-critical task has slack before it affects the timeline. Adjust escalation urgency accordingly:
   - Critical-path task stalled → skip Nudge, go directly to **Warn**
   - Non-critical task stalled → follow normal Nudge → Warn → Escalate ladder

3. **Escalation ladder**:
   - **Nudge** (first check): request status update
   - **Warn** (second check, ~5 min later): "Task #N is at risk. Need status or BLOCKED report."
   - **Escalate** (third check): mark task as at-risk in `tasks.md`, consider reassignment or scope reduction
4. **Scope reduction option**: if task is too large, lead proposes splitting:
   ```
   Task #N is taking longer than expected. Options:
   a) Continue (estimated X more minutes)
   b) Split: complete [partial scope], defer [remaining scope] as follow-up
   c) Reassign to [other teammate]
   ```

### Key Rule

Deadline escalation is proactive, not punitive. The goal is visibility — silent tasks are the biggest risk to team throughput. Combine with the PROGRESS message type for teammates to self-report before escalation triggers.

## Circular Dependency Detection

Validate task dependency graphs before execution to prevent silent deadlocks.

### When to Use

- Phase 2 plan has 4+ tasks with `blocked by` relationships
- Any time tasks form chains longer than 2 levels deep

### Protocol

1. **During Phase 2**: Before presenting the plan, trace all dependency chains:
   - For each task with `blocked by`, follow the chain: A blocks B blocks C...
   - If any chain leads back to a task already visited, there's a cycle
2. **On cycle detected**: Do NOT present the plan. Instead, restructure:
   - Option A: Merge the cyclic tasks into one (assign to same teammate)
   - Option B: Remove the weakest dependency (the one where the blocker could be worked around)
   - Option C: Split one task to break the cycle (the blocking portion runs first)
3. **Log**: Record the detected cycle and resolution in `progress.md` Decision Log

### Example

```
Task #1: Set up database schema
Task #2: Write API endpoints (blocked by #1)
Task #3: Write migrations (blocked by #2)
Task #1 update: schema depends on migration format (blocked by #3)  ← CYCLE

Resolution: Merge #1 and #3 into single task "Database schema + migrations"
```

### Prevention

The best prevention is Phase 1 decomposition by independent modules, not by sequential steps. If streams need constant handoffs, merge them.

## Graceful Degradation

Reduce scope rather than stopping when the team hits resource limits or unrecoverable blockers.

### When to Use

- Context window is running low (frequent compaction)
- Multiple teammates are blocked and remediation isn't viable
- User's time budget is exceeded but partial delivery has value

### Protocol

1. **Detect degradation trigger**:
   - 2+ context compactions in short succession
   - 3+ teammates blocked simultaneously
   - Lead judges that full scope cannot be completed
2. **Assess salvageable work**: read `tasks.md` — which tasks are COMPLETED? What partial value exists?
3. **Present scope reduction to user**:
   ```
   Scope reduction needed: [trigger reason]

   Completed work (will be preserved):
   - [task IDs and summaries]

   Work to defer (will be logged as follow-up):
   - [task IDs and summaries]

   Approve reduced scope?
   ```
4. **If approved**:
   - Mark deferred tasks as `deferred` in `tasks.md`
   - Shut down teammates working on deferred tasks
   - Continue to Phase 5 with completed work only
   - Include deferred items in report's Follow-up section
5. **Log**: Record scope reduction decision in `progress.md` Decision Log

### Key Rule

Graceful degradation is a controlled retreat, not a failure. The user gets partial value immediately and a clear list of what remains. This is always better than a team that burns context trying to finish everything and produces nothing.

## Auto-Block on Repeated Failures

Prevents teammates from spinning on the same error. Escalates automatically after repeated failures.

### Protocol

1. **Track blocked count per task** — when receiving a BLOCKED message, check `issues.md` for previous BLOCKED entries on the same task
2. **Threshold: 3 attempts** — if a teammate has reported BLOCKED on the same task 3 times:
   - Do NOT let them retry
   - Mark the task as blocked in `tasks.md`
   - Escalate immediately: either reassign to a different teammate or escalate to the user
3. **Log**: Update `issues.md` with the escalation: "Auto-blocked after 3 attempts. Reassigned to [teammate] / Escalated to user."

### Lead Check

When processing a BLOCKED message:
```
1. Read issues.md — count OPEN entries for this task ID
2. If count >= 2 (this is the 3rd block):
   a. Message teammate: "This task has been blocked 3 times. Pausing your work on it."
   b. Decide: reassign or escalate
3. If count < 2:
   a. Acknowledge and route to resolution as normal
```

## Anti-Pattern Catalog

Known coordination anti-patterns to avoid. These emerge from research into multi-agent systems (CrewAI, AutoGen, LangGraph, MetaGPT) and distributed systems theory.

### Critical (Prevent by Design)

**Circular Wait Deadlock**: Tasks A→B→C→A where each blocks the next. Prevention: validate dependency DAG in Phase 2 (see [Circular Dependency Detection](#circular-dependency-detection)).

**Race Condition on Shared State**: Two teammates simultaneously edit the same file; last write wins. Prevention: 1:1 file ownership mapping in Phase 2 + PreToolUse hook enforcement.

**Context Overflow Cascade**: Workspace grows unbounded; teammates can't read full context; compaction fires repeatedly. Prevention: batch workspace updates, keep workspace files concise, use [Graceful Degradation](#graceful-degradation) when compaction frequency increases.

**Infinite Re-Debate Loop**: Two teammates keep revisiting a completed decision. Prevention: once a task is COMPLETED, no further work on it unless explicitly reassigned by the lead. Log decisions in `progress.md` Decision Log as the authoritative record.

### Warning (Monitor and Mitigate)

**Silent Failure**: Teammate completes but sends no message — task appears blocked but is actually done. Mitigation: First Contact Verification + proactive check-ins. If idle 2+ cycles without any message, investigate.

**Scope Explosion**: Team grows beyond lead's effective span of control (>6 agents). Mitigation: enforce team size limits in Phase 3; for >6, use hierarchical sub-leads or phased execution.

**Single Point of Failure**: All work depends on one teammate; if they fail, the whole team stalls. Mitigation: avoid assigning >50% of tasks to any single teammate. For critical paths, ensure another teammate can take over.

**Byzantine Output**: Teammate reports task complete but output is incorrect or hallucinated. Mitigation: Adversarial Review Rounds for critical tasks; verify file changes actually exist before marking tasks complete (TaskCompleted hook already does this for implementers).

## See Also

- [coordination-patterns.md](coordination-patterns.md) — core patterns (batch updates, shutdown, commit, handoff, conflict resolution, error recovery)
