# Open Issue Remediation Gate — Implementation Plan

**Status**: Implemented

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** After team completion, the lead reviews `issues.md` for OPEN items and can spawn a remediation team (max 1 cycle) with user approval before shutdown.

**Architecture:** Three files change — SKILL.md (Phase 5 remediation gate step + workspace template field), coordination-patterns.md (new pattern section), and report-format.md (escalation format). All changes are prompt/doc edits — no code or hooks.

**Tech Stack:** Markdown (SKILL.md prompt engineering, reference docs)

---

### Task 1: Add `Remediation cycle` field to `progress.md` workspace template in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:109` (progress.md template, after `**Last updated**` line)

**Step 1: Add the remediation cycle field**

In `skills/agent-team/SKILL.md`, inside the `progress.md` workspace template, add a `**Remediation cycle**` field after the `**Last updated**` line. This field tracks whether the current team is a remediation team to prevent infinite recursion.

Find:
```
   **Status**: active | completing | done
   **Created**: {timestamp}
   **Last updated**: {timestamp}
```

Replace with:
```
   **Status**: active | completing | done
   **Created**: {timestamp}
   **Last updated**: {timestamp}
   **Remediation cycle**: 0
```

**Step 2: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add remediation cycle field to progress.md workspace template"
```

---

### Task 2: Insert remediation gate step in SKILL.md Phase 5

**Files:**
- Modify: `skills/agent-team/SKILL.md:327-351` (Phase 5, after step 6 "Generate final report")

**Step 1: Insert remediation gate as new step 7**

In `skills/agent-team/SKILL.md`, after step 6 (Generate final report, ending at line 331) and before step 7 (Report to user, line 333), insert the remediation gate step:

Find:
```
6. **Generate final report** (MANDATORY — do not skip):
   - Read all workspace files for full history
   - Read TaskList for final task states
   - Write `.agent-team/{team-name}/report.md` using the format in [report-format.md](../../docs/report-format.md)
   - **Self-check**: "Does `.agent-team/{team-name}/report.md` exist and contain the executive summary?" If no, generate it now

7. **Report to user**:
```

Replace with:
```
6. **Generate final report** (MANDATORY — do not skip):
   - Read all workspace files for full history
   - Read TaskList for final task states
   - Write `.agent-team/{team-name}/report.md` using the format in [report-format.md](../../docs/report-format.md)
   - **Self-check**: "Does `.agent-team/{team-name}/report.md` exist and contain the executive summary?" If no, generate it now

7. **Remediation gate** — review `issues.md` for OPEN issues:
   - Read `issues.md` and count issues with Status = OPEN
   - If **0 OPEN issues**: skip to step 8
   - If **OPEN issues exist**:
     1. Check `progress.md` for `**Remediation cycle**` value
        - If already `1` → this IS the remediation team. Do NOT spawn another. Include unresolved issues prominently in the user report (step 8) using the escalation format:
          ```
          Unresolved issues (require manual follow-up):
          - Issue #N (severity): description
          See .agent-team/{team-name}/issues.md for full details.
          ```
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

8. **Report to user**:
```

**Step 2: Renumber remaining steps**

Renumber the existing steps 8-9 to 9-10:

Find:
```
8. **Shutdown sequence** (parallel — do NOT wait for each one sequentially):
```

Replace with:
```
9. **Shutdown sequence** (parallel — do NOT wait for each one sequentially):
```

Find:
```
9. **Cleanup**:
```

Replace with:
```
10. **Cleanup**:
```

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add remediation gate step to Phase 5"
```

---

### Task 3: Add Remediation Gate pattern to `docs/coordination-patterns.md`

**Files:**
- Modify: `docs/coordination-patterns.md:11` (Contents list)
- Modify: `docs/coordination-patterns.md:121` (after Pre-Shutdown Commit section, before File Conflict Resolution)

**Step 1: Add to Contents list**

In `docs/coordination-patterns.md`, add a new entry after the Pre-Shutdown Commit entry in the Contents list:

Find:
```
- [Pre-Shutdown Commit](#pre-shutdown-commit) — ensuring implementers commit before shutdown
- [File Conflict Resolution](#file-conflict-resolution) — handling shared-file issues
```

Replace with:
```
- [Pre-Shutdown Commit](#pre-shutdown-commit) — ensuring implementers commit before shutdown
- [Remediation Gate](#remediation-gate) — spawning a fix team for unresolved issues
- [File Conflict Resolution](#file-conflict-resolution) — handling shared-file issues
```

**Step 2: Add pattern section**

Insert after the Pre-Shutdown Commit section (after line 121, the `**Why**` paragraph ending), before `## File Conflict Resolution`:

Find:
```
**Why**: Without this step, teammate work exists only as uncommitted changes on disk. If anything goes wrong during shutdown or cleanup, work is lost. Per-teammate commits also make `git log` useful for tracing who did what.

## File Conflict Resolution
```

Replace with:
```
**Why**: Without this step, teammate work exists only as uncommitted changes on disk. If anything goes wrong during shutdown or cleanup, work is lost. Per-teammate commits also make `git log` useful for tracing who did what.

## Remediation Gate

After generating the final report, the lead reviews `issues.md` for OPEN items. If unresolved issues exist, the lead can spawn a remediation team to fix them — with user approval.

### Protocol

1. **Count OPEN issues** — read `issues.md`, filter for Status = OPEN.
2. **Check remediation cycle** — read `progress.md` for `**Remediation cycle**` value. If already `1`, this IS the remediation team — do not spawn another. Escalate to the user in the report instead.
3. **Present to user** — list OPEN issues with severity and affected tasks. Propose a remediation team (`{team-name}-fix`) with role composition. Ask for approval.
4. **If user approves**:
   - Shut down the original team (parallel shutdown + cleanup)
   - Set `progress.md` `**Remediation cycle**` to `1`
   - Create remediation team: `{original-team-name}-fix`
   - Reuse the same workspace directory — `issues.md` carries forward
   - Create tasks from the OPEN issues (each issue becomes a task)
   - Spawn teammates (typically 1-2 implementers + 1 tester if original was complex)
   - Run Phases 3-5 for remediation scope
5. **If user declines** — include unresolved issues in the user report with the escalation format:
   ```
   Unresolved issues (require manual follow-up):
   - Issue #N (severity): description
   See .agent-team/{team-name}/issues.md for full details.
   ```

### Remediation team conventions

- **Team name**: `{original-team-name}-fix` (e.g., `refactor-auth-fix`)
- **Workspace**: reuses `.agent-team/{original-team-name}/` — no new workspace directory
- **Max 1 cycle**: if the remediation team also has OPEN issues, escalate to user instead of recursing
- **Scope**: only the OPEN issues — tasks derive from the issue list, not a fresh decomposition

**Why**: OPEN issues represent known problems that were logged but never resolved. Leaving them as "FYI" in the report means the user must manually investigate and fix. A remediation team gives the lead a structured way to close the loop while keeping the user in control.

## File Conflict Resolution
```

**Step 3: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "feat: add Remediation Gate coordination pattern"
```

---

### Task 4: Add unresolved issues escalation format to `docs/report-format.md`

**Files:**
- Modify: `docs/report-format.md:41-46` (Issues Summary and Follow-up Items in template)

**Step 1: Add escalation callout to report template**

In `docs/report-format.md`, update the Issues Summary section in the template to include a prominent escalation block for unresolved issues:

Find:
```
### Issues Summary
- **Resolved**: {count} — {one-line summary of significant ones}
- **Open/Deferred**: {count} — {one-line each, these need user follow-up}

### Follow-up Items
{Bulleted list of anything that needs attention after the team disbanded}
```

Replace with:
```
### Issues Summary
- **Resolved**: {count} — {one-line summary of significant ones}
- **Open/Deferred**: {count} — {one-line each, these need user follow-up}
- **Remediation**: {applied | declined | not needed}

> **Unresolved issues (require manual follow-up):**
> _(Include this block only if OPEN issues remain after remediation was declined or after a remediation cycle completed with remaining issues.)_
> - Issue #N (severity): description
> - Issue #N (severity): description
> See `issues.md` for full details.

### Follow-up Items
{Bulleted list of anything that needs attention after the team disbanded}
```

**Step 2: Commit**

```bash
git add docs/report-format.md
git commit -m "docs: add unresolved issues escalation format to report template"
```

---

### Task 5: Final verification

**Step 1: Verify all files are consistent**

Read each modified file and check:
- `skills/agent-team/SKILL.md`: progress.md template has `**Remediation cycle**: 0`, Phase 5 has remediation gate as step 7 with correct numbering (steps 8-10 for report/shutdown/cleanup)
- `docs/coordination-patterns.md`: Remediation Gate pattern exists in Contents list and body, placed between Pre-Shutdown Commit and File Conflict Resolution
- `docs/report-format.md`: Issues Summary has `**Remediation**` field and the escalation callout block

**Step 2: Verify no broken markdown**

Spot-check that table alignment, code fences, and blockquotes are correct in all modified files.

**Step 3: Commit any fixes if needed**

```bash
git add -A && git commit -m "fix: address review findings from remediation gate verification"
```
