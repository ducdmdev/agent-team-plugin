# SKILL.md Improvements — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve SKILL.md quality across all 12 review findings — expand thin sections, extract templates, add self-checks and error handling, trim duplication. Target ~342 lines (down from 414).

**Architecture:** Surgical edits to `skills/agent-team/SKILL.md` + one new file `docs/workspace-templates.md`. All changes are markdown/prompt edits — no code, no hooks, no scripts. Each task is one logical edit with a commit.

**Tech Stack:** Markdown (SKILL.md prompt engineering, reference docs)

**Design doc:** `docs/plans/2026-02-28-skill-improvements-design.md`

**Task ordering:** Tasks MUST execute in order 1→12. Key dependencies: Task 4 requires Task 1 (creates the file it references), Task 7 requires Task 2 (removes step 8 that sits between step 7 and Phase 4).

---

### Task 1: Create `docs/workspace-templates.md`

**Files:**
- Create: `docs/workspace-templates.md`

**Step 1: Create the file**

Write `docs/workspace-templates.md` with the following content (extracted verbatim from SKILL.md lines 101-175):

```markdown
# Workspace Templates

Templates for the 3 workspace tracking files initialized during Phase 3. The lead creates these immediately after TeamCreate.

## Contents

- [progress.md](#progressmd) — team status, members, phase checklist, decisions, handoffs
- [tasks.md](#tasksmd) — task ledger with status tracking
- [issues.md](#issuesmd) — issue tracker with severity and impact

## progress.md

```​markdown
# Team: {team-name}

**Task**: {one-line description of the overall task}
**Status**: active | completing | done
**Created**: {timestamp}
**Last updated**: {timestamp}
**Remediation cycle**: 0

## Team Members

| Name | Role | Status | Current Task |
|------|------|--------|-------------|
| {name} | {role} | active / idle / shutdown | {task ID or "—"} |

## Phase Checklist

- [ ] Phase 1: Decomposed task, identified 2+ independent streams
- [ ] Phase 2: Presented plan, received user confirmation
- [ ] Phase 3: TeamCreate, workspace initialized, tasks created, teammates spawned
- [ ] Phase 4: All teammates sent STARTING, coordination active
- [ ] Phase 5: All tasks completed, report generated, teammates shut down, cleanup done

## Decision Log

Append-only log of significant decisions.

- [{timestamp}] {decision and reasoning}

## Handoffs

Cross-teammate information transfers.

- [{timestamp}] {source} → {target}: {what was handed off}
```​

## tasks.md

```​markdown
# Tasks: {team-name}

**Last updated**: {timestamp}

| ID | Subject | Owner | Status | Blocked By | Notes |
|----|---------|-------|--------|-----------|-------|
| {id} | {subject} | {owner} | pending / in_progress / completed | {IDs or "—"} | {brief notes} |
```​

## issues.md

```​markdown
# Issues: {team-name}

**Last updated**: {timestamp}
**Open**: 0 | **Resolved**: 0

| # | Severity | Reporter | Description | Impact | Affected Tasks | Status | Resolution |
|---|----------|----------|-------------|--------|---------------|--------|------------|

## Severity Guide
- **critical**: Blocks multiple teammates or the entire team
- **high**: Blocks one teammate or one task chain
- **medium**: Degrades quality or slows progress but work continues
- **low**: Cosmetic, minor, or nice-to-have

## Impact Categories
- **blocked**: Work cannot proceed
- **degraded**: Quality or scope reduced
- **rework**: Completed work must be redone
- **deferred**: Logged for post-team follow-up
```​
```

Note: The file contains markdown code fences nested inside markdown sections. Use **4-backtick outer fences** (``````) for each template section, with standard 3-backtick inner fences for the template content. This prevents the inner fences from closing the outer ones. Extract the template content verbatim from SKILL.md lines 105-175.

**Step 2: Verify the file**

Read back `docs/workspace-templates.md` and confirm it contains all 3 templates (progress.md, tasks.md, issues.md) with correct markdown formatting.

**Step 3: Commit**

```bash
git add docs/workspace-templates.md
git commit -m "docs: extract workspace templates to dedicated reference file"
```

---

