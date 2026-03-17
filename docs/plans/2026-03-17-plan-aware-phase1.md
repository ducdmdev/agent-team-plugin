# Plan-Aware Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add plan detection, creation, audit, and plan-driven decomposition to Agent Team Phase 1, plus plan status update in Phase 5.

**Architecture:** All changes are documentation updates to `docs/shared-phases.md` (primary), archetype SKILL.md files (minor), `docs/team-archetypes.md`, `docs/workspace-templates.md`, and `README.md`. No new scripts, hooks, or code files. The plan-awareness logic lives in `shared-phases.md` and is inherited by all archetype skills.

**Tech Stack:** Markdown documentation files, bash test scripts

**Reference:** `docs/specs/2026-03-17-plan-aware-phase1-design.md` — approved design spec

---

## Chunk 1: Core Phase 1 Rewrite

### Task 1: Add Early Exit and Budget Constraints to shared-phases.md

**Files:**
- Modify: `docs/shared-phases.md:32-49` (current Phase 1 section)

- [ ] **Step 1: Read the current Phase 1 section**

Read `docs/shared-phases.md` lines 32-49 to confirm the current "Phase 1: Analyze and Decompose" structure.

- [ ] **Step 2: Insert Early Exit and Budget Constraints before Phase 1**

Replace the current Phase 1 header and opening line:

```markdown
## Phase 1: Analyze and Decompose

Analyze the user's task: $ARGUMENTS
```

With:

```markdown
## Phase 1: Analyze and Decompose

Analyze the user's task: $ARGUMENTS

### Early Exit — Trivial Tasks

Before entering Phase 1a, apply a quick complexity check:
- If the task obviously targets a single file with no dependencies (e.g., "fix the typo in README.md"), skip plan detection entirely and proceed to the "team not warranted" determination in Phase 1b step 4
- Signals: task mentions one file, uses words like "typo", "rename", "bump version", no cross-module impact
- When in doubt, proceed to Phase 1a — false negatives (skipping a plan for a complex task) are worse than false positives (scanning for a simple task)

### Budget Constraints

Phase 1a should remain lightweight relative to the overall team workflow:
- **Plan scan**: Limit to scanning directory listings + reading first 20 lines of each candidate (title, status, summary). Full file reads only for the top 3 ranked candidates.
- **Plan creation**: The writing-plans skill manages its own budget. The context bundle from Step 2a should be concise — key file paths and summaries, not full file contents.
- **Audit**: 7 checks against one plan file. The Team Lead reads the plan once and evaluates all checks in a single pass.
- **Max candidates scanned**: If a directory contains more than 20 `.md` files, rank by filename date prefix (most recent first) and keyword overlap, then read only the top 5.
```

- [ ] **Step 3: Verify the edit**

Read back lines 32-55 of `docs/shared-phases.md` to confirm the new sections are in place and the original Phase 1 content follows.

- [ ] **Step 4: Commit**

```bash
git add docs/shared-phases.md
git commit -m "docs: add early exit and budget constraints to Phase 1"
```

### Task 2: Add Phase 1a — Plan Detection & Preparation

**Files:**
- Modify: `docs/shared-phases.md` (insert Phase 1a after the Budget Constraints section, before the current step 1)

- [ ] **Step 1: Read the current state**

Read `docs/shared-phases.md` to identify exactly where the Budget Constraints section ends and the numbered steps begin.

- [ ] **Step 2: Insert Phase 1a section**

After the Budget Constraints section and before the current numbered step 1, insert the full Phase 1a content. This replaces steps 1-6 of the current Phase 1 (which become Phase 1b). Insert:

```markdown
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

    Task: {user's original task description}
    Archetype: {known archetype if dedicated skill, or "to be determined" for /agent-team}
    Context:
    - Relevant files: {list of files/modules identified}
    - References: {specs, ADRs, design docs found}
    - Dependencies: {what touches what}
    - Conventions: {from CLAUDE.md and codebase patterns}
    - Constraints: {anything discovered that limits the solution}

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

**Behavior per option:**

| Option | What happens |
|--------|-------------|
| Proceed as-is | Move to Phase 1b with the plan unchanged. Team Lead works around known issues during decomposition. |
| Update | Team Lead fixes the identified issues in the plan file, re-runs audit, presents again. Max 2 update cycles — if still `insufficient` after 2 rounds, ask user whether to proceed anyway or create new. |
| Create new | Set aside the current plan. Re-enter the creation path (Step 2) from scratch. Only offered once — if the second plan also fails audit, compare both and proceed with the plan that has fewer High-severity issues. |

**Guard rail:** For `insufficient` status, option 1 (proceed as-is) is presented but with a warning: "This plan may not have enough detail to decompose into parallel work. Proceeding may result in a weaker team structure."
```

