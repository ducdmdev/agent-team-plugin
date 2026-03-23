# Workflow Orchestration Integration — Design Spec

**Date**: 2026-03-23
**Status**: Draft
**Approach**: Pipeline Extensions (Approach B)

## Overview

Integrate 4 workflow orchestration capabilities into the agent-team-plugin's existing 5-phase structure as pipeline extensions (pre-steps and post-steps). No phase renumbering. All features are additive and non-breaking.

### Guidelines Being Addressed

From the user's workflow orchestration philosophy:

1. **Plan Mode Default** — enter plan mode for non-trivial tasks
2. **Subagent Strategy** — already the plugin's core (no gap)
3. **Self-Improvement Loop** — capture lessons, build error pattern library
4. **Verification Before Done** — extend with elegance checks
5. **Demand Elegance** — new reviewer role with quality rubric
6. **Autonomous Bug Fixing** — classify errors, auto-retry, fallback strategies

### Gaps Addressed

| # | Gap | Phase Extension | Type |
|---|-----|-----------------|------|
| 1 | Self-Improvement Loop | Phase 1 pre-step + Phase 5 post-step | Pre + Post |
| 2 | Plan-Mode Orchestration | Phase 2 extension | Extension |
| 3 | Error Recovery Loop | Phase 4 extension | Extension |
| 4 | Elegance Checks | Phase 5 post-step | Post |

---

## Section 1: Phase 1 Pre-Step — `load-prior-context`

### Purpose

Before decomposing the new task, load lessons and error patterns from prior teams to inform better planning.

### Trigger

Always runs at the start of Phase 1, before plan detection.

### Mechanism

1. **Scan `.agent-team/*/lessons.md`** — find all completed teams' lessons files, sorted by date (newest first)
2. **Scan global `~/.claude/agent-team-patterns.json`** — the error pattern library (shared across all projects)
3. **Relevance filter** — match prior lessons by keyword overlap with current task description (e.g., if task mentions "auth", pull lessons from teams that touched auth)
4. **Inject context** — append a `## Learned Context` block to `progress.md` (created during Phase 3 workspace setup) containing:
   - Top 3 most relevant lessons (with source team name)
   - Known error patterns for files/modules in scope
   - Estimation adjustments (e.g., "prior auth team underestimated by 2x")
   - This block is also surfaced in the Phase 2 plan presentation so the user can see what prior context informed the decomposition

### New Templates

#### `lessons.md` (per-team workspace file)

```markdown
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
```

#### `error-patterns.json` (global, at `~/.claude/agent-team-patterns.json`)

```json
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
```

### File Changes

| File | Change |
|------|--------|
| `docs/shared-phases.md` Phase 1 | Add "Pre-step: Load Prior Context" section |
| `docs/workspace-templates.md` | Add `lessons.md` template + `error-patterns.json` schema |
| All 5 `skills/*/SKILL.md` Phase 1 | Reference the pre-step |

### Invariants

- Plan detection (Phase 1a) and decomposition logic remain untouched
- Pre-step runs before them and only adds context
- If no prior lessons or patterns exist, pre-step is a no-op

---

## Section 2: Phase 2 Extension — `plan-mode-gate`

### Purpose

For non-trivial tasks, teammates propose their approach before executing. Lead reviews and approves, preventing wasted work on wrong approaches.

### Trigger

Activates when task complexity ≥ standard (3+ steps or architectural decisions). Lead sets `plan_mode: true` per-teammate in the Phase 2 plan presentation.

### Mechanism

1. **Lead marks plan-mode teammates** during Phase 2 plan presentation:
   ```
   Teammates (3 total):
   - auth-impl-1 (Implementer, plan-mode): token validation → proposes approach before coding
   - auth-impl-2 (Implementer): session management → executes directly (simple enough)
   - auth-reviewer (Reviewer): validate all changes → executes directly
   ```
   User can override: "make all teammates plan-mode" or "skip plan-mode"

2. **Spawn with plan-mode instruction** — plan-mode teammates get an additional spawn directive:
   ```
   PLAN-MODE ACTIVE: Before writing any code, send a PLAN_PROPOSAL message to the lead.
   Do NOT write/edit files until you receive PLAN_APPROVED.
   ```

3. **New message type `PLAN_PROPOSAL`**:
   ```
   PLAN_PROPOSAL #N:
     approach={description of proposed approach}
     alternatives_considered={what else was evaluated and why rejected}
     files_to_touch={list}
     estimated_complexity={low|medium|high}
     risks={potential issues}
   ```

