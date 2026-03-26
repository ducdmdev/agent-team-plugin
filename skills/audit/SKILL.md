---
name: audit
description: >
  Agent Team audit stage. Runs completion gates, elegance review, captures
  lessons learned, updates error pattern library, generates final report.
  Requires completed workspace. Triggers: "audit the team work", "review team results",
  "run verification", "check team output".
argument-hint: "[workspace path]"
allowed-tools: Read, Write, Glob, Grep, Bash, Agent, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, TeamCreate, TeamDelete, SendMessage
---

# Audit Stage Orchestrator

The audit stage owns **Phase 5: Synthesize and Complete**. It runs after the execute stage has coordinated all teammate work.

## Overview

This stage verifies the team's output, captures organizational knowledge, and produces the final report. It covers:

1. Pre-shutdown commit enforcement
2. Archetype-specific completion gates
3. Remediation gate for unresolved issues
4. Elegance review (code quality assessment)
5. Lessons learned capture
6. Error pattern library update
7. Final report generation (with elegance and lessons data)
8. Meta-review of the report by the audit review agent
9. Team shutdown
10. Cleanup

For workspace templates and file schemas, see [workspace-templates.md](../../docs/workspace-templates.md).
For teammate role definitions, see [teammate-roles.md](../../docs/teammate-roles.md).

## Preconditions

Before proceeding, validate the workspace:

1. **Workspace directory must exist** at `.agent-team/{team-name}/` with `progress.md`, `tasks.md`, `issues.md`, and `task-graph.json`
2. **At least one task must be completed** in `task-graph.json` (any node with `status: completed`)
3. **Read the archetype** from `progress.md` field `**Archetype**:` — this determines which completion gates apply and which report variant to generate
4. **If ALL tasks are incomplete** (zero completed nodes), exit with: "Nothing to audit — no tasks have been completed. Run the execute stage first or complete tasks manually."
5. **If some tasks are incomplete**, flag them as ABANDONED in `tasks.md` and `task-graph.json` and proceed with the audit for completed work

> **Pipeline gate**: Check `progress.md` for `**Pipeline status**: executed`. If absent (legacy/manual workspace), proceed with a warning but do not block — treat absence as "not gated" for backward compatibility.

Read workspace state:
```
Read: .agent-team/{team-name}/progress.md
Read: .agent-team/{team-name}/tasks.md
Read: .agent-team/{team-name}/issues.md
Read: .agent-team/{team-name}/task-graph.json
```

## Phase 5: Synthesize

### Phase 5 Ordering

1. **TeamCreate** — create audit team with same team name from workspace
2. **Spawn audit teammates** — you MUST spawn these roles:
   - **Reviewer** (ALWAYS) — runs completion gate checks. See `agents/reviewer.md` for spawn prompt.
   - **Elegance Reviewer** (if ANY teammate had write access and completed tasks) — scores code quality. See `agents/elegance-reviewer.md` for spawn prompt. Skip ONLY for pure research/audit/planning teams with zero code changes.
   - **Audit Reviewer** (ALWAYS) — validates the final report. See `agents/audit-reviewer.md` for spawn prompt.

   > **Do not skip spawning.** The audit team needs all applicable roles to produce a thorough review. Spawn them in parallel — they work on different aspects and don't conflict.
3. Reviewer validates work (completion gate checks per archetype — see `references/completion-gates.md`)
4. **Reviewer: deep code review** — read ALL changed files, review for correctness, bugs, security, integration, test coverage (see Deep Code Review below)
5. Remediation gate (if critical issues from gates OR code review — lead coordinates fixes)
6. Elegance gate (Elegance Reviewer teammate scores code quality)
7. Lessons capture (lead synthesizes from workspace data)
8. Pattern library update (lead writes to `~/.claude/agent-team-patterns.json`)
9. Report generation (lead writes `report.md` — now includes code review findings)
10. Audit Reviewer validates report (sends AUDIT_REVIEW message)
11. **Shutdown teammates** (parallel shutdown requests)
12. **TeamDelete**
13. Cleanup — write `**Pipeline status**: audited` and `**Stage**: audit` to `progress.md`

