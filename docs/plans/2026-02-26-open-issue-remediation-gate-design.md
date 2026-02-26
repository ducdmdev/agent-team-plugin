# Design: Open Issue Remediation Gate

**Date**: 2026-02-26
**Status**: Approved

---

## Problem

When a team completes all tasks, there may be OPEN issues in `issues.md` that were logged during coordination but never resolved. Currently, these are reported to the user in the final summary but no automated follow-up happens. The lead should be able to spawn a remediation team to fix them.

## Design

Add a remediation gate step to Phase 5, between "generate report" (step 6) and "report to user" (step 7). The lead reviews `issues.md` for OPEN items and, if any exist, presents them to the user with a proposed remediation team.

### Decisions

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Trigger | Only OPEN issues in `issues.md` | Explicitly tracked problems, not deferred tasks |
| Loop guard | Max 1 remediation cycle | Prevents infinite recursion; escalate to user after 1 cycle |
| User gate | Require user approval | Consistent with Phase 2 hard gate; user stays in control |
| Placement | After report, before shutdown | Original team still alive; workspace has full context |

### Flow

```
Step 6: Generate report (existing)
        |
Step 7: Remediation gate (NEW)
        +-- Read issues.md -> count OPEN issues
        +-- If 0 OPEN -> skip, continue to step 8
        +-- If OPEN issues exist:
            +-- Check: is this already a remediation cycle?
            |   +-- If yes -> skip, escalate in user report instead
            +-- Present to user: list OPEN issues + proposed remediation team
            +-- User approves?
            |   +-- No -> skip, include in user report as unresolved
            |   +-- Yes:
            |       +-- Shut down original team (steps 9-10)
            |       +-- Create remediation team: {team-name}-fix
            |       +-- Reuse workspace (issues.md carries over)
            |       +-- Run Phases 1-5 for remediation scope
            |       +-- On completion, proceed to final report to user
        |
Step 8: Report to user (renumbered from 7)
Step 9: Shutdown sequence (renumbered from 8)
Step 10: Cleanup (renumbered from 9)
```

### Remediation Team Conventions

- **Team name**: `{original-team-name}-fix` (e.g., `refactor-auth-fix`)
- **Workspace**: reuses the same `.agent-team/{original-team-name}/` directory. The `issues.md` carries forward so the remediation team has full context on what to fix
- **Cycle tracking**: the lead sets a field in `progress.md` — `**Remediation cycle**: 1` — so it knows not to recurse again
- **Scope**: only the OPEN issues. Tasks are derived from the issue list, not from a fresh decomposition
- **Team composition**: typically 1-2 implementers targeting the specific issues + 1 reviewer/tester if the original plan was complex

### User Presentation Format

```
Open issues found after team completion:

| # | Severity | Description | Affected Tasks |
|---|----------|-------------|---------------|
| 3 | high     | API endpoint missing error handling | #2, #5 |
| 7 | medium   | Test coverage gap in auth module   | #4     |

Proposed remediation team: {team-name}-fix
- implementer: fix issues #3, #7
- tester: verify fixes (if original plan was complex)

Approve remediation? (The original team will be shut down first.)
```

### Escalation (no remediation)

If the user declines remediation, or this is already a remediation cycle with new OPEN issues, the lead includes them prominently in the user report:

```
Unresolved issues (require manual follow-up):
- Issue #3 (high): API endpoint missing error handling
- Issue #7 (medium): Test coverage gap in auth module
See .agent-team/{team-name}/issues.md for full details.
```

### Scope

#### Files changed

| File | Change |
|------|--------|
| `skills/agent-team/SKILL.md` | Insert remediation gate step in Phase 5 (new step 7), renumber steps 7-9 to 8-10, add `Remediation cycle` field to `progress.md` workspace template |
| `docs/coordination-patterns.md` | Add "Remediation Gate" pattern section with full protocol |
| `docs/report-format.md` | Add unresolved issues escalation format to Executive Summary template |

#### Files NOT changed

- `hooks/` — no new hooks needed; existing hooks apply to the remediation team naturally
- `docs/worker-roles.md` — no new roles; remediation teams use existing roles
- `README.md` — no user-facing behavior change needed in README (workspace and roles unchanged)
