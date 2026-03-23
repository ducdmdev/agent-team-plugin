# Workflow Orchestration Integration — Design Spec

**Date**: 2026-03-23
**Status**: Draft
**Approach**: Pipeline Skills + Phase Extensions (Approach B)

## Overview

Two major changes to the agent-team-plugin:

1. **Skill restructure**: Replace 5 archetype-based skills with 4 pipeline-stage skills (`agent-team:start`, `agent-team:plan`, `agent-team:execute`, `agent-team:audit`)
2. **Workflow extensions**: Integrate 4 workflow orchestration capabilities into the pipeline stages

All features are additive. The 5-phase internal logic is preserved but redistributed across pipeline stages.

### Guidelines Being Addressed

From the user's workflow orchestration philosophy:

1. **Plan Mode Default** — enter plan mode for non-trivial tasks
2. **Subagent Strategy** — already the plugin's core (no gap)
3. **Self-Improvement Loop** — capture lessons, build error pattern library
4. **Verification Before Done** — extend with elegance checks
5. **Demand Elegance** — new reviewer role with quality rubric
6. **Autonomous Bug Fixing** — classify errors, auto-retry, fallback strategies

### Gaps Addressed

| # | Gap | Pipeline Stage | Extension Type |
|---|-----|---------------|----------------|
| 1 | Self-Improvement Loop | `plan` (load context) + `audit` (capture lessons) | Pre-load + Post-capture |
| 2 | Plan-Mode Orchestration | `plan` | Gate extension |
| 3 | Error Recovery Loop | `execute` | Coordination extension |
| 4 | Elegance Checks | `audit` | Verification extension |

---

## Section 1: Skill Restructure — Archetype-Based → Pipeline-Stage

### Current Structure (Being Replaced)

```
skills/
├── agent-team/SKILL.md          ← hybrid/catch-all
├── agent-implement/SKILL.md     ← implementation archetype
├── agent-research/SKILL.md      ← research archetype
├── agent-audit/SKILL.md         ← audit archetype
└── agent-plan/SKILL.md          ← planning archetype
```

5 skills sharing ~70% logic via `docs/shared-phases.md`. Archetype differences are limited to Phase 3 spawn config and Phase 5 completion gates. With the new workflow extensions, shared logic grows even further.

### New Structure

```
skills/
├── start/                        → agent-team:start
│   └── SKILL.md                  Entry point — chains plan → execute → audit
│
├── plan/                         → agent-team:plan
│   ├── SKILL.md                  Stage 1: analyze + decompose + plan-mode proposals
│   ├── references/
│   │   ├── plan-mode-protocol.md     Plan-mode gate rules, message formats, revision limits
│   │   └── prior-context-loading.md  How to scan lessons + error patterns, relevance filtering
│   ├── examples/
│   │   └── plan-proposal-example.md  Sample PLAN_PROPOSAL exchange
│   └── agents/
│       └── plan-reviewer.md          Prompt for reviewing teammate proposals
│
├── execute/                      → agent-team:execute
│   ├── SKILL.md                  Spawn + coordinate + error recovery
│   ├── references/
│   │   ├── error-recovery-protocol.md    Decision tree, bounds, tracking
│   │   ├── coordination-patterns.md      Core conflict resolution, handoffs
│   │   └── communication-protocol.md     Structured message formats
│   ├── agents/
│   │   ├── spawn-templates.md            Teammate spawn prompts for all roles
│   │   └── execute-reviewer.md           Smoke test before audit handoff
│   └── scripts/
│       └── (hook scripts remain in plugin-root hooks/ and scripts/)
│
└── audit/                        → agent-team:audit
    ├── SKILL.md                  Verify + elegance + lessons + report
    ├── references/
    │   ├── completion-gates.md       Archetype-specific gate checks
    │   ├── elegance-rubric.md        5-dimension scoring rubric
    │   └── report-format.md          Final report template + variants
    ├── examples/
    │   └── lessons-example.md        Sample lessons.md from a completed team
    └── agents/
        ├── elegance-reviewer.md      Prompt for the Elegance Reviewer
        └── audit-reviewer.md         Meta-review of report quality
```

### How Pipeline Stages Map to Phases

| Pipeline Stage | Phases Covered | What It Owns |
|---------------|----------------|--------------|
| `agent-team:start` | Orchestration layer | Chains plan → execute → audit; detects archetype; can re-invoke individual stages |
| `agent-team:plan` | Phase 1 + Phase 2 | Analyze task, load prior context, decompose, plan-mode gate, present plan for user approval |
| `agent-team:execute` | Phase 3 + Phase 4 | Create workspace, spawn teammates, coordinate, error recovery loop, track progress |
| `agent-team:audit` | Phase 5 | Completion gate, elegance review, lessons capture, pattern library update, report generation, shutdown |

### Archetype as Configuration, Not Separate Skill

