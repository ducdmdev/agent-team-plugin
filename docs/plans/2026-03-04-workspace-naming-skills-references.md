# Workspace Naming, Skill Hints, Doc References & Completion Gate — Implementation Plan

> **Status**: Implemented (2026-03-04)

**Goal:** Add date-prefixed workspace names, CLAUDE.md + skill hints in spawn prompts, documentation references in workspace files, and a comprehensive Completion Gate in Phase 5.

**Architecture:** Four improvements touching SKILL.md (all 4), worker-roles.md (#2), workspace-templates.md (#1, #3, #4), coordination-patterns.md (#4), report-format.md (#3), and README.md (#1). No script changes.

**Tech Stack:** Markdown (skill prompts, templates, docs)

**Design doc:** `docs/plans/2026-03-04-workspace-naming-skills-references-design.md`

---

### Task 1: Add date prefix to workspace naming in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:101-103` (Phase 3 step 2)
- Modify: `skills/agent-team/SKILL.md:197` (Setup Failures table)

**Step 1: Update Phase 3 step 2 naming guidance**

In `skills/agent-team/SKILL.md`, replace:

```
2. **Create team**:
   ```
   TeamCreate: team-name based on task (e.g., "refactor-auth", "review-pr-142")
   ```
```

With:

```
2. **Create team**:
   ```
   TeamCreate: team-name = MMDD-{task-slug} (e.g., "0304-refactor-auth", "0304-review-pr-142")
   The MMDD prefix is today's date. This prevents name collisions across sessions and makes workspaces chronologically sortable.
   ```
```

**Step 2: Update Setup Failures collision row**

In `skills/agent-team/SKILL.md`, replace:

```
| TeamCreate fails (name collision) | Append a suffix: `{team-name}-2`. If that also fails, ask the user for a name |
```

With:

```
| TeamCreate fails (name collision) | Append a counter: `{name}-2`, `{name}-3`. If `-3` also fails, ask the user for a name |
```

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add MMDD date prefix to workspace naming"
```

---

### Task 2: Update workspace-templates.md with date prefix examples

**Files:**
- Modify: `docs/workspace-templates.md:15` (progress.md template header)

**Step 1: Update progress.md template team name example**

In `docs/workspace-templates.md`, replace:

```markdown
# Team: {team-name}
```

No change needed — `{team-name}` is a placeholder that already accepts any format including date-prefixed names. The SKILL.md guidance in Task 1 ensures the lead generates the right format.

**Skip this task** — the templates use `{team-name}` placeholder which is format-agnostic. No changes needed.

---

### Task 3: Update README.md workspace examples with date prefix

**Files:**
- Modify: `README.md:140-150` (Workspace section)

**Step 1: Update workspace path examples**

In `README.md`, replace:

```
Each team creates a persistent workspace at `.agent-team/{team-name}/` in your project:

```
.agent-team/{team-name}/
```

With:

```
Each team creates a persistent workspace at `.agent-team/{team-name}/` in your project, where `{team-name}` uses an `MMDD-` date prefix for uniqueness (e.g., `0304-refactor-auth`):

```
.agent-team/0304-refactor-auth/
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update workspace examples with date-prefixed names"
```

---

### Task 4: Add CLAUDE.md instruction to all spawn templates in worker-roles.md

**Files:**
- Modify: `docs/worker-roles.md:74-98` (Researcher template)
- Modify: `docs/worker-roles.md:105-133` (Implementer template)
- Modify: `docs/worker-roles.md:140-171` (Reviewer template)
- Modify: `docs/worker-roles.md:179-202` (Challenger template)
- Modify: `docs/worker-roles.md:209-240` (Tester template)

**Step 1: Add context block to Researcher template**

In the Researcher spawn prompt, after `Workspace: .agent-team/[TEAM_NAME]/ — read these files for context on team progress, tasks, and known issues.`, add:

```
Project conventions: If CLAUDE.md exists in the project root, read it before starting. Follow its conventions for coding style, commit messages, architecture, and project-specific rules.
```

**Step 2: Add context block to Implementer template**

Same addition after the Workspace line. Additionally, add to the Rules section:

```
- If available, use /tdd for test-driven development. Use /systematic-debugging if you encounter unexpected failures.
```

**Step 3: Add context block to Reviewer template**

Same context block after the Workspace line. Additionally, add to the Rules section:

```
- If available, use /requesting-code-review for structured review patterns.
```

**Step 4: Add context block to Challenger template**

Same context block after the Workspace line. No skill hints for this role.

**Step 5: Add context block to Tester template**

Same context block after the Workspace line. Additionally, add to the Rules section:

```
- If available, use /verification-before-completion before marking any task done.
```

**Step 6: Commit**

```bash
git add docs/worker-roles.md
git commit -m "feat: add CLAUDE.md instruction and skill hints to all spawn templates"
```

---

### Task 5: Update Spawn Example in worker-roles.md

**Files:**
- Modify: `docs/worker-roles.md:242-277` (Spawn Example)

**Step 1: Add context and skill hint to the concrete example**

In the Spawn Example section, after the `Workspace: .agent-team/refactor-auth/` line, add:

```
    Project conventions: If CLAUDE.md exists in the project root, read it before starting. Follow its conventions.
```

And add to the Rules section:

```
    - If available, use /tdd for test-driven development. Use /systematic-debugging for unexpected failures.
```

**Step 2: Commit**

```bash
git add docs/worker-roles.md
git commit -m "docs: update spawn example with CLAUDE.md and skill hints"
```

---

### Task 6: Add spawn prompt checklist items to SKILL.md Phase 3

**Files:**
- Modify: `skills/agent-team/SKILL.md:154-173` (Phase 3 step 5 spawn checklist)

**Step 1: Add items 6-7 to the Context section of the spawn checklist**

In `skills/agent-team/SKILL.md`, the spawn prompt checklist currently has:

```
   Context:
   4. Workspace path: `.agent-team/{team-name}/` — read for team state, write output artifacts here
   5. Communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF/QUESTION — see Phase 4)