- [ ] **Step 3: Verify the edit**

Read back the full Phase 1a section to confirm all 5 steps (0-4) are present with correct formatting.

- [ ] **Step 4: Commit**

```bash
git add docs/shared-phases.md
git commit -m "docs: add Phase 1a plan detection and preparation to shared-phases"
```

### Task 3: Rewrite current Phase 1 steps as Phase 1b — Decompose from Plan

**Files:**
- Modify: `docs/shared-phases.md` (replace current numbered steps 1-8 and self-check with Phase 1b)

- [ ] **Step 1: Read the current state**

Read `docs/shared-phases.md` to find the current numbered steps 1-8 that now follow Phase 1a.

- [ ] **Step 2: Replace steps 1-8 with Phase 1b**

Replace the current 8 numbered steps and self-check paragraph with:

```markdown
### Phase 1b: Decompose from Plan

User has approved a plan (or no plan — see fallback below). The decomposition steps now derive from the approved plan:

1. **Map plan tasks to parallel streams** — Group plan tasks by independence. Tasks with no mutual dependencies form separate streams. Tasks that share file ownership or blocked-by relationships stay in the same stream.
2. **Assign file ownership from plan** — Plan tasks reference specific files. Each stream's files become that teammate's owned files. No two teammates edit the same file. If the plan doesn't specify files, the Team Lead infers from task descriptions + codebase scan.
3. **Derive dependencies from plan** — The plan's task ordering and blocked-by relationships translate directly to Agent Team task dependencies.
4. **Determine if a team is warranted** — if fewer than 2 independent streams exist, tell the user a single session is more efficient. Offer: "This plan is sequential — shall I execute it directly without a team?" Stop here if not warranted.
5. **Integration points** — for each pair of streams, identify where plan tasks reference shared interfaces, contracts, or outputs. These become explicit handoff points in Phase 2.
6. **Identify reference documents** — already gathered during Phase 1a. Carry forward into workspace. If Phase 1a was skipped (trivial task early exit), find specs, ADRs, design docs, PRs, or other docs relevant to the task.
7. **Check for custom roles** — if `docs/custom-roles.md` exists in the project, read it. Use custom roles alongside built-in roles when they match the task requirements.

**Fallback — no plan available:** If Phase 1a was skipped (trivial task early exit) or the user declined all plans, the Team Lead performs ad-hoc decomposition using the strategies below:
- **By module/area**: frontend vs backend, auth vs payments (best for feature work)
- **By concern**: implementation vs verification vs research (best for quality-critical tasks)
- **By layer**: data model vs API vs UI (best for full-stack features)
- Avoid splits that create heavy cross-dependencies — if two streams need constant handoffs, merge them

**Self-check**: "Do I have 2+ streams where each can make meaningful progress without waiting on the others? Are integration points identified?" If no, reconsider the split.
```

- [ ] **Step 3: Verify the edit**

Read back the Phase 1b section to confirm all 7 steps are present and the fallback/self-check are intact.

- [ ] **Step 4: Commit**

```bash
git add docs/shared-phases.md
git commit -m "docs: replace Phase 1 steps with Phase 1b plan-driven decomposition"
```

### Task 4: Update Phase 2 presentation format

**Files:**
- Modify: `docs/shared-phases.md:51-92` (Phase 2 section)

- [ ] **Step 1: Read the current Phase 2 section**

Read `docs/shared-phases.md` Phase 2 to find the presentation template.

- [ ] **Step 2: Add "Based on" line to the Phase 2 template**

In the Phase 2 presentation template, after `Team plan for: [task summary]`, add a new line:

```
Based on: [plan file path] (existing | generated) — omit if no plan
```

So the template becomes:

```
Team plan for: [task summary]
Based on: [plan file path] (existing | generated) — omit if no plan
Team type: [detected-type] (auto-detected from task — say "change to [type]" to override)
...
```

- [ ] **Step 3: Verify the edit**

Read back the Phase 2 template to confirm the new line is present and formatting is correct.

- [ ] **Step 4: Commit**

```bash
git add docs/shared-phases.md
git commit -m "docs: add plan source line to Phase 2 presentation template"
```

---

