# Paired Reviewer Implementation Plan

**Status**: Approved

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add 1:1 paired reviewer for every implementer, with continuous review, lead-audited issues, and blocking gate.

**Architecture:** The reviewer is spawned alongside each implementer. When an implementer sends COMPLETED, the lead routes the task to the paired reviewer instead of marking it complete. The reviewer sends REVIEW-PASS or REVIEW-FAIL to the lead. On REVIEW-FAIL, the lead audits findings, writes confirmed issues to issues.md, and routes fixes to the implementer. The loop repeats until REVIEW-PASS.

**Tech Stack:** Markdown skill files, no code — all changes are to SKILL.md and docs/*.md.

**Design doc:** `docs/plans/2026-02-26-paired-reviewer-design.md`

---

### Task 1: Update Reviewer Spawn Template in worker-roles.md

**Files:**
- Modify: `docs/worker-roles.md:132-167` (Reviewer section)

**Step 1: Replace the Reviewer spawn prompt template**

Replace lines 132-167 of `docs/worker-roles.md` with the updated reviewer section that adds paired reviewer mode. The new template includes:
- `Your paired implementer: [IMPLEMENTER_NAME]`
- `Your review scope: [IMPLEMENTER_FILES]`
- New message formats: `REVIEW-PASS #N` and `REVIEW-FAIL #N`
- Rule: wait for lead to route tasks for review (don't self-assign)

```markdown
### Reviewer
**Purpose**: Validate code quality, find issues, verify correctness. Each reviewer is paired 1:1 with an implementer.
**When to use**: Every implementer must have a paired reviewer. Also used standalone for code review, security audit, test validation, compliance check.
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
- BLOCKED #N: severity={level}, {what's blocking}, impact={what can't proceed}
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

**Step 2: Verify the edit**

Read `docs/worker-roles.md:132-170` to verify the Reviewer section is correct and the Challenger section below it wasn't affected.

**Step 3: Commit**

```bash
git add docs/worker-roles.md
git commit -m "feat: update reviewer role to paired 1:1 mode with REVIEW-PASS/FAIL protocol"
```

---

### Task 2: Update Role Selection Guide and Team Size Limits in worker-roles.md

**Files:**
- Modify: `docs/worker-roles.md:279-296` (Role Selection Guide + Team Size Limits)

**Step 1: Replace the Role Selection Guide table**

Replace lines 281-290 with the updated table that reflects 1:1 pairing:

```markdown
| Task Type | Recommended Roles | Typical Size |
|---|---|---|
| Code review | 2-3 reviewers with different lenses (security, performance, style) | 2-3 (all read-only) |
| New feature (standard) | 1-2 implementers + paired reviewers | 2-4 |
| New feature (complex) | 1-2 implementers + paired reviewers + 1 tester | 3-5 |
| Bug investigation | 2-3 researchers with competing hypotheses | 2-3 (all read-only) |
| Refactoring | 1-2 implementers + paired reviewers | 2-4 |
| Architecture evaluation | 1 researcher + 1 challenger | 2 (all read-only) |
| Full-stack feature | 2 implementers + 2 paired reviewers + 1 tester | 5 |
| Large audit / migration | 2 implementers + paired reviewers + 2-3 researchers | 6-7 |
```

**Step 2: Replace the Team Size Limits section**

Replace lines 292-296 with updated limits:

```markdown
### Team Size Limits

- **Default max: 6** for mixed teams (implementers + their paired reviewers + other roles)
- **Up to 8** if the additional teammates beyond 6 are read-only (researchers, extra reviewers using `subagent_type: "Explore"`) — they have zero file conflict risk and low coordination cost
- Paired reviewers use `subagent_type: "Explore"` (read-only) and do not count toward the "implementer" limit — they have zero file conflict risk
- **Self-check for N > 6**: before spawning, verify (1) every stream has zero file overlap, (2) cross-communication between teammates is minimal, (3) workspace churn remains manageable. If any check fails, merge roles
```

**Step 3: Verify the edit**

Read `docs/worker-roles.md:279-300` to verify both sections are correct.

**Step 4: Commit**

```bash
git add docs/worker-roles.md
git commit -m "feat: update role selection guide and team size limits for paired reviewers"
```

---

### Task 3: Add Spawn Example for Paired Reviewer in worker-roles.md

**Files:**
- Modify: `docs/worker-roles.md:236-277` (Spawn Example section)

**Step 1: Add a paired reviewer spawn example after the existing implementer example**

After line 271 (end of the existing implementer spawn example), add a new example showing how to spawn the paired reviewer for that implementer:

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
    - BLOCKED #N: severity={level}, {what's blocking}, impact={what can't proceed}
    - QUESTION: {what I need to know, what I already checked in workspace}

    Rules:
    - Read and analyze only. Do not modify files.
    - Wait for the lead to route tasks to you for review.
    - Include specific file:line references and fix suggestions for every high-severity issue.
    - Send REVIEW-PASS if the work meets quality standards. Send REVIEW-FAIL if issues are found.
    - Read workspace issues.md to avoid reporting known/duplicate issues.
` ` `
```

**Step 2: Update the Key parameters note**

Update the `subagent_type` explanation at line 273-277 to mention paired reviewers explicitly:

```markdown
Key parameters:
- `subagent_type`: `"general-purpose"` for full tool access (implementers, challengers, testers). `"Explore"` for read-only roles (paired reviewers, researchers). `"general-purpose"` if a reviewer needs Bash (e.g., running tests, build verification).
- `team_name`: must match the team created via TeamCreate.
- `name`: human-readable name used for messaging and task assignment. Convention for paired reviewers: `{implementer-name}-reviewer` (e.g., `backend-impl` → `backend-reviewer`).
- `mode`: `"default"` for normal operation. `"plan"` requires the teammate to get plan approval from the lead before making changes — use this for risky or architectural tasks.
```

**Step 3: Verify the edit**

Read `docs/worker-roles.md:236-310` to verify both the new example and updated parameters.

**Step 4: Commit**

```bash
git add docs/worker-roles.md
git commit -m "feat: add paired reviewer spawn example to worker-roles.md"
```

---

### Task 4: Update Phase 2 Plan Format in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:42-78` (Phase 2)

**Step 1: Update the plan template**

Replace lines 46-72 with the updated plan template that shows reviewer pairing:

```markdown
` ` `
Team plan for: [task summary]
Complexity: standard | complex
  (if complex) Reason: [why — e.g., multi-module, risky refactor, security-sensitive]
  (if complex) ✓ Dedicated tester included

Teammates (N total):
⚠ Team size check: [default max 6 | up to 8 if extra are read-only]
- [implementer-name] (implementer): [what they do] -> owns [files/area]
  └─ [reviewer-name] (reviewer): reviews [implementer-name]'s work
- [implementer-name] (implementer): [what they do] -> owns [files/area]
  └─ [reviewer-name] (reviewer): reviews [implementer-name]'s work
- [other-role-name]: [what they do] -> owns [files/area]

Task breakdown:
1. [task] -> assigned to [role]
2. [task] -> assigned to [role]
3. [task] -> assigned to [role] (blocked by #1)

Every phase has an owner (omit for pure review tasks):
- Setup/config: [role]
- Implementation: [role(s)]
- Review: paired reviewers (automatic — each implementer's tasks are reviewed continuously)
- Testing: [role] (required for complex plans)
- Finalization: [role]

Workspace: .agent-team/[team-name]/
Estimated teammates: N
` ` `
```

**Step 2: Update the self-check**

Replace lines 74-76 with updated self-check that includes paired reviewer validation:

```markdown
**Self-check before proceeding**:
1. "Does every implementer in the plan have a paired reviewer listed directly beneath them? If not, add one."
2. "Is this plan complex? Complexity signals: multi-module/area changes, architectural decisions, risky refactors, multiple implementers with cross-dependencies, security-sensitive changes, new integrations. If yes, does the teammate list include a **dedicated tester** (separate from reviewers)? If no, add one before presenting."
3. "Have I presented this plan AND received user confirmation?" If no, STOP.
```

**Step 3: Verify the edit**

Read `skills/agent-team/SKILL.md:42-80` to verify Phase 2 is correct.

**Step 4: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: update Phase 2 plan format to require paired reviewers per implementer"
```

---

### Task 5: Update Phase 3 Spawn Rules in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:184-200` (Phase 3 steps 5-6)

**Step 1: Update spawn instructions (step 5)**

Replace lines 184-194 to add the paired reviewer spawn rule:

```markdown
5. **Spawn teammates** using the Task tool with `team_name`, `name`, and `subagent_type` parameters. See [worker-roles.md](../../docs/worker-roles.md) for role-specific spawn templates. Use `subagent_type: "general-purpose"` for teammates that need full tool access (Write, Edit, Bash) — implementers, challengers, testers. Use `subagent_type: "Explore"` for read-only teammates (paired reviewers, researchers). Use `general-purpose` if a reviewer needs to run commands (tests, builds). Optionally set `mode: "plan"` to require plan approval before a teammate implements anything — useful for risky or architectural tasks.

   **Paired reviewer rule**: For every implementer spawned, you MUST also spawn a paired reviewer. The reviewer's spawn prompt MUST include:
   - Their paired implementer's name
   - The implementer's file ownership (= the reviewer's review scope)
   - The REVIEW-PASS / REVIEW-FAIL message format
   - Instruction to wait for the lead to route tasks for review

   Each spawn prompt MUST include:
   - Their role and responsibilities
   - Which tasks are assigned to them (reference task IDs)
   - Which files/areas they own exclusively (implementers) or review (reviewers)
   - **Workspace path**: `.agent-team/{team-name}/` — tell them to read these files for context. Teammates should write any output artifacts (reports, findings) to this directory so all outputs are co-located
   - **Communication protocol** (see Phase 4 section below — include the structured message format)
   - What to do when blocked: message the lead with severity and impact, do not wait silently
   - Instruction to mark tasks complete immediately after verification (implementers) or send REVIEW-PASS/FAIL (reviewers)
   - Instruction to check TaskList after completing each task and self-claim next available
   - Instruction to use subagents (Task tool) for focused subtasks that don't need teammate communication
   - **Update workspace**: record each teammate in `progress.md` Team Members table
```

**Step 2: Update team size gate (step 6)**

Replace lines 196-200 with updated limits:

```markdown
6. **Team size gate** — explicitly count before spawning: "I am spawning N teammates: [list names]."
   - **Default max: 6** for mixed teams (implementers + their paired reviewers + other roles)
   - **Up to 8** if the additional teammates beyond 6 are **read-only** (researchers, extra reviewers using `subagent_type: "Explore"`) — read-only agents have zero file conflict risk and minimal coordination cost
   - Paired reviewers use `subagent_type: "Explore"` (read-only) — they do not create file conflict risk
   - **Self-check for N > 6**: (1) every stream has zero file overlap, (2) cross-communication between teammates is minimal, (3) the lead can track all streams without excessive workspace churn
   - If the self-check fails on any point, merge roles until it passes
```

**Step 3: Verify the edit**

Read `skills/agent-team/SKILL.md:184-210` to verify Phase 3 steps 5-6 are correct.

**Step 4: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: update Phase 3 spawn rules to require paired reviewer per implementer"
```

---

### Task 6: Update Phase 4 Lead Processing Rules in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:242-264` (Communication Protocol + Lead Processing Rules)

**Step 1: Add review message formats to the Communication Protocol**

After line 251 (the QUESTION line), add the reviewer-specific message formats:

```markdown
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
```

**Step 2: Update the Lead Processing Rules table**

Replace lines 258-264 to add the review loop routing and the lead audit step:

```markdown
| Prefix | Lead Action |
|--------|--------------|
| STARTING | Update `tasks.md` status to `in_progress`, add note |
| COMPLETED | **Do NOT mark task complete yet.** Route to the paired reviewer: message reviewer with "Review task #N — implementer changed files: [list]. Review the implementation quality and send REVIEW-PASS or REVIEW-FAIL." |
| BLOCKED | Add row to `issues.md` immediately. Acknowledge the teammate. Route to resolution |
| HANDOFF | Extract key details, forward to dependent teammate with actionable context. Log in `progress.md` Handoffs |
| QUESTION | Check if answer is in workspace files. If yes, answer with file reference. If no, investigate |
| REVIEW-PASS | Mark task #N as `completed` in `tasks.md`. Check: does this unblock other tasks? If yes, message the dependent teammate |
| REVIEW-FAIL | **Lead audit step**: (1) Read the reviewer's findings (H/M/L with file:line references). (2) Validate each finding — is it real? Is severity correct? (3) Write confirmed issues to `issues.md`. (4) Route confirmed issues to the implementer: "Fix these issues for task #N: [list confirmed issues]". (5) If lead disagrees with a finding, drop it. The task stays `in_progress` until the implementer sends COMPLETED #N again and the reviewer sends REVIEW-PASS |
```

**Step 3: Verify the edit**

Read `skills/agent-team/SKILL.md:242-275` to verify the updated protocol and processing rules.

**Step 4: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: update Phase 4 lead processing rules with review loop and audit step"
```

---

### Task 7: Update Workspace Update Protocol in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:228-240` (Workspace Update Protocol table)

**Step 1: Add review-related events to the table**

Add rows for review events after the "Task completed" row:

```markdown
| Event | File | What to update |
|-------|------|---------------|
| Team created | All 3 files | Initialize from templates |
| Tasks created | tasks.md | Fill task ledger |
| Teammate spawned | progress.md | Add row to Team Members |
| Task started | tasks.md | Status -> `in_progress` |
| Task sent to reviewer | tasks.md | Add note: "under review by {reviewer-name}" |
| Review passed | tasks.md | Status -> `completed`, add notes |
| Review failed (issues confirmed) | issues.md, tasks.md | Append confirmed issues to issues.md, add note to tasks.md: "review failed — N issues, awaiting fix" |
| Issue fixed and re-reviewed | issues.md, tasks.md | Update issue status, update task notes |
| Decision made | progress.md | Append to Decision Log |
| Handoff occurs | progress.md | Append to Handoffs |
| Issue found | issues.md | Append row, update Open count |
| Issue resolved | issues.md | Status -> RESOLVED/MITIGATED, update counts |
| Teammate status change | progress.md | Update Team Members table |
| All work done | progress.md | Status -> `done` |
```

**Step 2: Verify the edit**

Read `skills/agent-team/SKILL.md:228-245` to verify the updated table.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add review events to workspace update protocol"
```

---

### Task 8: Update Anti-Patterns in SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md:396-407` (Anti-Patterns section)

**Step 1: Update team size limit anti-pattern and add reviewer anti-pattern**

Replace line 404:
```
- **DO NOT exceed team size limits** — max 4 mixed, up to 6 if extras are read-only. Self-check required for N > 4
```

With:
```
- **DO NOT exceed team size limits** — max 6 mixed, up to 8 if extras are read-only. Self-check required for N > 6
- **DO NOT skip paired reviewers** — every implementer MUST have a paired reviewer. Do not mark implementer tasks complete without a REVIEW-PASS from the paired reviewer
- **DO NOT write issues to issues.md without auditing** — when a reviewer sends REVIEW-FAIL, the lead must validate each finding before writing to issues.md
```

**Step 2: Verify the edit**

Read `skills/agent-team/SKILL.md:396-412` to verify the updated anti-patterns.

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add paired reviewer anti-patterns to SKILL.md"
```

---

### Task 9: Add Review Loop Section to coordination-patterns.md

**Files:**
- Modify: `docs/coordination-patterns.md:1-14` (Contents), then append new section

**Step 1: Add Review Loop to the Contents list**

After line 7 (Pre-Shutdown Commit line), add:
```
- [Review Loop](#review-loop) — paired reviewer continuous review cycle with lead audit
```

**Step 2: Add the Review Loop section**

Insert the new section after the Pre-Shutdown Commit section (after line 122) and before the Remediation Gate section:

```markdown
## Review Loop

Every implementer has a paired reviewer. When an implementer completes a task, the lead routes it to the paired reviewer before marking it complete. This creates a continuous review cycle with a blocking gate.

### Protocol

1. **Implementer sends COMPLETED #N** — the lead does NOT mark the task complete yet.
2. **Lead routes to paired reviewer** — message the reviewer: "Review task #N. [Implementer-name] changed these files: [list]. Review the implementation quality and send REVIEW-PASS or REVIEW-FAIL."
3. **Reviewer reviews and responds**:
   - `REVIEW-PASS #N`: no issues found, task is approved
   - `REVIEW-FAIL #N`: issues found with severity labels (H1, M1, L1...)
4. **Lead processes the response**:
   - **REVIEW-PASS**: mark task #N as `completed` in `tasks.md`. Check if this unblocks other tasks.
   - **REVIEW-FAIL**: lead audits findings (see Lead Audit Step below), writes confirmed issues to `issues.md`, routes confirmed issues to implementer.
5. **Implementer fixes** — sends COMPLETED #N again after fixing.
6. **Loop repeats** until REVIEW-PASS.

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
| Review passed | tasks.md | Status -> `completed` |
| Review failed (issues confirmed) | issues.md, tasks.md | Append confirmed issues, add note: "review failed — N issues" |
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

**Step 3: Update the Lead Processing table in coordination-patterns.md**

Replace lines 40-46 to add review message types:

```markdown
| Prefix | Lead Action |
|--------|--------------|
| STARTING | Update `tasks.md` status to `in_progress`, add note |
| COMPLETED | Route to the paired reviewer for review. Do NOT mark complete yet |
| BLOCKED | Add row to `issues.md` immediately. Acknowledge the teammate. Route to resolution |
| HANDOFF | Extract key details, forward to dependent teammate with actionable context. Log in `progress.md` Handoffs |
| QUESTION | Check if answer is in workspace files. If yes, answer with file reference. If no, investigate |
| REVIEW-PASS | Mark task as `completed` in `tasks.md`. Check if this unblocks other tasks |
| REVIEW-FAIL | Audit findings, write confirmed issues to `issues.md`, route confirmed fixes to implementer |
```

**Step 4: Verify the edit**

Read `docs/coordination-patterns.md:1-15` to verify Contents. Read the new Review Loop section to verify it's complete.

**Step 5: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "feat: add Review Loop coordination pattern for paired reviewers"
```

---

### Task 10: Final verification

**Files:**
- Read: all 3 modified files

**Step 1: Verify consistency across files**

Read all modified files and check:
1. Team size limits are consistent: 6 mixed / 8 read-only across SKILL.md and worker-roles.md
2. REVIEW-PASS/REVIEW-FAIL message format is identical across worker-roles.md, SKILL.md, and coordination-patterns.md
3. The lead audit step is described consistently in SKILL.md and coordination-patterns.md
4. The Phase 2 plan template shows the pairing format
5. The spawn instructions in Phase 3 require paired reviewers
6. The anti-patterns include the new rules

**Step 2: Run plugin validation**

```bash
claude plugin validate .
```

Expected: validation passes (no structural issues — changes are all in docs/skills markdown)

**Step 3: Final commit (if any fixups needed)**

```bash
git add -A
git commit -m "fix: consistency fixups for paired reviewer feature"
```
