# Skill Best-Practices Compliance Overhaul — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Maximize compliance with official Claude skill authoring best practices — fix token duplication, add examples, standardize terminology, trim SKILL.md, add quick start.

**Architecture:** 8 tasks in dependency order: create canonical file → rename → update consumers → trim+enhance SKILL.md (single pass) → update CLAUDE.md → verify. Amended from original 10-task plan after audit.

**Tech Stack:** Markdown files only. No code changes. All edits are docs/skill content.

**Design doc:** `docs/plans/2026-03-06-skill-best-practices-design.md`

---

### Task 1: Create `docs/communication-protocol.md` (canonical source)

**Files:**
- Create: `docs/communication-protocol.md`

**Step 1: Create the canonical protocol file**

```markdown
# Communication Protocol

Canonical definition of structured messages used by all teammates. The lead reads this file during Phase 3 and injects the protocol into each teammate's spawn prompt.

## Contents

- [Structured Messages](#structured-messages)
- [Reviewer/Auditor Findings Format](#reviewerauditor-findings-format)
- [Tester Results Format](#tester-results-format)
- [Auditor Compliance Format](#auditor-compliance-format)
- [Analyst Results Format](#analyst-results-format)
- [Scout Report Format](#scout-report-format)

## Structured Messages

All teammates use these prefixes when communicating with the lead:

\`\`\`
STARTING #N: {what I plan to do, which files I'll touch}
COMPLETED #N: {what I did, files changed, any concerns}
BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
HANDOFF #N: {what I produced that another teammate needs, key details}
QUESTION: {what I need to know, what I already checked in workspace}
\`\`\`

## Reviewer/Auditor Findings Format

Use consistent severity labels with sequential numbering per severity within each task:

- **H{n}** (high — must fix): file:line, description, suggested fix
- **M{n}** (medium — should fix): file:line, description
- **L{n}** (low — suggestion): file:line, description

In COMPLETED messages, include total counts: "N issues: X high, Y medium, Z low"

## Tester Results Format

- **PASS**: test name, what was verified
- **FAIL**: test name, expected vs actual, reproduction steps, suggested fix
- **SKIP**: test name, reason skipped

In COMPLETED messages, include total counts: "N tests: X passed, Y failed, Z skipped"

## Auditor Compliance Format

- **PASS**: checklist item, what was verified, evidence
- **FAIL**: checklist item, what's wrong, file:line, recommended fix, severity
- **WARNING**: checklist item, potential concern, file:line, recommendation

In COMPLETED messages, include total counts: "N items checked: X pass, Y fail, Z warning"

## Analyst Results Format

- **Metric**: name, value, baseline/comparison, significance
- **Pattern**: description, evidence (file:line or data references), confidence (high/medium/low)
- **Anomaly**: description, affected area, severity

## Scout Report Format

- **Structure**: directory layout, key files, entry points
- **Dependencies**: external libraries, internal module relationships
- **Patterns**: coding patterns, conventions, architectural style
- **Risks**: potential issues, technical debt, areas of concern
- **Recommendations**: suggested focus areas for deeper investigation
```

**Step 2: Verify the file**

Run: `wc -l docs/communication-protocol.md`
Expected: ~65 lines

**Step 3: Commit**

```bash
git add docs/communication-protocol.md
git commit -m "docs: add canonical communication protocol definition"
```

---

### Task 2: Rename `docs/worker-roles.md` → `docs/teammate-roles.md` and update all references

**Files:**
- Rename: `docs/worker-roles.md` → `docs/teammate-roles.md`
- Modify: `docs/teammate-roles.md` — update title and heading
- Modify: `skills/agent-team/SKILL.md:15,160,175,408` — update 4 links
- Modify: `CLAUDE.md:34,125` — update 2 references
- Modify: `README.md:243` — update plugin structure reference
- Modify: `docs/custom-roles.md:1,3` — update terminology in heading/references

**Step 1: Rename the file**

```bash
git mv docs/worker-roles.md docs/teammate-roles.md
```

**Step 2: Update the title in `docs/teammate-roles.md`**

Change line 1 from:
```
# Worker Roles Reference
```
to:
```
# Teammate Roles Reference
```

Also update line 3 from:
```
Generic role definitions for agent team teammates. Select roles based on the task, not technology.
```
No change needed — already says "teammates".

**Step 3: Update `skills/agent-team/SKILL.md`**