## Chunk 2: Phase 5 and Supporting Docs

### Task 5: Add Plan Status Update section to Phase 5

**Files:**
- Modify: `docs/shared-phases.md` (Phase 5 section)

**Important:** Do NOT renumber existing steps 1-7. The plan status update is added as an unnumbered shared section that archetype Phase 5 Overrides reference. This avoids breaking the "steps 4-7" references in all 5 archetype SKILL.md files.

- [ ] **Step 1: Read the current Phase 5 section**

Read `docs/shared-phases.md` Phase 5 to find step 3 ("Update workspace") — the plan status section will be inserted after it, before step 4.

- [ ] **Step 2: Insert plan status update section**

After step 3 ("Update workspace") and before step 4 ("Remediation gate"), insert an unnumbered section:

```markdown
### Plan Status Update

After the archetype-specific completion gate passes and before generating the report, update the source plan file's status. Each archetype's Phase 5 Override references this step at the appropriate point in its sequence.

If the team was based on a plan file (tracked in `progress.md` References), update the plan file's `Status:` field:

| Team outcome | Status value |
|-------------|-------------|
| All plan tasks completed | `Status: COMPLETED — Implemented via team {team-name} ({date})` |
| Partial completion | `Status: PARTIAL — {N}/{total} tasks completed via team {team-name} ({date}). Remaining: {list}` |
| Team failed or abandoned | `Status: ABANDONED — Team {team-name} ({date}). Reason: {reason}` |

This ensures future Phase 1a plan scans correctly skip completed/abandoned plans. Skip if no plan file was used. See [workspace-templates.md](workspace-templates.md#plan-file-conventions) for the full status value reference.
```

- [ ] **Step 3: Verify placement**

Read back Phase 5 to confirm: (a) steps are still numbered 1-7 (unchanged), (b) the new "Plan Status Update" section sits between step 3 and step 4, and (c) it's framed as a shared reference, not a numbered step.

- [ ] **Step 4: Commit**

```bash
git add docs/shared-phases.md
git commit -m "docs: add plan status update section to Phase 5"
```

### Task 6: Add Plan File Conventions to workspace-templates.md

**Files:**
- Modify: `docs/workspace-templates.md` (add new section after "Workspace Update Protocol")

- [ ] **Step 1: Read the end of workspace-templates.md**

Read `docs/workspace-templates.md` to find where the Workspace Update Protocol section ends.

- [ ] **Step 2: Append Plan File Conventions section**

At the end of the file, add:

```markdown
## Plan File Conventions

Plan files used by Agent Team Phase 1a follow these conventions. The Team Lead reads and writes these status values during plan scanning and Phase 5 completion.

### Status Values

| Status | Meaning | Set by |
|--------|---------|--------|
| (none) | Plan has not been started | — |
| `IN PROGRESS` | Plan is currently being executed | Team Lead at Phase 3 start |
| `COMPLETED — Implemented via team {team-name} ({date})` | All plan tasks finished | Team Lead at Phase 5 |
| `PARTIAL — {N}/{total} tasks completed via team {team-name} ({date}). Remaining: {list}` | Some tasks incomplete | Team Lead at Phase 5 |
| `ABANDONED — Team {team-name} ({date}). Reason: {reason}` | Team failed or was stopped | Team Lead at Phase 5 |

### Scan Behavior

- Phase 1a Step 1 skips files with `COMPLETED` or `ABANDONED` status
- `PARTIAL` plans are eligible for re-use — they appear in scan results with their remaining tasks highlighted
- `IN PROGRESS` plans trigger a warning: "This plan is being executed by another team"

### Minimum Structure

A plan file must contain:
1. Identifiable task descriptions (numbered sections or markdown headings)
2. Enough specificity to map tasks to files or modules
3. A `Status:` field in the header (recommended but not required — absence is treated as "not started")
```

- [ ] **Step 3: Verify the edit**

Read back the new section to confirm formatting and content.

- [ ] **Step 4: Commit**

```bash
git add docs/workspace-templates.md
git commit -m "docs: add plan file conventions to workspace-templates"
```

### Task 7: Update Phase Checklist in workspace-templates.md progress.md template

**Files:**
- Modify: `docs/workspace-templates.md` (Phase Checklist section in the progress.md template)

- [ ] **Step 1: Read the progress.md template**

Read `docs/workspace-templates.md` to find the Phase Checklist block.

- [ ] **Step 2: Update the checklist**

Replace the current Phase Checklist:

```markdown
## Phase Checklist

- [ ] Phase 1: Decomposed task, identified 2+ independent streams
- [ ] Phase 2: Presented plan, received user confirmation
- [ ] Phase 3: TeamCreate, workspace initialized, tasks created, teammates spawned
- [ ] Phase 4: All teammates sent STARTING, coordination active
- [ ] Phase 5a: Completion Gate passed (uncommitted, build, lint, integration, security, issues, plan, docs)
- [ ] Phase 5b: Report generated, teammates shut down, cleanup done
```

With:

```markdown
## Phase Checklist

- [ ] Phase 1a: Plan detected/created, audited, user approved plan
- [ ] Phase 1b: Decomposed plan into 2+ independent streams
- [ ] Phase 2: Presented team decomposition, received user confirmation
- [ ] Phase 3: TeamCreate, workspace initialized, tasks created, teammates spawned
- [ ] Phase 4: All teammates sent STARTING, coordination active
- [ ] Phase 5a: Completion Gate passed (uncommitted, build, lint, integration, security, issues, plan, docs)
- [ ] Phase 5b: Plan status updated, report generated, teammates shut down, cleanup done
```

- [ ] **Step 3: Verify the edit**

Read back the Phase Checklist to confirm both 1a and 1b are listed and Phase 5b includes plan status.

- [ ] **Step 4: Commit**

```bash
git add docs/workspace-templates.md
git commit -m "docs: update phase checklist for plan-aware workflow"
```

---

## Chunk 3: Archetype Skill Updates

### Task 8: Update agent-team/SKILL.md Phase 1 and Phase 5 Overrides

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 1 Override + Phase 5 Override)

- [ ] **Step 1: Read current file**

Read `skills/agent-team/SKILL.md` to find both the Phase 1 Override (lines 33-39) and Phase 5 Override (line referencing "shared Phase 5 steps 4-7").

- [ ] **Step 2: Update Phase 1 Override**

Replace:

```markdown
## Phase 1 Override: Hybrid Decomposition

Apply shared Phase 1, then:
- **Identify which parts map to which archetype** (e.g., research streams vs implementation streams)
- **Compose roles from the full catalog** based on combined task types
- Show `Team type: hybrid ([component types])` in Phase 2 (e.g., `hybrid (research + implementation)`)
```

With:

```markdown
## Phase 1 Override: Hybrid Decomposition

Apply shared Phase 1a (plan detection & preparation). During Phase 1a Step 0, archetype is "to be determined" — plan content will inform the detection.

Then in Phase 1b, apply the shared decomposition steps plus:
- **Detect archetype from plan content** — if the plan mixes implementation and research tasks, confirm Hybrid. If it's clearly one type, inform the user a dedicated skill exists.
- **Identify which parts map to which archetype** (e.g., research streams vs implementation streams)
- **Compose roles from the full catalog** based on combined task types
- Show `Team type: hybrid ([component types])` in Phase 2 (e.g., `hybrid (research + implementation)`)
```

- [ ] **Step 3: Add plan status update to Phase 5 Override**

In the Phase 5 Override section, find the "Generate Report" subsection. Before it, add:

```markdown
### Plan Status Update

Update the source plan file per shared Phase 5 Plan Status Update section.
```

- [ ] **Step 4: Verify both edits**

Read back the Phase 1 and Phase 5 Override sections.

- [ ] **Step 5: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "docs: update agent-team Phase 1 and Phase 5 overrides for plan-aware workflow"
```

### Task 9: Update agent-implement/SKILL.md Phase 1 and Phase 5 Overrides

**Files:**
- Modify: `skills/agent-implement/SKILL.md` (Phase 1 Override + Phase 5 Override)

- [ ] **Step 1: Read current file**

Read `skills/agent-implement/SKILL.md` to find the Phase 1 Override (lines 17-22) and the Phase 5 Override (line referencing "shared Phase 5 steps 4-7").

- [ ] **Step 2: Update Phase 1 Override**

Replace:

```markdown
## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1, then:
- **Decompose by module/area** (frontend vs backend, auth vs payments) or **by layer** (data model vs API vs UI)
- **Default roles**: 1-2 Implementers + Reviewer (standard) or + Reviewer + Tester (complex)
- Detect archetype as `implementation` — show `Team type: implementation (auto-detected)` in Phase 2
```

With:

```markdown
## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1a (plan detection & preparation) and Phase 1b (decompose from plan), then:
- **Decompose by module/area** (frontend vs backend, auth vs payments) or **by layer** (data model vs API vs UI). Plan tasks with implementation verbs (build, refactor, fix, migrate) map to implementer streams.
- **Default roles**: 1-2 Implementers + Reviewer (standard) or + Reviewer + Tester (complex)
- Detect archetype as `implementation` — show `Team type: implementation (auto-detected)` in Phase 2
```

- [ ] **Step 3: Add plan status update to Phase 5 Override**

In the Phase 5 Override section, find the "Generate Report" subsection. Before it, add:

```markdown
### Plan Status Update

