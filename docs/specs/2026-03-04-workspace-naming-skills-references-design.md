# Design: Workspace Naming, Skill Hints & Doc References

**Date**: 2026-03-04
**Status**: Implemented
**Scope**: 4 improvements to agent-team plugin

---

## Improvement 1: Date-Prefixed Workspace Names

**Problem**: Team names like `refactor-auth` collide when the same task runs in different sessions. Existing collision handling is reactive (append `-2` on TeamCreate failure) and workspaces aren't chronologically sortable.

**Design**: Use `MMDD-{descriptive-name}` format (e.g., `0304-refactor-auth`).

### Changes

| File | Change |
|------|--------|
| `skills/agent-team/SKILL.md` Phase 3 step 2 | Update naming guidance: `team-name = MMDD-{task-slug}` with explanation |
| `skills/agent-team/SKILL.md` Phase 3 Setup Failures | Update collision row: append counter `-2`, `-3`; ask user after 3 |
| `README.md` Workspace section | Update example paths to show date prefix |
| `docs/workspace-templates.md` | Update template headers to show date-prefixed names |

**No script changes** — hooks use team name dynamically.

---

## Improvement 2: CLAUDE.md + Skill Hints in Spawn Prompts

**Problem**: Teammates are spawned without project conventions (CLAUDE.md) or awareness of available skills. Implementers write code without knowing commit message format; reviewers miss structured review patterns.

**Design**: Add "Read CLAUDE.md" instruction to all spawn templates + role-specific skill hints.

### Changes

| File | Change |
|------|--------|
| `docs/worker-roles.md` — all spawn templates | Add Context block: "Read CLAUDE.md if it exists. Follow its conventions." |
| `docs/worker-roles.md` — Implementer | Add skill hint: `/tdd`, `/systematic-debugging` |
| `docs/worker-roles.md` — Reviewer | Add skill hint: `/requesting-code-review` |
| `docs/worker-roles.md` — Tester | Add skill hint: `/verification-before-completion` |
| `docs/worker-roles.md` — Researcher, Challenger | No skill hints (pure investigation/analysis) |
| `docs/worker-roles.md` — Spawn Example | Update concrete example with new context block and skill hint |
| `skills/agent-team/SKILL.md` Phase 3 step 5 | Add items 6-7 to spawn prompt checklist: project conventions + skill hints |

### Role-Skill Mapping

| Role | Skill Hints |
|------|------------|
| Implementer | `/tdd` for test-driven dev, `/systematic-debugging` for failures |
| Reviewer | `/requesting-code-review` for structured severity-rated review |
| Tester | `/verification-before-completion` before marking tasks done |
| Researcher | _(none)_ |
| Challenger | _(none)_ |

**Why not inject CLAUDE.md content?** Claude Code auto-loads CLAUDE.md for all sessions including subagents. The explicit instruction reinforces awareness without wasting prompt tokens.

---

## Improvement 3: Documentation References in Workspace Files

**Problem**: Workspace files are self-contained with no links to source docs (specs, ADRs, design docs). After context compaction, teammates can't trace tasks back to requirements. Final reports lack source traceability.

**Design**: Add References sections to progress.md, tasks.md (Ref column), and report.md.

### Changes

| File | Change |
|------|--------|
| `docs/workspace-templates.md` — progress.md | Add `## References` section with Type/Path/Description table |
| `docs/workspace-templates.md` — tasks.md | Add `Ref` column to all task tables |
| `docs/report-format.md` — report template | Add `### References` section in Full Audit Trail |
| `skills/agent-team/SKILL.md` Phase 1 | Add step: "Identify reference documents" (after file ownership mapping) |
| `skills/agent-team/SKILL.md` Phase 3 step 3 | Add: "Populate References section in progress.md" |
| `skills/agent-team/SKILL.md` Phase 5 step 7 | Add: "Copy References from progress.md into report" |

### Reference Types

| Type | Example |
|------|---------|
| spec | `docs/auth-spec.md` |
| ADR | `docs/adr/ADR-003.md` |
| design | `docs/plans/2026-03-01-dashboard-design.md` |
| PR/issue | `#142`, `github.com/org/repo/pull/142` |
| external | API docs URL, library docs |

If no relevant docs exist, the References section stays empty with a `—` row. Checking is mandatory; having references is not.