Execute these 13 steps in order. Each step references its detailed specification below or in supporting files.

### Step 1: Pre-Shutdown Commit

**Applies to**: Teams with write-access teammates (implementation, hybrid with implementers).
**Skip for**: Research, audit, planning teams (read-only).

Message each **implementer** to commit their owned files:
```
Commit your owned files before shutdown.
- Stage ONLY files in your owned area: git add <your owned files>
- Commit with a descriptive message following project conventions
- Send me the commit hash when done
- If the commit fails, fix the issue and retry. Do NOT proceed without a successful commit.
```
Wait for all implementers to confirm. Log failures in `issues.md` as **high** severity.

If worktree isolation was used, run merge after commits:
- Worktree: `scripts/merge-worktrees.sh {team-name}`
- Auto-branching only: `git merge --no-ff {team-name}/{teammate-name}` per branch
- Merge conflicts: log in `issues.md`, assign implementer to resolve

### Step 2: Completion Gate

Run the archetype-specific completion gate checks. See [references/completion-gates.md](references/completion-gates.md) for the full check matrix.

Read the archetype from `progress.md` and apply the corresponding gate:

| Archetype | Checks Required |
|-----------|----------------|
| Implementation | All 8: uncommitted, build, lint, integration, security, issues, plan, docs |
| Research | 2: issues, plan |
| Audit | 4: integration coverage, security coverage, issues, plan |
| Planning | 2: issues, plan |
| Hybrid | Union of all checks required by component archetypes present |

Log gate result in `progress.md` Decision Log.

If any check fails, create fix tasks and assign to appropriate teammates. Re-run failed checks after fixes complete.

### Step 3: Deep Code Review

**Applies to**: Teams that produced code changes (at least one Implementer completed tasks). Skip for pure research/audit/planning teams.

After completion gates pass, the Reviewer reads ALL files changed by the team. This is a thorough review — not the light per-task review from the execute stage.

**What the Reviewer checks:**

| Category | What to look for |
|----------|-----------------|
| **Correctness** | Does the code do what the plan says? Are requirements met? |
| **Bugs** | Edge cases, null checks, error handling, off-by-one, race conditions |
| **Security** | Injection risks, auth gaps, exposed secrets, unsafe input handling |
| **Integration** | Do cross-teammate changes work together? Interface compatibility? |
| **Test coverage** | Do tests actually cover the behavior, not just mock it? Missing test cases? |

**Reviewer sends extended COMPLETED message:**

```
COMPLETED #review:
  gate_results={8/8 passed}
  code_review={N files reviewed, M issues found}
  issues=[{file, line, severity=critical|important|minor, category=bug|security|integration|test-gap, description}]
```

**Processing review findings:**

| Severity | Action |
|----------|--------|
| `critical` | Must fix — goes to remediation gate (step 4) |
| `important` | Logged in `issues.md`, flagged in report. Fix if time allows. |
| `minor` | Logged in report only (like elegance findings) |

**Difference from Elegance Reviewer**: The Reviewer checks **correctness and safety** (does it work? is it secure?). The Elegance Reviewer checks **quality and craft** (is it clean? could it be simpler?). They complement each other — do not skip either one.

### Step 4: Remediation Gate

Review `issues.md` for OPEN items after the completion gate:

- **0 OPEN issues**: Skip — proceed to Step 5
- **OPEN issues exist, remediation cycle = 0**: Present issues to the user, propose a remediation team. Follow the remediation gate protocol in the execute stage's coordination patterns. Set `progress.md` `**Remediation cycle**` to `1` if approved.
- **OPEN issues exist, remediation cycle = 1**: Do NOT spawn another team. Include unresolved issues in the report:
  > **Unresolved issues (require manual follow-up):**
  > - Issue #N (severity): description
  > See `.agent-team/{team-name}/issues.md` for full details.

### Step 5: Elegance Gate

**When to run**: Only if write-access teammates (implementers) completed tasks. Skip for pure research, audit, or planning teams.

