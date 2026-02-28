# Paired Reviewer + Hook Workspace Fix Implementation Plan

**Status**: Draft (not started)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** (1) Add optional 1:1 paired reviewer per implementer — user opts in during Phase 2, lead recommends for complex plans. When enabled: continuous review, lead-audited issues, blocking gate. When disabled: COMPLETED → task complete directly. (2) Fix the TaskCompleted and TeammateIdle hook workspace lookup bug for remediation teams.

**Architecture:** Paired review is opt-in. The lead presents it in Phase 2 and the user approves or declines. When enabled, paired reviewers are spawned alongside implementers. When an implementer sends COMPLETED, the lead routes the task to the paired reviewer instead of marking it complete. The reviewer sends REVIEW-PASS or REVIEW-FAIL. On REVIEW-FAIL, the lead audits findings, writes confirmed issues to issues.md, and routes fixes to the implementer. Loop repeats until REVIEW-PASS. Every review cycle is logged in `review-log.md`. When disabled, no reviewers are spawned, COMPLETED goes straight to task completion, and review-log.md is not created. For the hook fix, both scripts learn to strip the `-fix` suffix from team names to find the remediation workspace at `.agent-team/{original-team}/`.

**Tech Stack:** Markdown skill files, bash scripts, bash test scripts

**Design doc:** `docs/plans/2026-02-26-paired-reviewer-design.md`
**Supersedes:** `docs/plans/2026-02-26-paired-reviewer-impl.md` (outdated line numbers)

---

### Task 1: Fix verify-task-complete.sh remediation workspace lookup

**Files:**
- Modify: `scripts/verify-task-complete.sh:21-39`
- Test: `tests/hooks/test-verify-task-complete.sh`

**Context:** Issue #24 — when a remediation team named `{original}-fix` runs, the hook looks for `.agent-team/{original}-fix/` but the workspace is at `.agent-team/{original}/`. The hook blocks task completion because it can't find the workspace files.

**Step 1: Write the failing test**

Add test 12 to `tests/hooks/test-verify-task-complete.sh` before the `print_summary` line:

```bash
# --- Test 12: Remediation team (-fix suffix) finds original workspace ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "my-project"   # workspace at .agent-team/my-project/
setup_mock_git_repo "dirty"
run_hook "$HOOK" '{"task_subject":"Fix README issues","team_name":"my-project-fix"}'
assert_exit_code 0 "$HOOK_EXIT" "12: Remediation team (-fix suffix) finds original workspace"
cleanup_temp_dir
```

**Step 2: Run the test to verify it fails**

Run: `bash tests/hooks/test-verify-task-complete.sh`
Expected: Test 12 FAIL (exit code 2 instead of 0 — workspace not found)

**Step 3: Fix the workspace lookup in verify-task-complete.sh**

Replace lines 21-39 of `scripts/verify-task-complete.sh`:

Current code:
```bash
if [ -n "$TEAM_NAME" ]; then
  # Check for workspace in project directory
  WORKSPACE_DIR=".agent-team/$TEAM_NAME"
  if [ -d "$WORKSPACE_DIR" ]; then
    # Workspace exists in project — check for tracking files
    for f in progress.md tasks.md issues.md; do
      if [ ! -f "$WORKSPACE_DIR/$f" ]; then
        echo "Workspace file missing: $WORKSPACE_DIR/$f. The lead must initialize all workspace files (Phase 3, step 3) before tasks can be completed." >&2
        exit 2
      fi
    done
  else
    # Fallback: check legacy workspace location (pre-v1.2.0 used ~/.claude/teams/)
    WORKSPACE_FALLBACK="$HOME/.claude/teams/$TEAM_NAME/progress.md"
    if [ ! -f "$WORKSPACE_FALLBACK" ]; then
      echo "Workspace missing at $WORKSPACE_DIR/. The lead must initialize the workspace (Phase 3, step 3) before any tasks can be completed." >&2
      exit 2
    fi
  fi
fi
```

New code:
```bash
if [ -n "$TEAM_NAME" ]; then
  # Check for workspace in project directory.
  # Remediation teams use name {original}-fix but reuse workspace at .agent-team/{original}/.
  WORKSPACE_DIR=".agent-team/$TEAM_NAME"
  if [ ! -d "$WORKSPACE_DIR" ]; then
    # Try stripping -fix suffix (remediation team convention)
    BASE_NAME="${TEAM_NAME%-fix}"
    if [ "$BASE_NAME" != "$TEAM_NAME" ] && [ -d ".agent-team/$BASE_NAME" ]; then
      WORKSPACE_DIR=".agent-team/$BASE_NAME"
    fi
  fi

  if [ -d "$WORKSPACE_DIR" ]; then
    # Workspace exists — check for tracking files
    for f in progress.md tasks.md issues.md; do
      if [ ! -f "$WORKSPACE_DIR/$f" ]; then
        echo "Workspace file missing: $WORKSPACE_DIR/$f. The lead must initialize all workspace files (Phase 3, step 3) before tasks can be completed." >&2
        exit 2
      fi
    done
  else
    # Fallback: check legacy workspace location (pre-v1.2.0 used ~/.claude/teams/)
    WORKSPACE_FALLBACK="$HOME/.claude/teams/$TEAM_NAME/progress.md"
    if [ ! -f "$WORKSPACE_FALLBACK" ]; then
      echo "Workspace missing at .agent-team/$TEAM_NAME/. The lead must initialize the workspace (Phase 3, step 3) before any tasks can be completed." >&2
      exit 2
    fi
  fi
fi
```