---

## Improvement 4: Completion Gate (Phase 5 Hard Gate)

**Problem**: Phase 5 step 5 ("Check integration") is a vague single check. There's no systematic verification that build passes, issues are resolved, plan is fully completed, docs are synced, code is committed, or security is clean before the team shuts down. Failures discovered after shutdown require manual cleanup.

**Design**: Replace Phase 5 step 5 with an 8-item hard gate. ALL items must PASS before report generation. Failures create fix tasks and loop back.

### The Gate

Run checks in order. Items marked ★ are project-specific — PASS automatically if the project has no configured tooling for that check.

| # | Check | How | PASS Criteria | On FAIL |
|---|-------|-----|---------------|---------|
| 1 | **Uncommitted changes** | Run `git status` scoped to each implementer's owned files | All owned files committed. Working tree clean for owned paths | Message the implementer to commit. Re-run after confirmation |
| 2 | **Build & tests** | Assign a teammate: "Run `[build cmd]` and `[test cmd]`, report PASS/FAIL with output" | Build exits 0, all tests pass | Create fix task, assign to relevant implementer, re-run gate |
| 3 | **Lint/format** ★ | Assign a teammate: "Run `[lint cmd]`, report new warnings/errors" | No new lint errors (pre-existing are acceptable) | Create fix task, assign to implementer who owns the file, re-run gate |
| 4 | **Integration** | Assign a teammate: "Verify [module A] correctly calls [module B] after changes. Check shared interfaces, imports, API contracts" | Cross-teammate outputs connect correctly | Create integration fix task, assign to the implementer closest to the boundary, re-run gate |
| 5 | **Security scan** ★ | Assign a teammate: "Check for hardcoded secrets, common vulnerabilities (OWASP top 10) in changed files" | No new security issues in changed files | Create fix task as **critical** severity, assign to implementer, re-run gate |
| 6 | **Workspace issues** | Read `issues.md`, count OPEN items | 0 OPEN issues (all RESOLVED or MITIGATED) | Route each OPEN issue to a teammate for resolution, re-run gate |
| 7 | **Plan completion** | Compare Phase 2 plan streams against TaskList + teammate summaries | Every planned stream has completed tasks. No orphaned streams | Create tasks for missing streams, assign, re-run gate |
| 8 | **Documentation sync** | Assign a teammate: "Check if README, ADRs, or docs need updates based on changes made" | No stale docs, or update tasks completed | Create doc update task, assign, re-run gate |

★ = Project-specific. If no lint/security tooling exists, mark PASS and note "N/A — no tooling configured" in the gate log.

### Check Order Rationale

1. Uncommitted first — everything else depends on code being committed
2. Build/tests — no point checking lint or integration if it doesn't compile
3. Lint — quick, catches style issues before deeper checks
4. Integration — core cross-teammate verification
5. Security — catches vulnerabilities in the integrated code
6. Issues — workspace accounting after all code checks pass
7. Plan completion — scope verification
8. Docs last — can only verify docs are current after all code is finalized

### Changes

| File | Change |
|------|--------|
| `skills/agent-team/SKILL.md` Phase 5 step 5 | Replace "Check integration" with 8-item Completion Gate |
| `skills/agent-team/SKILL.md` Phase 5 step 8 | Simplify Remediation gate — issue check moves to gate item #6 |
| `docs/coordination-patterns.md` Quality Gate | Add cross-reference to Completion Gate |
| `docs/workspace-templates.md` progress.md | Add `Phase 5a: Completion Gate passed` to Phase Checklist |

### Interaction with Remediation Gate

Gate item #6 resolves OPEN issues by assigning fix tasks to existing teammates. The Remediation Gate (step 8) then only triggers if:
- Fix tasks themselves fail (teammates can't resolve the issue)
- Issues are found during report generation that weren't in `issues.md`

Step 8 becomes a **fallback** for spawning a remediation team, not the primary issue resolution path.

---

## Files Modified (Summary)

| File | Improvements |
|------|-------------|
| `skills/agent-team/SKILL.md` | 1, 2, 3, 4 |
| `docs/worker-roles.md` | 2 |
| `docs/workspace-templates.md` | 1, 3, 4 |
| `docs/coordination-patterns.md` | 4 |
| `docs/report-format.md` | 3 |
| `README.md` | 1 |