### Task 2: Move delegate mode to Prerequisites

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Prerequisites section, ~line 22)
- Modify: `skills/agent-team/SKILL.md` (Phase 3 step 8, ~line 208)

**Step 1: Add delegate mode to Prerequisites**

In `skills/agent-team/SKILL.md`, find:

```
- Do NOT proceed until TeamCreate is available
```

Replace with:

```
- Do NOT proceed until TeamCreate is available

**Recommended**: Tell the user to press Shift+Tab to enable delegate mode, which restricts you to coordination-only tools. This reinforces the Zero-Code Rule.
```

**Step 2: Remove Phase 3 step 8**

Find and remove this block (including the blank line before the step — this prevents a double-blank-line gap between step 7 and Phase 4):

```

8. **Delegate mode** — tell the user to press Shift+Tab to enable delegate mode (Claude Code UI feature), which restricts you to coordination-only tools. Until they do, enforce this yourself: do NOT write code or edit files directly.
```

Replace with empty string (delete the block).

**Step 3: Verify**

Read the Prerequisites section — should end with the delegate mode recommendation. Read Phase 3 — step 7 (assign all work) should be the last numbered step. Verify there is exactly one blank line between step 7's last bullet and `## Phase 4: Coordinate`.

**Step 4: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "refactor: move delegate mode instruction to Prerequisites section"
```

---

### Task 3: Expand Phase 1

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 1, ~lines 37-40)

**Step 1: Add decomposition strategies and self-check**

Find:

```
4. **Map file ownership** — each teammate owns distinct files. No two teammates edit the same file.
```

Replace with:

```
4. **Map file ownership** — each teammate owns distinct files. No two teammates edit the same file.
5. **Decomposition strategies** — choose the split that maximizes parallelism:
   - **By module/area**: frontend vs backend, auth vs payments (best for feature work)
   - **By concern**: implementation vs verification vs research (best for quality-critical tasks)
   - **By layer**: data model vs API vs UI (best for full-stack features)
   - Avoid splits that create heavy cross-dependencies — if two streams need constant handoffs, merge them
6. **Integration points** — for each pair of streams, identify where their outputs must connect (shared interfaces, API contracts, database schemas). These become explicit handoff points in Phase 2.

**Self-check**: "Do I have 2+ streams where each can make meaningful progress without waiting on the others? Are integration points identified?" If no, reconsider the split.
```

**Step 2: Verify**

Read Phase 1 — should now have 6 numbered items plus a self-check.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: expand Phase 1 with decomposition strategies and self-check"
```

---

### Task 4: Replace inline workspace templates with doc reference

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 3 step 3, ~lines 89-175)

**Step 1: Replace the template block**

Find this entire block (from step 3 through the end of the issues.md template):

```
3. **Initialize workspace** — immediately after TeamCreate, create the workspace directory and all 3 tracking files:
   ```
   mkdir -p .agent-team/{team-name}
   Write: .agent-team/{team-name}/progress.md
   Write: .agent-team/{team-name}/tasks.md
   Write: .agent-team/{team-name}/issues.md
   ```

   Use the following templates. The workspace is your persistent memory AND the team's shared state. It MUST exist before any tasks are created.

   If a `.gitignore` exists and doesn't already exclude `.agent-team/`, add it. Workspace files are coordination artifacts, not project deliverables.

   ### Workspace Templates

   #### progress.md

   ```markdown
   # Team: {team-name}

   **Task**: {one-line description of the overall task}
   **Status**: active | completing | done
   **Created**: {timestamp}
   **Last updated**: {timestamp}
   **Remediation cycle**: 0

   ## Team Members

   | Name | Role | Status | Current Task |
   |------|------|--------|-------------|
   | {name} | {role} | active / idle / shutdown | {task ID or "—"} |

   ## Phase Checklist

   - [ ] Phase 1: Decomposed task, identified 2+ independent streams
   - [ ] Phase 2: Presented plan, received user confirmation
   - [ ] Phase 3: TeamCreate, workspace initialized, tasks created, teammates spawned
   - [ ] Phase 4: All teammates sent STARTING, coordination active
   - [ ] Phase 5: All tasks completed, report generated, teammates shut down, cleanup done

   ## Decision Log

   Append-only log of significant decisions.

   - [{timestamp}] {decision and reasoning}

   ## Handoffs

   Cross-teammate information transfers.

   - [{timestamp}] {source} → {target}: {what was handed off}
   ```

   #### tasks.md

   ```markdown
   # Tasks: {team-name}

   **Last updated**: {timestamp}

   | ID | Subject | Owner | Status | Blocked By | Notes |
   |----|---------|-------|--------|-----------|-------|
   | {id} | {subject} | {owner} | pending / in_progress / completed | {IDs or "—"} | {brief notes} |
   ```

   #### issues.md

   ```markdown
   # Issues: {team-name}

   **Last updated**: {timestamp}
   **Open**: 0 | **Resolved**: 0

   | # | Severity | Reporter | Description | Impact | Affected Tasks | Status | Resolution |
   |---|----------|----------|-------------|--------|---------------|--------|------------|

   ## Severity Guide
   - **critical**: Blocks multiple teammates or the entire team
   - **high**: Blocks one teammate or one task chain
   - **medium**: Degrades quality or slows progress but work continues
   - **low**: Cosmetic, minor, or nice-to-have

   ## Impact Categories
   - **blocked**: Work cannot proceed
   - **degraded**: Quality or scope reduced
   - **rework**: Completed work must be redone
   - **deferred**: Logged for post-team follow-up
   ```
```