**Step 4: Run the test to verify it passes**

Run: `bash tests/hooks/test-verify-task-complete.sh`
Expected: All 12 tests PASS

**Step 5: Commit**

```bash
git add scripts/verify-task-complete.sh tests/hooks/test-verify-task-complete.sh
git commit -m "fix: handle remediation team workspace lookup in TaskCompleted hook"
```

---

### Task 2: Fix check-teammate-idle.sh remediation workspace lookup

**Files:**
- Modify: `scripts/check-teammate-idle.sh:21-28`
- Test: `tests/hooks/test-check-teammate-idle.sh`

**Context:** Same bug as Task 1 but in the idle hook. When team name is `{original}-fix`, the hook looks for `.agent-team/{original}-fix/tasks.md` which doesn't exist. Currently it silently exits 0 (no nudge), so idle enforcement is disabled for all remediation teams.

**Step 1: Write the failing test**

Read the existing test file first to find where to insert. Add a new test that creates a workspace for `my-project` with an in-progress task owned by the teammate, then runs the hook with team name `my-project-fix`. The hook should find the workspace via the `-fix` fallback and block.

Add before `print_summary`:

```bash
# --- Test N: Remediation team (-fix suffix) finds original workspace ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
# Create workspace at .agent-team/my-project/ (the original team)
setup_mock_workspace "my-project"
# Add an in-progress task owned by the teammate
cat >> "$WORKSPACE_DIR/tasks.md" <<'TASKS'
| 1 | Fix something | test-impl | in_progress | — | — |
TASKS
run_hook "$HOOK" '{"teammate_name":"test-impl","team_name":"my-project-fix"}'
assert_exit_code 2 "$HOOK_EXIT" "N: Remediation team (-fix) finds original workspace and blocks idle"
cleanup_temp_dir
```

**Step 2: Run the test to verify it fails**

Run: `bash tests/hooks/test-check-teammate-idle.sh`
Expected: New test FAIL (exit 0 instead of 2 — workspace not found, so hook skips)

**Step 3: Fix the workspace lookup in check-teammate-idle.sh**

Replace lines 21-28 of `scripts/check-teammate-idle.sh`:

Current code:
```bash
# Check workspace tasks.md for in-progress tasks owned by this teammate.
# Format: markdown table with columns: ID | Subject | Owner | Status | Blocked By | Notes
TASKS_FILE=".agent-team/$TEAM/tasks.md"

# Skip if workspace tasks.md doesn't exist — graceful degradation
if [ ! -f "$TASKS_FILE" ]; then
  exit 0
fi
```

New code:
```bash
# Check workspace tasks.md for in-progress tasks owned by this teammate.
# Format: markdown table with columns: ID | Subject | Owner | Status | Blocked By | Notes
# Remediation teams use name {original}-fix but reuse workspace at .agent-team/{original}/.
TASKS_FILE=".agent-team/$TEAM/tasks.md"
if [ ! -f "$TASKS_FILE" ]; then
  BASE_NAME="${TEAM%-fix}"
  if [ "$BASE_NAME" != "$TEAM" ] && [ -f ".agent-team/$BASE_NAME/tasks.md" ]; then
    TASKS_FILE=".agent-team/$BASE_NAME/tasks.md"
  else
    # Skip if workspace tasks.md doesn't exist — graceful degradation
    exit 0
  fi
fi
```

**Step 4: Run the test to verify it passes**

Run: `bash tests/hooks/test-check-teammate-idle.sh`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add scripts/check-teammate-idle.sh tests/hooks/test-check-teammate-idle.sh
git commit -m "fix: handle remediation team workspace lookup in TeammateIdle hook"
```

---

### Task 3: Update Reviewer spawn template in worker-roles.md

**Files:**
- Modify: `docs/worker-roles.md:132-167` (Reviewer section)

**Step 1: Replace the Reviewer section**

Replace lines 132-167 with:

```markdown
### Reviewer
**Purpose**: Validate code quality, find issues, verify correctness. When paired review is enabled, each reviewer is paired 1:1 with an implementer.
**When to use**: Paired 1:1 with each implementer when user enables paired review. Also used standalone for code review, security audit, test validation, compliance check.
**Typical tools**: Read, Grep, Glob, Bash (read-only commands; Bash for verification commands)