Update the source plan file per shared Phase 5 Plan Status Update section.
```

- [ ] **Step 4: Verify both edits**

Read back the Phase 1 and Phase 5 Override sections.

- [ ] **Step 5: Commit**

```bash
git add skills/agent-implement/SKILL.md
git commit -m "docs: update agent-implement Phase 1 and Phase 5 overrides for plan-aware workflow"
```

### Task 10: Update agent-research/SKILL.md Phase 1 and Phase 5 Overrides

**Files:**
- Modify: `skills/agent-research/SKILL.md` (Phase 1 Override + Phase 5 Override)

- [ ] **Step 1: Read current file**

Read `skills/agent-research/SKILL.md` to find the Phase 1 Override (lines 17-22) and the Phase 5 Override (line referencing "shared Phase 5 steps 4-7").

- [ ] **Step 2: Update Phase 1 Override**

Replace:

```markdown
## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1, then:
- **Decompose by research question/hypothesis**, not by module
- **Default roles**: 2-3 Researchers (different angles) + optional Analyst or Challenger
- Detect archetype as `research` — show `Team type: research (auto-detected)` in Phase 2
```

With:

```markdown
## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1a (plan detection & preparation) and Phase 1b (decompose from plan), then:
- **Decompose by research question/hypothesis**, not by module
- **Default roles**: 2-3 Researchers (different angles) + optional Analyst or Challenger
- Detect archetype as `research` — show `Team type: research (auto-detected)` in Phase 2
```

- [ ] **Step 3: Add plan status update to Phase 5 Override**

In the Phase 5 Override section, find the "Generate Report" subsection. Before it, add:

```markdown
### Plan Status Update

Update the source plan file per shared Phase 5 Plan Status Update section.
```

- [ ] **Step 4: Verify both edits**

Read back the Phase 1 and Phase 5 Override sections.

- [ ] **Step 5: Commit**

```bash
git add skills/agent-research/SKILL.md
git commit -m "docs: update agent-research Phase 1 and Phase 5 overrides for plan-aware workflow"
```

### Task 11: Update agent-audit/SKILL.md Phase 1 and Phase 5 Overrides

**Files:**
- Modify: `skills/agent-audit/SKILL.md` (Phase 1 Override + Phase 5 Override)

- [ ] **Step 1: Read current file**

Read `skills/agent-audit/SKILL.md` to find the Phase 1 Override (lines 17-22) and the Phase 5 Override (line referencing "shared Phase 5 steps 4-7").

- [ ] **Step 2: Update Phase 1 Override**

Replace:

```markdown
## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1, then:
- **Decompose by audit lens/checklist area** (security, performance, compliance, style)
- **Default roles**: 2-3 Reviewers or Auditors (different lenses) + optional Challenger
- Detect archetype as `audit` — show `Team type: audit (auto-detected)` in Phase 2
```

With:

```markdown
## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1a (plan detection & preparation) and Phase 1b (decompose from plan), then:
- **Decompose by audit lens/checklist area** (security, performance, compliance, style)
- **Default roles**: 2-3 Reviewers or Auditors (different lenses) + optional Challenger
- Detect archetype as `audit` — show `Team type: audit (auto-detected)` in Phase 2
```

- [ ] **Step 3: Add plan status update to Phase 5 Override**

In the Phase 5 Override section, find the "Generate Report" subsection. Before it, add:

```markdown
### Plan Status Update