Replace with:

```
3. **Initialize workspace** — immediately after TeamCreate, create the workspace directory and all 3 tracking files:
   ```
   mkdir -p .agent-team/{team-name}
   ```
   Use the templates from [workspace-templates.md](../../docs/workspace-templates.md) to create:
   - `.agent-team/{team-name}/progress.md` — team status, members, decisions, handoffs
   - `.agent-team/{team-name}/tasks.md` — task ledger with status tracking
   - `.agent-team/{team-name}/issues.md` — issue tracker with severity and impact

   The workspace is your persistent memory AND the team's shared state. It MUST exist before any tasks are created.

   If a `.gitignore` exists and doesn't already exclude `.agent-team/`, add it. Workspace files are coordination artifacts, not project deliverables.
```

**Step 2: Verify**

Read Phase 3 step 3 — should reference workspace-templates.md and list the 3 files with one-line descriptions. No inline templates.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "refactor: replace inline workspace templates with doc reference"
```

---

### Task 5: Add task granularity guidance and self-check to Phase 3 step 4

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 3 step 4, ~line 181)

**Step 1: Add granularity guidance**

Find:

```
   - Every task must have clear completion criteria in its description
   - **Update workspace**: record all tasks in `tasks.md`
```

Replace with:

```
   - Every task must have clear completion criteria in its description
   - A good task is **completable in one focused session** and produces a **verifiable artifact** (a file changed, a test passing, a report written). If a task requires "implement the whole backend", it's too broad — split it. If a task is "add one import statement", it's too narrow — bundle it into an adjacent task.
   - **Update workspace**: record all tasks in `tasks.md`
   - **Self-check**: "Does every task have a verifiable completion criterion — something a teammate can confirm as done or not done?" If any task says just "implement X" without a success condition, rewrite it.
```

**Step 2: Verify**

Read Phase 3 step 4 — should now include granularity heuristic and self-check.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add task granularity guidance and self-check to Phase 3"
```

---

### Task 6: Restructure Phase 3 step 5 spawn checklist

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 3 step 5, ~lines 184-194)

**Step 1: Replace the spawn checklist**

Find:

```
5. **Spawn teammates** using the Task tool with `team_name`, `name`, and `subagent_type` parameters. See [worker-roles.md](../../docs/worker-roles.md) for role-specific spawn templates. Use `subagent_type: "general-purpose"` for teammates that need full tool access (Write, Edit, Bash) — implementers, challengers, testers. Use `subagent_type: "Explore"` for read-only research teammates. Use `general-purpose` if a reviewer needs to run commands (tests, builds). Optionally set `mode: "plan"` to require plan approval before a teammate implements anything — useful for risky or architectural tasks. Each spawn prompt MUST include:
   - Their role and responsibilities
   - Which tasks are assigned to them (reference task IDs)
   - Which files/areas they own exclusively
   - **Workspace path**: `.agent-team/{team-name}/` — tell them to read these files for context. Teammates should write any output artifacts (reports, findings) to this directory so all outputs are co-located
   - **Communication protocol** (see Phase 4 section below — include the structured message format)
   - What to do when blocked: message the lead with severity and impact, do not wait silently
   - Instruction to mark tasks complete immediately after verification
   - Instruction to check TaskList after completing each task and self-claim next available
   - Instruction to use subagents (Task tool) for focused subtasks that don't need teammate communication
   - **Update workspace**: record each teammate in `progress.md` Team Members table
```

Replace with:

```
5. **Spawn teammates** using the Task tool with `team_name`, `name`, and `subagent_type` parameters. See [worker-roles.md](../../docs/worker-roles.md) for role-specific spawn templates.

   **subagent_type**: `"general-purpose"` for full tool access (implementers, challengers, testers). `"Explore"` for read-only research teammates. `"general-purpose"` if a reviewer needs Bash. Optionally set `mode: "plan"` for risky or architectural tasks.

   Every spawn prompt MUST include:

   Identity:
   1. Role and responsibilities
   2. Assigned task IDs
   3. Owned files/areas (exclusive — no overlap with other teammates)

   Context:
   4. Workspace path: `.agent-team/{team-name}/` — read for team state, write output artifacts here
   5. Communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF/QUESTION — see Phase 4)

   Behavior:
   6. When blocked: message the lead with severity and impact, do not wait silently
   7. After completing a task: mark complete via TaskUpdate, check TaskList, self-claim next available
   8. Use subagents (Task tool) for focused subtasks that don't need teammate communication
   9. Write output artifacts to the workspace directory

   **Update workspace**: record each teammate in `progress.md` Team Members table
```

**Step 2: Verify**

Read Phase 3 step 5 — should show grouped checklist (Identity 1-3, Context 4-5, Behavior 6-9) with clear subagent_type guidance.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "refactor: restructure spawn checklist into grouped categories"
```

---

### Task 7: Add Setup Failures table to Phase 3

**Files:**
- Modify: `skills/agent-team/SKILL.md` (after Phase 3 step 7, before Phase 4)

**Step 1: Add the setup failures section**

Find:

```
7. **Assign ALL work to teammates** — every phase of the task must have a teammate owner. This includes:
   - Setup work (env files, config) — assign to an implementer
   - Verification (build, test, lint) — assign to a reviewer or create verification tasks for an implementer
   - Finalization (status updates, cleanup edits) — assign to the nearest teammate
   - If a phase seems too small for a dedicated teammate, bundle it into an adjacent teammate's task list

## Phase 4: Coordinate
```

Replace with:

```
7. **Assign ALL work to teammates** — every phase of the task must have a teammate owner. This includes:
   - Setup work (env files, config) — assign to an implementer
   - Verification (build, test, lint) — assign to a reviewer or create verification tasks for an implementer
   - Finalization (status updates, cleanup edits) — assign to the nearest teammate
   - If a phase seems too small for a dedicated teammate, bundle it into an adjacent teammate's task list

### Setup Failures

| Failure | Recovery |
|---------|----------|
| TeamCreate fails (name collision) | Append a suffix: `{team-name}-2`. If that also fails, ask the user for a name |
| TeamCreate fails (feature not enabled) | Tell the user to enable `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and restart |
| Workspace directory already exists | Read `progress.md` — if status is `done`, it's stale: ask user to confirm reuse or clean up. If status is `active`, another session may be using it: ask user |
| Teammate fails to spawn | Check the error. Common causes: tool not available, permission denied. Retry once. If still failing, log to `issues.md`, continue with remaining teammates, reassign orphaned tasks |
| Context compaction during Phase 3 | On recovery, read workspace files. If they exist but tasks/teammates are incomplete, resume from where you left off. If workspace doesn't exist yet, restart Phase 3 |

## Phase 4: Coordinate
```

**Step 2: Verify**