**Spawn prompt template**:
` ` `
You are a reviewer on this team. Your job is to validate work quality and find issues for your paired implementer.

Your paired implementer: [IMPLEMENTER_NAME]
Your review scope: [IMPLEMENTER_FILES]
Your assigned tasks: [TASK_IDS]

Workspace: .agent-team/[TEAM_NAME]/ — read these files for context on team progress, tasks, and known issues.

Communication protocol — send structured messages to the lead:
- STARTING #N: {what I plan to review}
- REVIEW-PASS #N: {no issues found, task approved}
- REVIEW-FAIL #N: {issues found by severity — H1: ..., M1: ..., L1: ...}
- BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
- QUESTION: {what I need to know, what I already checked in workspace}

Findings format — use consistent severity labels:
- **H{n}** (high — must fix): file:line, description, suggested fix
- **M{n}** (medium — should fix): file:line, description
- **L{n}** (low — suggestion): file:line, description
Number sequentially per severity within each review (H1, H2, M1, M2, L1...).
In REVIEW-FAIL messages, include total counts: "N issues: X high, Y medium, Z low"

Rules:
- Read and analyze only. Do not modify files.
- Wait for the lead to route tasks to you for review. Do not self-assign review tasks.
- When the lead sends you a task to review, read the implementer's changed files and assess quality, correctness, and adherence to requirements.
- Include specific file:line references and fix suggestions for every high-severity issue.
- Send REVIEW-PASS if the work meets quality standards. Send REVIEW-FAIL if issues are found.
- Read workspace issues.md to avoid reporting known/duplicate issues.
- After completing each review, check with the lead for more review work.
- For large review scopes, use subagents (Task tool with subagent_type=Explore) to parallelize file reads.
` ` `
```

(Note: `` ` ` ` `` above represents triple backticks — the actual file uses real triple backticks.)

**Step 2: Verify the edit**

Read `docs/worker-roles.md:132-172` to confirm the Reviewer section is correct and the Challenger section (starting with `### Challenger`) follows immediately after.

**Step 3: Commit**

```bash
git add docs/worker-roles.md
git commit -m "feat: update reviewer role to paired 1:1 mode with REVIEW-PASS/FAIL protocol"
```

---

### Task 4: Update Role Selection Guide + Team Size Limits in worker-roles.md

**Files:**
- Modify: `docs/worker-roles.md:279-296` (Role Selection Guide + Team Size Limits)

**Step 1: Replace the Role Selection Guide table**

Replace lines 281-290 (the table body) with:

```markdown
| Task Type | Recommended Roles | Typical Size | Paired Review |
|---|---|---|---|
| Code review | 2-3 reviewers with different lenses (security, performance, style) | 2-3 (all read-only) | N/A |
| New feature (standard) | 1-2 implementers (+ paired reviewers if enabled) | 1-4 | Optional |
| New feature (complex) | 1-2 implementers + paired reviewers + 1 tester | 3-5 | Recommended |
| Bug investigation | 2-3 researchers with competing hypotheses | 2-3 (all read-only) | N/A |
| Refactoring | 1-2 implementers (+ paired reviewers if enabled) | 1-4 | Optional |
| Architecture evaluation | 1 researcher + 1 challenger | 2 (all read-only) | N/A |
| Full-stack feature | 2 implementers + 2 paired reviewers + 1 tester | 3-5 | Recommended |
| Large audit / migration | 2 implementers + paired reviewers + 2-3 researchers | 4-7 | Recommended |
```

**Step 2: Replace Team Size Limits**

Replace lines 292-296 with:

```markdown
### Team Size Limits

- **Default max: 6** for mixed teams (implementers + their paired reviewers + other roles)
- **Up to 8** if the additional teammates beyond 6 are read-only (researchers, extra reviewers using `subagent_type: "Explore"`) — they have zero file conflict risk and low coordination cost
- Paired reviewers use `subagent_type: "Explore"` (read-only) and do not count toward the "implementer" limit — they have zero file conflict risk
- **Self-check for N > 6**: before spawning, verify (1) every stream has zero file overlap, (2) cross-communication between teammates is minimal, (3) workspace churn remains manageable. If any check fails, merge roles
```

**Step 3: Verify the edit**

Read `docs/worker-roles.md:279-300`.

**Step 4: Commit**

```bash
git add docs/worker-roles.md
git commit -m "feat: update role selection guide and team size limits for paired reviewers"
```

---

### Task 5: Add paired reviewer spawn example in worker-roles.md

**Files:**
- Modify: `docs/worker-roles.md:236-277` (Spawn Example section)

**Step 1: Add paired reviewer spawn example**

