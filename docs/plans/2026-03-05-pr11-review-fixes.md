# PR #11 Review Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Address all 8 medium and 5 actionable low findings from the PR #11 review.

**Architecture:** Pure documentation edits across 5 files. No code, no scripts, no hooks. All changes are additive (notes, clarifications, labels) — nothing is removed or restructured.

**Tech Stack:** Markdown docs only.

---

## Triage Summary

### Address (8 medium + 5 low = 13 findings)

| Finding | Action | File |
|---------|--------|------|
| M1 | Add trigger disambiguation note | team-archetypes.md |
| M2 | Clarify audit gate #4/#5 semantics | team-archetypes.md |
| M3 | Add lead judgment note for Hybrid gate | team-archetypes.md |
| M4 | Add workspace sub-path note for Planning | team-archetypes.md |
| M5 | Add `Subagent type` line to 6 new roles | worker-roles.md |
| M7 | Add forward-reference for check numbers | team-archetypes.md |
| M8 | Add bridging note in Audit Report | report-format.md |
| L3 | Add Planner fallback note in Plan Report | report-format.md |
| L5 | Add Hybrid mention to Phase 3 override | SKILL.md |
| L6 | Update custom-roles.md intro to list all 12 roles | custom-roles.md |
| L11 | Expand project conventions phrasing in 6 roles | worker-roles.md |
| L12 | Add subagent guidance to Planner and Writer | worker-roles.md |
| M6 | Add note about Planner/Writer ownership difference | worker-roles.md |

### Skip (8 low findings — no action needed)

| Finding | Reason |
|---------|--------|
| L1 | "write documentation" fallback is fine — Phase 2 override handles it |
| L2 | Hybrid Standard report edge case — rare, not worth a variant |
| L4 | Placeholder format cosmetic — does not affect behavior |
| L7 | Approved plan deviation — informational only |
| L8 | Mid-session archetype change — covered by existing re-plan pattern |
| L9 | Scout/Researcher overlap — adequately differentiated per reviewer |
| L10 | Plan format deviation — improvement, not a bug |
| L13 | Role Selection Guide archetype name brevity — fine as-is |

---

### Task 1: Clarify trigger patterns and check numbering in team-archetypes.md

**Addresses:** M1, M2, M3, M4, M7

