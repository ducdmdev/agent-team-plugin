# Pre-Shutdown Commit & Complex Plan Enforcement — Implementation Plan

**Status**: Implemented

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add pre-shutdown commit enforcement for implementers and mandatory reviewer + tester roles for complex plans.

**Architecture:** Two independent features touching SKILL.md (Phase 2 and Phase 5), worker-roles.md (new Tester role + Implementer commit rule), coordination-patterns.md (new pattern), and README.md (roles table). All changes are prompt/doc edits — no code or hooks.

**Tech Stack:** Markdown (SKILL.md prompt engineering, reference docs)

---

### Task 1: Add Tester role to `docs/worker-roles.md`

**Files:**
- Modify: `docs/worker-roles.md:8` (Contents list)
- Modify: `docs/worker-roles.md:195` (after Challenger section, before Spawn Example)
- Modify: `docs/worker-roles.md:241-249` (Role Selection Guide table)

**Step 1: Add Tester to the Contents list**

In `docs/worker-roles.md`, add a Tester entry after the Challenger line in the Contents section (line 11):

```markdown
- [Tester](#tester) — run tests, verify builds, check runtime behavior
```

**Step 2: Add Tester role definition after Challenger section**

Insert after line 195 (`After completing each task, mark it complete via TaskUpdate and check TaskList for more work.` + closing triple backticks), before `## Spawn Example`:

```markdown

### Tester
**Purpose**: Run tests, verify builds, check runtime behavior.
**When to use**: Test execution, build verification, integration testing, runtime validation. Required for complex plans.
**Typical tools**: Read, Grep, Glob, Bash

**Spawn prompt template**:
```
You are a tester on this team. Your job is to verify that the implementation works correctly by running tests, checking builds, and validating runtime behavior.

Your assigned tasks: [TASK_IDS]
Your test scope: [SCOPE]

Workspace: .agent-team/[TEAM_NAME]/ — read these files for context on team progress, tasks, and known issues.

Communication protocol — send structured messages to the lead:
- STARTING #N: {what I plan to test}
- COMPLETED #N: {test results summary, pass/fail counts, any failures}
- BLOCKED #N: severity={level}, {what's blocking}, impact={what can't proceed}
- HANDOFF #N: {test failures that the implementer needs to fix}
- QUESTION: {what I need to know, what I already checked in workspace}

Results format — use consistent structure:
- **PASS**: test name, what was verified
- **FAIL**: test name, expected vs actual, reproduction steps, suggested fix
- **SKIP**: test name, reason skipped
In COMPLETED messages, include total counts: "N tests: X passed, Y failed, Z skipped"

Rules:
- Run existing test suites and write new tests as needed to verify implementation correctness.
- Do not modify implementation code. If you find a bug, report it via HANDOFF to the lead.
- Include reproduction steps for every failure.
- Read workspace files before asking the lead questions — the answer may already be there.
- When blocked on another teammate's output, message the lead with the BLOCKED format above.
- After completing each task, send COMPLETED to the lead, mark it complete via TaskUpdate, and check TaskList for more work.
- For large test scopes, use subagents (Task tool) to parallelize independent test runs.
```
```

**Step 3: Update Role Selection Guide table**

In `docs/worker-roles.md`, update the Role Selection Guide table. Add tester to relevant rows and add a new row:

Replace:
```
| New feature | 1-2 implementers (by module) + 1 reviewer | 2-3 |
```
With:
```
| New feature (standard) | 1-2 implementers (by module) + 1 reviewer | 2-3 |
| New feature (complex) | 1-2 implementers + 1 reviewer + 1 tester | 3-4 |
```

Replace:
```
| Full-stack feature | implementer (backend) + implementer (frontend) + reviewer | 3 |
```
With:
```
| Full-stack feature | implementer (backend) + implementer (frontend) + reviewer + tester | 3-4 |
```

**Step 4: Commit**

```bash
git add docs/worker-roles.md
git commit -m "feat: add Tester role definition and spawn template"
```

---

### Task 2: Add complexity assessment to SKILL.md Phase 2

**Files:**
- Modify: `skills/agent-team/SKILL.md:42-71` (Phase 2 section)

**Step 1: Add complexity assessment block**

In `skills/agent-team/SKILL.md`, replace the Phase 2 plan presentation template (lines 46-67) with the updated version that includes complexity assessment:

Replace this block:
```
Team plan for: [task summary]

Teammates (N total):
⚠ Team size check: [default max 4 | up to 6 if extra are read-only]
- [role-name]: [what they do] -> owns [files/area]
- [role-name]: [what they do] -> owns [files/area]

Task breakdown:
1. [task] -> assigned to [role]
2. [task] -> assigned to [role]
3. [task] -> assigned to [role] (blocked by #1)

Every phase has an owner (omit for pure review tasks):
- Setup/config: [role]
- Implementation: [role(s)]
- Verification: [role]
- Finalization: [role]

Workspace: .agent-team/[team-name]/
Estimated teammates: N
```

With:
```
Team plan for: [task summary]
Complexity: standard | complex
  (if complex) Reason: [why — e.g., multi-module, risky refactor, security-sensitive]
  (if complex) ✓ Dedicated reviewer included
  (if complex) ✓ Dedicated tester included

Teammates (N total):
⚠ Team size check: [default max 4 | up to 6 if extra are read-only]
- [role-name]: [what they do] -> owns [files/area]
- [role-name]: [what they do] -> owns [files/area]

Task breakdown:
1. [task] -> assigned to [role]
2. [task] -> assigned to [role]
3. [task] -> assigned to [role] (blocked by #1)

Every phase has an owner (omit for pure review tasks):
- Setup/config: [role]
- Implementation: [role(s)]
- Verification: [role]
- Testing: [role] (required for complex plans)
- Finalization: [role]

Workspace: .agent-team/[team-name]/
Estimated teammates: N
```

**Step 2: Add complexity self-check**

Replace the existing self-check line (line 69):

```
**Self-check before proceeding**: "Have I presented this plan AND received user confirmation?" If no, STOP.
```

With:

```
**Self-check before proceeding**:
1. "Is this plan complex? Complexity signals: multi-module/area changes, architectural decisions, risky refactors, multiple implementers with cross-dependencies, security-sensitive changes, new integrations. If yes, does the teammate list include a **dedicated reviewer** AND a **dedicated tester** (separate teammates, not combined)? If no, add them before presenting."
2. "Have I presented this plan AND received user confirmation?" If no, STOP.
```

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add complexity assessment and reviewer/tester gate to Phase 2"
```

---

### Task 3: Add pre-shutdown commit step to SKILL.md Phase 5

**Files:**
- Modify: `skills/agent-team/SKILL.md:290-331` (Phase 5 section)

**Step 1: Insert pre-shutdown commit step**

In `skills/agent-team/SKILL.md`, after step 2 ("Collect results", ending at line 301) and before step 3 ("Check integration", line 303), insert:

```markdown

3. **Pre-shutdown commit** — message each **implementer** to commit their owned files:
   ```
   Commit your owned files before shutdown.
   - Stage ONLY files in your owned area: git add <your owned files>
   - Commit with a descriptive message following project conventions
   - Send me the commit hash when done
   - If the commit fails (e.g., pre-commit hook rejection), fix the issue and retry. Do NOT proceed without a successful commit.
   ```
   Wait for all implementers to confirm with commit hashes. If any commit fails:
   - The implementer must fix and retry — shutdown cannot proceed until all commits succeed
   - Log the failure in `issues.md` as **high** severity
   - Only read-only teammates (reviewers, researchers, challengers, testers) are exempt — they have no files to commit
```

**Step 2: Renumber remaining steps**

Renumber the existing steps 3-8 to 4-9:
- Step 3 (Check integration) → Step 4
- Step 4 (Update workspace) → Step 5
- Step 5 (Generate final report) → Step 6
- Step 6 (Report to user) → Step 7
- Step 7 (Shutdown sequence) → Step 8
- Step 8 (Cleanup) → Step 9

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add pre-shutdown commit step to Phase 5"
```

---

### Task 4: Add pre-shutdown commit rule to Implementer spawn template in `docs/worker-roles.md`

**Files:**
- Modify: `docs/worker-roles.md:119-127` (Implementer Rules section in spawn template)

**Step 1: Add commit rule to Implementer template**

In `docs/worker-roles.md`, add a new rule after line 127 (`- For independent subtasks...`), before the closing triple backticks:

```
- Before shutdown: when the lead asks you to commit, stage ONLY your owned files (git add <owned files>) and commit with a descriptive message. Send the commit hash to the lead. If the commit fails, fix the issue and retry — do not accept shutdown until the commit succeeds.
```