Update the source plan file per shared Phase 5 Plan Status Update section.
```

- [ ] **Step 4: Verify both edits**

Read back the Phase 1 and Phase 5 Override sections.

- [ ] **Step 5: Commit**

```bash
git add skills/agent-audit/SKILL.md
git commit -m "docs: update agent-audit Phase 1 and Phase 5 overrides for plan-aware workflow"
```

### Task 12: Update agent-plan/SKILL.md Phase 1 and Phase 5 Overrides

**Files:**
- Modify: `skills/agent-plan/SKILL.md` (Phase 1 Override + Phase 5 Override)

- [ ] **Step 1: Read current file**

Read `skills/agent-plan/SKILL.md` to find the Phase 1 Override (lines 17-22) and the Phase 5 Override (line referencing "shared Phase 5 steps 4-7").

- [ ] **Step 2: Update Phase 1 Override**

Replace:

```markdown
## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1, then:
- **Decompose by planning concern** (architecture, data model, API design, etc.)
- **Default roles**: 1-2 Planners or Strategists + Researcher + optional Challenger
- Detect archetype as `planning` — show `Team type: planning (auto-detected)` in Phase 2
```

With:

```markdown
## Phase 1 Override: Decomposition Strategy

Apply shared Phase 1a (plan detection & preparation) and Phase 1b (decompose from plan), then:
- **Decompose by planning concern** (architecture, data model, API design, etc.)
- **Default roles**: 1-2 Planners or Strategists + Researcher + optional Challenger
- Detect archetype as `planning` — show `Team type: planning (auto-detected)` in Phase 2
```

- [ ] **Step 3: Add plan status update to Phase 5 Override**

In the Phase 5 Override section, find the "Generate Report" subsection. Before it, add:

```markdown
### Plan Status Update

Update the source plan file per shared Phase 5 Plan Status Update section.
```

- [ ] **Step 4: Verify both edits**

Read back the Phase 1 and Phase 5 Override sections.

- [ ] **Step 5: Commit**

```bash
git add skills/agent-plan/SKILL.md
git commit -m "docs: update agent-plan Phase 1 and Phase 5 overrides for plan-aware workflow"
```

---

## Chunk 4: External Docs and Tests

### Task 13: Update team-archetypes.md Archetype Detection section

**Files:**
- Modify: `docs/team-archetypes.md:15-29` (Archetype Detection section)

- [ ] **Step 1: Read current Archetype Detection section**

Read `docs/team-archetypes.md` lines 15-29.

- [ ] **Step 2: Add plan-awareness note**

After the existing paragraph "The lead matches the user's task description against trigger patterns..." and after the table, add:

```markdown
**Plan-aware detection:** When a plan file is available (from Phase 1a), the lead also considers plan content for archetype detection. A plan with implementation tasks maps to Implementation, research tasks to Research, etc. Plan content takes precedence over trigger word matching when the two disagree — the plan represents the user's confirmed intent.
```

- [ ] **Step 3: Verify the edit**

Read back the section.

- [ ] **Step 4: Commit**

```bash
git add docs/team-archetypes.md
git commit -m "docs: add plan-aware detection note to team-archetypes"
```

### Task 14: Update README.md How It Works section

**Files:**
- Modify: `README.md` (the "How It Works" table and Phase description)

- [ ] **Step 1: Read current How It Works section**

Read `README.md` to find the Phase table (around lines 163-174).

- [ ] **Step 2: Update Phase 1 row**

Replace:

```markdown
| **1. Analyze** | Identify independent streams, dependencies, file ownership |
```

With:

```markdown
| **1. Analyze** | Detect or create a plan, audit it, then decompose into independent streams, dependencies, file ownership |
```

- [ ] **Step 3: Add plan-awareness note after the table**

After the How It Works table, add a brief note:

```markdown
**Plan-aware:** Phase 1 scans for existing plan files (`docs/plans/`, `docs/specs/`, etc.). If found, it audits and uses the plan. If not found, it gathers context and creates one (via the `writing-plans` skill or inline). The team decomposition derives from the approved plan.
```

- [ ] **Step 4: Verify the edit**

Read back the section to confirm changes.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: update README Phase 1 description for plan-awareness"
```

### Task 15: Run tests and validate

**Files:**
- Read: `tests/run-tests.sh` (run full test suite)

- [ ] **Step 1: Run the full test suite**

```bash
bash tests/run-tests.sh
```

Expected: All 78 assertions pass. Key concern: the doc reference tests (`test-doc-references.sh`) will verify that all markdown cross-references in `docs/shared-phases.md` and `skills/*/SKILL.md` still resolve correctly.

- [ ] **Step 2: If any tests fail, fix the issues**

Common failure: a broken markdown link reference. Fix and re-commit the affected file.

- [ ] **Step 3: Run tests again to confirm all pass**

```bash
bash tests/run-tests.sh
```

Expected: All tests pass.

- [ ] **Step 4: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: resolve test failures from plan-aware Phase 1 changes"
```