**Files:**
- Modify: `docs/team-archetypes.md:26` (after fallback line — add disambiguation note for M1)
- Modify: `docs/team-archetypes.md:44` (after Implementation completion gate — add forward-reference for M7)
- Modify: `docs/team-archetypes.md:82` (Audit Phase 5 — clarify #4/#5 semantics for M2)
- Modify: `docs/team-archetypes.md:100` (Planning Phase 3 — add workspace sub-path note for M4)
- Modify: `docs/team-archetypes.md:141` (after Strictest Gate Rule table — add lead judgment note for M3)

**Step 1: Add trigger disambiguation note after fallback line (M1)**

After line 26 (`**Fallback**: If no clear match...`), add:

```markdown

> **Disambiguation — "evaluate"**: "Evaluate against a standard/checklist" (e.g., "evaluate our security posture") → Audit. "Evaluate alternatives/options" (e.g., "evaluate database options") → Research or Planning. When ambiguous, the Phase 2 override lets the user correct.
```

**Step 2: Add forward-reference for check numbers at Implementation gate (M7)**

Change line 44 from:
```
**Completion gate**: All 8 checks (#1-#8)
```
to:
```
**Completion gate**: All 8 checks (#1-#8). See [Strictest Gate Rule](#strictest-gate-rule) for check definitions.
```

**Step 3: Clarify Audit gate semantics (M2)**

Change line 82 (Audit Phase 5 row) from:
```
| Phase 5 | **SKIP**: pre-shutdown commit (#3), branch merge (#4). **Completion gate**: #4 (integration) + #5 (security) + #6 (workspace issues) + #7 (plan completion). **SKIP**: #1-#3, #8 | Partial gate, no commits |
```
to:
```
| Phase 5 | **SKIP**: pre-shutdown commit (#3), branch merge (#4). **Completion gate**: #4 (integration — verify audit covered cross-module concerns) + #5 (security — verify audit covered security aspects) + #6 (workspace issues) + #7 (plan completion). **SKIP**: #1-#3, #8 | Partial gate, no commits |
```

And change line 84 from:
```
**Completion gate**: #4 (integration) + #5 (security) + #6 (workspace issues) + #7 (plan completion)
```
to:
```
**Completion gate**: #4 (integration — audit comprehensiveness, not code changes) + #5 (security — audit coverage, not code changes) + #6 (workspace issues) + #7 (plan completion)
```

**Step 4: Add workspace sub-path note for Planning (M4)**

Change line 100 (Planning Phase 3 row) from:
```
| Phase 3 | Workspace: progress.md, tasks.md, issues.md, events.log. **SKIP file-locks.json** (Planners/Writers write docs to workspace, not project files). **SKIP branch instructions** | No file-locks, no branches |
```
to:
```
| Phase 3 | Workspace: progress.md, tasks.md, issues.md, events.log. **SKIP file-locks.json** (Planners/Writers write docs to workspace, not project files). **SKIP branch instructions**. If multiple Planners, assign distinct workspace sub-paths (e.g., `{workspace}/planner-1/`) to avoid write conflicts | No file-locks, no branches |
```

**Step 5: Add lead judgment note after Strictest Gate Rule table (M3)**

After line 141 (last row of Strictest Gate Rule table), add:

```markdown

> **Lead judgment**: When the implementation component is minor (e.g., a single config change), the lead may mark checks as N/A with a brief note in `progress.md`. The gate is a safety net, not a blocker for obviously inapplicable checks.
```

**Step 6: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass (this is a docs-only change).

**Step 7: Commit**

```bash
git add docs/team-archetypes.md
git commit -m "docs: clarify trigger disambiguation, gate semantics, and check labels in team-archetypes"
```

---

### Task 2: Add subagent_type and conventions to new role definitions in worker-roles.md

**Addresses:** M5, M6, L11, L12

**Files:**
- Modify: `docs/worker-roles.md:272-274` (Analyst header — add subagent_type)
- Modify: `docs/worker-roles.md:311-314` (Planner header — add subagent_type + note)
- Modify: `docs/worker-roles.md:345-348` (Writer header — add subagent_type)
- Modify: `docs/worker-roles.md:383-386` (Strategist header — add subagent_type)
- Modify: `docs/worker-roles.md:424-427` (Auditor header — add subagent_type)
- Modify: `docs/worker-roles.md:465-468` (Scout header — add subagent_type)
- Modify: `docs/worker-roles.md:286,327,398,438,478` (project conventions lines — expand phrasing)
- Modify: `docs/worker-roles.md:342-343,376-377` (Planner and Writer — add subagent guidance)

**Step 1: Add Subagent type to each of the 6 new roles (M5)**

Add a `**Subagent type**:` line after `**Typical tools**:` in each role header:

For **Analyst** (after line 275):
```markdown
**Subagent type**: `general-purpose` (needs Bash for data queries)
```

For **Planner** (after line 314):
```markdown
**Subagent type**: `general-purpose` (needs Write for design docs)
```

For **Writer** (after line 348):
```markdown
**Subagent type**: `general-purpose` (needs Write for documentation)
```

For **Strategist** (after line 386):
```markdown
**Subagent type**: `Explore` (read-only analysis, no Bash needed)
```

For **Auditor** (after line 427):
```markdown
**Subagent type**: `general-purpose` (needs Bash for read-only audit commands)
```

For **Scout** (after line 468):
```markdown
**Subagent type**: `general-purpose` (needs Bash for quick recon commands)
```

**Step 2: Expand project conventions phrasing in new roles (L11)**

In each of the 6 new role spawn templates, change:
```
Follow its conventions.
```
to:
```
Follow its conventions for coding style, commit messages, architecture, and project-specific rules.
```

Applies to lines: ~286 (Analyst), ~327 (Planner), ~398 (Strategist), ~438 (Auditor), ~478 (Scout).

Note: Writer (line 360) already has the expanded version (`Follow its conventions for documentation style.`) — leave it as-is.

**Step 3: Add subagent guidance to Planner and Writer (L12)**

In the **Planner** spawn template rules (after line 342), add:
```
- For independent research subtasks, use subagents (Task tool with subagent_type=Explore) to gather information in parallel.
```

In the **Writer** spawn template rules (after line 376), add:
```
- For independent research subtasks (checking existing docs, verifying code references), use subagents (Task tool with subagent_type=Explore).
```

**Step 4: Add note about Planner/Writer file ownership difference (M6)**

After the Writer section (after line 382, before Strategist), add a brief note:

```markdown
> **Note — Planner vs Writer**: Planners write to the workspace directory only (no file ownership). Writers write to project files (have file ownership and commit instructions). In Hybrid teams with both, the lead creates file-locks.json for Writers but not Planners.
```

**Step 5: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass.

**Step 6: Commit**

```bash
git add docs/worker-roles.md
git commit -m "docs: add subagent_type, expand conventions, and add guidance to new roles"
```

---

### Task 3: Add bridging notes in report-format.md

**Addresses:** M8, L3

**Files:**
- Modify: `docs/report-format.md:190` (after Audit Summary section — add bridging note)
- Modify: `docs/report-format.md:236-239` (Decision Rationale section — add Planner fallback note)

**Step 1: Add bridging note in Audit Report (M8)**

After line 190 (`- **Overall compliance**: {percentage or qualitative assessment}`) and before the Findings by Severity section, add:

```markdown

> PASS/FAIL/WARNING is the per-checklist-item status (Compliance Status table below). FAIL items are further classified by severity (Critical/High/Medium/Low) in the Findings section based on impact.
```

**Step 2: Add Planner fallback note in Plan Report (L3)**

After line 239 (`- {Risks and mitigations}`), add:

```markdown

> If the team has Planners but no Strategist, the lead synthesizes the assumption analysis from Planners' "alternatives considered" and "trade-offs" outputs.
```

**Step 3: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass.

**Step 4: Commit**

```bash
git add docs/report-format.md
git commit -m "docs: add bridging notes for audit dual-format and planner fallback"
```

---

### Task 4: Update SKILL.md Phase 3 override and custom-roles.md intro

**Addresses:** L5, L6

**Files:**
- Modify: `skills/agent-team/SKILL.md:104` (Phase 3 override note — add Hybrid mention)
- Modify: `docs/custom-roles.md:3` (intro line — update role list)

**Step 1: Add Hybrid mention to Phase 3 override (L5)**

Change line 104 from:
```
> **Archetype overrides**: Check [team-archetypes.md](../../docs/team-archetypes.md) for Phase 3 overrides. Key differences: read-only archetypes (research, audit, planning) SKIP file-locks.json and branch instructions.
```
to:
```
> **Archetype overrides**: Check [team-archetypes.md](../../docs/team-archetypes.md) for Phase 3 overrides. Key differences: read-only archetypes (research, audit, planning) SKIP file-locks.json and branch instructions. Hybrid teams create file-locks.json only if ANY teammate writes project files.
```

**Step 2: Update custom-roles.md intro to list all 12 roles (L6)**

Change line 3 from:
```
Project-specific role definitions that extend the built-in roles (Implementer, Reviewer, Researcher, Challenger, Tester).
```
to:
```
Project-specific role definitions that extend the built-in roles (Leader, Implementer, Reviewer, Researcher, Challenger, Tester, Analyst, Planner, Writer, Strategist, Auditor, Scout).
```

**Step 3: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass.

**Step 4: Commit**

```bash
git add skills/agent-team/SKILL.md docs/custom-roles.md
git commit -m "docs: add Hybrid file-locks note and update custom-roles intro for 12 roles"
```

---

### Task 5: Run final validation

**Step 1: Run full test suite**

Run: `bash tests/run-tests.sh`
Expected: All tests pass (88+ assertions).

**Step 2: Validate plugin**

Run: `claude plugin validate .`
Expected: Plugin valid.

**Step 3: Verify cross-references**

Run: `bash tests/structure/test-doc-references.sh`
Expected: All markdown links resolve.
