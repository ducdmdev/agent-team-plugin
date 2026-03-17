# Plan-Aware Phase 1 Design

**Date:** 2026-03-17
**Status:** APPROVED
**Scope:** Modify Phase 1 (Analyze) to detect, create, audit, and decompose from plan files before spawning teams.

---

## Summary

Currently Phase 1 does ad-hoc analysis of the user's task to identify parallel streams. This design adds plan-awareness: the Team Lead first checks for existing plan files, creates one if missing (via `superpowers:writing-plans`), audits the plan, and then derives the team decomposition from the approved plan.

The 5-phase contract is preserved. Phase 1 expands into two sub-phases (1a: Plan Detection & Preparation, 1b: Decompose from Plan). All other phases remain unchanged.

## Motivation

- Plans provide higher-quality task breakdowns than ad-hoc analysis
- Existing plans in the project should be reused, not ignored
- The writing-plans skill already produces well-structured plans — the Agent Team should leverage it
- An audit gate ensures plan quality regardless of source (pre-existing or generated)

## Design

### Early Exit — Trivial Tasks

Before entering Phase 1a, the Team Lead applies a quick complexity check:
- If the task obviously targets a single file with no dependencies (e.g., "fix the typo in README.md"), skip plan detection entirely and proceed to the existing "team not warranted" determination
- Signals: task mentions one file, uses words like "typo", "rename", "bump version", no cross-module impact
- When in doubt, proceed to Phase 1a — false negatives (skipping a plan for a complex task) are worse than false positives (scanning for a simple task)

### Budget Constraints

Phase 1a should remain lightweight relative to the overall team workflow:
- **Plan scan**: Limit to scanning directory listings + reading first 20 lines of each candidate (title, status, summary). Full file reads only for the top 3 ranked candidates.
- **Plan creation**: The writing-plans skill manages its own budget. The context bundle from Step 2a should be concise — key file paths and summaries, not full file contents.
- **Audit**: 7 checks against one plan file. The Team Lead reads the plan once and evaluates all checks in a single pass.
- **Max candidates scanned**: If a directory contains more than 20 `.md` files, rank by filename date prefix (most recent first) and keyword overlap, then read only the top 5.

### Phase 1a: Plan Detection & Preparation

#### Step 0 — Archetype Context

For **dedicated archetype skills** (`/agent-implement`, `/agent-research`, `/agent-audit`, `/agent-plan`), the archetype is already known at invocation — it was determined by which skill the user triggered. This archetype context is available throughout Phase 1a and informs plan creation if needed.

For **`/agent-team`** (hybrid/catch-all), archetype detection moves to Phase 1b after the plan is approved — plan content helps inform the detection.

#### Step 1 — Scan for Existing Plans

Scan these locations in priority order, collecting all `.md` candidates:

| Priority | Location | Pattern |
|----------|----------|---------|
| 1 | User-specified path | Direct path from trigger (e.g., "implement `docs/plans/my-plan.md`") |
| 2 | `docs/plans/` | `*.md` |
| 3 | `docs/specs/` | `*.md` |
| 4 | `plans/`, `.plans/` | `*.md` |
| 5 | `specs/` | `*.md` |
| 6 | `docs/` | `*plan*.md`, `*spec*.md`, `*design*.md` |
| 7 | Project root | `*plan*.md`, `*spec*.md`, `*design*.md` |

**Matching logic:**
- Rank candidates by relevance to the user's task (keyword overlap between task description and plan title/content)
- If multiple candidates found, present top 3 to user: "I found these plans — which one applies, or should I create a new one?"
- If exactly one strong match, propose it: "I found `docs/plans/X.md` — shall I use this?"
- If zero matches → proceed to plan creation (Step 2)
- Skip files with `Status: COMPLETED` or `Status: ABANDONED` in frontmatter/header
- In monorepo structures (detected by multiple `package.json`, workspace configs, etc.), scope the scan to the subdirectory relevant to the user's task

**Minimum plan structure for usability:**
A plan file must contain at minimum: (a) identifiable task descriptions (numbered or headed sections), and (b) enough specificity to map tasks to files or modules. If a found plan is unstructured prose (e.g., a high-level strategy doc), it can inform context but cannot be used as the decomposition source — treat it as "zero matches" and proceed to plan creation, passing the prose document as a reference.

#### Step 2 — Create Plan (No Plan Found)