```

Replace with:

```
   Context:
   4. Workspace path: `.agent-team/{team-name}/` — read for team state, write output artifacts here
   5. Communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF/QUESTION — see Phase 4)
   6. Project conventions: "Read CLAUDE.md if it exists. Follow its conventions."
   7. Skill hints: role-specific recommendations from [worker-roles.md](../../docs/worker-roles.md)
```

**Step 2: Renumber Behavior section**

Update Behavior section numbering from `6. 7. 8. 9.` to `8. 9. 10. 11.`:

```
   Behavior:
   8. When blocked: message the lead with severity and impact, do not wait silently
   9. After completing a task: mark complete via TaskUpdate, check TaskList, self-claim next available
   10. Use subagents (Task tool) for focused subtasks that don't need teammate communication
   11. Write output artifacts to the workspace directory
```

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add CLAUDE.md and skill hint items to spawn prompt checklist"
```

---

### Task 7: Add "Identify reference documents" to SKILL.md Phase 1

**Files:**
- Modify: `skills/agent-team/SKILL.md:38-54` (Phase 1)

**Step 1: Add step 6 and renumber**

In Phase 1, after step 5 (Decomposition strategies), add:

```
6. **Identify reference documents** — find specs, ADRs, design docs, PRs, or other docs relevant to the task. These populate the workspace References section in Phase 3.
```

Renumber existing steps 6-7 to 7-8:
- "Integration points" becomes step 7
- "Check for custom roles" becomes step 8

**Step 2: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add reference document identification to Phase 1"
```

---

### Task 8: Add References section to workspace-templates.md progress.md template

**Files:**
- Modify: `docs/workspace-templates.md:14-48` (progress.md template)

**Step 1: Add References section to progress.md template**

After the `**Remediation cycle**: 0` line and before `## Team Members`, add:

```markdown
## References

Source documents for this team's work.

| Type | Path/URL | Description |
|------|----------|-------------|
| {spec/ADR/design/PR/doc} | {path or URL} | {one-line description} |
```

**Step 2: Commit**

```bash
git add docs/workspace-templates.md
git commit -m "feat: add References section to progress.md template"
```

---

### Task 9: Add Ref column to workspace-templates.md tasks.md template

**Files:**
- Modify: `docs/workspace-templates.md:52-76` (tasks.md template)

**Step 1: Add Ref column to all task tables**

Update the In Progress table:

```markdown
| ID | Subject | Owner | Ref | Notes |
|----|---------|-------|-----|-------|
```

Update the Blocked table:

```markdown
| ID | Subject | Owner | Ref | Blocked By | Notes |
|----|---------|-------|-----|-----------|-------|
```

Update the Pending table:

