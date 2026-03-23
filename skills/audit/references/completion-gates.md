# Completion Gates Reference

Single source of truth for which completion gate checks apply to each team archetype. The audit stage reads the archetype from `progress.md` and applies the corresponding gate.

## Check Matrix

### Check #1: Uncommitted Changes

| Field | Value |
|-------|-------|
| **Applies to** | Implementation, Hybrid (if implementer present) |
| **How** | `git status` scoped to each implementer's owned files (from `file-locks.json`) |
| **PASS criteria** | All owned files committed |
| **On FAIL** | Message implementer to commit |
| **N/A for** | Research, Audit, Planning (no code changes) |

### Check #2: Build & Tests

| Field | Value |
|-------|-------|
| **Applies to** | Implementation, Hybrid (if implementer present) |
| **How** | Assign teammate: "Run build + test commands, report PASS/FAIL" |
| **PASS criteria** | Exit 0, all tests pass |
| **On FAIL** | Create fix task |
| **N/A for** | Research, Audit, Planning (no code changes) |

### Check #3: Lint/Format

| Field | Value |
|-------|-------|
| **Applies to** | Implementation, Hybrid (if implementer present) |
| **How** | Assign teammate: "Run lint, report new warnings/errors" |
| **PASS criteria** | No new lint errors |
| **On FAIL** | Create fix task |
| **Project-specific** | PASS automatically if no lint tooling configured |
| **N/A for** | Research, Audit, Planning (no code changes) |

### Check #4: Integration

| Field | Value |
|-------|-------|
| **Applies to** | Implementation, Audit, Hybrid (if implementer or audit component present) |
| **How (Implementation)** | Assign teammate: "Verify cross-module connections". If any convergence points in `task-graph.json` were flagged during Phase 4, verify they were resolved. |
| **How (Audit)** | Verify audit covered cross-module concerns — audit comprehensiveness check |
| **PASS criteria (Implementation)** | Cross-teammate outputs connect, flagged convergence points resolved |
| **PASS criteria (Audit)** | Audit comprehensiveness confirmed |
| **On FAIL (Implementation)** | Create integration fix task |
| **On FAIL (Audit)** | Assign follow-up audit task |
| **N/A for** | Research, Planning |

### Check #5: Security Scan

| Field | Value |
|-------|-------|
| **Applies to** | Implementation, Audit, Hybrid (if implementer or audit component present) |
| **How (Implementation)** | Assign teammate: "Check for secrets, OWASP top 10 in changed files" |
| **How (Audit)** | Verify audit covered security aspects — security coverage check |
| **PASS criteria (Implementation)** | No new security issues |
| **PASS criteria (Audit)** | Security coverage confirmed |
| **On FAIL (Implementation)** | Create fix task (critical severity) |
| **On FAIL (Audit)** | Assign security audit task |
| **Project-specific** | PASS automatically if no security tooling configured |
| **N/A for** | Research, Planning |

### Check #6: Workspace Issues

| Field | Value |
|-------|-------|
| **Applies to** | ALL archetypes (Implementation, Research, Audit, Planning, Hybrid) |
| **How** | Read `issues.md` |
| **PASS criteria** | 0 OPEN issues |
| **On FAIL** | Route to appropriate teammate for resolution |

### Check #7: Plan Completion

| Field | Value |
|-------|-------|
| **Applies to** | ALL archetypes (Implementation, Research, Audit, Planning, Hybrid) |
| **How** | Compare Phase 2 plan vs TaskList |
| **PASS criteria (Implementation)** | Every stream has completed tasks |
| **PASS criteria (Research)** | Every research angle has completed tasks |
| **PASS criteria (Audit)** | Every audit lens has completed tasks |
| **PASS criteria (Planning)** | Every planning concern has completed tasks |
| **PASS criteria (Hybrid)** | All component archetypes' criteria met |
| **On FAIL** | Create missing tasks |

### Check #8: Documentation Sync

| Field | Value |
|-------|-------|
| **Applies to** | Implementation, Hybrid (if implementer present) |
| **How** | Assign teammate: "Check if README/docs need updates" |
| **PASS criteria** | No stale docs |
| **On FAIL** | Create doc update task |
| **N/A for** | Research, Audit, Planning |

## Archetype Summary

### Implementation (8 checks)

All 8 checks apply. Items marked with a star are project-specific — PASS automatically if no tooling configured.

| # | Check | Required |
|---|-------|----------|
| 1 | Uncommitted changes | Yes |
| 2 | Build & tests | Yes |
| 3 | Lint/format | Yes (star) |
| 4 | Integration | Yes |
| 5 | Security scan | Yes (star) |
| 6 | Workspace issues | Yes |
| 7 | Plan completion | Yes |
| 8 | Documentation sync | Yes |

Run checks in order. Log gate result in `progress.md` Decision Log.

### Research (2 checks)

Only checks #6 and #7 apply. Checks #1-#5 and #8 are N/A (no code changes).

| # | Check | Required |
|---|-------|----------|
| 6 | Workspace issues | Yes |
| 7 | Plan completion | Yes |

Log gate result in `progress.md` Decision Log.

### Audit (4 checks)

Checks #4, #5, #6, and #7 apply. Note that #4 and #5 assess audit coverage, not code correctness. Checks #1-#3 and #8 are N/A (no code changes).

| # | Check | Required |
|---|-------|----------|
| 4 | Integration (coverage) | Yes |
| 5 | Security (coverage) | Yes |
| 6 | Workspace issues | Yes |
| 7 | Plan completion | Yes |

Log gate result in `progress.md` Decision Log.

### Planning (2 checks)

Only checks #6 and #7 apply. Checks #1-#5 and #8 are N/A (planners write to workspace, not project files).

| # | Check | Required |
|---|-------|----------|
| 6 | Workspace issues | Yes |
| 7 | Plan completion | Yes |

Log gate result in `progress.md` Decision Log.

### Hybrid (Strictest Gate Rule)

Include any check required by ANY component archetype present in the team. The union of all applicable checks applies.

| # | Check | Required if... |
|---|-------|---------------|
| 1 | Uncommitted changes | Any Implementer present |
| 2 | Build & tests | Any Implementer present |
| 3 | Lint/format | Any Implementer present |
| 4 | Integration | Any Implementer present OR Audit component |
| 5 | Security scan | Any Implementer present OR Audit component |
| 6 | Workspace issues | Always |
| 7 | Plan completion | Always |
| 8 | Documentation sync | Any Implementer present |

**Lead judgment**: When the implementation component is minor (e.g., a single config change), mark checks as N/A with a brief note in `progress.md`.

Log gate result in `progress.md` Decision Log.