4. **Lead evaluates proposals**:
   - If acceptable → sends `PLAN_APPROVED #N` via SendMessage
   - If needs revision → sends `PLAN_REVISION #N: {feedback}` — teammate revises and resubmits
   - Max 2 revision rounds, then lead decides (accept or reassign)

5. **Workspace tracking** — proposals logged in `progress.md` under new section:
   ```markdown
   ## Plan Proposals
   | Teammate | Task | Proposal | Status | Revisions |
   |----------|------|----------|--------|-----------|
   | auth-impl-1 | #1 | Refactor via adapter pattern | Approved | 0 |
   ```

### Archetype Defaults

| Archetype | Plan-mode default |
|-----------|-------------------|
| Implementation | ON for complexity ≥ standard |
| Research | OFF (researchers explore freely) |
| Audit | OFF (auditors follow checklists) |
| Planning | ON always (planners should propose before drafting) |
| Hybrid | Follows detected archetype rules |

User can always override during Phase 2 approval.

### File Changes

| File | Change |
|------|--------|
| `docs/shared-phases.md` Phase 2 | Add plan-mode gate documentation: when to enable, override rules |
| `docs/communication-protocol.md` | Add `PLAN_PROPOSAL`, `PLAN_APPROVED`, `PLAN_REVISION` message formats |
| `docs/spawn-templates.md` | Add plan-mode variant directive block (injected into any role's spawn prompt) |
| `docs/workspace-templates.md` | Add "Plan Proposals" section template for `progress.md` |
| `docs/coordination-patterns.md` | Add "Plan-Mode Coordination" pattern (evaluate → approve/revise → unblock) |
| `docs/team-archetypes.md` | Add plan-mode defaults per archetype (from Archetype Defaults table above) |
| All 5 `skills/*/SKILL.md` Phase 2 | Reference plan-mode gate; archetype defaults |

### Relationship to Existing `mode: "plan"`

This plan-mode gate is distinct from the Claude Code platform's `mode: "plan"` spawn parameter. The platform `mode: "plan"` gates individual tool use (teammate must get approval before each tool call). The plan-mode gate described here is an **orchestration-level pattern** where the teammate proposes their overall approach via `PLAN_PROPOSAL` messages before the lead authorizes execution. Both can be used together but serve different purposes.

### Invariants

- Phase 2's core approval gate (user approves full team plan) is unchanged
- Plan-mode is an additional layer within that
- User sees which teammates are plan-mode and can override

---

## Section 3: Phase 4 Extension — `error-recovery-loop`

### Purpose

When a teammate hits a blocker, classify the error, check the pattern library, and attempt bounded recovery before escalating.

### Trigger

Activates whenever the lead receives a `BLOCKED` message during Phase 4 coordination.

### Extended BLOCKED Message Format

Teammates now include `error_type`:

```
BLOCKED #N: severity={critical|high|medium|low}, error_type={retry|recoverable|design_flaw|unknown},
           {blocker description}, impact={what can't proceed}
```

Classification guide:

| error_type | When to use | Examples |
|------------|-------------|---------|
| `retry` | Transient/flaky failure, might work on second attempt | Timeout, rate limit, flaky test |
| `recoverable` | Fixable with a different approach, no re-plan needed | Wrong import path, missing dependency, type mismatch |
| `design_flaw` | Fundamental approach won't work, needs re-plan | Interface incompatibility, wrong architecture choice |
| `unknown` | Can't classify — let the lead decide | Novel errors |

### Recovery Decision Tree

```
On BLOCKED received:
├── error_type = retry
│   ├── Check retry count for this task (from issues.md)
│   ├── retries < 2 → Tell teammate: "Retry with: {strategy from pattern library or 'try again'}"
│   └── retries ≥ 2 → Escalate (reclassify as recoverable or design_flaw)
│
├── error_type = recoverable
│   ├── Query error-patterns.json for matching pattern
│   ├── Match found → Tell teammate: "Try recovery strategy: {strategy}, success rate: {N/M}"
│   ├── No match → Lead suggests fix based on blocker description
│   └── If fix fails → Escalate (reclassify as design_flaw or surface to user)
│
├── error_type = design_flaw
│   ├── Check if task has fallback_approach in task-graph.json
│   ├── Fallback exists → Reassign task with fallback approach
│   └── No fallback → Trigger re-plan pattern (from coordination-advanced.md)
│
└── error_type = unknown
    └── Lead classifies based on description, then re-enters decision tree
```

### Fallback Approaches in task-graph.json

Optional field on task nodes:

```json
{
  "id": "task-3",
  "title": "Implement auth middleware",
  "approach": "JWT-based with refresh tokens",
  "fallback_approach": "Session-based with server-side storage",
  "fallback_reason": "Use if JWT library has compatibility issues"
}
```

### Recovery Tracking in issues.md

Extended format:

```markdown
## ISS-003: Token validation timeout
- **Severity**: medium
- **Error type**: retry
- **Affected tasks**: #1
- **Recovery attempts**:
  1. Retry with increased timeout (30s → 60s) — FAILED
  2. Retry with connection pooling — SUCCEEDED
- **Status**: RESOLVED
- **Pattern captured**: Yes (pattern-012)
```

### Generic Recovery Behavior (Role-Based, Not Archetype-Based)

Recovery behavior is determined by the teammate's role characteristics, not the team archetype:

| Role characteristic | Recovery behavior |
|---------------------|-------------------|
| **Has write access** (Implementer, Tester) | Full recovery loop: retry → recover → fallback → escalate |
| **Read-only, produces findings** (Reviewer, Auditor, Analyst, Scout) | No retries — flag as finding, continue with remaining scope |
| **Read-only, produces report** (Researcher, Challenger, Strategist) | Skip blocker, report as gap, move to next research angle |
| **Produces docs** (Planner, Writer) | Recover only — try alternative framing/approach, no code retries |

This means:
- The archetype does NOT dictate recovery — the teammate's role does
- A hybrid team with 2 implementers + 1 researcher naturally gets full recovery for implementers and skip-and-report for the researcher
- Custom roles inherit recovery behavior based on their tool access category

The `docs/teammate-roles.md` role definitions gain a new field: `recovery_class: full | report-gap | skip-and-continue | recover-only`, derived from the role's tool access.

### Bounds and Safety

- Max 2 retries per task for `retry` type
- Max 1 recovery attempt for `recoverable` type
- `design_flaw` always escalates immediately (fallback or re-plan)
- Total recovery budget per team: max 3 recovery cycles across all tasks. After that, surface to user. Track total cycles in `progress.md` using a new field `**Recovery cycles**: 0` (analogous to the existing `**Remediation cycle**: 0` field). Increment on each recovery attempt
- All recovery attempts logged in `issues.md` and `events.log`

### File Changes

| File | Change |
|------|--------|
| `docs/shared-phases.md` Phase 4 | Add "Error Recovery Loop" section with decision tree |
| `docs/communication-protocol.md` | Add `error_type` field to BLOCKED format |
| `docs/coordination-patterns.md` | Add "Error Recovery" pattern with retry/recover/escalate protocol |
| `docs/coordination-advanced.md` | Extend "Re-plan on Block" to reference error classification; add "Fallback Approach" pattern |
| `docs/workspace-templates.md` | Add `fallback_approach` and `fallback_reason` fields to task-graph.json schema; extend issues.md with recovery attempts |
| `docs/teammate-roles.md` | Add `recovery_class` field to each role definition |
| All 5 `skills/*/SKILL.md` Phase 4 | Reference error recovery loop |

### Invariants

- Existing BLOCKED handling (lead decides) still works — `error_type` is a new field, not a replacement
- If teammate sends BLOCKED without `error_type`, lead classifies it as `unknown` and follows the decision tree
- Recovery is bounded and always terminates

---

## Section 4: Phase 5 Post-Step — `quality-and-learning`

### Purpose

After the existing completion gate passes, run an elegance review, capture lessons learned, and update the global error pattern library.

### Trigger

Always runs after Phase 5's existing completion gate checks pass and after the remediation gate (if triggered). Runs before report generation and team shutdown. Specifically, the Phase 5 order becomes:

1. Pre-shutdown commit (existing)
2. Completion gate (existing)
3. Remediation gate (existing, if open issues)
4. **Quality-and-learning post-step** (new — this section)
5. Report generation (existing, now includes elegance + lessons data)
6. Team shutdown (existing)
7. Cleanup (existing)

### Three Sub-Steps (Sequential)

#### Sub-step 1: Elegance Gate

**When**: Only for teams that produced code changes (has at least one teammate with write access who completed tasks). Skipped for pure research/audit/planning teams.

**New Role — Elegance Reviewer**:
- Tools: Read, Grep, Glob, Bash (read-only)
- Scope: Only files touched by implementers (from `file-locks.json`)
- Recovery class: `skip-and-continue` (read-only role)
- **Lifecycle**: Spawned after the remediation gate but before report generation. Included in the normal shutdown sequence. Does NOT count toward the initial team size limit (it is a post-step addition, not part of the original team plan). The team remains alive during this sub-step; the Elegance Reviewer is shut down with the rest of the team in step 6.

**Rubric** (scored 1-5 per dimension):

| Dimension | What it checks |
|-----------|----------------|
| **Simplicity** | Could this be simpler? Unnecessary abstractions? |
| **Consistency** | Follows existing codebase patterns and conventions? |
| **Readability** | Clear naming, logical structure, self-documenting? |
| **Testability** | Easy to test? Proper separation of concerns? |
| **Minimal impact** | Only touches what's necessary? No scope creep? |

**Output**: `ELEGANCE_REVIEW` message to lead:

```
ELEGANCE_REVIEW:
  overall_score={average 1-5}
  dimensions={simplicity: 4, consistency: 5, readability: 3, testability: 4, minimal_impact: 5}
  findings=[{file, line_range, dimension, suggestion, severity=nitpick|improve|refactor}]
```

**Completion gate integration**: Elegance gate is **advisory, not blocking**. Findings go into the final report. The lead includes a summary but does NOT spawn fix tasks unless the user explicitly asks.

#### Sub-step 2: Capture Lessons

**Inputs the lead reviews**:
- `issues.md` — what went wrong, how it was resolved
- `progress.md` — decisions, handoffs, blockers
- `events.log` — timeline, duration per teammate
- `task-graph.json` — estimate vs actual (from `created_at` vs `completed_at` timestamps)
- Recovery attempts from the error-recovery-loop
- Elegance review findings

**Output**: `lessons.md` written to workspace using the template from Section 1.

**Lead fills in**:
- What worked / what failed (from issues + blockers)
- Estimation accuracy (from task-graph timestamps)
- Integration friction points (from handoff and convergence events)
- Recommendations (synthesized from all of the above)

#### Sub-step 3: Update Global Pattern Library

**Rules**:
- Only patterns from **resolved** issues get captured (unresolved = we don't know the fix)
- If a matching pattern already exists, update its `success_rate` counters and `last_seen` date
- If new, create a new entry with `success_rate: {attempts: 1, successes: 1}`
- Deduplication: match by `error_regex` similarity — don't create near-duplicate patterns

**Bounds**: Max 5 new patterns per team. If more issues were resolved, capture the 5 with highest severity.

### File Changes

| File | Change |
|------|--------|
| `docs/shared-phases.md` Phase 5 | Add "Post-step: Quality and Learning" with 3 sub-steps |
| `docs/teammate-roles.md` | Add Elegance Reviewer role definition with rubric |
| `docs/spawn-templates.md` | Add Elegance Reviewer spawn template |
| `docs/communication-protocol.md` | Add `ELEGANCE_REVIEW` message format |
| `docs/workspace-templates.md` | Extend `report.md` template with elegance metrics (uses `lessons.md` template already defined in Section 1) |
| `docs/report-format.md` | Add "Elegance Review" section and "Lessons Summary" section to report template |
| `README.md` | Add Elegance Reviewer to Teammate Roles table (13 roles total) |
| All 5 `skills/*/SKILL.md` Phase 5 | Reference quality-and-learning post-step |

### Invariants

- Existing completion gate checks are unchanged
- Post-step runs after them, not instead of them
- Report generation moves to after the post-step (so it includes elegance findings and lessons summary)

---

## Summary of All File Changes

### New Files

| File | Purpose |
|------|---------|
| `docs/specs/2026-03-23-workflow-orchestration-integration-design.md` | This spec |
| `~/.claude/agent-team-patterns.json` | Global error pattern library (created at runtime by Phase 5 post-step if not present, initialized with `{"patterns": []}`) |

### Modified Files (Documentation)

| File | Sections Added/Changed |
|------|----------------------|
| `docs/shared-phases.md` | Phase 1 pre-step, Phase 2 plan-mode gate, Phase 4 error recovery loop, Phase 5 post-step |
| `docs/communication-protocol.md` | `PLAN_PROPOSAL`, `PLAN_APPROVED`, `PLAN_REVISION`, `error_type` in BLOCKED, `ELEGANCE_REVIEW` |
| `docs/spawn-templates.md` | Plan-mode directive block, Elegance Reviewer template |
| `docs/workspace-templates.md` | `lessons.md` template, `error-patterns.json` schema, `fallback_approach` and `fallback_reason` in task-graph.json, "Plan Proposals" section in progress.md, recovery attempts and `Recovery cycles` counter in issues.md/progress.md |
| `docs/coordination-patterns.md` | "Plan-Mode Coordination" pattern, "Error Recovery" pattern |
| `docs/coordination-advanced.md` | Extend "Re-plan on Block" with error classification, add "Fallback Approach" pattern |
| `docs/teammate-roles.md` | Add Elegance Reviewer role, add `recovery_class` field to all roles |
| `docs/report-format.md` | Add "Elegance Review" and "Lessons Summary" sections |
| `docs/team-archetypes.md` | Add plan-mode defaults per archetype |

### Modified Files (Skills)

| File | Changes |
|------|---------|
| `skills/agent-team/SKILL.md` | Reference all 4 extensions |
| `skills/agent-implement/SKILL.md` | Reference all 4 extensions (full recovery, elegance gate ON) |
| `skills/agent-research/SKILL.md` | Reference pre-step + plan-mode OFF + role-based recovery + lessons only (no elegance gate) |
| `skills/agent-audit/SKILL.md` | Reference pre-step + plan-mode OFF + role-based recovery + lessons only (no elegance gate) |
| `skills/agent-plan/SKILL.md` | Reference pre-step + plan-mode ON + recovery (recover-only) + lessons only |

### Version Impact

This is a **minor version bump** (additive features, no breaking changes). All existing behavior is preserved.

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Plan-mode adds latency to simple tasks | Medium | Defaults are conservative (OFF for research/audit); user can always skip |
| Error recovery loops extend execution time | Low | Hard bounds: 2 retries, 3 cycles total per team |
| Elegance reviewer disagreements with implementer | Low | Advisory only, not blocking |
| Global pattern library grows unbounded | Low | Max 5 patterns per team; deduplication |
| Lessons.md becomes noisy/unhelpful | Medium | Structured template constrains output; relevance filter limits injection |

---

## Testing Plan

### New Structure Tests

| Test | Validates |
|------|-----------|
| Elegance Reviewer role in `teammate-roles.md` | New role exists with rubric and `recovery_class` |
| Elegance Reviewer in `README.md` Teammate Roles table | User-facing docs updated (13 roles) |
| `recovery_class` field on all roles in `teammate-roles.md` | Every role has a `recovery_class` value |
| `PLAN_PROPOSAL` format in `communication-protocol.md` | New message type documented |
| `PLAN_APPROVED` / `PLAN_REVISION` in `communication-protocol.md` | Response message types documented |
| `error_type` field in BLOCKED format in `communication-protocol.md` | Extended format documented |
| `ELEGANCE_REVIEW` format in `communication-protocol.md` | New message type documented |
| `lessons.md` template in `workspace-templates.md` | Template exists with required sections |
| `error-patterns.json` schema in `workspace-templates.md` | Schema exists with required fields |
| `fallback_approach` and `fallback_reason` in task-graph.json schema | New optional fields documented |
| Plan-mode defaults in `team-archetypes.md` | Each archetype has a plan-mode default |
| Plan-mode directive in `spawn-templates.md` | Directive block exists |
| Elegance Reviewer spawn template in `spawn-templates.md` | Template exists |

### New Workspace Template Validation

| Test | Validates |
|------|-----------|
| `lessons.md` template has all 5 sections | What Worked, What Failed, Estimation Accuracy, Integration Friction, Recommendations |
| `progress.md` template has Plan Proposals section | New section added |
| `progress.md` template has Recovery cycles field | New tracking field added |
| `issues.md` template has Recovery attempts subsection | Extended format documented |

### Integration Tests (Manual)

| Test | How to verify |
|------|--------------|
| Phase 1 pre-step loads lessons | Create a completed workspace with `lessons.md`, start a new team touching similar files, verify `## Learned Context` appears in `progress.md` |
| Phase 2 plan-mode gate | Start an implementation team with complexity ≥ standard, verify plan-mode teammates are marked, approve, verify teammates send `PLAN_PROPOSAL` before coding |
| Phase 4 error recovery | Have a teammate send `BLOCKED` with `error_type=retry`, verify lead attempts recovery before escalating |
| Phase 5 elegance gate | Complete an implementation team, verify Elegance Reviewer is spawned and `ELEGANCE_REVIEW` message appears |
| Phase 5 lessons capture | Complete any team, verify `lessons.md` is written to workspace |
| Phase 5 pattern library update | Complete a team with resolved issues, verify `~/.claude/agent-team-patterns.json` is created/updated |
