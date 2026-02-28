# SKILL.md Improvements — Design

**Date**: 2026-02-28
**Status**: Implemented
**Scope**: Full sweep of SKILL.md (414 lines → ~340 lines) + new docs/workspace-templates.md
**Approach**: Surgical edits — edit in-place, extract templates, tighten sections, add missing content. No structural reorganization.

---

## Context

Review of the 414-line SKILL.md identified 12 improvement opportunities across 5 categories: size reduction, content gaps, prompt engineering, structural issues, and duplication. The skill's Phase 1-5 structure is solid — the problems are content gaps and bloat, not architecture.

### Design Decisions

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Approach | Surgical edits (not structural refactor) | Minimal diff, low risk, preserves known-good Phase 1-5 structure |
| Workspace templates | Extract to docs/workspace-templates.md | 76 lines used once during init; extraction keeps SKILL.md focused on orchestration |
| Roadmap overlap | Stay independent | Roadmap items (v1.3.0-v2.0.0) remain separate releases as planned |

---

## Changes

### 1. Phase 1 Expansion

**Problem**: Phase 1 is 6 lines — too thin for the phase that determines decomposition quality. Only says *what* to do, not *how*.

**Change**: Add decomposition strategies, integration point identification, and a self-check after the existing 4 bullets:

```markdown
5. **Decomposition strategies** — choose the split that maximizes parallelism:
   - **By module/area**: frontend vs backend, auth vs payments (best for feature work)
   - **By concern**: implementation vs verification vs research (best for quality-critical tasks)
   - **By layer**: data model vs API vs UI (best for full-stack features)
   - Avoid splits that create heavy cross-dependencies — if two streams need constant handoffs, merge them

6. **Integration points** — for each pair of streams, identify where their outputs must connect (shared interfaces, API contracts, database schemas). These become explicit handoff points in Phase 2.

**Self-check**: "Do I have 2+ streams where each can make meaningful progress without waiting on the others? Are integration points identified?" If no, reconsider the split.
```

**Net change**: +10 lines. Phase 1 goes from 6 to ~16 lines.

---

### 2. Extract Workspace Templates

**Problem**: Lines 101-175 (76 lines) contain full progress.md, tasks.md, and issues.md templates inline in Phase 3. Used once during initialization.

**Change**: Create `docs/workspace-templates.md` with the 3 templates. Replace the inline block in SKILL.md with:

```markdown
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

**Net change**: -65 lines in SKILL.md, +80 lines in new `docs/workspace-templates.md`.

---

### 3. Consistent Self-Checks

**Problem**: Self-checks exist in Phase 2 and Phase 3 step 6 but are missing from Phase 1, Phase 3 step 4, and Phase 5 step 4.

**Change**: Add self-checks at 3 missing phase boundaries (Phase 1 already covered in Section 1):

**Phase 3 step 4** — after "Every task must have clear completion criteria":
```markdown
**Self-check**: "Does every task have a verifiable completion criterion — something a teammate can confirm as done or not done?" If any task says just "implement X" without a success condition, rewrite it.
```

**Phase 5 step 4** — after "Check integration":
```markdown
**Self-check**: "Did I verify that the pieces integrate? If issues were found, have I assigned fixes before proceeding?" If no, STOP — do not generate the report until integration is confirmed.
```

**Net change**: +6 lines.

---

### 4. Setup Error Handling

**Problem**: No guidance for failures during Phase 3 — TeamCreate failures, spawn crashes, existing workspace collisions, mid-setup compaction.

**Change**: Add a "Setup Failures" sub-section after Phase 3 step 7 (assign all work), before Phase 4:

```markdown
### Setup Failures

| Failure | Recovery |
|---------|----------|
| TeamCreate fails (name collision) | Append a suffix: `{team-name}-2`. If that also fails, ask the user for a name |
| TeamCreate fails (feature not enabled) | Tell the user to enable `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and restart |
| Workspace directory already exists | Read `progress.md` — if status is `done`, it's stale: ask user to confirm reuse or clean up. If status is `active`, another session may be using it: ask user |
| Teammate fails to spawn | Check the error. Common causes: tool not available, permission denied. Retry once. If still failing, log to `issues.md`, continue with remaining teammates, reassign orphaned tasks |
| Context compaction during Phase 3 | On recovery, read workspace files. If they exist but tasks/teammates are incomplete, resume from where you left off. If workspace doesn't exist yet, restart Phase 3 |
```

**Net change**: +10 lines.

---

### 5. Task Granularity Guidance

**Problem**: Phase 3 step 4 says "Target 2-6 tasks per teammate" but doesn't explain what makes a good task.

**Change**: Add one line after the existing "2-6 tasks per teammate" bullet:

```markdown
   - A good task is **completable in one focused session** and produces a **verifiable artifact** (a file changed, a test passing, a report written). If a task requires "implement the whole backend", it's too broad — split it. If a task is "add one import statement", it's too narrow — bundle it into an adjacent task.
```

**Net change**: +1 line.