Read the end of Phase 3 — should show step 7, then the Setup Failures table, then Phase 4 heading.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add setup failure recovery table to Phase 3"
```

---

### Task 8: Remove Shared Workspace as Bulletin Board from Phase 4

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 4 Communication Protocol, ~lines 266-278)

**Step 1: Remove the bulletin board section**

Find and remove this entire block:

```
#### Shared Workspace as Bulletin Board

The workspace at `.agent-team/{team-name}/` serves as the team's bulletin board:
- **Teammates read** workspace files for self-service context before messaging the lead
- **Lead writes** to workspace files after every significant event
- This reduces "what's happening?" messages and gives teammates situational awareness

When to tell teammates to check the workspace:
- Teammate asks about another teammate's progress -> "Check tasks.md for current status"
- Teammate asks about known issues -> "Check issues.md for known problems"
- Teammate asks about a decision -> "Check progress.md Decision Log"

Use `message` (1:1) for all task-specific communication. Reserve `broadcast` for blocking issues that affect every teammate.

```

Replace with empty string (delete the block). The content is already in coordination-patterns.md and conveyed by spawn templates.

**Step 2: Verify**

Read Phase 4 Communication Protocol section — should go from Lead Processing Rules table directly to Plan Approval Handling, with no bulletin board section in between.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "refactor: remove duplicated bulletin board section from Phase 4"
```

---

### Task 9: Add self-check to Phase 5 step 4

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 5 step 4, ~line 333)

**Step 1: Add the self-check**

Find:

```
4. **Check integration** — do the pieces fit together? If issues found, assign fixes before wrapping up
```

Replace with:

```
4. **Check integration** — do the pieces fit together? If issues found, assign fixes before wrapping up

   **Self-check**: "Did I verify that the pieces integrate? If issues were found, have I assigned fixes before proceeding?" If no, STOP — do not generate the report until integration is confirmed.
```

**Step 2: Verify**

Read Phase 5 step 4 — should now include the self-check.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add integration self-check to Phase 5 step 4"
```

---

### Task 10: Condense Phase 5 remediation gate

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 5 step 7, ~lines 343-375)

**Step 1: Replace the inline protocol with condensed version**

Find:

```
7. **Remediation gate** — review `issues.md` for OPEN issues:
   - Read `issues.md` and count issues with Status = OPEN
   - If **0 OPEN issues**: skip to step 8
   - If **OPEN issues exist**:
     1. Check `progress.md` for `**Remediation cycle**` value
        - If already `1` → this IS the remediation team. Do NOT spawn another. Include unresolved issues prominently in the user report (step 8) using the escalation format:
          > **Unresolved issues (require manual follow-up):**
          > - Issue #N (severity): description
          > See `.agent-team/{team-name}/issues.md` for full details.
        - If `0` → proceed to present remediation proposal
     2. Present OPEN issues to user and propose a remediation team:
        ```
        Open issues found after team completion:

        | # | Severity | Description | Affected Tasks |
        |---|----------|-------------|---------------|
        | {n} | {level} | {description} | {task IDs} |

        Proposed remediation team: {team-name}-fix
        - [role]: [what they fix / verify]

        Approve remediation? (The original team will be shut down first.)
        ```
     3. **If user declines**: skip remediation, include unresolved issues in user report (step 8) using the escalation format above
     4. **If user approves**:
        a. Shut down the original team (steps 9-10: shutdown sequence + cleanup)
        b. Set `progress.md` `**Remediation cycle**` to `1`
        c. Create remediation team: `{original-team-name}-fix`
        d. Reuse the same workspace directory `.agent-team/{original-team-name}/`
        e. Create tasks derived from the OPEN issues (each issue becomes a task)
        f. Spawn teammates — typically 1-2 implementers + 1 tester if original plan was complex
        g. Run Phases 3-5 for the remediation scope (skip Phase 1-2 decomposition — scope is already defined by the issues)
        h. On remediation completion, return to step 6 (generate updated report) and continue