See [Elegance Gate](#elegance-gate) section below for details and [references/elegance-rubric.md](references/elegance-rubric.md) for the scoring rubric.

The Elegance Reviewer is spawned with the audit team at stage start (step 2). It is a regular team member, not a post-step addition.

Process the `ELEGANCE_REVIEW` message and include findings in the report. This gate is **advisory only** — findings do not block completion.

### Step 6: Lessons Capture

Synthesize lessons from the entire team execution. See [Lessons Capture](#lessons-capture) section below.

Write `.agent-team/{team-name}/lessons.md` using the template from [workspace-templates.md](../../docs/workspace-templates.md#lessonsmd).

### Step 7: Pattern Library Update

Extract error patterns from resolved issues and update the global library. See [Pattern Library Update](#pattern-library-update) section below.

### Step 8: Report Generation

Write `.agent-team/{team-name}/report.md` using the appropriate report variant. See [references/report-format.md](references/report-format.md) for templates.

Select the variant based on archetype:
- **Implementation**: Standard report (Files Changed)
- **Research**: Findings report (What Was Discovered)
- **Audit**: Audit report (What Was Audited)
- **Planning**: Plan report (What Was Planned)
- **Hybrid**: Standard report; omit Files Changed if no implementation component, substitute the appropriate variant section

Include elegance review data (if Step 5 ran) and lessons summary (from Step 6) in the report. See the Elegance Review and Lessons Summary sections in the report format reference.

**Self-check**: Read the file back. Does it contain the Executive Summary? If not, regenerate.

### Plan Status Update

After the completion gate passes and before the report is finalized, update the source plan file's status (if the team was based on a plan file tracked in `progress.md` References):

| Team outcome | Status value |
|-------------|-------------|
| All plan tasks completed | `Status: COMPLETED — Implemented via team {team-name} (YYYY-MM-DD)` |
| Partial completion | `Status: PARTIAL — {N}/{total} tasks completed via team {team-name} (YYYY-MM-DD). Remaining: {list}` |
| Team failed or abandoned | `Status: ABANDONED — Team {team-name} (YYYY-MM-DD). Reason: {reason}` |

Skip if no plan file was used. See [workspace-templates.md](../../docs/workspace-templates.md#plan-file-conventions) for the full status value reference.

### Step 9: Audit Review Agent

Spawn the audit review agent using the prompt in [agents/audit-reviewer.md](agents/audit-reviewer.md). See [Inter-Stage Review: Audit Review Agent](#inter-stage-review-audit-review-agent) section below.

Process the `AUDIT_REVIEW` message:
- `status=approved` — proceed to shutdown
- `status=revisions_needed` — fix the report/lessons and re-run review (max 2 cycles, then finalize as-is with a note)

### Step 10: Team Shutdown

Shut down teammates in parallel — not sequentially:

```
Send ALL shutdown_request messages in a single turn (parallel SendMessage calls)
Wait for all approval responses
If a teammate rejects: check their reason, resolve, then re-request
```

Update `progress.md` status to `done`, record completion time.

### Step 11: Cleanup

- **Only call TeamDelete after ALL teammates have confirmed shutdown.** TeamDelete may fail if teammates are still active.
- TeamDelete to remove ephemeral team resources (`~/.claude/teams/{team-name}/`). The workspace at `.agent-team/{team-name}/` is NOT deleted — it is the permanent record.
- Clean up idle hook counters: `rm -f /tmp/agent-team-idle-counters/{team-name}--* 2>/dev/null || true`
- Clean up ownership violation tracking: `rm -rf /tmp/agent-team-ownership-violations 2>/dev/null || true`

Report to user:
- Summary of all work completed
- Files modified by each teammate
- **Issues summary**: list any OPEN or MITIGATED issues from `issues.md` with their impact
- Elegance review summary (if applicable)
- Lessons learned highlights
- Any open concerns or follow-up items
- **Workspace path**: `.agent-team/{team-name}/`

### Stage Complete — Next Steps

After the report is presented, show:

```
✓ Audit complete. Report: .agent-team/{team-name}/report.md
  {X}/{Y} tasks completed, {N} issues, elegance {score}/5

Next steps:
  → Review the report at .agent-team/{team-name}/report.md
  → Review lessons at .agent-team/{team-name}/lessons.md
  → Commit the team's work if not already committed
  → Re-run audit if fixes were needed: /agent-team:audit
  → Start a new task: /agent-team:start [next task]
```

When chained via `/agent-team:start`, this is the final output of the entire pipeline. The workspace persists for future reference.

---

## Completion Gates

The completion gate is the primary verification step ensuring team output meets quality standards. Each archetype has a specific set of checks — the audit stage applies the correct gate based on the archetype recorded in `progress.md`.

See [references/completion-gates.md](references/completion-gates.md) for the full check matrix with exact check descriptions, how to run each check, pass criteria, and failure actions.

**Summary table:**

| # | Check | Impl | Research | Audit | Planning | Hybrid |
|---|-------|------|----------|-------|----------|--------|
| 1 | Uncommitted changes | Yes | -- | -- | -- | If implementer |
| 2 | Build & tests | Yes | -- | -- | -- | If implementer |
| 3 | Lint/format | Yes | -- | -- | -- | If implementer |
| 4 | Integration | Yes | -- | Yes (coverage) | -- | If impl or audit |
| 5 | Security scan | Yes | -- | Yes (coverage) | -- | If impl or audit |
| 6 | Workspace issues | Yes | Yes | Yes | Yes | Always |
| 7 | Plan completion | Yes | Yes | Yes | Yes | Always |
| 8 | Documentation sync | Yes | -- | -- | -- | If implementer |

Items marked with -- are N/A for that archetype. Items with qualifiers (e.g., "coverage") have archetype-specific interpretations documented in the reference.

## Elegance Gate

### When to Run

Only for teams where at least one write-access teammate (implementer) completed tasks. This means:
- **Run**: Implementation teams, Hybrid teams with an implementation component
- **Skip**: Research teams, Audit teams, Planning teams

### Advisory Nature

The elegance gate is **advisory only**. Findings are included in the report for the user's reference but do not block completion or create fix tasks (unless the user explicitly requests fixes).

### Process

1. Spawn the Elegance Reviewer agent using [agents/elegance-reviewer.md](agents/elegance-reviewer.md)
2. The reviewer reads all files from `file-locks.json` (implementer-owned files)
3. The reviewer scores each dimension 1-5 using [references/elegance-rubric.md](references/elegance-rubric.md)
4. The reviewer sends an `ELEGANCE_REVIEW` message with overall score, per-dimension scores, and findings
5. The lead records findings in the report's Elegance Review section
6. The lead shuts down the Elegance Reviewer with the rest of the team

### Finding Severity Levels

| Severity | Meaning | Action |
|----------|---------|--------|
| `nitpick` | Style preference, not a quality issue | Include in report only |
| `improve` | Would make the code better, not critical | Include in report only |
| `refactor` | Should change before merge | Include in report; note as follow-up item |

## Lessons Capture

### Inputs

The lead synthesizes lessons from these workspace sources:
- `issues.md` — problems encountered, resolution strategies, severity distribution
- `progress.md` — decisions made, handoffs, recovery cycles
- `events.log` — timeline of team activity, spawn/stop events
- `task-graph.json` — timestamps for estimation accuracy (`created` vs node `completed_at`)
- Elegance review findings (if Step 5 ran)
- Recovery attempts and their outcomes

### Output

Write `.agent-team/{team-name}/lessons.md` using the template from [workspace-templates.md](../../docs/workspace-templates.md#lessonsmd).

See [examples/lessons-example.md](examples/lessons-example.md) for a filled-in example.

### What the Lead Fills In

- **What Worked**: Patterns, tools, approaches that saved time or prevented issues. Look at tasks that completed ahead of estimate, smooth handoffs, effective coordination patterns.
- **What Failed**: Problems encountered with root cause analysis (not just symptoms). Look at issues.md for patterns, blocked events, recovery cycles.
- **Estimation Accuracy**: Compare `task-graph.json` `created` timestamp (approximate start) vs each node's `completed_at`. Calculate delta. Note systematic over- or under-estimation.
- **Integration Friction Points**: Where handoffs or convergence points caused delays. Look at convergence points in `task-graph.json` and handoff log in `progress.md`.
- **Recommendations**: Concrete, actionable advice for future teams with similar scope. Minimum 2 recommendations.

## Pattern Library Update

### Rules

1. **Resolved issues only** — only patterns from issues with Status = RESOLVED get captured. OPEN, MITIGATED, and DEFERRED issues are excluded.
2. **Deduplication** — before adding a new pattern, check existing patterns by `error_regex` similarity. If a matching pattern exists, update its `success_rate` and `last_seen` instead of creating a duplicate.
3. **Max 5 per team** — capture at most 5 new patterns per team execution. Prioritize by issue severity (critical first, then high, medium, low).
4. **Global cap: 200** — the pattern library at `~/.claude/agent-team-patterns.json` holds at most 200 patterns. When the cap is reached, evict patterns with the lowest `success_rate` (fewest successes relative to attempts) before adding new ones.
5. **Directory creation** — if `~/.claude/` does not exist, create it with `mkdir -p ~/.claude`. If the file does not exist, initialize with `{"patterns": []}`.

### Pattern Schema

See [workspace-templates.md](../../docs/workspace-templates.md#error-patternsjson-global) for the full schema.

Each pattern includes:
- `id`: Unique identifier (pattern-NNN)
- `error_regex`: Regex matching the error message
- `error_type`: `retry`, `recoverable`, or `design_flaw`
- `context`: Short description of when this error occurs
- `strategies`: Ordered list of recovery actions
- `success_rate`: `{attempts, successes}`
- `last_seen`: ISO date
- `source_team`: Team that first captured this pattern

### Process

1. Read `issues.md` and filter for RESOLVED issues that have recovery attempts logged
2. Read `~/.claude/agent-team-patterns.json` (or create if missing)
3. For each resolved issue (up to 5, highest severity first):
   a. Extract `error_regex` from the issue description
   b. Check for existing pattern with similar regex
   c. If match: update `success_rate` (increment attempts and successes if recovery succeeded), update `last_seen`
   d. If new: create entry with `success_rate: {attempts: 1, successes: 1}`, set `source_team` to current team
4. Check global cap (200). Evict lowest success_rate entries if needed.
5. Write updated library back to `~/.claude/agent-team-patterns.json`

## Inter-Stage Review: Audit Review Agent

The audit review agent performs a meta-review of the report and lessons quality before the report is presented to the user. This is the final quality gate.

See [agents/audit-reviewer.md](agents/audit-reviewer.md) for the full agent prompt.

### Checks

| Check | What it validates |
|-------|-------------------|
| **Report completeness** | All required sections present per report template for the archetype |
| **Evidence backing** | Every finding in the report has a file reference or concrete example |
| **Lessons actionability** | Lessons in `lessons.md` are specific and reusable (not vague like "communicate better") |
| **Consistency** | No contradictions between report sections (e.g., "0 issues" but issues.md has OPEN items) |
| **Metrics accuracy** | Task counts, file counts, duration match workspace data |
| **Elegance review included** | If elegance gate ran, its findings appear in the report |

### Behavior

- `status=approved` — proceed to shutdown and present report to user
- `status=revisions_needed` — lead fixes the report/lessons and re-runs review (max 2 cycles, then finalize as-is with a note that the report may have quality gaps)

## References

- [references/completion-gates.md](references/completion-gates.md) — archetype-specific gate checks
- [references/elegance-rubric.md](references/elegance-rubric.md) — 5-dimension scoring rubric
- [references/report-format.md](references/report-format.md) — report template and variants with elegance and lessons sections
- [examples/lessons-example.md](examples/lessons-example.md) — sample lessons.md from a completed team
- [agents/elegance-reviewer.md](agents/elegance-reviewer.md) — Elegance Reviewer spawn prompt
- [agents/audit-reviewer.md](agents/audit-reviewer.md) — Audit Review Agent prompt
- [../../docs/workspace-templates.md](../../docs/workspace-templates.md) — workspace file templates and schemas
- [../../docs/teammate-roles.md](../../docs/teammate-roles.md) — role definitions including Elegance Reviewer
- [../../docs/team-archetypes.md](../../docs/team-archetypes.md) — archetype definitions and phase profiles