The archetype (implementation, research, audit, planning, hybrid) becomes a **configuration parameter** passed between stages, not a separate skill. It determines:

- Which completion gates apply (owned by `audit` stage)
- Which roles are spawned (owned by `execute` stage)
- Plan-mode defaults (owned by `plan` stage)
- Report variant (owned by `audit` stage)

The `start` skill detects the archetype from the task description (same detection logic currently in `agent-team/SKILL.md`) and writes it to the workspace `progress.md` as `**Archetype**: {type}`. Each stage reads archetype config from this field. When `plan` is invoked independently, it detects the archetype itself and writes it.

### Independent Invocation

Each stage can be invoked independently:

| Command | Use Case |
|---------|----------|
| `/agent-team:start refactor auth` | Full pipeline — plan → execute → audit |
| `/agent-team:plan refactor auth` | Just planning — analyze, decompose, get user approval. Stops after Phase 2 |
| `/agent-team:execute` | Resume from existing plan. **Preconditions**: workspace directory exists at `.agent-team/{name}/` with `progress.md` (containing `**Archetype**` and `**Status**: approved`), `tasks.md` (with task breakdown), and `task-graph.json` (with pending tasks) |
| `/agent-team:audit` | Re-run verification. **Preconditions**: workspace directory exists with `task-graph.json` where at least one task has `status: completed`. Incomplete tasks are flagged as ABANDONED in the report. If all tasks are incomplete, audit exits with "nothing to audit" |

### Where Shared Content Lives

Content that is truly shared across stages stays in plugin-root `docs/`. Stage-specific content moves into the skill folder.

**Stays in `docs/` (shared across stages)**:

| File | Why shared |
|------|-----------|
| `docs/workspace-templates.md` | All stages read/write workspace files |
| `docs/teammate-roles.md` | `plan` selects roles, `execute` spawns them, `audit` reviews their output |
| `docs/team-archetypes.md` | `start` detects archetype, all stages use it as config |
| `docs/custom-roles.md` | Reference for users, not stage-specific |

**Moves into skill folders (stage-specific)**:

| Current Location | New Location | Reason |
|-----------------|-------------|--------|
| `docs/shared-phases.md` Phase 1+2 content | `skills/plan/SKILL.md` + `skills/plan/references/` | Owned entirely by plan stage |
| `docs/shared-phases.md` Phase 3+4 content | `skills/execute/SKILL.md` + `skills/execute/references/` | Owned entirely by execute stage |
| `docs/shared-phases.md` Phase 5 content | `skills/audit/SKILL.md` + `skills/audit/references/` | Owned entirely by audit stage |
| `docs/spawn-templates.md` | `skills/execute/agents/spawn-templates.md` | Only execute stage spawns teammates |
| `docs/communication-protocol.md` | `skills/execute/references/communication-protocol.md` | Execute stage coordinates communication |
| `docs/coordination-patterns.md` | `skills/execute/references/coordination-patterns.md` | Execute stage handles coordination |
| `docs/coordination-advanced.md` | Merged into `skills/execute/references/coordination-patterns.md` | Single file for all coordination patterns (core + advanced) |
| `docs/report-format.md` | `skills/audit/references/report-format.md` | Audit stage generates reports |

**Deleted after migration**:
- `docs/shared-phases.md` — content distributed across 3 stage skills
- `skills/agent-team/SKILL.md` — replaced by `skills/start/SKILL.md`
- `skills/agent-implement/SKILL.md` — absorbed into archetype config
- `skills/agent-research/SKILL.md` — absorbed into archetype config
- `skills/agent-audit/SKILL.md` — absorbed into archetype config (note: different from `skills/audit/` which is the pipeline stage)
- `skills/agent-plan/SKILL.md` — absorbed into archetype config (note: different from `skills/plan/` which is the pipeline stage)

### SKILL.md Frontmatter

Each skill's frontmatter follows the standard pattern:

**`skills/start/SKILL.md`**:
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

**`skills/plan/SKILL.md`**:
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

**`skills/execute/SKILL.md`**:
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

**`skills/audit/SKILL.md`**:
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

> **Note on plugin naming**: Claude Code plugins namespace skills as `{plugin-name}:{skill-name}`. Since `plugin.json` sets the plugin name to `agent-team`, skills named `start`, `plan`, `execute`, `audit` in their folder/frontmatter are invoked as `agent-team:start`, `agent-team:plan`, etc.

### Migration Path

This is a **major version bump** (skill names change, folder structure changes). Migration steps:

1. Create new skill folders (`start/`, `plan/`, `execute/`, `audit/`) with SKILL.md and supporting files
2. Distribute `shared-phases.md` content into the 3 stage skills
3. Move stage-specific docs into skill folders
4. Update `docs/custom-roles.md` and `docs/team-archetypes.md` cross-references
5. Update test suite for new structure
6. **Verify**: Run `bash tests/run-tests.sh` — all new tests must pass
7. Delete old skill folders (`agent-team/`, `agent-implement/`, `agent-research/`, `agent-audit/`, `agent-plan/`)
8. Delete migrated `docs/` files (`shared-phases.md`, `spawn-templates.md`, etc.)
9. **Verify again**: Run `bash tests/run-tests.sh` — confirm no regressions
10. Update README, CLAUDE.md, CHANGELOG
11. Bump version in `plugin.json` and `marketplace.json`

### Relative Path Convention

Files within a skill folder use relative paths:
- Skill-local references: `references/plan-mode-protocol.md` (from SKILL.md)
- Shared docs in plugin root: `../../docs/teammate-roles.md` (from `skills/plan/SKILL.md` → `docs/`)
- Cross-stage references: avoid where possible; use shared `docs/` files instead

### Test Suite Migration

Key test breakages to address in `tests/structure/test-doc-references.sh`:
- Remove: assertion that `docs/shared-phases.md` exists (it's deleted)
- Remove: assertions for `skills/agent-*/SKILL.md` glob pattern (old skills deleted)
- Add: assertions for `skills/start/SKILL.md`, `skills/plan/SKILL.md`, `skills/execute/SKILL.md`, `skills/audit/SKILL.md`
- Add: assertions that each stage skill's relative refs resolve (e.g., `references/plan-mode-protocol.md` exists)
- Update: `docs/*.md` reference checks to exclude migrated files
- Add: cross-reference validation for `docs/team-archetypes.md` and `docs/custom-roles.md` pointing to valid targets

---

## Section 2: `agent-team:plan` — Load Prior Context + Plan-Mode Gate

### Purpose

Owns Phase 1 (analyze + decompose) and Phase 2 (present plan + user approval). New: loads prior lessons before decomposing and enables plan-mode for non-trivial teammates.

### Prior Context Loading (Phase 1 Pre-Step)

Runs at the start of Phase 1, before plan detection.

1. **Scan `.agent-team/*/lessons.md`** — find all completed teams' lessons files, sorted by date (newest first)
2. **Scan global `~/.claude/agent-team-patterns.json`** — the error pattern library (shared across all projects)
3. **Relevance filter** — match prior lessons by keyword overlap with current task description
4. **Inject context** — collect a `## Learned Context` block in memory during the plan stage. This block is written to `progress.md` after the execute stage creates the workspace (or the plan stage creates a minimal `progress.md` if invoked independently). Contents:
   - Top 3 most relevant lessons (with source team name)
   - Known error patterns for files/modules in scope
   - Estimation adjustments (e.g., "prior auth team underestimated by 2x")
   - This block is also surfaced in the Phase 2 plan presentation so the user sees what informed the decomposition
5. If no prior lessons or patterns exist, this step is a no-op

#### `lessons.md` Template (per-team workspace file)

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

#### `error-patterns.json` Schema (global, at `~/.claude/agent-team-patterns.json`)

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

### Plan-Mode Gate (Phase 2 Extension)

Activates when task complexity ≥ standard (3+ steps or architectural decisions).

1. **Lead marks plan-mode teammates** in plan presentation:
   ```
   Teammates (3 total):
   - auth-impl-1 (Implementer, plan-mode): token validation → proposes approach before coding
   - auth-impl-2 (Implementer): session management → executes directly (simple enough)
   - auth-reviewer (Reviewer): validate all changes → executes directly
   ```
   User can override: "make all teammates plan-mode" or "skip plan-mode"

2. **Plan-mode directive** (injected by the `execute` stage during spawning, not by `plan` stage):
   ```
   PLAN-MODE ACTIVE: Before writing any code, send a PLAN_PROPOSAL message to the lead.
   Do NOT write/edit files until you receive PLAN_APPROVED.
   ```
   The `plan` stage only *marks* which teammates get plan-mode in the approved plan. The `execute` stage reads these marks and *injects the directive* into spawn prompts. PLAN_PROPOSAL evaluation also happens during `execute` (Phase 4 coordination), not during `plan`.

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
   - Acceptable → `PLAN_APPROVED #N`
   - Needs revision → `PLAN_REVISION #N: {feedback}` — max 2 rounds, then lead decides
   - Proposals tracked in `progress.md` under `## Plan Proposals` section

5. **Archetype defaults**:

   | Archetype | Plan-mode default |
   |-----------|-------------------|
   | Implementation | ON for complexity ≥ standard |
   | Research | OFF (researchers explore freely) |
   | Audit | OFF (auditors follow checklists) |
   | Planning | ON always (planners should propose before drafting) |
   | Hybrid | Follows detected archetype rules |

### Relationship to Existing `mode: "plan"`

This plan-mode gate is distinct from the Claude Code platform's `mode: "plan"` spawn parameter. The platform `mode: "plan"` gates individual tool use. The plan-mode gate described here is an **orchestration-level pattern** where the teammate proposes their overall approach via `PLAN_PROPOSAL` messages before the lead authorizes execution. Both can be used together but serve different purposes.

### Inter-Stage Review: Plan Review Agent

**When**: Mandatory — runs after plan decomposition, BEFORE presenting the plan to the user for approval.

**Purpose**: Catch plan quality issues before the user sees the plan. The user should review a pre-validated plan, not raw output.

**Agent**: `skills/plan/agents/plan-reviewer.md`
- Tools: Read, Grep, Glob (read-only)
- Scope: Reads the draft plan from workspace (`progress.md`, `tasks.md`, `task-graph.json`)

**Checks**:

| Check | What it validates |
|-------|-------------------|
| **Completeness** | Every task has an owner, description, and dependencies |
| **Dependency integrity** | No circular dependencies, no orphaned tasks, convergence points identified |
| **File ownership** | No overlapping file assignments between teammates |
| **Scope sanity** | Task count vs. team size is reasonable (not 10 tasks for 2 teammates) |
| **Missing coverage** | Common gaps: no test task, no review task, no integration verification |
| **Estimate plausibility** | Flags tasks with no estimate or estimates that seem off (e.g., "refactor entire module" marked as low complexity) |

**Output**: `PLAN_REVIEW` message to lead:
```
PLAN_REVIEW:
  status={approved|issues_found}
  issues=[{check, severity=blocking|warning, description, suggestion}]
```

**Behavior**:
- If `status=approved` → lead presents plan to user as-is
- If `status=issues_found` with only warnings → lead presents plan with warnings noted
- If `status=issues_found` with blocking issues → lead fixes the plan and re-runs the review (max 2 cycles, then present with caveats)

### Stage-Specific Files

| File | Content |
|------|---------|
| `skills/plan/references/plan-mode-protocol.md` | Plan-mode rules, message formats, revision limits, archetype defaults |
| `skills/plan/references/prior-context-loading.md` | Lessons scanning, pattern library querying, relevance filtering algorithm |
| `skills/plan/examples/plan-proposal-example.md` | Sample PLAN_PROPOSAL → PLAN_APPROVED exchange |
| `skills/plan/agents/plan-reviewer.md` | Plan review agent prompt — validates plan quality before user approval |

### Invariants

- Plan detection (existing Phase 1a) and decomposition logic are preserved
- Phase 2's core approval gate (user approves full team plan) is unchanged — the review agent runs BEFORE this gate, not instead of it
- Plan-mode is an additional layer within Phase 2
- Prior context loading is a no-op if no prior data exists

---

## Section 3: `agent-team:execute` — Coordination + Error Recovery

### Purpose

Owns Phase 3 (create workspace, spawn teammates) and Phase 4 (coordinate, track progress). New: error classification and bounded auto-recovery.

### Error Recovery Loop (Phase 4 Extension)

Activates whenever the lead receives a `BLOCKED` message.

#### Extended BLOCKED Message Format

```
BLOCKED #N: severity={critical|high|medium|low}, error_type={retry|recoverable|design_flaw|unknown},
           {blocker description}, impact={what can't proceed}
```

| error_type | When to use | Examples |
|------------|-------------|---------|
| `retry` | Transient/flaky failure | Timeout, rate limit, flaky test |
| `recoverable` | Fixable with different approach, no re-plan | Wrong import path, missing dependency |
| `design_flaw` | Fundamental approach won't work | Interface incompatibility, wrong architecture |
| `unknown` | Can't classify | Novel errors |

#### Recovery Decision Tree

```
On BLOCKED received:
├── error_type = retry
│   ├── retries < 2 → Tell teammate: "Retry with: {strategy from pattern library or 'try again'}"
│   └── retries ≥ 2 → Escalate (reclassify as recoverable or design_flaw)
│
├── error_type = recoverable
│   ├── Pattern match found → "Try: {strategy}, success rate: {N/M}"
│   ├── No match → Lead suggests fix
│   └── Fix fails → Escalate (reclassify or surface to user)
│
├── error_type = design_flaw
│   ├── Fallback exists in task-graph.json → Reassign with fallback approach
│   └── No fallback → Trigger re-plan pattern
│
└── error_type = unknown
    └── Lead classifies, re-enters tree
```

#### Fallback Approaches in task-graph.json

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

#### Recovery Tracking in issues.md

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

#### Generic Recovery Behavior (Role-Based)

Recovery is determined by the teammate's role, not the team archetype:

| Role characteristic | Recovery behavior |
|---------------------|-------------------|
| **Has write access** (Implementer, Tester) | Full: retry → recover → fallback → escalate |
| **Read-only, produces findings** (Reviewer, Auditor, Analyst, Scout) | Flag as finding, continue with remaining scope |
| **Read-only, produces report** (Researcher, Challenger, Strategist) | Report as gap, move to next angle |
| **Produces docs** (Planner, Writer) | Recover only — try alternative framing |

The `docs/teammate-roles.md` role definitions gain a new field: `recovery_class: full | report-gap | skip-and-continue | recover-only`. Added as a bold field in each role's markdown section (e.g., `**Recovery class**: full`), consistent with the existing field format (`**Tools**: ...`).

#### Bounds and Safety

- Max 2 retries per task for `retry` type
- Max 1 recovery attempt for `recoverable` type
- `design_flaw` always escalates immediately
- Total recovery budget: max 3 cycles per team. Track in `progress.md` as `**Recovery cycles**: 0`
- All recovery attempts logged in `issues.md` and `events.log`

### Inter-Stage Review: Execute Review Agent

**When**: Mandatory — runs after all tasks complete (or are abandoned), BEFORE handoff to the audit stage.

**Purpose**: Quick smoke test to catch obvious failures before the full audit. Saves the audit stage from reviewing obviously broken output.

**Agent**: `skills/execute/agents/execute-reviewer.md`
- Tools: Read, Grep, Glob, Bash (read-only — `git status`, `git diff`, test runners)
- Scope: Workspace files + all files owned by teammates (from `file-locks.json`)

**Checks**:

| Check | What it validates |
|-------|-------------------|
| **Files exist** | All files listed in `file-locks.json` exist on disk |
| **No uncommitted changes** | `git status` shows clean for owned files |
| **Build passes** | `npm run build` / `tsc` / equivalent exits 0 (if applicable) |
| **Tests pass** | `npm test` / equivalent exits 0 (if applicable) |
| **No merge conflicts** | No conflict markers (`<<<<<<<`) in owned files |
| **Handoffs resolved** | All HANDOFF messages have a corresponding COMPLETED or acknowledgment |
| **Open issues** | Count of OPEN issues in `issues.md` — reported but not blocking |

**Output**: `EXECUTE_REVIEW` message to lead:
```
EXECUTE_REVIEW:
  status={ready_for_audit|issues_found}
  issues=[{check, severity=blocking|warning, description}]
  summary={N tasks completed, M files changed, K open issues}
```

**Behavior**:
- If `status=ready_for_audit` → proceed to audit stage
- If `status=issues_found` with warnings only → proceed to audit with warnings forwarded
- If `status=issues_found` with blocking issues → lead attempts remediation (one cycle: fix and re-review). If still blocking after remediation, proceed to audit anyway with blocking issues flagged — the audit stage will capture them in the report

### Stage-Specific Files

| File | Content |
|------|---------|
| `skills/execute/references/error-recovery-protocol.md` | Decision tree, error_type classification guide, bounds, tracking format |
| `skills/execute/references/coordination-patterns.md` | Core conflict resolution, handoffs, error recovery pattern (migrated from `docs/`) |
| `skills/execute/references/communication-protocol.md` | All message formats including extended BLOCKED with error_type (migrated from `docs/`) |
| `skills/execute/agents/spawn-templates.md` | All teammate spawn prompts including plan-mode directive (migrated from `docs/`) |
| `skills/execute/agents/execute-reviewer.md` | Execute review agent prompt — smoke test before audit handoff |

### Invariants

- Existing BLOCKED handling still works — `error_type` is additive
- If teammate sends BLOCKED without `error_type`, lead classifies as `unknown`
- Recovery is bounded and always terminates
- Execute review agent does NOT block handoff to audit — blocking issues are forwarded, not gates

---

## Section 4: `agent-team:audit` — Elegance + Lessons + Report

### Purpose

Owns Phase 5 (completion gate, report, shutdown). New: elegance review, lessons capture, and pattern library update.

### Phase 5 Ordering

1. Pre-shutdown commit (existing)
2. Completion gate (existing)
3. Remediation gate (existing, if open issues)
4. **Elegance gate** (new — Sub-step 1)
5. **Lessons capture** (new — Sub-step 2)
6. **Pattern library update** (new — Sub-step 3)
7. Report generation (existing, now includes elegance + lessons data)
8. **Audit review agent** (new — validates report quality before presenting to user)
9. Team shutdown (existing)
10. Cleanup (existing)

### Sub-step 1: Elegance Gate

**When**: Only for teams that produced code changes (at least one write-access teammate completed tasks). Skipped for pure research/audit/planning teams.

**New Role — Elegance Reviewer**:
- Tools: Read, Grep, Glob, Bash (read-only — limited to verification commands like `npm test`, `npm run lint`, `tsc --noEmit`; no write operations)
- Scope: Only files touched by implementers (from `file-locks.json`)
- Recovery class: `skip-and-continue` (appropriate because the role is advisory — if it hits a blocker, skip and continue; findings are informational, not blocking)
- **Lifecycle**: Spawned after the remediation gate but before report generation. Does NOT count toward the initial team size limit (post-step addition). Shut down with the rest of the team in step 8.

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

**Advisory, not blocking.** Findings go into the final report. No fix tasks spawned unless user explicitly asks.

### Sub-step 2: Capture Lessons

Lead synthesizes lessons from the entire team execution.

**Inputs**: `issues.md`, `progress.md`, `events.log`, `task-graph.json` timestamps, recovery attempts, elegance findings.

**Output**: `lessons.md` written to workspace using the template defined in Section 2.

**Lead fills in**: What worked/failed, estimation accuracy, integration friction points, recommendations.

### Sub-step 3: Update Global Pattern Library

- Only patterns from **resolved** issues get captured
- If matching pattern exists → update `success_rate` and `last_seen`
- If new → create entry with `success_rate: {attempts: 1, successes: 1}`
- Deduplication by `error_regex` similarity
- Max 5 new patterns per team (highest severity first)
- Global library cap: 200 patterns maximum. When cap is reached, evict patterns with the lowest `success_rate` (least useful) before adding new ones
- If `~/.claude/agent-team-patterns.json` doesn't exist, create `~/.claude/` directory if needed (`mkdir -p`) and initialize with `{"patterns": []}`

### Inter-Stage Review: Audit Review Agent

**When**: Mandatory — runs after report generation, BEFORE team shutdown. This is the final quality gate.

**Purpose**: Meta-review of the audit output itself — ensures the report is complete, lessons are actionable, and findings are backed by evidence. Catches audit quality issues before the report is presented to the user.

**Agent**: `skills/audit/agents/audit-reviewer.md`
- Tools: Read, Grep, Glob (read-only)
- Scope: Workspace files only (`report.md`, `lessons.md`, `issues.md`, `progress.md`)

**Checks**:

| Check | What it validates |
|-------|-------------------|
| **Report completeness** | All required sections present per report template for the archetype |
| **Evidence backing** | Every finding in the report has a file reference or concrete example |
| **Lessons actionability** | Lessons in `lessons.md` are specific and reusable (not vague like "communicate better") |
| **Consistency** | No contradictions between report sections (e.g., "0 issues" but issues.md has OPEN items) |
| **Metrics accuracy** | Task counts, file counts, duration match workspace data |
| **Elegance review included** | If elegance gate ran, its findings appear in the report |

**Output**: `AUDIT_REVIEW` message to lead:
```
AUDIT_REVIEW:
  status={approved|revisions_needed}
  issues=[{check, severity=blocking|warning, description, fix_suggestion}]
```

**Behavior**:
- If `status=approved` → proceed to shutdown and present report to user
- If `status=revisions_needed` → lead fixes the report/lessons and re-runs review (max 2 cycles, then finalize as-is with a note that the report may have quality gaps)

### Stage-Specific Files

| File | Content |
|------|---------|
| `skills/audit/references/completion-gates.md` | Archetype-specific gate checks: maps each archetype to its required checks (e.g., Implementation → 8 checks, Research → 2 checks). Migrated from the per-archetype Phase 5 overrides in the old `agent-implement/SKILL.md`, `agent-research/SKILL.md`, etc. This is the single source of truth for "which gates apply to which archetype" |
| `skills/audit/references/elegance-rubric.md` | 5-dimension rubric with scoring guide and examples |
| `skills/audit/references/report-format.md` | Report template + variants + new elegance/lessons sections (migrated from `docs/`) |
| `skills/audit/examples/lessons-example.md` | Sample `lessons.md` from a completed team |
| `skills/audit/agents/elegance-reviewer.md` | Spawn prompt for Elegance Reviewer |
| `skills/audit/agents/audit-reviewer.md` | Audit review agent prompt — meta-review of report and lessons quality |

### Invariants

- Existing completion gate checks unchanged
- Post-steps run after them, not instead
- Report generation now includes elegance and lessons data
- Audit review agent runs after report generation but before shutdown — it reviews the report, not the code

---

## Section 5: `agent-team:start` — Entry Point

### Purpose

The user-facing entry point that chains all 3 pipeline stages. Detects archetype, then orchestrates plan → execute → audit.

### Behavior

1. **Receive task description** from user
2. **Detect archetype** (same logic currently in `agent-team/SKILL.md`):
   - Implementation: build, refactor, fix, migrate
   - Research: investigate, analyze, compare
   - Audit: review, assess, evaluate
   - Planning: design, architect, produce specs
   - Hybrid: mixed or unclear
3. **Invoke `agent-team:plan`** with task + archetype config
   - Plan review agent validates the plan
   - User approves the validated plan
4. **Invoke `agent-team:execute`** with approved plan
   - Execute review agent smoke-tests the output
5. **Invoke `agent-team:audit`** with reviewed workspace
   - Audit review agent validates the final report

If any stage fails or the user cancels, the pipeline stops. Workspace persists for resumption.

**Full pipeline with review agents**:
```
plan → [plan-review] → user approval → execute → [execute-review] → audit → [audit-review] → report to user
```

### Stage Chaining Mechanism

The `start` skill chains stages by **inlining their logic sequentially within a single skill execution**. It does NOT use the Skill tool to invoke other skills or spawn subagents per stage. Instead:

1. `start/SKILL.md` contains the archetype detection logic and a sequential orchestration flow
2. Each stage's SKILL.md defines the logic for that stage; `start` reads and follows the same logic inline
3. The workspace directory (`.agent-team/{name}/`) is the handoff mechanism between stages — each stage reads workspace state left by the previous stage

When stages are invoked independently (e.g., `/agent-team:execute`), they read workspace state directly. When chained via `start`, the lead executes each stage's logic in sequence within the same session.

This means `start/SKILL.md` references the other 3 skills' logic via `Read` instructions (e.g., "Read `../plan/SKILL.md` and follow Phase 1+2"). The actual phase logic lives in the stage skills; `start` orchestrates the order.

### Skill File

`skills/start/SKILL.md` is lightweight — primarily archetype detection logic, stage ordering, and Read references to the 3 stage skills. No `references/`, `examples/`, or `agents/` subfolders needed.

---

## Summary of All File Changes

### New Files

| File | Purpose |
|------|---------|
| `skills/start/SKILL.md` | Entry point skill |
| `skills/plan/SKILL.md` | Plan stage skill |
| `skills/plan/references/plan-mode-protocol.md` | Plan-mode rules and formats |
| `skills/plan/references/prior-context-loading.md` | Lessons/pattern loading algorithm |
| `skills/plan/examples/plan-proposal-example.md` | Sample proposal exchange |
| `skills/plan/agents/plan-reviewer.md` | Plan review agent — validates plan quality before user approval |
| `skills/execute/SKILL.md` | Execute stage skill |
| `skills/execute/references/error-recovery-protocol.md` | Error recovery decision tree |
| `skills/execute/references/coordination-patterns.md` | Migrated + extended from `docs/` |
| `skills/execute/references/communication-protocol.md` | Migrated + extended from `docs/` |
| `skills/execute/agents/spawn-templates.md` | Migrated from `docs/` |
| `skills/execute/agents/execute-reviewer.md` | Execute review agent — smoke test before audit handoff |
| `skills/audit/SKILL.md` | Audit stage skill |
| `skills/audit/references/completion-gates.md` | Archetype-specific gates |
| `skills/audit/references/elegance-rubric.md` | 5-dimension rubric |
| `skills/audit/references/report-format.md` | Migrated + extended from `docs/` |
| `skills/audit/examples/lessons-example.md` | Sample lessons.md |
| `skills/audit/agents/elegance-reviewer.md` | Elegance Reviewer prompt |
| `skills/audit/agents/audit-reviewer.md` | Audit review agent — meta-review of report quality |
| `~/.claude/agent-team-patterns.json` | Global error pattern library (created at runtime if not present) |

### Deleted Files

| File | Reason |
|------|--------|
| `skills/agent-team/SKILL.md` | Replaced by `skills/start/SKILL.md` |
| `skills/agent-implement/SKILL.md` | Absorbed into archetype config |
| `skills/agent-research/SKILL.md` | Absorbed into archetype config |
| `skills/agent-audit/SKILL.md` | Absorbed into archetype config |
| `skills/agent-plan/SKILL.md` | Absorbed into archetype config |
| `docs/shared-phases.md` | Content distributed across 3 stage skills |
| `docs/spawn-templates.md` | Migrated to `skills/execute/agents/` |
| `docs/communication-protocol.md` | Migrated to `skills/execute/references/` |
| `docs/coordination-patterns.md` | Migrated to `skills/execute/references/` |
| `docs/coordination-advanced.md` | Merged into `skills/execute/references/coordination-patterns.md` |
| `docs/report-format.md` | Migrated to `skills/audit/references/` |

### Modified Files

| File | Change |
|------|--------|
| `docs/workspace-templates.md` | Add `lessons.md` template, `error-patterns.json` schema, `fallback_approach`/`fallback_reason` in task-graph.json, Plan Proposals section in progress.md, recovery tracking in issues.md, Recovery cycles counter |
| `docs/teammate-roles.md` | Add Elegance Reviewer role (13 entries total: Leader + 12 teammate roles), add `recovery_class` field to all roles |
| `docs/team-archetypes.md` | Add plan-mode defaults per archetype; fix cross-references to migrated docs (e.g., `coordination-advanced.md` → `skills/execute/references/coordination-patterns.md`); update "See Also" section skill references from old names (`/agent-implement`, `/agent-research`, etc.) to new names (`/agent-team:start`, `/agent-team:plan`, etc.) |
| `docs/custom-roles.md` | Update `/agent-team` reference to `/agent-team:start` |
| `.claude-plugin/plugin.json` | Major version bump |
| `.claude-plugin/marketplace.json` | Major version bump (sync) |
| `README.md` | Update skill commands, folder structure, Teammate Roles table (13 roles), pipeline stage documentation |
| `CLAUDE.md` | Update architecture, file ownership table, skill editing guidelines, common tasks |
| `CHANGELOG.md` | Add major version entry |
| `tests/` | Update structure tests for new skill folders, add pipeline stage tests |

### Preserved Files (No Changes)

| File | Reason |
|------|--------|
| `hooks/hooks.json` | All hook paths reference `scripts/*.sh`, not skill folders — no changes needed |
| `scripts/*.sh` | All 12 hook scripts unchanged |
| `docs/plans/` | Historical plan files — left as-is (they reference old skill paths but are historical records, not active references) |

---

## Version Impact

This is a **major version bump** (breaking change: skill names change from `agent-team:agent-*` to `agent-team:start/plan/execute/audit`).

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Breaking change for existing users | High | Major version bump, migration guide in CHANGELOG |
| Plan-mode adds latency to simple tasks | Medium | Defaults conservative (OFF for research/audit); user can skip |
| Error recovery loops extend execution time | Low | Hard bounds: 2 retries, 3 cycles per team |
| Elegance reviewer disagreements | Low | Advisory only, not blocking |
| Global pattern library grows unbounded | Low | Max 5 patterns per team; deduplication; 200 pattern global cap with lowest-success-rate eviction |
| Lessons.md becomes noisy | Medium | Structured template; relevance filter |
| Stage-specific docs drift from shared docs | Medium | Clear ownership table; tests validate references |

---

## Testing Plan

### Skill Structure Tests

| Test | Validates |
|------|-----------|
| `skills/start/SKILL.md` exists with valid frontmatter | Entry point skill |
| `skills/plan/SKILL.md` exists with valid frontmatter | Plan stage skill |
| `skills/execute/SKILL.md` exists with valid frontmatter | Execute stage skill |
| `skills/audit/SKILL.md` exists with valid frontmatter | Audit stage skill |
| Old skill folders deleted | No `skills/agent-team/`, `skills/agent-implement/`, etc. |
| Each stage skill has required subfolders | `references/`, `examples/`, `agents/` as applicable |
| No orphaned doc references | All relative paths in SKILL.md resolve to existing files |

### New Feature Tests

| Test | Validates |
|------|-----------|
| Elegance Reviewer role in `teammate-roles.md` | Role exists with rubric and `recovery_class` |
| Elegance Reviewer in `README.md` | User-facing docs updated (13 roles) |
| `recovery_class` on all roles | Every role has a value |
| `PLAN_PROPOSAL` in communication protocol | New message type documented |
| `error_type` in BLOCKED format | Extended format documented |
| `ELEGANCE_REVIEW` in communication protocol | New message type documented |
| `lessons.md` template in `workspace-templates.md` | Template with 5 required sections |
| `error-patterns.json` schema in `workspace-templates.md` | Schema with required fields |
| `fallback_approach`/`fallback_reason` in task-graph.json schema | New optional fields |
| Plan-mode defaults in `team-archetypes.md` | Each archetype has a default |
| Plan review agent in `skills/plan/agents/plan-reviewer.md` | Agent prompt exists |
| Execute review agent in `skills/execute/agents/execute-reviewer.md` | Agent prompt exists |
| Audit review agent in `skills/audit/agents/audit-reviewer.md` | Agent prompt exists |

### Integration Tests (Manual)

| Test | How to verify |
|------|--------------|
| `/agent-team:start` chains all 3 stages | Invoke with a task, verify plan → execute → audit sequence |
| `/agent-team:plan` works independently | Invoke, verify it stops after user approval |
| `/agent-team:execute` resumes from plan | Create workspace with plan, invoke execute, verify it spawns from existing plan |
| `/agent-team:audit` re-runs verification | Complete a workspace, invoke audit, verify gates + elegance + lessons |
| Prior context loading | Create completed workspace with lessons.md, start new team, verify Learned Context appears |
| Plan-mode gate | Start implementation team, verify plan-mode teammates send PLAN_PROPOSAL |
| Error recovery | Have teammate send BLOCKED with error_type=retry, verify auto-recovery |
| Elegance gate | Complete implementation team, verify Elegance Reviewer spawns |
| Lessons capture | Complete any team, verify lessons.md written |
| Pattern library update | Complete team with resolved issues, verify `~/.claude/agent-team-patterns.json` updated |
| Plan review agent | Run `/agent-team:plan`, verify `PLAN_REVIEW` message appears before user approval |
| Execute review agent | Complete all tasks, verify `EXECUTE_REVIEW` message appears before audit |
| Audit review agent | Complete audit, verify `AUDIT_REVIEW` message appears before report is presented |
| Review agent cycle limits | Trigger blocking issues in plan review, verify max 2 fix cycles then proceed |