**2a. Gather context and references:**
- Codebase scan: Identify relevant files, modules, and architecture related to the user's task (using Glob, Grep, Read)
- Reference discovery: Find specs, ADRs, design docs, PRs, existing tests, CLAUDE.md conventions
- Dependency mapping: Identify which files/modules are touched, what imports what, integration boundaries
- Conventions check: Read CLAUDE.md, check for existing patterns in the codebase

**2b. Invoke `superpowers:writing-plans` with context:**

Pass a context bundle to the writing-plans skill:
```
Task: {user's original task description}
Archetype: {known archetype if dedicated skill, or "to be determined" for /agent-team}
Context:
- Relevant files: {list of files/modules identified}
- References: {specs, ADRs, design docs found}
- Dependencies: {what touches what}
- Conventions: {from CLAUDE.md and codebase patterns}
- Constraints: {anything discovered that limits the solution}
```

The writing-plans skill produces a plan file at `docs/plans/YYYY-MM-DD-{task-slug}-plan.md`.

**2c. Proceed to audit (Step 3).**

**Fallback — writing-plans skill unavailable:**
If `superpowers:writing-plans` is not installed or fails to invoke, the Team Lead falls back to inline plan creation:
- Use the gathered context from Step 2a to produce a plan document directly
- Follow the same output format (numbered tasks with file references, completion criteria, dependencies)
- Save to `docs/plans/YYYY-MM-DD-{task-slug}-plan.md`
- Log a note in the workspace: "Plan created inline (writing-plans skill unavailable)"
- Proceed to audit as normal

This ensures the plugin degrades gracefully, consistent with how hooks handle missing `jq`.

#### Step 3 — Audit Plan (Common Gate)

Both paths converge here. Every plan is audited before the user sees it.