**Step 2: Commit**

```bash
git add docs/worker-roles.md
git commit -m "feat: add pre-shutdown commit rule to Implementer spawn template"
```

---

### Task 5: Add Pre-Shutdown Commit pattern to `docs/coordination-patterns.md`

**Files:**
- Modify: `docs/coordination-patterns.md:7` (Contents list)
- Modify: `docs/coordination-patterns.md:86-100` (after First Contact Verification, before Parallel Shutdown — or after Parallel Shutdown)

**Step 1: Add to Contents list**

In `docs/coordination-patterns.md`, add after the Parallel Shutdown entry in the Contents list (line 10):

```markdown
- [Pre-Shutdown Commit](#pre-shutdown-commit) — ensuring implementers commit before shutdown
```

**Step 2: Add pattern section**

Insert after the Parallel Shutdown section (after line 100, `rm -f /tmp/agent-team-idle-counters/{team-name}--* 2>/dev/null || true` + closing backticks), before `## File Conflict Resolution`:

```markdown

## Pre-Shutdown Commit

Before sending shutdown requests, the lead must ensure all implementers have committed their owned files. This preserves git history and makes each teammate's contribution traceable.

1. **Identify implementers** — only teammates with file ownership need to commit. Read-only roles (reviewers, researchers, challengers, testers) are exempt.
2. **Message each implementer** in parallel:
   ```
   Commit your owned files before shutdown.
   - Stage ONLY files in your owned area: git add <your owned files>
   - Commit with a descriptive message following project conventions
   - Send me the commit hash when done
   - If the commit fails, fix the issue and retry.
   ```
3. **Wait for all commit confirmations** — each implementer sends a message with their commit hash.
4. **If a commit fails**: the implementer must fix and retry. Log the failure in `issues.md` as **high** severity. Shutdown cannot proceed until all commits succeed.
5. **Only after all commits confirmed**: proceed to the shutdown sequence.

**Why**: Without this step, teammate work exists only as uncommitted changes on disk. If anything goes wrong during shutdown or cleanup, work is lost. Per-teammate commits also make `git log` useful for tracing who did what.
```

**Step 3: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "feat: add Pre-Shutdown Commit coordination pattern"
```

---

### Task 6: Add Tester to README.md roles table

**Files:**
- Modify: `README.md:79-84` (Teammate Roles table)

**Step 1: Add Tester row**

In `README.md`, add after the Challenger row (line 84):

```markdown
| **Tester** | Run tests, verify builds, check runtime behavior | Read, Grep, Glob, Bash |
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add Tester role to README teammate roles table"
```

---

### Task 7: Add Tester to SKILL.md Phase 3 spawn guidance

**Files:**
- Modify: `skills/agent-team/SKILL.md:176` (Phase 3, step 5 — spawn teammates paragraph)

**Step 1: Add Tester to subagent_type guidance**

In `skills/agent-team/SKILL.md`, in Phase 3 step 5 (line 176), the sentence about subagent_type currently reads:

```
Use `subagent_type: "general-purpose"` for teammates that need full tool access (Write, Edit, Bash). Use `subagent_type: "Explore"` for read-only research teammates. Use `general-purpose` if a reviewer needs to run commands (tests, builds).
```

Replace with:

```
Use `subagent_type: "general-purpose"` for teammates that need full tool access (Write, Edit, Bash) — implementers, challengers, testers. Use `subagent_type: "Explore"` for read-only research teammates. Use `general-purpose` if a reviewer needs to run commands (tests, builds).
```

**Step 2: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add Tester to Phase 3 spawn guidance"
```

---

### Task 8: Final verification

**Step 1: Verify all files are consistent**

Read each modified file and check:
- `docs/worker-roles.md`: Tester role exists with full spawn template, Role Selection Guide updated, Implementer has commit rule
- `skills/agent-team/SKILL.md`: Phase 2 has complexity assessment + self-check, Phase 3 mentions Tester, Phase 5 has pre-shutdown commit step with correct numbering
- `docs/coordination-patterns.md`: Pre-Shutdown Commit pattern exists in Contents and body
- `README.md`: Tester row in roles table

**Step 2: Verify no broken markdown**

Spot-check that table alignment and code fences are correct in all modified files.

**Step 3: Commit any fixes if needed**

```bash
git add -A && git commit -m "fix: address review findings from implementation verification"
```