---

### 6. Restructure Spawn Checklist

**Problem**: Phase 3 step 5 is a dense paragraph + 10 unstructured bullet points. Easy to miss items near the end.

**Change**: Replace with grouped numbered checklist:

```markdown
5. **Spawn teammates** using the Task tool with `team_name`, `name`, and `subagent_type` parameters. See [worker-roles.md](../../docs/worker-roles.md) for role-specific spawn templates.

   **subagent_type**: `"general-purpose"` for full tool access (implementers, challengers, testers). `"Explore"` for read-only research teammates. `"general-purpose"` if a reviewer needs Bash. Optionally set `mode: "plan"` for risky or architectural tasks.

   Every spawn prompt MUST include:

   Identity:
   1. Role and responsibilities
   2. Assigned task IDs
   3. Owned files/areas (exclusive — no overlap with other teammates)

   Context:
   4. Workspace path: `.agent-team/{team-name}/` — read for team state
   5. Communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF/QUESTION from Phase 4)

   Behavior:
   6. When blocked: message the lead with severity and impact, do not wait silently
   7. After completing a task: mark complete via TaskUpdate, check TaskList, self-claim next available
   8. Use subagents (Task tool) for focused subtasks that don't need teammate communication
   9. Write output artifacts to the workspace directory

   **Update workspace**: record each teammate in `progress.md` Team Members table
```

**Net change**: ~0 lines (same length, better structure).

---

### 7. Trim Duplication

Three small trims targeting redundant content:

**7a. Remove "Shared Workspace as Bulletin Board" from SKILL.md (lines 266-278)**

Already conveyed by every spawn template ("Read workspace files before asking the lead questions"), Phase 4 Context Recovery, and coordination-patterns.md. Remove entirely. **-12 lines.**

**7b. Condense Remediation Gate in Phase 5 step 7 (lines 343-375)**

Replace inline protocol with decision logic + doc reference:

```markdown
7. **Remediation gate** — review `issues.md` for OPEN issues:
   - If **0 OPEN issues**: skip to step 8
   - If **OPEN issues exist** and `progress.md` remediation cycle is already `1`: do NOT spawn another team. Include unresolved issues in the user report (step 8):
     > **Unresolved issues (require manual follow-up):**
     > - Issue #N (severity): description
     > See `.agent-team/{team-name}/issues.md` for full details.
   - If **OPEN issues exist** and remediation cycle is `0`: present issues to the user and propose a remediation team. Follow the full protocol in [coordination-patterns.md](../../docs/coordination-patterns.md#remediation-gate).
```

**-18 lines.**

**7c. Trim redundant Anti-Patterns (lines 403-414)**

Remove 3 items that echo earlier hard gates:
- "DO NOT skip Phase 2" — already hard gate at Phase 2 self-check
- "DO NOT exceed team size limits" — already Phase 3 step 6 with self-check
- "DO NOT skip the workspace" — already Phase 3 step 3

Keep the 6 that add unique value (Zero-Code Rule, same-file conflict, skip report, assume completion, broadcast misuse, nest teams). **-3 lines.**

**Net change**: -33 lines total.

---

### 8. Move Delegate Mode to Prerequisites

**Problem**: "Shift+Tab to enable delegate mode" is buried at end of Phase 3 step 8. It's a session-level UI instruction, not orchestration logic.

**Change**: Move to Prerequisites section after the TeamCreate check:

```markdown
**Recommended**: Tell the user to press Shift+Tab to enable delegate mode, which restricts you to coordination-only tools. This reinforces the Zero-Code Rule.
```

Remove current Phase 3 step 8 entirely.

**Net change**: -1 line.

---

### 9. Phase 4 Restructure — Skipped

The existing heading separation (`### Context Recovery`, `### Workspace Updates`, `### Communication Protocol`, `### Coordination Patterns`) already creates natural grouping. Adding horizontal rules would be visual noise for no functional gain.

**Net change**: 0 lines.

---

## Files Changed

| File | Change |
|------|--------|
| `skills/agent-team/SKILL.md` | All 8 active sections applied. ~340 lines target (down from 414) |
| `docs/workspace-templates.md` | New file. ~80 lines. Contains progress.md, tasks.md, issues.md templates |

## Line Budget

| Section | Delta |
|---------|-------|
| 1. Phase 1 expansion | +10 |
| 2. Extract templates | -65 |
| 3. Self-checks | +6 |
| 4. Error handling | +10 |
| 5. Task granularity | +1 |
| 6. Spawn checklist | 0 |
| 7. Trim duplication | -33 |
| 8. Move delegate mode | -1 |
| 9. Skip Phase 4 restructure | 0 |
| **Total** | **-72** |

**Estimated final size**: ~342 lines (414 - 72).

## Not In Scope

- Roadmap items v1.3.0-v2.0.0 (stay in separate releases)
- Re-read workspace in spawn templates (v1.4.0 #1)
- New coordination patterns, hooks, auto-branch, worktree isolation