| # | Check | What it validates | Severity |
|---|-------|-------------------|----------|
| 1 | Task completeness | Every task has clear completion criteria, file references, and step-by-step instructions | High |
| 2 | Dependency coherence | No circular dependencies between tasks. Blocked-by chains resolve. | High |
| 3 | File reference validity | Files mentioned in the plan actually exist in the codebase (or are explicitly marked as "to be created") | Medium |
| 4 | Scope coverage | Plan tasks collectively cover the user's original request — nothing major missing | High |
| 5 | Reference freshness | Referenced specs/ADRs/docs still exist and haven't been superseded | Low |
| 6 | Feasibility | Tasks are achievable — no references to unavailable tools, APIs, or dependencies | Medium |
| 7 | Parallelizability | At least 2 tasks can run concurrently (otherwise a team isn't warranted) | High |

**Note on check #7 vs Phase 1b "team warranted" gate:** Check #7 is an early signal during audit — if it fails, the audit status reflects it and the user is warned. If the user chooses "proceed as-is" despite a failed check #7, Phase 1b step 4 performs the definitive evaluation after full decomposition. The audit flags the risk; Phase 1b makes the final call.

**Audit output:**
- **Status**: `ready` (0 high issues), `needs-revision` (1+ high issues), `insufficient` (plan is too vague to decompose)
- **Issues list**: Each issue with severity, description, and suggested fix
- **Parallelism assessment**: How many independent streams the plan supports

The Team Lead performs the audit inline — reading the plan file, cross-referencing codebase state, and evaluating each check. No separate skill invocation needed.

#### Step 4 — User Decision Gate

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
1. Proceed as-is — use this plan for team decomposition
2. Update — fix the issues above and re-audit
3. Create new — discard this plan, start fresh with writing-plans

Which option?
```

**Behavior per option:**

| Option | What happens |
|--------|-------------|
| Proceed as-is | Move to Phase 1b with the plan unchanged. Team Lead works around known issues during decomposition. |
| Update | Team Lead fixes the identified issues in the plan file, re-runs audit, presents again. Max 2 update cycles — if still `insufficient` after 2 rounds, ask user whether to proceed anyway or create new. |
| Create new | Set aside the current plan. Re-enter the creation path (Step 2) from scratch. Only offered once — if the second plan also fails audit, compare both and proceed with the plan that has fewer High-severity issues. |

**Guard rail:** For `insufficient` status, option 1 (proceed as-is) is presented but with a warning: "This plan may not have enough detail to decompose into parallel work. Proceeding may result in a weaker team structure."

### Phase 1b: Decompose from Plan

User has approved a plan. The existing Phase 1 decomposition steps now derive from the plan:

1. **Map plan tasks to parallel streams** — Group plan tasks by independence. Tasks with no mutual dependencies form separate streams. Tasks that share file ownership or blocked-by relationships stay in the same stream.

2. **Assign file ownership from plan** — Plan tasks reference specific files. Each stream's files become that teammate's owned files. If the plan doesn't specify files, the Team Lead infers from task descriptions + codebase scan.

3. **Derive dependencies from plan** — The plan's task ordering and blocked-by relationships translate directly to Agent Team task dependencies.

4. **Determine team warranted** — Same gate as current Phase 1: if fewer than 2 independent streams exist, tell user a single session is more efficient. Offer: "This plan is sequential — shall I execute it directly without a team?"

5. **Integration points** — For each pair of streams, identify where plan tasks reference shared interfaces, contracts, or outputs. These become explicit handoff points in Phase 2.

6. **Reference documents** — Already gathered during plan creation/audit. Carry forward into workspace.

Existing shared Phase 1 steps 7-8 (integration points, custom roles check) and the self-check remain unchanged — they apply after decomposition. Step 5 (decomposition strategies) is effectively replaced by Phase 1b steps 1-3 above. Step 6 (reference documents) is handled by Phase 1a context gathering.

Phase 2 presentation adds the plan source:

```
Team plan for: [task summary]
Based on: docs/plans/2026-03-17-refactor-auth-plan.md (existing)
Team type: ...
```

The `(existing)` / `(generated)` annotation indicates whether the plan was found in the project or created by writing-plans during this session.

### Archetype Skill Impact

| File | Change | Size |
|------|--------|------|
| `docs/shared-phases.md` | Rewrite Phase 1 to add 1a (scan → create/audit → user gate) before 1b (decompose from plan). Add plan scan locations table, audit checks table, user decision gate format. | Large |
| `skills/agent-team/SKILL.md` | Phase 1 Override: hybrid archetype detection happens in 1b after plan is approved. Minor rewording. | Small |
| `skills/agent-implement/SKILL.md` | Phase 1 Override unchanged — "decompose by module/area" still applies in 1b. Add note: "plan tasks with implementation verbs map to implementer streams". | Minimal |
| `skills/agent-research/SKILL.md` | Phase 1 Override unchanged — "decompose by research question" still applies in 1b. | Minimal |
| `skills/agent-audit/SKILL.md` | Phase 1 Override unchanged — "decompose by audit lens" still applies in 1b. | Minimal |
| `skills/agent-plan/SKILL.md` | Phase 1 Override unchanged — "decompose by planning concern" still applies in 1b. | Minimal |
| `docs/team-archetypes.md` | Add note that archetype detection now considers plan content alongside trigger patterns. | Small |
| `README.md` | Update Phase 1 description in "How It Works" table. Add note about plan-awareness. | Small |
| `CLAUDE.md` | No change. | None |

### Phase 5 Addition: Plan Status Update

A new **completion step** (not a gate check) added to shared Phase 5, after the completion gate passes and before report generation.

**When:** If the team was based on a plan file (tracked in `progress.md` References).

**Action:** The Team Lead updates the source plan file's `Status:` field:

| Team outcome | Status value |
|-------------|-------------|
| All plan tasks completed | `Status: COMPLETED — Implemented via team {team-name} ({date})` |
| Partial completion | `Status: PARTIAL — {N}/{total} tasks completed via team {team-name} ({date}). Remaining: {list}` |
| Team failed or abandoned | `Status: ABANDONED — Team {team-name} ({date}). Reason: {reason}` |

This ensures the plan scan in future Phase 1a runs correctly skips completed/abandoned plans.

**Plan status conventions:** The valid status values (`COMPLETED`, `PARTIAL`, `ABANDONED`, and the pre-existing `IN PROGRESS`) should be documented in `docs/workspace-templates.md` under a new "Plan File Conventions" section so they are discoverable outside this spec.

### Impact Summary

**Key principle:** Plan-awareness logic lives entirely in `shared-phases.md` Phase 1. Archetype skills inherit it automatically. Their Phase 1 overrides only add archetype-specific decomposition strategies in 1b. No new files, scripts, or hooks. Phase 5 gets a small addition for plan status tracking.