4 references to update:
- Line 15: `[worker-roles.md](../../docs/worker-roles.md)` → `[teammate-roles.md](../../docs/teammate-roles.md)`
- Line 160: `[worker-roles.md](../../docs/worker-roles.md)` → `[teammate-roles.md](../../docs/teammate-roles.md)`
- Line 175: `[worker-roles.md](../../docs/worker-roles.md)` → `[teammate-roles.md](../../docs/teammate-roles.md)`
- Line 408: `[worker-roles.md](../../docs/worker-roles.md)` → `[teammate-roles.md](../../docs/teammate-roles.md)`

**Step 4: Update `CLAUDE.md`**

- Line 34: `worker-roles.md` → `teammate-roles.md` and `Role definitions + spawn templates` stays
- Line 125: `worker-roles.md` → `teammate-roles.md`

**Step 5: Update `README.md`**

- Line 243: `worker-roles.md` → `teammate-roles.md` in plugin structure diagram

**Step 6: Update `docs/custom-roles.md`**

- Line 1: `# Custom Role Definitions` — no change needed
- Line 3: change `built-in roles (Leader, Implementer, Reviewer, Researcher, Challenger, Tester, Analyst, Planner, Writer, Strategist, Auditor, Scout)` — no change needed, no "worker" in content

**Step 7: Verify no remaining references to old filename in active files**

Run: `grep -r "worker-roles" --include="*.md" . --exclude-dir="docs/plans"`
Expected: 0 results (historical plan files in `docs/plans/` are excluded — they are archival)

**Step 8: Commit**

```bash
git add -A
git commit -m "refactor: rename worker-roles.md to teammate-roles.md

Standardize terminology: 'teammate' is the canonical term for team
members. 'worker' eliminated from filenames. Updates all references
in SKILL.md, CLAUDE.md, README.md, and docs."
```

---

### Task 3: Replace protocol blocks in `docs/teammate-roles.md` with placeholder

**Files:**
- Modify: `docs/teammate-roles.md` — 12 spawn templates

**Step 1: Replace protocol blocks in all 12 spawn templates**

In each spawn template, find the block that looks like:
```
Communication protocol — send structured messages to the lead:
- STARTING #N: {what I plan to do, which files I'll touch}
- COMPLETED #N: {what I did, files changed, any concerns}
- BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
- HANDOFF #N: {what I produced that another teammate needs, key details}
- QUESTION: {what I need to know, what I already checked in workspace}
```

Replace with:
```
{COMMUNICATION_PROTOCOL}
```

Also replace role-specific format blocks that are now in `communication-protocol.md`:

**Reviewer** (lines 174-179): Remove the "Findings format" block (H/M/L severity labels). Replace with:
```
{FINDINGS_FORMAT}
```

**Tester** (lines 251-256): Remove the "Results format" block (PASS/FAIL/SKIP). Replace with:
```
{RESULTS_FORMAT}
```

**Analyst** (lines 296-300): Remove the "Results format" block (Metric/Pattern/Anomaly). Replace with:
```
{RESULTS_FORMAT}
```

**Auditor** (lines 457-462): Remove the "Findings format" block (PASS/FAIL/WARNING). Replace with:
```
{FINDINGS_FORMAT}
```

**Scout** (lines 500-506): Remove the "Report format" block (Structure/Dependencies/etc). Replace with:
```
{REPORT_FORMAT}
```

Templates affected (11 total — protocol block replacement):
1. Researcher (~line 91-96)
2. Implementer (~line 124-129)
3. Reviewer (~line 167-172)
4. Challenger (~line 208-213)
5. Tester (~line 244-249)
6. Analyst (~line 289-294)
7. Planner (~line 330-335)
8. Writer (~line 366-371)
9. Strategist (~line 407-412)
10. Auditor (~line 450-455)
11. Scout (~line 493-498)

> **Amendment 5**: The Spawn Example (~line 520-556) is intentionally LEFT AS-IS. It shows a concrete expanded prompt (what the teammate actually receives), so the protocol block should remain verbatim there to demonstrate the final injected result.

**Step 2: Add a note at the top of the Available Roles section**

After line 73 ("## Available Roles"), add:

```markdown
> **Protocol placeholders**: Spawn templates use `{COMMUNICATION_PROTOCOL}`, `{FINDINGS_FORMAT}`, `{RESULTS_FORMAT}`, and `{REPORT_FORMAT}` placeholders. The lead reads [communication-protocol.md](communication-protocol.md) at spawn time and substitutes the appropriate blocks into each teammate's prompt.
```

**Step 3: Verify line count reduction**

Run: `wc -l docs/teammate-roles.md`
Expected: ~480 lines (down from 610 — ~130 lines saved from 12 protocol blocks + 5 format blocks)