```

Replace with:

```
7. **Remediation gate** — review `issues.md` for OPEN issues:
   - If **0 OPEN issues**: skip to step 8
   - If **OPEN issues exist** and `progress.md` remediation cycle is already `1`: do NOT spawn another team. Include unresolved issues in the user report (step 8):
     > **Unresolved issues (require manual follow-up):**
     > - Issue #N (severity): description
     > See `.agent-team/{team-name}/issues.md` for full details.
   - If **OPEN issues exist** and remediation cycle is `0`: present issues to the user and propose a remediation team. Follow the full protocol in [coordination-patterns.md](../../docs/coordination-patterns.md#remediation-gate).
```

**Step 2: Verify**

Read Phase 5 step 7 — should be 5 lines (decision logic + doc reference), not 32 lines.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "refactor: condense remediation gate to decision logic with doc reference"
```

---

### Task 11: Trim redundant anti-patterns

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Anti-Patterns section, near end of file)

**Step 1: Remove 3 redundant items**

The 3 items to remove are **non-contiguous** — lines 409-410 (kept items) sit between lines 407-408 and 411. Find the full contiguous block of 5 items and replace with only the 2 that should remain:

Find:

```
- **DO NOT skip Phase 2** — present the plan and get user confirmation before creating anything. No exceptions
- **DO NOT skip the workspace** — all 3 tracking files MUST be initialized before tasks are created
- **DO NOT skip the report** — `.agent-team/{team-name}/report.md` MUST exist before shutdown
- **DO NOT assume task completion** — no COMPLETED message means the task is NOT done
- **DO NOT exceed team size limits** — max 4 mixed, up to 6 if extras are read-only. Self-check required for N > 4
```

Replace with (keeping only the 2 items that add unique value):

```
- **DO NOT skip the report** — `.agent-team/{team-name}/report.md` MUST exist before shutdown
- **DO NOT assume task completion** — no COMPLETED message means the task is NOT done
```

The remaining 6 anti-patterns stay (Zero-Code Rule, same-file conflict, skip report, assume completion, broadcast misuse, nest teams).

**Step 2: Verify**

Read the Anti-Patterns section — should have exactly 6 items.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "refactor: remove 3 redundant anti-patterns already enforced by phase gates"
```

---

### Task 12: Final verification

**Step 1: Count lines**

```bash
wc -l skills/agent-team/SKILL.md
```

Expected: approximately 340-350 lines (down from 414).

**Step 2: Verify all changes are consistent**

Read `skills/agent-team/SKILL.md` in full and check:
- Phase 1: 6 numbered items + self-check
- Prerequisites: includes delegate mode recommendation
- Phase 3 step 3: references workspace-templates.md, no inline templates
- Phase 3 step 4: includes granularity guidance + self-check
- Phase 3 step 5: grouped spawn checklist (Identity/Context/Behavior)
- Phase 3: Setup Failures table exists after step 7
- Phase 3: no step 8 (delegate mode removed)
- Phase 4: no "Shared Workspace as Bulletin Board" sub-section
- Phase 5 step 4: includes integration self-check
- Phase 5 step 7: condensed remediation gate (5 lines, not 32)
- Anti-Patterns: 6 items (not 9)
- `docs/worker-roles.md` line 26: references `workspace-templates.md` directly (not SKILL.md Phase 3)

**Step 3: Verify doc reference**

Read `docs/workspace-templates.md` and confirm it contains all 3 templates with correct formatting.

**Step 4: Verify cross-references**

Check that the workspace-templates.md reference path in SKILL.md (`../../docs/workspace-templates.md`) resolves correctly from `skills/agent-team/SKILL.md`.

**Step 4b: Update stale reference in worker-roles.md**

`docs/worker-roles.md` line 26 references "see workspace templates in [SKILL.md](...) Phase 3". After Task 4, the templates live in `docs/workspace-templates.md`. Update the reference to point directly to workspace-templates.md:

Find in `docs/worker-roles.md`:
```
see workspace templates in [SKILL.md](../skills/agent-team/SKILL.md) Phase 3
```

Replace with:
```
see [workspace-templates.md](workspace-templates.md)
```

**Step 5: Run plugin validation**

```bash
claude plugin validate .
```

Expected: validation passes.

**Step 6: Commit any fixes**

If any issues found in steps 1-5:

```bash
git add skills/agent-team/SKILL.md docs/workspace-templates.md docs/worker-roles.md
git commit -m "fix: address review findings from final verification"
```
