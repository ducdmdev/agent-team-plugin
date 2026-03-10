# Protocol & Coordination Patterns Improvement Plan

**Status:** COMPLETED — Implemented via team 0309-protocol-improvement, released as v2.4.0 (2026-03-09)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enhance the agent-team plugin's communication protocol, coordination patterns, and resilience based on research findings from team 0309-protocol-research.

**Architecture:** All changes are documentation-only (docs/*.md). No hook scripts, no SKILL.md frontmatter changes, no code changes. Each task adds a self-contained section to an existing doc file. The protocol remains additive and backward-compatible — existing 5-prefix messages are unchanged.

**Tech Stack:** Markdown documentation files, bash test scripts

**Reference:** `.agent-team/0309-protocol-research/final-report.md` — synthesized research from 4 parallel streams

---

### Task 1: Add PROGRESS and CHECKPOINT message types to communication protocol

**Files:**
- Modify: `docs/communication-protocol.md`

**Step 1: Read the current file**

Read `docs/communication-protocol.md` to confirm current structure (Contents, Structured Messages, then role-specific formats).

**Step 2: Add PROGRESS and CHECKPOINT to Structured Messages**

After the existing 5-prefix code block (lines 18-24), add two new optional message types. Edit the code block to become:

```
STARTING #N: {what I plan to do, which files I'll touch}
COMPLETED #N: {what I did, files changed, any concerns}
BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
HANDOFF #N: {what I produced that another teammate needs, key details}
QUESTION: {what I need to know, what I already checked in workspace}
```

Then add a new section `## Extended Messages (Optional)` after the Structured Messages section, before the Reviewer/Auditor format:

```markdown
## Extended Messages (Optional)

These message types are optional enhancements. Teammates use them when the lead requests granular updates or when tasks are long-running.

### Progress Reporting

For long-running tasks (>5 minutes expected), teammates report intermediate progress:

```
PROGRESS #N: milestone={description}, percent={0-100}, eta={minutes or omitted}
```

Example:
```
PROGRESS #5: milestone="security scan phase 2 of 4", percent=50, eta=3
```

**Lead processing**: Log milestone in `tasks.md` Notes column. No workspace file update needed unless the milestone unblocks another task.

### Checkpoint (Partial Completion)

When a task produces intermediate artifacts that downstream tasks can consume early:

```
CHECKPOINT #N: {what was completed}, artifacts={file references}, ready_for=[task IDs]
```

Example:
```
CHECKPOINT #5: completed 50/100 tests, early findings: 3 failures in auth module, artifacts=.agent-team/{team}/test-results-partial.md, ready_for=[6]
```

**Lead processing**: If `ready_for` lists task IDs, message the dependent teammate with the checkpoint details. Log in `progress.md` Handoffs section.
```

**Step 3: Run tests to verify doc references still resolve**

Run: `bash tests/run-tests.sh`
Expected: All tests pass (no new doc refs added, only content within existing file)

**Step 4: Commit**

```bash
git add docs/communication-protocol.md
git commit -m "feat: add PROGRESS and CHECKPOINT optional message types to protocol"
```

---

### Task 2: Add confidence grades and priority marking to protocol

**Files:**
- Modify: `docs/communication-protocol.md`

**Step 1: Add confidence grades to Reviewer/Auditor Findings Format**

After the existing H/M/L format (lines 30-33), add an optional confidence annotation. Edit the section to read:

```markdown
## Reviewer/Auditor Findings Format

Use consistent severity labels with sequential numbering per severity within each task:

- **H{n}** (high — must fix): file:line, description, suggested fix
- **M{n}** (medium — should fix): file:line, description
- **L{n}** (low — suggestion): file:line, description

**Optional confidence grade**: Append `[X%]` to any finding when confidence is meaningful:
- `H1[95%]: src/auth.py:15, SQL injection via unsanitized input, fix: use parameterized query`
- `M2[60%]: src/api.py:42, possible race condition under load`

Omit the grade when confidence is obviously high (most findings). Use it when a finding is uncertain or based on inference rather than direct evidence.

In COMPLETED messages, include total counts: "N issues: X high, Y medium, Z low"
```

**Step 2: Add priority marking to Structured Messages section**

In the Extended Messages section (added in Task 1), add a Priority Marking subsection:

```markdown
### Priority Marking

Teammates can signal task urgency in STARTING and HANDOFF messages:

```
STARTING #N: priority={critical|high|normal|low}, {what I plan to do, which files I'll touch}
HANDOFF #N: priority={critical|high|normal|low}, {what I produced, key details}
```

Default is `normal` — omit the field for routine work. Use `critical` only when the task blocks multiple teammates or has a deadline.

**Lead processing**: Prioritize `critical` and `high` messages. For `critical` HANDOFF, forward immediately (don't batch).
```

**Step 3: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 4: Commit**

```bash
git add docs/communication-protocol.md
git commit -m "feat: add confidence grades and priority marking to protocol"
```

---

### Task 3: Add Checkpoint/Rollback coordination pattern

**Files:**
- Modify: `docs/coordination-patterns.md`

**Step 1: Read the current file to identify insertion point**

Read `docs/coordination-patterns.md`. New patterns go before the existing "## Auto-Block on Repeated Failures" section (around line 385).

**Step 2: Add Checkpoint/Rollback pattern**

Insert a new section before Auto-Block on Repeated Failures:

```markdown
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
```

**Step 3: Update the Contents list**

Add `- [Checkpoint/Rollback](#checkpointrollback) — save and resume long-running tasks` to the Contents list in the appropriate position (after Quality Gate).

**Step 4: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 5: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "feat: add checkpoint/rollback coordination pattern"
```

---

### Task 4: Add Deadline/Timeout Escalation coordination pattern

**Files:**
- Modify: `docs/coordination-patterns.md`

**Step 1: Add Deadline Escalation pattern**

Insert after the Checkpoint/Rollback section added in Task 3:

```markdown
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
```

**Step 2: Update the Contents list**

Add `- [Deadline Escalation](#deadline-escalation) — time-based proactive escalation` to the Contents list.

**Step 3: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 4: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "feat: add deadline escalation coordination pattern"
```

---

### Task 5: Add Circular Dependency Detection to Phase 2

**Files:**
- Modify: `docs/shared-phases.md`
- Modify: `docs/coordination-patterns.md`

**Step 1: Add DAG validation step to Phase 2 in shared-phases.md**

In shared-phases.md, Phase 2 plan presentation section (around line 51), add a new self-check. The existing self-check block (lines 87-89) has 2 numbered checks. Append a 3rd check after check #2 (line 89), before "Wait for user confirmation":

```markdown
3. "Do any tasks form circular dependencies? Trace each `blocked by` chain — if task A blocks B blocks C blocks A, that's a cycle. If found, restructure: merge the cyclic tasks or break the cycle by removing one dependency."
```

**Step 2: Add Circular Dependency Detection pattern to coordination-patterns.md**

Insert after Deadline Escalation:

```markdown
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
```

**Step 3: Update the Contents list in coordination-patterns.md**

Add `- [Circular Dependency Detection](#circular-dependency-detection) — prevent deadlocks in Phase 2`.

**Step 4: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 5: Commit**

```bash
git add docs/shared-phases.md docs/coordination-patterns.md
git commit -m "feat: add circular dependency detection to Phase 2 and coordination patterns"
```

---

### Task 6: Add Graceful Degradation coordination pattern

**Files:**
- Modify: `docs/coordination-patterns.md`

**Step 1: Add Graceful Degradation pattern**

Insert after Circular Dependency Detection:

```markdown
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
```

**Step 2: Update the Contents list**

Add `- [Graceful Degradation](#graceful-degradation) — scope reduction under resource pressure`.

**Step 3: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 4: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "feat: add graceful degradation coordination pattern"
```

---

### Task 7: Add Warm vs Cold Handoff distinction

**Files:**
- Modify: `docs/coordination-patterns.md`

**Step 1: Enhance the existing Result Handoff Between Teammates section**

In coordination-patterns.md, find the "Result Handoff Between Teammates" section (around line 194). Add a subsection at the end:

```markdown
### Warm vs Cold Handoff

- **Warm handoff**: Lead forwards full context — what was done, why, key decisions, and specific next steps for the receiving teammate. Use when the handoff requires understanding of reasoning.
  ```
  A finished task #3 (auth token refactor). Key changes:
  - Moved token validation to src/auth/validate.ts
  - New interface: TokenResult { valid: boolean, claims: Claims }
  - Decision: used JWT over opaque tokens (see progress.md Decision Log)
  You can now proceed with task #5 using the new TokenResult interface.
  ```

- **Cold handoff**: Lead forwards minimal context — just file paths and a pointer to workspace. Use when the receiving teammate only needs to know what files to read.
  ```
  A finished task #3. Output files: src/auth/validate.ts, src/auth/types.ts.
  Check workspace tasks.md for full details. Proceed with task #5.
  ```

**Default to warm handoffs** — the extra context costs little and prevents follow-up QUESTION messages. Use cold handoffs only when the downstream task is clearly independent (e.g., reviewer just needs to read files).
```

**Step 2: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 3: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "feat: add warm vs cold handoff distinction to result handoff pattern"
```

---

### Task 8: Add Anti-Pattern Catalog

**Files:**
- Modify: `docs/coordination-patterns.md`

**Step 1: Add Anti-Pattern Catalog section**

Add at the very end of coordination-patterns.md, after the Direct Handoff section:

```markdown
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
```

**Step 2: Update the Contents list**

Add `- [Anti-Pattern Catalog](#anti-pattern-catalog) — known coordination pitfalls to avoid` to Contents.

**Step 3: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 4: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "feat: add anti-pattern catalog to coordination patterns"
```

---

### Task 9: Document scaling best practices in team-archetypes.md

**Files:**
- Modify: `docs/team-archetypes.md`

**Step 1: Add Scaling Patterns section**

After the "Design Notes" section and before "See Also", add:

```markdown
## Scaling Patterns

When team size exceeds the default 4-6 limit, use these patterns. They are ordered by complexity — try simpler patterns first.

### Read-Only Extension (5-6 agents)

Add 1-2 read-only teammates (Researchers, Reviewers with `subagent_type: "Explore"`) to a standard 4-agent team. Zero file conflict risk, minimal coordination overhead.

**When to use**: Need parallel investigation alongside implementation.

**Example Phase 2 plan**:
```
Teammates (6 total):
⚠ Team size check: 6 agents (4 core + 2 read-only researchers)
- impl-1 (Implementer): backend auth refactor -> owns src/auth/
- impl-2 (Implementer): frontend auth UI -> owns src/components/auth/
- reviewer (Reviewer): code quality review -> read-only
- tester (Tester): verify auth flows -> read-only
- perf-analyst (Researcher): performance impact analysis -> read-only (Explore)
- sec-researcher (Researcher): security implications -> read-only (Explore)
```

### Phased Execution (12-16+ agents over time)

Break large projects into sequential team waves. Each phase is an independent team (4-6 agents). Workspace carries forward between phases.

**When to use**: Clear sequential stages (research → design → implement → test).

**Protocol**:
1. Run Phase 1 team (e.g., 3 researchers), collect findings
2. Present findings to user, get approval for Phase 2
3. TeamDelete Phase 1, create Phase 2 team (e.g., 4 implementers) reusing same workspace
4. Repeat for Phase 3 (verification)

**Key constraint**: Each phase waits for the previous to complete. High wall-clock time but low concurrent token cost.

### Sub-Agent Specialization (within 4-6 agents)

Senior implementers spawn subagents for independent subtasks within their scope. Multiplies throughput without multiplying team coordination.

**When to use**: A single teammate's task is large enough to parallelize internally.

**Already supported**: See [teammate-roles.md Nested Task Decomposition](teammate-roles.md#nested-task-decomposition-senior-implementers). One level of nesting max.
```

**Step 2: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 3: Commit**

```bash
git add docs/team-archetypes.md
git commit -m "feat: document scaling patterns in team archetypes"
```

---

### Task 10: Update shared-phases.md Lead Processing Rules for new message types

**Files:**
- Modify: `docs/shared-phases.md`

**Step 1: Add PROGRESS and CHECKPOINT to Lead Processing Rules**

In shared-phases.md Phase 4 section, find the Lead Processing Rules table (around line 204-210). Add two new rows:

```markdown
| PROGRESS | Note milestone in `tasks.md` Notes column. If percent indicates near-completion, no action needed. If stalled, trigger Deadline Escalation |
| CHECKPOINT | If `ready_for` lists task IDs, forward checkpoint details to dependent teammate. Log in `progress.md` Handoffs |
```

**Step 2: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 3: Commit**

```bash
git add docs/shared-phases.md
git commit -m "feat: add PROGRESS and CHECKPOINT to lead processing rules"
```

---

### Task 11: Update README.md with new protocol and patterns

**Files:**
- Modify: `README.md`

**Step 1: Update Communication Protocol section**

In README.md, find the Communication Protocol section (line 164). Add the two new optional message types after the existing 5:

```markdown
### Communication Protocol

Teammates use structured messages for clean coordination:

```
STARTING #N:   what I plan to do, which files I'll touch
COMPLETED #N:  what I did, files changed, any concerns
BLOCKED #N:    severity={level}, what's blocking, impact
HANDOFF #N:    what I produced that another teammate needs
QUESTION:      what I need to know
```

Optional extended messages for long-running tasks:

```
PROGRESS #N:   milestone={desc}, percent={0-100}, eta={minutes}
CHECKPOINT #N: intermediate results, artifacts, ready_for=[task IDs]
```
```

**Step 2: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update README with new protocol message types"
```

---

### Task 12: Update CLAUDE.md to reference new patterns and research

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Verify research workspace exists**

Run: `ls .agent-team/0309-protocol-research/final-report.md`
Expected: File exists. If not, this task should be skipped (the reference would be dangling).

**Step 2: Add research reference to CLAUDE.md**

In the File Ownership table, add a row for the research workspace:

```markdown
| `.agent-team/0309-protocol-research/` | Research findings | Reference only — do not modify. Contains 4 reports on protocol, patterns, resilience, and scaling |
```

**Step 3: Run full test suite**

Run: `bash tests/run-tests.sh`
Expected: All tests pass (final verification)

**Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add research findings reference to CLAUDE.md"
```

---

### Task 13: Final verification and version bump

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `package.json`
- Modify: `CHANGELOG.md`

**Step 1: Run full test suite**

Run: `bash tests/run-tests.sh`
Expected: All 78+ assertions pass

**Step 2: Bump version to 2.4.0**

Update version in all three files from `2.3.0` to `2.4.0`:
- `.claude-plugin/plugin.json`: `"version": "2.4.0"`
- `.claude-plugin/marketplace.json`: `"version": "2.4.0"`
- `package.json`: `"version": "2.4.0"`

**Step 3: Add CHANGELOG entry**

Add to top of CHANGELOG.md:

```markdown
## 2.4.0

### Added
- **PROGRESS message type**: Optional granular progress reporting for long-running tasks
- **CHECKPOINT message type**: Intermediate results with downstream task notification
- **Confidence grades**: Optional `[X%]` annotation on reviewer/auditor findings
- **Priority marking**: Optional `priority={critical|high|normal|low}` on STARTING/HANDOFF
- **Checkpoint/Rollback pattern**: Save and resume long-running tasks at natural breakpoints
- **Deadline Escalation pattern**: Proactive time-based escalation for stalled tasks
- **Circular Dependency Detection**: DAG validation in Phase 2 to prevent deadlocks
- **Graceful Degradation pattern**: Controlled scope reduction under resource pressure
- **Warm vs Cold Handoff**: Context-level distinction for result handoffs
- **Anti-Pattern Catalog**: 8 documented coordination pitfalls with prevention/mitigation
- **Scaling Patterns documentation**: Read-only extension, phased execution, sub-agent specialization
```

**Step 4: Validate plugin**

Run: `claude plugin validate .`
Expected: Validation passes

**Step 5: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json package.json CHANGELOG.md
git commit -m "chore: bump version to 2.4.0"
```