**Step 4: Commit**

```bash
git add docs/teammate-roles.md
git commit -m "refactor: replace protocol blocks with placeholders in spawn templates

12 spawn templates now use {COMMUNICATION_PROTOCOL} placeholder.
5 role-specific format blocks replaced with {FINDINGS_FORMAT},
{RESULTS_FORMAT}, {REPORT_FORMAT}. Lead injects from
docs/communication-protocol.md at spawn time. ~130 lines saved."
```

---

### Task 4: Update `docs/coordination-patterns.md` — remove protocol copy, absorb setup failures

**Files:**
- Modify: `docs/coordination-patterns.md:29-39` — replace structured messages section
- Modify: `docs/coordination-patterns.md` — add Setup Failures section (from SKILL.md)

**Step 1: Replace the Structured Messages block**

Lines 29-39 currently contain the full protocol definition. Replace with:

```markdown
### Structured Messages

See [communication-protocol.md](communication-protocol.md) for the canonical protocol definition (STARTING, COMPLETED, BLOCKED, HANDOFF, QUESTION prefixes and role-specific formats).
```

Keep lines 41-51 (Lead Processing table) — this is lead-specific behavior, not duplication.

**Step 2: Add Setup Failures section**

Add before the "## File Conflict Resolution" section. Content moved from SKILL.md Phase 3:

```markdown
## Setup Failures

Recovery actions for common Phase 3 failures.

| Failure | Recovery |
|---------|----------|
| TeamCreate fails (name collision) | Append a counter: `{name}-2`, `{name}-3`. If `-3` also fails, ask the user for a name |
| TeamCreate fails (feature not enabled) | Tell the user to enable `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and restart |
| Workspace directory already exists | Read `progress.md` — if status is `done`, it's stale: ask user to confirm reuse or clean up. If status is `active`, another session may be using it: ask user |
| Teammate fails to spawn | Check the error. Common causes: tool not available, permission denied. Retry once. If still failing, log to `issues.md`, continue with remaining teammates, reassign orphaned tasks |
| Context compaction during Phase 3 | On recovery, read workspace files. If they exist but tasks/teammates are incomplete, resume from where you left off. If workspace doesn't exist yet, restart Phase 3 |
```

**Step 3: Update Contents section**

Add `- [Setup Failures](#setup-failures)` to the Contents list.

**Step 4: Verify**

Run: `grep -c "STARTING\|COMPLETED\|BLOCKED\|HANDOFF\|QUESTION" docs/coordination-patterns.md`
Expected: reduced count (only in Lead Processing table, not in standalone protocol block)

**Step 5: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "refactor: deduplicate protocol in coordination-patterns, add setup failures

Replace inline protocol definition with reference to canonical
communication-protocol.md. Absorb setup failures table from SKILL.md."
```

---

### Task 5: Update `docs/workspace-templates.md` — absorb moved sections

**Files:**
- Modify: `docs/workspace-templates.md` — add Workspace Update Protocol section, expand file-locks/events.log

**Step 1: Add Workspace Update Protocol section**

Add after the "## Additional Workspace Files" section (after line 111), before the file-locks.json subsection:

```markdown
## Workspace Update Protocol

The lead updates workspace files at every significant event. When multiple events arrive close together, batch them into a single edit per file.

| Event | File | What to update |
|-------|------|---------------|
| Team created | All 3 files | Initialize from templates |
| Tasks created | tasks.md | Fill task ledger |
| Teammate spawned | progress.md | Add row to Team Members |
| Task started | tasks.md | Status -> `in_progress` |
| Task completed | tasks.md | Status -> `completed`, add notes |
| Decision made | progress.md | Append to Decision Log |
| Handoff occurs | progress.md | Append to Handoffs |
| Issue found | issues.md | Append row, update Open count |
| Issue resolved | issues.md | Status -> RESOLVED/MITIGATED, update counts |
| Teammate status change | progress.md | Update Team Members table |
| All work done | progress.md | Status -> `done` |
| Teammate spawned | events.log | Append spawn event (also auto-logged by SubagentStart hook) |
| Task started | events.log | Append task_start event |
| Task completed | events.log | Append task_complete event |
| Blocked event | events.log | Append blocked event |
| Handoff occurs | events.log | Append handoff event |
| Decision made | events.log | Append decision event |
```

**Step 2: ~~Expand file-locks.json section~~ SKIP (Amendment 2)**

> **SKIP**: The "When to create" note and "Populated from Phase 2 plan" text already exist in `workspace-templates.md` at lines 117-119. Adding them again would create duplicates.

**Step 3: Expand events.log section**

The existing section (lines 128-135) covers basics. Add event types list if not present:

```markdown
Event types: `spawn`, `stop`, `task_start`, `task_complete`, `blocked`, `handoff`, `decision`, `replan`.
```

**Step 4: Update Contents section**

Add `- [Workspace Update Protocol](#workspace-update-protocol)` to the Contents list.

**Step 5: Commit**

```bash
git add docs/workspace-templates.md
git commit -m "docs: absorb workspace update protocol and expand file details

Move Workspace Update Protocol table from SKILL.md into
workspace-templates.md. Expand file-locks.json and events.log
sections with details previously only in SKILL.md."
```

---

### Task 6: SKILL.md single-pass update — trim, add quick start, add examples, add protocol instruction, update references (Amendment 4: merged Tasks 6+7+8)

> **Amendment 4**: Tasks 6, 7, and 8 are merged into a single pass because they all edit SKILL.md. Applying them separately would cause line-number drift between tasks. Read the file once, apply all changes, write once.

**Files:**
- Modify: `skills/agent-team/SKILL.md`

**Read the file first**, then apply all changes in this order (top-to-bottom through the file):

**Step 1: Add Quick Start section**

Insert after the role definition link ("For your full role definition..."), before "## Prerequisites":

```markdown
## Quick Start

1. **Analyze** — identify 2+ independent streams, detect archetype
2. **Plan** — present to user, wait for approval (hard gate)
3. **Create** — team, workspace, tasks, spawn teammates
4. **Coordinate** — track progress, route messages, resolve blockers
5. **Synthesize** — completion gate, report, shutdown
```

**Step 2: Replace file-locks.json section (Phase 3, ~lines 125-134)**

Replace the full section with:

```markdown
   #### file-locks.json

   Maps teammates to owned files/directories. Used by PreToolUse hook. See [workspace-templates.md](../../docs/workspace-templates.md#file-locksjson) for format and creation rules.
```

**Step 3: Replace events.log section (Phase 3, ~lines 136-145)**

Replace with:

```markdown
   #### events.log

   Initially empty. Append-only JSON event log. Written by SubagentStart/Stop hooks and the lead during coordination. See [workspace-templates.md](../../docs/workspace-templates.md#eventslog) for format and event types.
```

**Step 4: Add protocol injection instruction to Phase 3**

In Phase 3, step 5 (spawn teammates), add before "Every spawn prompt MUST include":

```markdown
   **Protocol injection**: Before building spawn prompts, read [communication-protocol.md](../../docs/communication-protocol.md). Substitute the `{COMMUNICATION_PROTOCOL}` placeholder in each role's spawn template with the Structured Messages block. For roles with format placeholders (`{FINDINGS_FORMAT}`, `{RESULTS_FORMAT}`, `{REPORT_FORMAT}`), substitute the matching section from the same file.
```

**Step 5: Add spawn prompt assembly example**

Insert in Phase 3 after step 5 (spawn teammates), before step 5b:

````markdown
   **Example — assembling a spawn prompt**:

   The lead reads `docs/communication-protocol.md`, then substitutes into the role template:

   ```
   # 1. Read the protocol
   Read: docs/communication-protocol.md → get COMMUNICATION_PROTOCOL block

   # 2. Build prompt from teammate-roles.md template
   Task tool call:
     subagent_type: "general-purpose"
     team_name: "0306-refactor-auth"
     name: "auth-impl-1"
     prompt: |
       You are an implementer on this team. Your job is to write code...

       Your assigned tasks: #1
       Your file ownership: src/auth/token.ts, src/auth/validate.ts

       Workspace: .agent-team/0306-refactor-auth/
       Project conventions: Read CLAUDE.md if it exists.

       Communication protocol — send structured messages to the lead:
       - STARTING #N: {what I plan to do, which files I'll touch}
       - COMPLETED #N: {what I did, files changed, any concerns}
       - BLOCKED #N: severity={level}, {what's blocking}, impact={what can't proceed}
       - HANDOFF #N: {what I produced that another teammate needs}
       - QUESTION: {what I need to know}

       Rules: [... rest of implementer template ...]
   ```
````

**Step 6: Replace Setup Failures section (Phase 3, ~lines 205-213)**

Replace the full table with:

```markdown
### Setup Failures

See [coordination-patterns.md](../../docs/coordination-patterns.md#setup-failures) for recovery actions on common Phase 3 failures (name collisions, missing feature flag, stale workspaces, spawn failures, context compaction).
```

**Step 7: Replace Workspace Update Protocol (Phase 4, ~lines 233-253)**

Replace with:

```markdown
### Workspace Updates

Update workspace files at every significant event. Batch multiple events into a single edit per file. See [workspace-templates.md](../../docs/workspace-templates.md#workspace-update-protocol) for the full event-to-file mapping table.
```

**Step 8: Add Phase 2 example**

Insert after the plan template block (after `Estimated teammates: N`), before the self-check:

````markdown
**Example** — "refactor the auth module":

```
Team plan for: Refactor auth module — extract token validation and session management
Team type: implementation (auto-detected)
Complexity: standard

Teammates (3 total):
- auth-impl-1 (Implementer): Refactor token validation -> owns src/auth/token.ts, src/auth/validate.ts
- auth-impl-2 (Implementer): Extract session management -> owns src/auth/session.ts, src/middleware/auth.ts
- auth-reviewer (Reviewer): Review all changes -> read-only

Task breakdown:
1. Refactor token validation logic -> auth-impl-1
2. Extract session management to dedicated module -> auth-impl-2
3. Update middleware to use new session API -> auth-impl-2 (blocked by #2)
4. Review all changes across both scopes -> auth-reviewer (blocked by #1, #2)

Isolation: shared (default)
Workspace: .agent-team/0306-refactor-auth/
Estimated teammates: 3
```
````

**Step 9: Update the Reference section at the bottom**

Update the worker-roles reference (already renamed in Task 2):
```markdown
- [teammate-roles.md](../../docs/teammate-roles.md) — lead + teammate role definitions and spawn templates
```

Add new reference:
```markdown
- [communication-protocol.md](../../docs/communication-protocol.md) — structured message formats (canonical source for spawn prompt injection)
```

**Step 10: Verify**

Run: `wc -l skills/agent-team/SKILL.md`
Expected: ~415 lines

Run: `grep -n "worker-roles\|\.\.\/\.\.\/docs\/.*\.md" skills/agent-team/SKILL.md`
Expected: All links point to existing files, no "worker-roles" remaining

**Step 11: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "refactor: trim SKILL.md, add quick start, examples, and protocol injection

Single-pass update:
- Remove Setup Failures, file-locks details, events.log details,
  Workspace Update Protocol (moved to docs)
- Add Quick Start section for fast orientation
- Add Phase 2 plan example and Phase 3 spawn prompt assembly example
- Add protocol injection instruction for {COMMUNICATION_PROTOCOL}
- Update Reference section with communication-protocol.md"
```

---

### Task 7: Update CLAUDE.md file ownership table

**Files:**
- Modify: `CLAUDE.md:34,125`

**Step 1: Update File Ownership table**

Line 34: change `docs/worker-roles.md` → `docs/teammate-roles.md`

Add new row after the teammate-roles row:
```
| `docs/communication-protocol.md` | Structured message formats | Update when changing protocol prefixes or role-specific formats |
```

**Step 2: Update "Adding a New Teammate Role" section**

Line 125: change `docs/worker-roles.md` → `docs/teammate-roles.md`

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for renamed teammate-roles and new protocol file"
```

---

### Task 8: Final verification

**Files:**
- Read: all modified files

**Step 1: Verify no broken references in active project files**

```bash
grep -r "worker-roles" --include="*.md" . --exclude-dir="docs/plans"
```
Expected: 0 results (historical plan files in `docs/plans/` are excluded — they are archival and should not be updated)

**Step 2: Verify SKILL.md line count**

```bash
wc -l skills/agent-team/SKILL.md
```
Expected: under 500 lines

**Step 3: Verify total docs line count**

```bash
wc -l skills/agent-team/SKILL.md docs/*.md
```
Expected: total reduced from 2093

**Step 4: Verify communication protocol appears once canonically**

```bash
grep -l "STARTING #N.*COMPLETED #N" docs/*.md skills/agent-team/SKILL.md
```
Expected: `docs/communication-protocol.md` and `skills/agent-team/SKILL.md` (Phase 3 example only)

**Step 5: Run existing tests**

```bash
bash tests/run-tests.sh
```
Expected: all tests pass (may need to update tests that reference `worker-roles.md`)

**Step 6: Fix any test failures**

If tests reference `worker-roles.md`, update them to `teammate-roles.md`.

**Step 7: Final commit if tests needed fixing**

```bash
git add tests/
git commit -m "fix: update tests for worker-roles → teammate-roles rename"
```