After line 271 (end of the implementer spawn example's closing triple-backtick block), insert:

```markdown

Here is a concrete example of spawning the paired reviewer for the implementer above:

` ` `
Task tool call:
  subagent_type: "Explore"
  team_name: "refactor-auth"
  name: "backend-reviewer"
  prompt: |
    You are a reviewer on this team. Your job is to validate work quality and find issues for your paired implementer.

    Your paired implementer: backend-impl
    Your review scope: src/auth/, src/middleware/auth.ts
    Your assigned tasks: (assigned dynamically by the lead as backend-impl completes tasks)

    Workspace: .agent-team/refactor-auth/ — read these files for context on team progress, tasks, and known issues.

    Communication protocol — send structured messages to the lead:
    - STARTING #N: {what I plan to review}
    - REVIEW-PASS #N: {no issues found, task approved}
    - REVIEW-FAIL #N: {issues found by severity — H1: ..., M1: ..., L1: ...}
    - BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
    - QUESTION: {what I need to know, what I already checked in workspace}

    Rules:
    - Read and analyze only. Do not modify files.
    - Wait for the lead to route tasks to you for review.
    - Include specific file:line references and fix suggestions for every high-severity issue.
    - Send REVIEW-PASS if the work meets quality standards. Send REVIEW-FAIL if issues are found.
    - Read workspace issues.md to avoid reporting known/duplicate issues.
` ` `
```

**Step 2: Update Key parameters note**

Replace lines 273-277 with:

```markdown
Key parameters:
- `subagent_type`: `"general-purpose"` for full tool access (implementers, challengers, testers). `"Explore"` for read-only roles (paired reviewers, researchers). `"general-purpose"` if a reviewer needs Bash (e.g., running tests, build verification).
- `team_name`: must match the team created via TeamCreate.
- `name`: human-readable name used for messaging and task assignment. Convention for paired reviewers: `{implementer-name}-reviewer` (e.g., `backend-impl` → `backend-reviewer`).
- `mode`: `"default"` for normal operation. `"plan"` requires the teammate to get plan approval from the lead before making changes — use this for risky or architectural tasks.
```

**Step 3: Verify the edit**

Read `docs/worker-roles.md:236-320` to confirm the example and parameters are correct.

**Step 4: Commit**

```bash
git add docs/worker-roles.md
git commit -m "feat: add paired reviewer spawn example to worker-roles.md"
```

---

### Task 6: Update Phase 2 plan format in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:46-78` (Phase 2 plan template + self-check)

**Step 1: Replace the plan template code block**

Replace lines 46-72 (the plan template code block) with:

````markdown
```
Team plan for: [task summary]
Complexity: standard | complex
  (if complex) Reason: [why — e.g., multi-module, risky refactor, security-sensitive]
  (if complex) ✓ Dedicated tester included
Paired review: yes | no  ← recommended for complex plans; adds a paired reviewer per implementer for continuous code review
  (if yes) Each implementer gets a paired reviewer — tasks require REVIEW-PASS before completion

Teammates (N total):
⚠ Team size check: [default max 6 | up to 8 if extra are read-only]
- [implementer-name] (implementer): [what they do] -> owns [files/area]
  └─ [reviewer-name] (reviewer): reviews [implementer-name]'s work  ← only if paired review = yes
- [other-role-name]: [what they do] -> owns [files/area]

Task breakdown:
1. [task] -> assigned to [role]
2. [task] -> assigned to [role]
3. [task] -> assigned to [role] (blocked by #1)

Every phase has an owner (omit for pure review tasks):
- Setup/config: [role]
- Implementation: [role(s)]
- Review: paired reviewers (only if paired review = yes — each implementer's tasks are reviewed continuously)
- Testing: [role] (required for complex plans)
- Finalization: [role]

Workspace: .agent-team/[team-name]/
Estimated teammates: N
```
````

**Step 2: Replace the self-check**

Replace lines 74-78 with:

```markdown
**Self-check before proceeding**:
1. "Is this plan complex? Complexity signals: multi-module/area changes, architectural decisions, risky refactors, multiple implementers with cross-dependencies, security-sensitive changes, new integrations. If yes, does the teammate list include a **dedicated tester** (separate from reviewers)? If no, add one before presenting."
2. "Have I included a `Paired review: yes | no` line? For complex plans, I should recommend `yes`. For standard plans, present both options and let the user decide."
3. "If paired review = yes, does every implementer have a paired reviewer listed directly beneath them (with └─ prefix)? If not, add one."
4. "Have I presented this plan AND received user confirmation?" If no, STOP.
```

**Step 3: Verify the edit**

Read `skills/agent-team/SKILL.md:42-85`.

**Step 4: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: update Phase 2 plan format with opt-in paired review"
```

---

### Task 7: Update Phase 3 spawn rules + team size gate in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:184-200` (Phase 3 steps 5-6)

**Step 1: Replace spawn instructions (step 5)**

Replace lines 184-194 with:

```markdown
5. **Spawn teammates** using the Task tool with `team_name`, `name`, and `subagent_type` parameters. See [worker-roles.md](../../docs/worker-roles.md) for role-specific spawn templates. Use `subagent_type: "general-purpose"` for teammates that need full tool access (Write, Edit, Bash) — implementers, challengers, testers. Use `subagent_type: "Explore"` for read-only teammates (paired reviewers, researchers). Use `general-purpose` if a reviewer needs to run commands (tests, builds). Optionally set `mode: "plan"` to require plan approval before a teammate implements anything — useful for risky or architectural tasks.

   **Paired reviewer rule** (only if user approved paired review in Phase 2): For every implementer spawned, also spawn a paired reviewer. The reviewer's spawn prompt MUST include:
   - Their paired implementer's name
   - The implementer's file ownership (= the reviewer's review scope)
   - The REVIEW-PASS / REVIEW-FAIL message format
   - Instruction to wait for the lead to route tasks for review
   If paired review was declined, do NOT spawn paired reviewers.

   Each spawn prompt MUST include:
   - Their role and responsibilities
   - Which tasks are assigned to them (reference task IDs)
   - Which files/areas they own exclusively (implementers) or review (reviewers)
   - **Workspace path**: `.agent-team/{team-name}/` — tell them to read these files for context. Teammates should write any output artifacts (reports, findings) to this directory so all outputs are co-located
   - **Communication protocol** (see Phase 4 section below — include the structured message format)
   - What to do when blocked: message the lead with severity and impact, do not wait silently
   - Instruction to mark tasks complete immediately after verification (implementers) or send REVIEW-PASS/FAIL (reviewers, if paired review enabled)
   - Instruction to check TaskList after completing each task and self-claim next available
   - Instruction to use subagents (Task tool) for focused subtasks that don't need teammate communication
   - **Update workspace**: record each teammate in `progress.md` Team Members table
```

**Step 2: Replace team size gate (step 6)**

Replace lines 196-200 with:

```markdown
6. **Team size gate** — explicitly count before spawning: "I am spawning N teammates: [list names]."
   - **Default max: 6** for mixed teams (implementers + their paired reviewers + other roles)
   - **Up to 8** if the additional teammates beyond 6 are **read-only** (researchers, extra reviewers using `subagent_type: "Explore"`) — read-only agents have zero file conflict risk and minimal coordination cost
   - Paired reviewers use `subagent_type: "Explore"` (read-only) — they do not create file conflict risk
   - **Self-check for N > 6**: (1) every stream has zero file overlap, (2) cross-communication between teammates is minimal, (3) the lead can track all streams without excessive workspace churn
   - If the self-check fails on any point, merge roles until it passes
```

**Step 3: Verify the edit**

Read `skills/agent-team/SKILL.md:184-210`.

**Step 4: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: update Phase 3 spawn rules to require paired reviewer per implementer"
```

---

### Task 8: Update Phase 4 Communication Protocol + Lead Processing Rules in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:242-264` (Communication Protocol + Lead Processing Rules)

**Step 1: Update the structured message format block**

Replace lines 246-252 (the message format code block content) with:

````markdown
```
STARTING #N: {what I plan to do, which files I'll touch}
COMPLETED #N: {what I did, files changed, any concerns}
BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
HANDOFF #N: {what I produced that another teammate needs, key details}
QUESTION: {what I need to know, what I already checked}

Reviewer-specific messages (paired reviewers use these instead of COMPLETED):
REVIEW-PASS #N: {no issues found, task approved}
REVIEW-FAIL #N: {issues found — H1: ..., M1: ..., L1: ...}
```
````

**Step 2: Replace the Lead Processing Rules table**

Replace lines 258-264 with:

```markdown
| Prefix | Lead Action |
|--------|--------------|
| STARTING | Update `tasks.md` status to `in_progress`, add note |
| COMPLETED | **If paired review enabled**: do NOT mark task complete yet — route to the paired reviewer: message reviewer with "Review task #N — implementer changed files: [list]. Review the implementation quality and send REVIEW-PASS or REVIEW-FAIL." **If paired review disabled**: mark task #N as `completed` in `tasks.md` directly. Check if this unblocks other tasks |
| BLOCKED | Add row to `issues.md` immediately. Acknowledge the teammate. Route to resolution |
| HANDOFF | Extract key details, forward to dependent teammate with actionable context. Log in `progress.md` Handoffs |
| QUESTION | Check if answer is in workspace files. If yes, answer with file reference. If no, investigate |
| REVIEW-PASS | _(Only when paired review enabled)_ Mark task #N as `completed` in `tasks.md`. Log cycle in `review-log.md` (result=PASS). Check: does this unblock other tasks? If yes, message the dependent teammate |
| REVIEW-FAIL | _(Only when paired review enabled)_ **Lead audit step**: (1) Read findings (H/M/L with file:line). (2) Validate each finding. (3) Write confirmed issues to `issues.md`. (4) Log cycle in `review-log.md` (result=FAIL, findings count). (5) Route confirmed fixes to implementer. (6) Drop findings the lead disagrees with. Task stays `in_progress` until implementer sends COMPLETED again and reviewer sends REVIEW-PASS |
```

**Step 3: Verify the edit**

Read `skills/agent-team/SKILL.md:242-280`.

**Step 4: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: update Phase 4 lead processing rules with conditional review loop"
```

---

### Task 9: Update Workspace Update Protocol in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:228-240` (Workspace Update Protocol table)

**Step 1: Replace the table**

Replace lines 228-240 with:

```markdown
| Event | File | What to update |
|-------|------|---------------|
| Team created | All files (3 base + review-log.md if paired review) | Initialize from templates |
| Tasks created | tasks.md | Fill task ledger |
| Teammate spawned | progress.md | Add row to Team Members |
| Task started | tasks.md | Status -> `in_progress` |
| Task completed (no paired review) | tasks.md | Status -> `completed`, add notes |
| Task sent to reviewer (paired review) | tasks.md | Add note: "under review by {reviewer-name}" |
| Review passed (paired review) | tasks.md, review-log.md | Status -> `completed`, add notes. Append row to review-log.md (result=PASS) |
| Review failed (paired review) | issues.md, tasks.md, review-log.md | Append confirmed issues to issues.md, add note to tasks.md: "review failed — N issues, awaiting fix". Append row to review-log.md (result=FAIL, findings count) |
| Issue fixed and re-reviewed | issues.md, tasks.md | Update issue status, update task notes |
| Decision made | progress.md | Append to Decision Log |
| Handoff occurs | progress.md | Append to Handoffs |
| Issue found | issues.md | Append row, update Open count |
| Issue resolved | issues.md | Status -> RESOLVED/MITIGATED, update counts |
| Teammate status change | progress.md | Update Team Members table |
| All work done | progress.md | Status -> `done` |
```

**Step 2: Verify the edit**

Read `skills/agent-team/SKILL.md:226-245`.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add review events to workspace update protocol"
```

---

### Task 10: Add review-log.md workspace template + conditional init + paired review field to SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:89-95` (Phase 3 workspace init)
- Modify: `skills/agent-team/SKILL.md:106-112` (progress.md template — add Paired review field)
- Modify: `skills/agent-team/SKILL.md` (insert new template after issues.md template, before step 4)

**Context:** The review-log.md tracks every review cycle when paired review is enabled. The lead appends a row on every REVIEW-PASS and REVIEW-FAIL, creating a full audit trail. When paired review is disabled, this file is not created. The progress.md template gets a new `**Paired review**` field so the lead (and hooks/coordination logic) can check whether paired review is active.

**Step 0: Add Paired review field to progress.md template**

In the progress.md template, after the `**Remediation cycle**` line, add:

```
   **Paired review**: enabled | disabled
```

This field is set during Phase 3 workspace init based on the user's Phase 2 choice.

**Step 1: Update the workspace init step**

In Phase 3 step 3 (lines 89-95), update the init instructions to conditionally include review-log.md:

Replace:
```
   mkdir -p .agent-team/{team-name}
   Write: .agent-team/{team-name}/progress.md
   Write: .agent-team/{team-name}/tasks.md
   Write: .agent-team/{team-name}/issues.md
```

With:
```
   mkdir -p .agent-team/{team-name}
   Write: .agent-team/{team-name}/progress.md
   Write: .agent-team/{team-name}/tasks.md
   Write: .agent-team/{team-name}/issues.md
   Write: .agent-team/{team-name}/review-log.md  ← only if paired review is enabled
```

**Step 2: Update "all 3 tracking files" references**

Search SKILL.md for "all 3 tracking files" and replace with "all 3 tracking files (+ review-log.md if paired review is enabled)". Also update "Use the following templates" paragraph at line 97 if it mentions 3 files.

**Step 3: Add review-log.md template**

Insert the following template block after the issues.md template closing (after the `## Impact Categories` section and its closing triple-backtick, before step 4 "Create ALL tasks upfront"):

```markdown
   #### review-log.md

   ` ` `markdown
   # Review Log: {team-name}

   **Last updated**: {timestamp}

   | Task | Implementer | Reviewer | Cycle | Result | Findings | Notes |
   |------|-------------|----------|-------|--------|----------|-------|

   ## Column Guide
   - **Task**: Task ID being reviewed (e.g., #3)
   - **Implementer**: Name of the implementer whose work is reviewed
   - **Reviewer**: Name of the paired reviewer
   - **Cycle**: Review cycle number (1 = first review, 2 = re-review after fixes, etc.)
   - **Result**: PASS or FAIL
   - **Findings**: Count summary (e.g., "0H 2M 1L" or "—" for PASS)
   - **Notes**: Brief summary of key issues or "clean"
   ` ` `
```

(Note: `` ` ` ` `` represents triple backticks.)

**Step 4: Verify the edit**

Read `skills/agent-team/SKILL.md:89-180` to confirm:
- progress.md template has `**Paired review**: enabled | disabled` field
- Workspace init conditionally lists review-log.md
- The review-log.md template has the correct table structure

**Step 5: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add review-log.md template, paired review field to progress.md"
```

---

### Task 11: Update Anti-Patterns in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Anti-Patterns section — line numbers will shift after Task 10 inserts the review-log.md template)

**Step 1: Replace the team size limit anti-pattern and add new ones**

Find the line:
```
- **DO NOT exceed team size limits** — max 4 mixed, up to 6 if extras are read-only. Self-check required for N > 4
```

Replace with:
```
- **DO NOT exceed team size limits** — max 6 mixed, up to 8 if extras are read-only. Self-check required for N > 6
- **DO NOT skip paired reviewers when enabled** — if the user approved paired review, every implementer MUST have a paired reviewer. Do not mark implementer tasks complete without a REVIEW-PASS from the paired reviewer
- **DO NOT write issues to issues.md without auditing** — when a reviewer sends REVIEW-FAIL, the lead must validate each finding before writing to issues.md
- **DO NOT force paired review on the user** — always present it as an option with a recommendation. The user decides
```

**Step 2: Verify the edit**

Read the Anti-Patterns section to confirm all entries.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add paired reviewer anti-patterns to SKILL.md"
```

---

### Task 12: Add Review Loop section to coordination-patterns.md

**Files:**
- Modify: `docs/coordination-patterns.md:6-20` (Contents), `docs/coordination-patterns.md:40-46` (Lead Processing), insert new section

**Step 1: Add Review Loop to the Contents list**

After line 12 (the Remediation Gate entry), add:
```
- [Review Loop](#review-loop) — paired reviewer continuous review cycle with lead audit
```

**Step 2: Update the Lead Processing table**

Replace lines 40-46 with:

```markdown
| Prefix | Lead Action |
|--------|--------------|
| STARTING | Update `tasks.md` status to `in_progress`, add note |
| COMPLETED | **If paired review enabled**: route to the paired reviewer for review — do NOT mark complete yet. **If paired review disabled**: mark task as `completed` directly |
| BLOCKED | Add row to `issues.md` immediately. Acknowledge the teammate. Route to resolution |
| HANDOFF | Extract key details, forward to dependent teammate with actionable context. Log in `progress.md` Handoffs |
| QUESTION | Check if answer is in workspace files. If yes, answer with file reference. If no, investigate |
| REVIEW-PASS | _(Paired review only)_ Mark task as `completed` in `tasks.md`. Log cycle in `review-log.md` (result=PASS). Check if this unblocks other tasks |
| REVIEW-FAIL | _(Paired review only)_ Audit findings, write confirmed issues to `issues.md`, log cycle in `review-log.md` (result=FAIL, findings count), route confirmed fixes to implementer |
```

**Step 3: Add the Review Loop section**

Insert after the Pre-Shutdown Commit section (after line 122, before the `## Remediation Gate` heading at line 124):

```markdown
## Review Loop

Paired review is an opt-in feature — the user approves it during Phase 2. When enabled, every implementer has a paired reviewer. When an implementer completes a task, the lead routes it to the paired reviewer before marking it complete. This creates a continuous review cycle with a blocking gate. Every cycle is logged in `review-log.md`. When paired review is disabled, this loop does not apply — COMPLETED goes straight to task completion.

### Protocol

1. **Implementer sends COMPLETED #N** — the lead does NOT mark the task complete yet.
2. **Lead routes to paired reviewer** — message the reviewer: "Review task #N. [Implementer-name] changed these files: [list]. Review the implementation quality and send REVIEW-PASS or REVIEW-FAIL."
3. **Reviewer reviews and responds**:
   - `REVIEW-PASS #N`: no issues found, task is approved
   - `REVIEW-FAIL #N`: issues found with severity labels (H1, M1, L1...)
4. **Lead processes the response**:
   - **REVIEW-PASS**: mark task #N as `completed` in `tasks.md`. Append row to `review-log.md` (result=PASS). Check if this unblocks other tasks.
   - **REVIEW-FAIL**: lead audits findings (see Lead Audit Step below), writes confirmed issues to `issues.md`, appends row to `review-log.md` (result=FAIL, findings count), routes confirmed issues to implementer.
5. **Implementer fixes** — sends COMPLETED #N again after fixing.
6. **Loop repeats** until REVIEW-PASS. Each cycle gets a new row in `review-log.md`.

### Lead Audit Step

When the reviewer sends REVIEW-FAIL #N, the lead validates the findings before acting:

1. Read each finding (H/M/L with file:line references)
2. Validate: is the issue real? Is the severity correct?
3. Write confirmed issues to `issues.md` (append rows, update Open count)
4. Route confirmed issues to the implementer: "Fix these issues for task #N: [list confirmed issues with file:line and severity]"
5. If the lead disagrees with a finding, drop it — do not write to `issues.md`

### Workspace Updates During Review

| Event | File | What to update |
|-------|------|---------------|
| Task sent to reviewer | tasks.md | Add note: "under review by {reviewer-name}" |
| Review passed | tasks.md, review-log.md | Status -> `completed`. Append row (result=PASS) |
| Review failed (issues confirmed) | issues.md, tasks.md, review-log.md | Append confirmed issues, add note: "review failed — N issues". Append row (result=FAIL) |
| Issue fixed and re-reviewed | issues.md, tasks.md | Update issue status, update task notes |

### Handling Slow Reviewers

If a paired reviewer hasn't responded within a reasonable time:
1. Send a status check: "Status on review for task #N?"
2. If still no response: investigate (check idle notification)
3. If unrecoverable: shut down reviewer, spawn replacement with same pairing

### Handling Disagreements

If the implementer disputes a reviewer's finding:
1. Implementer sends QUESTION to the lead explaining their reasoning
2. Lead evaluates both positions during audit
3. Lead makes final call — either confirms the issue or drops it
4. Log the decision in `progress.md` Decision Log
```

**Step 4: Verify the edit**

Read `docs/coordination-patterns.md:1-20` to verify Contents. Read the new Review Loop section.

**Step 5: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "feat: add Review Loop coordination pattern for paired reviewers"
```

---

### Task 13: Update SKILL.md coordination patterns list

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Coordination Patterns bullet list — line numbers will shift after Task 10)

**Step 1: Add Review Loop to the list**

Find the Remediation gate bullet in the coordination patterns list and add after it:
```
- **Review loop** (when paired review enabled) — paired reviewer reviews each task, lead audits findings, blocking gate until REVIEW-PASS
```

**Step 2: Verify the edit**

Read the coordination patterns list section to confirm.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add review loop to SKILL.md coordination patterns list"
```

---

### Task 14: Final verification

**Files:**
- Read: all modified files

**Step 1: Verify consistency across files**

Read all modified files and check:
1. Team size limits are consistent: 6 mixed / 8 read-only across SKILL.md (Phase 2, Phase 3, anti-patterns) and worker-roles.md (Team Size Limits)
2. REVIEW-PASS/REVIEW-FAIL message format is identical across worker-roles.md (Reviewer template), SKILL.md (Communication Protocol), and coordination-patterns.md (Review Loop + Lead Processing)
3. The lead audit step is described consistently in SKILL.md (Lead Processing Rules) and coordination-patterns.md (Review Loop)
4. The Phase 2 plan template includes `Paired review: yes | no` line and shows the `└─` pairing format conditionally
5. Phase 2 self-check includes paired review opt-in validation
6. Phase 3 spawn instructions conditionally require paired reviewers (only when user approved)
7. Phase 3 workspace init conditionally creates review-log.md (only if paired review enabled)
8. The review-log.md template exists in SKILL.md with correct table columns
9. Workspace Update Protocol has both paths: "Task completed (no paired review)" and "Task sent to reviewer (paired review)"
10. Lead Processing Rules COMPLETED row has conditional: route to reviewer if enabled, mark complete if disabled
11. Anti-patterns include the new rules: no skip reviewers when enabled, no unaudited issues, no forcing review on user
12. The hook scripts handle `-fix` suffix correctly
13. Coordination patterns list in SKILL.md includes the new Review Loop entry with "(when paired review enabled)" qualifier
14. The verify-task-complete.sh hook still checks only 3 files (not review-log.md — backward compat)

**Step 2: Run all tests**

```bash
bash tests/run-tests.sh
```

Expected: All tests pass (existing + new remediation workspace tests)

**Step 3: Run plugin validation**

```bash
claude plugin validate .
```

Expected: validation passes

**Step 4: Commit fixups if needed**

```bash
git add -A
git commit -m "fix: consistency fixups for paired reviewer and hook fix"
```

Only run this step if fixups were needed.

---

## Task Dependency Graph

```
Task 1 (hook fix: verify-task-complete.sh)       ─┐
Task 2 (hook fix: check-teammate-idle.sh)         ─┤
Task 3 (worker-roles: reviewer template)          ─┤
Task 4 (worker-roles: role guide + size limits)   ─┤
Task 5 (worker-roles: spawn example)              ─┼─→ Task 14 (verification)
Task 6 (SKILL.md: Phase 2 plan format)            ─┤
Task 7 (SKILL.md: Phase 3 spawn rules)            ─┤
Task 8 (SKILL.md: Phase 4 protocol + rules)       ─┤
Task 9 (SKILL.md: workspace update protocol)      ─┤
Task 10 (SKILL.md: review-log.md template + init) ─┤
Task 11 (SKILL.md: anti-patterns)                 ─┤
Task 12 (coordination-patterns.md: review loop)   ─┤
Task 13 (SKILL.md: patterns list)                 ─┘
```

All tasks 1-13 are independent of each other (different sections of different files). Task 14 depends on all.

## File Ownership for Parallel Execution

| File | Tasks |
|------|-------|
| `scripts/verify-task-complete.sh` | Task 1 |
| `tests/hooks/test-verify-task-complete.sh` | Task 1 |
| `scripts/check-teammate-idle.sh` | Task 2 |
| `tests/hooks/test-check-teammate-idle.sh` | Task 2 |
| `docs/worker-roles.md` | Tasks 3, 4, 5 (sequential — same file) |
| `skills/agent-team/SKILL.md` | Tasks 6, 7, 8, 9, 10, 11, 13 (sequential — same file) |
| `docs/coordination-patterns.md` | Task 12 |

Parallel streams:
- **Stream A**: Tasks 1 → 2 (hook scripts + tests)
- **Stream B**: Tasks 3 → 4 → 5 (worker-roles.md, sequential)
- **Stream C**: Tasks 6 → 7 → 8 → 9 → 10 → 11 → 13 (SKILL.md, sequential)
- **Stream D**: Task 12 (coordination-patterns.md)
- **Final**: Task 14 (verification, after all streams complete)