```markdown
| ID | Subject | Owner | Ref | Blocked By | Notes |
|----|---------|-------|-----|-----------|-------|
```

Update the Completed table:

```markdown
| ID | Subject | Owner | Ref | Notes |
|----|---------|-------|-----|-------|
```

**Step 2: Commit**

```bash
git add docs/workspace-templates.md
git commit -m "feat: add Ref column to tasks.md template tables"
```

---

### Task 10: Add References section to report-format.md

**Files:**
- Modify: `docs/report-format.md:86-107` (Full Audit Trail section)

**Step 1: Add References section after Handoff Log**

After the `### Handoff Log` section (line ~92) and before `### Issues & Impact Tracker`, add:

```markdown
### References

Source documents consulted during this team's work.

| Type | Path/URL | Description |
|------|----------|-------------|
| {spec/ADR/design/PR/doc} | {path or URL} | {one-line description} |
```

**Step 2: Update Generation Protocol step 1**

In the Generation Protocol, update step 1 to mention References:

```
1. Read all workspace files:
   - `.agent-team/{team-name}/progress.md` — team members, decisions, handoffs, **references**
   - `.agent-team/{team-name}/tasks.md` — task ledger
   - `.agent-team/{team-name}/issues.md` — issue tracker
```

**Step 3: Add step to copy references**

After step 3 ("Incorporate teammate summaries"), add:

```
4. Copy References section from `progress.md` into the report's References section
```

Renumber existing steps 4-5 to 5-6.

**Step 4: Commit**

```bash
git add docs/report-format.md
git commit -m "feat: add References section to report template"
```

---

### Task 11: Update SKILL.md Phase 3 and Phase 5 for references

**Files:**
- Modify: `skills/agent-team/SKILL.md:106-113` (Phase 3 step 3)
- Modify: `skills/agent-team/SKILL.md:337-341` (Phase 5 step 7)

**Step 1: Update Phase 3 step 3 workspace initialization**

After "Use the templates from workspace-templates.md to create:", add a note:

```
   Populate the `## References` section in `progress.md` with docs identified in Phase 1. If no reference docs were found, leave the table with a single `—` row.
```

**Step 2: Update Phase 5 step 7 report generation**

After the existing bullet points in step 7, add:

```
   - Copy References from `progress.md` into the report's References section
```

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add reference population to Phase 3 and Phase 5"
```

---

### Task 12: Replace Phase 5 step 5 with Completion Gate in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:331-333` (Phase 5 step 5)

**Step 1: Replace "Check integration" with Completion Gate**

In `skills/agent-team/SKILL.md`, replace:

```
5. **Check integration** — do the pieces fit together? If issues found, assign fixes before wrapping up

   **Self-check**: "Did I verify that the pieces integrate? If issues were found, have I assigned fixes before proceeding?" If no, STOP — do not generate the report until integration is confirmed.
```

With:

```
5. **Completion Gate** (hard gate — ALL must PASS before proceeding to report generation):

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

   Log gate result in `progress.md` Decision Log: "Completion Gate: PASS" or "Completion Gate: FAIL — [items], fix tasks created"

   **Self-check**: "Have all 8 checks passed? If any failed, have I created fix tasks and re-run?" If no, STOP.
```

**Step 2: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: replace Phase 5 integration check with 8-item Completion Gate"
```

---

### Task 13: Simplify Remediation Gate in SKILL.md Phase 5

**Files:**
- Modify: `skills/agent-team/SKILL.md:343-349` (Phase 5 step 8)

**Step 1: Update Remediation Gate to reflect that issues are now caught by Completion Gate**

In `skills/agent-team/SKILL.md`, replace:

```
8. **Remediation gate** — review `issues.md` for OPEN issues:
   - If **0 OPEN issues**: skip to step 9
   - If **OPEN issues exist** and `progress.md` remediation cycle is already `1`: do NOT spawn another team. Include unresolved issues in the user report (step 9):
     > **Unresolved issues (require manual follow-up):**
     > - Issue #N (severity): description
     > See `.agent-team/{team-name}/issues.md` for full details.
   - If **OPEN issues exist** and remediation cycle is `0`: present issues to the user and propose a remediation team. Follow the full protocol in [coordination-patterns.md](../../docs/coordination-patterns.md#remediation-gate).
```

With:

```
8. **Remediation gate** — the Completion Gate (step 5) resolves most OPEN issues via fix tasks. This step handles residual issues that couldn't be resolved:
   - If **0 OPEN issues** in `issues.md`: skip to step 9
   - If **OPEN issues exist** and `progress.md` remediation cycle is already `1`: do NOT spawn another team. Include unresolved issues in the user report (step 9):
     > **Unresolved issues (require manual follow-up):**
     > - Issue #N (severity): description
     > See `.agent-team/{team-name}/issues.md` for full details.
   - If **OPEN issues exist** and remediation cycle is `0`: present issues to the user and propose a remediation team. Follow the full protocol in [coordination-patterns.md](../../docs/coordination-patterns.md#remediation-gate).
```

**Step 2: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "refactor: simplify Remediation Gate now that Completion Gate handles primary issue resolution"
```

---

### Task 14: Add Completion Gate reference to workspace-templates.md Phase Checklist

**Files:**
- Modify: `docs/workspace-templates.md:29-35` (Phase Checklist in progress.md template)

**Step 1: Add Phase 5a checklist item**

In `docs/workspace-templates.md`, replace:

```
- [ ] Phase 4: All teammates sent STARTING, coordination active
- [ ] Phase 5: All tasks completed, report generated, teammates shut down, cleanup done
```

With:

```
- [ ] Phase 4: All teammates sent STARTING, coordination active
- [ ] Phase 5a: Completion Gate passed (uncommitted, build, lint, integration, security, issues, plan, docs)
- [ ] Phase 5b: Report generated, teammates shut down, cleanup done
```

**Step 2: Commit**

```bash
git add docs/workspace-templates.md
git commit -m "feat: add Completion Gate to progress.md Phase Checklist"
```

---

### Task 15: Add cross-reference in coordination-patterns.md Quality Gate

**Files:**
- Modify: `docs/coordination-patterns.md:343-352` (Quality Gate section)

**Step 1: Add cross-reference note**

In `docs/coordination-patterns.md`, replace:

```
## Quality Gate

A final validation pass before Phase 5 synthesis. Catches integration issues that per-task checks miss.

### When to Use

- Complex plans with 3+ implementers
- Cross-module changes where integration bugs are likely
- Plans marked as "complex" in Phase 2
```

With:

```
## Quality Gate

A final validation pass before Phase 5 synthesis. Catches integration issues that per-task checks miss.

> **Note**: The Completion Gate in SKILL.md Phase 5 step 5 provides mandatory quality checks (build, tests, lint, integration, security, issues, plan completion, doc sync) for ALL teams. This pattern describes extended verification options for complex plans that go beyond the standard gate.

### When to Use

- Complex plans with 3+ implementers
- Cross-module changes where integration bugs are likely
- Plans marked as "complex" in Phase 2
```

**Step 2: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "docs: add Completion Gate cross-reference to Quality Gate pattern"
```

---

### Task 16: Run tests and validate plugin

**Files:**
- Read: `tests/run-tests.sh`

**Step 1: Run full test suite**

```bash
bash tests/run-tests.sh
```

Expected: All assertions pass. If any fail, fix the issue in the relevant file.

**Step 2: Validate plugin structure**

```bash
claude plugin validate .
```

Expected: Validation passes.

**Step 3: Commit any fixes**

If test fixes were needed:

```bash
git add <fixed files>
git commit -m "fix: address test failures from workspace improvements"
```

---

## Task Summary

| # | Improvement | Description |
|---|-------------|-------------|
| 1 | Naming | Date prefix in SKILL.md Phase 3 |
| 2 | Naming | _(skipped — templates are format-agnostic)_ |
| 3 | Naming | README.md workspace examples |
| 4 | Skills | CLAUDE.md + skill hints in all spawn templates |
| 5 | Skills | Update Spawn Example |
| 6 | Skills | Spawn prompt checklist in SKILL.md Phase 3 |
| 7 | References | "Identify reference docs" in Phase 1 |
| 8 | References | References section in progress.md template |
| 9 | References | Ref column in tasks.md template |
| 10 | References | References section in report-format.md |
| 11 | References | Reference population in SKILL.md Phase 3 & 5 |
| 12 | Gate | Completion Gate replaces Phase 5 step 5 |
| 13 | Gate | Simplify Remediation Gate |
| 14 | Gate | Completion Gate in progress.md Phase Checklist |
| 15 | Gate | Cross-reference in coordination-patterns.md |
| 16 | Verify | Run tests + validate plugin |
