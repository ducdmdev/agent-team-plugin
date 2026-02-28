# Agent Team Plugin Improvement Roadmap — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement 21 improvements across 5 incremental releases (v1.3.0 through v2.0.0), layered by risk.

**Architecture:** Each release builds on the previous. v1.3.0 is docs-only (zero risk), v1.4.0 changes prompts/templates, v1.5.0 adds new hooks, v1.6.0 adds structural features, v2.0.0 adds major features. All changes preserve backward compatibility — new features degrade gracefully when dependencies are missing.

**Tech Stack:** Bash scripts (hooks), Markdown (SKILL.md, docs), JSON (hooks.json, file-locks.json)

**Design doc:** `docs/plans/2026-02-27-improvement-roadmap-design.md`

**Test framework:** `tests/run-tests.sh` discovers `tests/**/test-*.sh` files. Test helpers in `tests/lib/test-helpers.sh` provide `setup_temp_dir`, `setup_mock_workspace`, `setup_mock_git_repo`, `run_hook`, `assert_exit_code`, `assert_stderr_contains`, `assert_true`.

---

## Release 1: v1.3.0 — Documentation & Patterns (Zero Risk)

Files changed: `docs/coordination-patterns.md`, `docs/custom-roles.md` (new), `hooks/hooks.json`, `CHANGELOG.md` (new)

### Task 1: Add Re-plan on Block coordination pattern

**Files:**
- Modify: `docs/coordination-patterns.md` (append new section after "Issue Triage After Context Recovery")

**Step 1: Add the pattern section**

Append to `docs/coordination-patterns.md` before the end of file:

```markdown
## Re-plan on Block

When a critical or high-severity BLOCKED message arrives and the original plan may no longer be viable:

### Detection

The lead should consider re-planning when:
- A critical BLOCKED affects 2+ tasks or teammates
- A key assumption in the original Phase 2 plan turns out to be wrong
- An external dependency (API, library, service) is unavailable
- The blocking issue requires a fundamentally different approach

### Protocol

1. **Assess viability** — can the original plan still work with minor adjustments?
   - If yes: resolve the block normally (stuck dependency resolution, reassignment)
   - If no: proceed to re-plan
2. **Pause affected work** — message affected teammates: "Pause work on [tasks]. Re-planning in progress."
3. **Draft revised plan** — identify what changes: task decomposition, file ownership, teammate roles, dependencies
4. **Present to user** — this is a mandatory gate, same as Phase 2:
   ```
   Re-plan needed: [reason]

   Original plan: [summary]
   Revised plan: [summary of changes]

   Changes:
   - [task/role/ownership changes]

   Approve revised plan?
   ```
5. **If approved**: update workspace (tasks.md, progress.md Decision Log), reassign tasks, message affected teammates with new scope
6. **If declined**: user provides alternative direction. Adjust accordingly.

### Logging

- Log re-plan decision in `progress.md` Decision Log with reasoning
- Update `tasks.md` with any new/modified/removed tasks
- Log the block that triggered re-planning in `issues.md`
```

**Step 2: Validate plugin structure**

Run: `claude plugin validate .`
Expected: No errors

**Step 3: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "docs: add Re-plan on Block coordination pattern"
```

---

### Task 2: Add Adversarial Review Rounds coordination pattern

**Files:**
- Modify: `docs/coordination-patterns.md` (append new section)

**Step 1: Add the pattern section**

Append to `docs/coordination-patterns.md`:

```markdown
## Adversarial Review Rounds

When review quality is critical (security-sensitive code, architectural decisions, complex refactors), use multi-round adversarial review instead of single-pass:

### When to Use

- Security-sensitive changes
- Architectural decisions with long-term implications
- Complex refactors touching multiple modules
- When the first reviewer's findings seem superficially clean (early agreement is suspicious)

### Protocol

1. **Round 1 — Primary review**: Reviewer A reviews the implementation and reports findings using the standard findings format (H/M/L severity with file:line references)
2. **Round 2 — Cross-review**: Reviewer B receives Reviewer A's findings and is tasked with:
   - Verifying each finding (agree/disagree with evidence)
   - Finding issues Reviewer A missed
   - Challenging any "PASS" assessments that seem too lenient
3. **Round 3 — Synthesis**: Lead collects both reviews and:
   - Identifies agreements (high confidence findings)
   - Identifies disagreements (need resolution)
   - For disagreements: asks the dissenting reviewer to provide specific evidence
4. **Resolution**: If disagreements persist after Round 3, escalate to user with both positions and evidence

### Lead Coordination

- Route findings between reviewers via summarized messages (don't relay verbatim — extract actionable points)
- Log the review rounds in `progress.md` Decision Log: "Adversarial review: Round N complete, X agreements, Y disagreements"
- Create separate review tasks for each round (e.g., #5 "Primary security review", #6 "Cross-review of #5 findings")
- Reviewers can use subagents (Task tool with Explore) to parallelize file reads within their review scope

### Team Composition

- Minimum: 2 reviewers + lead
- Reviewers should have different review lenses when possible (e.g., security + performance, correctness + maintainability)
- Do NOT have the original implementer serve as a reviewer in adversarial rounds
```

**Step 2: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "docs: add Adversarial Review Rounds coordination pattern"
```

---

### Task 3: Add Quality Gate coordination pattern

**Files:**
- Modify: `docs/coordination-patterns.md` (append new section)

**Step 1: Add the pattern section**

Append to `docs/coordination-patterns.md`:

```markdown
## Quality Gate

A final validation pass before Phase 5 synthesis. Catches integration issues that per-task checks miss.

### When to Use

- Complex plans with 3+ implementers
- Cross-module changes where integration bugs are likely
- Plans marked as "complex" in Phase 2

### Protocol

1. **Trigger**: All implementation tasks are completed. Before starting Phase 5.
2. **Assign quick verification tasks** to remaining active teammates:
   - Build verification: "Run `[build command]` and report result"
   - Test verification: "Run `[test command]` and report result"
   - Integration check: "Verify [module A] correctly calls [module B] after both teammates' changes"
   - Lint/format check: "Run linter and report any new warnings"
3. **Gate decision**:
   - All checks pass → proceed to Phase 5
   - Failures found → create fix tasks, assign to relevant implementers, re-run gate after fixes
4. **Log**: Record gate result in `progress.md` Decision Log: "Quality gate: PASS" or "Quality gate: FAIL — [issues], fix tasks created"

### Implementation

The lead creates verification tasks with clear pass/fail criteria:

```
Task: "Quality gate — build verification"
Description: Run the project build command. Report PASS if it succeeds, FAIL with error output if it fails.
Completion criteria: Build exits 0 with no errors.
```

Assign to the nearest available teammate (reviewer or tester preferred, implementer if no others are available).
```

**Step 2: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "docs: add Quality Gate coordination pattern"
```

---

### Task 4: Add Auto-Block on Repeated Failures coordination pattern

**Files:**
- Modify: `docs/coordination-patterns.md` (append new section)

**Step 1: Add the pattern section**

Append to `docs/coordination-patterns.md`:

```markdown
## Auto-Block on Repeated Failures

Prevents teammates from spinning on the same error. Escalates automatically after repeated failures.

### Protocol

1. **Track blocked count per task** — when receiving a BLOCKED message, check `issues.md` for previous BLOCKED entries on the same task
2. **Threshold: 3 attempts** — if a teammate has reported BLOCKED on the same task 3 times:
   - Do NOT let them retry
   - Mark the task as blocked in `tasks.md`
   - Escalate immediately: either reassign to a different teammate or escalate to the user
3. **Log**: Update `issues.md` with the escalation: "Auto-blocked after 3 attempts. Reassigned to [teammate] / Escalated to user."

### Lead Check

When processing a BLOCKED message:
```
1. Read issues.md — count OPEN entries for this task ID
2. If count >= 2 (this is the 3rd block):
   a. Message teammate: "This task has been blocked 3 times. Pausing your work on it."
   b. Decide: reassign or escalate
3. If count < 2:
   a. Acknowledge and route to resolution as normal
```
```

**Step 2: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "docs: add Auto-Block on Repeated Failures coordination pattern"
```

---

### Task 5: Create custom role definitions template

**Files:**
- Create: `docs/custom-roles.md`

**Step 1: Create the file**

```markdown
# Custom Role Definitions

Project-specific role definitions that extend the built-in roles (Implementer, Reviewer, Researcher, Challenger, Tester).

The team lead reads this file during Phase 1 task decomposition and uses custom roles alongside built-in roles when they match the task requirements.

## How to Use

1. Define custom roles below using the template
2. When invoking `/agent-team`, the lead will check for this file
3. Custom roles are used alongside built-in roles — they don't replace them

## Template

Copy this template for each custom role:

### {Role Name}

**Purpose**: {One sentence — what does this role do that built-in roles don't cover?}

**When to use**: {Task types or scenarios where this role is appropriate}

**Subagent type**: `general-purpose` | `Explore`

**Typical tools**: {Comma-separated tool list}

**Spawn prompt template**:
```text
You are a {role name} on this team. Your job is to {primary responsibility}.

Your assigned tasks: [TASK_IDS]
Your focus area: [AREA]

Workspace: .agent-team/[TEAM_NAME]/ — read these files for context.

Communication protocol — send structured messages to the lead:
- STARTING #N: {what I plan to do}
- COMPLETED #N: {what I did, results}
- BLOCKED #N: severity={level}, {blocker}, impact={what can't proceed}
- HANDOFF #N: {output for another teammate}
- QUESTION: {what I need to know}

Rules:
- {Role-specific rules}
- Read workspace files before asking the lead questions.
- After completing each task, mark complete via TaskUpdate and check TaskList.
```

## Example: Database Migration Specialist

### Database Migration Specialist

**Purpose**: Handle schema migrations, data transformations, and database-specific concerns that general implementers may not handle safely.

**When to use**: Tasks involving schema changes, data migrations, or database engine-specific optimizations.

**Subagent type**: `general-purpose`

**Typical tools**: Read, Write, Edit, Bash, Grep, Glob

**Spawn prompt template**:
```text
You are a database migration specialist on this team. Your job is to write safe, reversible database migrations and handle data transformations.

Your assigned tasks: [TASK_IDS]
Your file ownership: [MIGRATION_FILES/DIRECTORIES]

Workspace: .agent-team/[TEAM_NAME]/ — read these files for context.

Communication protocol — send structured messages to the lead:
- STARTING #N: {migration I plan to write, tables affected}
- COMPLETED #N: {migration written, rollback verified, any data concerns}
- BLOCKED #N: severity={level}, {blocker}, impact={what can't proceed}
- HANDOFF #N: {schema changes that implementers need to know about}
- QUESTION: {what I need to know}

Rules:
- Every migration MUST have a rollback/down migration.
- Test migrations on a copy before applying to the main database.
- ONLY modify files in your owned area (migration directories).
- Document any data loss risks in your COMPLETED message.
- Read workspace files before asking the lead questions.
- After completing each task, mark complete via TaskUpdate and check TaskList.
```
```

**Step 2: Validate plugin structure**

Run: `claude plugin validate .`
Expected: No errors

**Step 3: Commit**

```bash
git add docs/custom-roles.md
git commit -m "docs: add custom role definitions template"
```

---

### Task 6: Add description field to hooks.json

**Files:**
- Modify: `hooks/hooks.json`

**Step 1: Add description field**

Add `"description"` as the first field in hooks.json:

Current:
```json
{
  "hooks": {
```

New:
```json
{
  "description": "Agent Team quality gates — prevents premature task completion and nudges idle teammates",
  "hooks": {
```

**Step 2: Validate plugin**

Run: `claude plugin validate .`
Expected: No errors

**Step 3: Commit**

```bash
git add hooks/hooks.json
git commit -m "docs: add description field to hooks.json"
```

---

### Task 7: Create CHANGELOG.md

**Files:**
- Create: `CHANGELOG.md`

**Step 1: Create the file**

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-02-27

### Added
- **Re-plan on Block** coordination pattern — structured re-planning when critical blockers invalidate the original plan
- **Adversarial Review Rounds** coordination pattern — multi-round cross-review for high-stakes changes
- **Quality Gate** coordination pattern — final validation pass before Phase 5 synthesis
- **Auto-Block on Repeated Failures** coordination pattern — auto-escalation after 3 blocked attempts on the same task
- Custom role definitions template (`docs/custom-roles.md`) — project-specific roles alongside built-in ones
- `description` field in `hooks/hooks.json` for better UX in `/hooks` menu

## [1.2.0] - 2026-02-26

### Added
- Remediation Gate in Phase 5 — spawn fix team for unresolved issues (max 1 cycle)
- Tester role with spawn template
- Pre-shutdown commit protocol for implementers
- Complexity assessment and dedicated reviewer/tester gate for complex plans
- Remediation cycle tracking in `progress.md`

## [1.1.0] - 2026-02-24

### Added
- TeammateIdle hook with loop protection (3 strikes)
- Batch updates coordination pattern
- First contact verification pattern
- Parallel shutdown pattern

## [1.0.0] - 2026-02-23

### Added
- Initial release: 5-phase team orchestrator
- TaskCompleted hook with workspace and git change verification
- 5 teammate roles: Implementer, Reviewer, Researcher, Challenger, Leader
- Persistent workspace with progress.md, tasks.md, issues.md
- Structured communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF/QUESTION)
- Coordination patterns library
- Final report generation
```

**Step 2: Add to package.json files array**

In `package.json`, add `"CHANGELOG.md"` to the `"files"` array.

**Step 3: Commit**

```bash
git add CHANGELOG.md package.json
git commit -m "docs: add CHANGELOG.md with retroactive history"
```

---

### Task 8: Update SKILL.md Table of Contents reference for new patterns

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 4 coordination patterns list)

**Step 1: Add new patterns to the reference list**

In SKILL.md Phase 4 "Coordination Patterns" section, add the 4 new patterns to the bullet list:

```markdown
- **Re-plan on Block** — when a critical blocker invalidates the original plan, re-plan with user approval
- **Adversarial review rounds** — multi-round cross-review for high-stakes changes
- **Quality gate** — final validation pass before Phase 5 synthesis
- **Auto-block on repeated failures** — auto-escalation after 3 blocked attempts
```

**Step 2: Validate plugin**

Run: `claude plugin validate .`
Expected: No errors

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "docs: reference new coordination patterns in SKILL.md"
```

---

### Task 9: Bump version to 1.3.0 and validate

**Files:**
- Modify: `.claude-plugin/plugin.json` — version to "1.3.0"
- Modify: `.claude-plugin/marketplace.json` — version to "1.3.0"
- Modify: `package.json` — version to "1.3.0"

**Step 1: Update all 3 version files**

In each file, change `"1.2.0"` to `"1.3.0"`.

**Step 2: Run full test suite**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 3: Validate plugin**

Run: `claude plugin validate .`
Expected: No errors

**Step 4: Commit and tag**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json package.json
git commit -m "chore: bump version to 1.3.0"
git tag v1.3.0
```

---

## Release 2: v1.4.0 — Prompt & Template Improvements (Low Risk)

Files changed: `skills/agent-team/SKILL.md`, `docs/worker-roles.md`, `docs/report-format.md`

### Task 10: Add re-read workspace instruction to spawn templates

**Files:**
- Modify: `docs/worker-roles.md` (all 5 spawn prompt templates)

**Step 1: Add instruction to each role's spawn prompt**

In each role's spawn prompt template (Researcher, Implementer, Reviewer, Challenger, Tester), add this line to the "Rules:" section:

```
- Before starting each new task, re-read workspace files (progress.md, tasks.md, issues.md) to ensure you have current state. This prevents context drift on long-running sessions.
```

Add it as the second rule in each template (after the first role-specific rule, before the existing "Read workspace files before asking..." rule).

**Step 2: Validate plugin**

Run: `claude plugin validate .`
Expected: No errors

**Step 3: Commit**

```bash
git add docs/worker-roles.md
git commit -m "feat: add re-read workspace instruction to all spawn templates"
```

---

### Task 11: Add team metrics to final report template

**Files:**
- Modify: `docs/report-format.md` (Template section, after "### Follow-up Items")

**Step 1: Add Team Metrics section to the template**

In the template section of `docs/report-format.md`, insert after `### Follow-up Items` and before the `---` separator:

```markdown
### Team Metrics

| Metric | Value |
|--------|-------|
| Tasks | {completed}/{total} |
| Issues | {resolved}/{total} ({critical}C {high}H {medium}M {low}L) |
| Handoffs | {count} |
| Blocked events | {count} |
| Remediation cycles | {0 or 1} |
| Re-plans | {count, 0 if none} |
```

**Step 2: Commit**

```bash
git add docs/report-format.md
git commit -m "feat: add team metrics section to report format"
```

---

### Task 12: Update tasks.md template to group by status

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 3, tasks.md workspace template)

**Step 1: Replace the tasks.md template**

Replace the existing tasks.md template in SKILL.md Phase 3 with:

```markdown
# Tasks: {team-name}

**Last updated**: {timestamp}

## In Progress

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|

## Blocked

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Pending

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Completed

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
```

**Step 2: Update the TeammateIdle hook test to match new format**

The `check-teammate-idle.sh` script parses tasks.md with awk looking for columns. The new format still uses pipe-delimited tables, but the columns are slightly different per section. Update `scripts/check-teammate-idle.sh` to parse the new grouped format.

The awk command needs to handle multiple table sections. The key difference: "In Progress" section has columns ID | Subject | Owner | Notes (no Status column — the section header IS the status). Update the awk to match Owner in column 4 when in the "In Progress" section:

```bash
# Count in-progress tasks owned by this teammate.
# New format: grouped by status sections. "## In Progress" section contains active tasks.
# Table columns in that section: ID | Subject | Owner | Notes
IN_PROGRESS=$(awk -F'|' -v owner="$TEAMMATE" '
  /^## In Progress/ { in_progress=1; next }
  /^## / { in_progress=0 }
  in_progress && NF >= 4 && tolower($4) ~ tolower(owner)
' "$TASKS_FILE" 2>/dev/null | wc -l | tr -d ' ')
```

**Step 3: Update test for new tasks.md format**

In `tests/hooks/test-check-teammate-idle.sh`, update `setup_mock_workspace` usage or add a helper that creates the new grouped format. The test-helpers `setup_mock_workspace` creates the old flat format — update it to create the new grouped format.

Update `tests/lib/test-helpers.sh` `setup_mock_workspace`:

```bash
  cat > "$WORKSPACE_DIR/tasks.md" <<'EOF'
# Tasks: test

**Last updated**: 2026-01-01

## In Progress

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|

## Blocked

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Pending

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Completed

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
EOF
```

**Step 4: Run tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass (TeammateIdle hook tests should pass with new format)

**Step 5: Commit**

```bash
git add skills/agent-team/SKILL.md scripts/check-teammate-idle.sh tests/lib/test-helpers.sh tests/hooks/test-check-teammate-idle.sh
git commit -m "feat: group tasks.md by status sections"
```

---

### Task 13: Add Phase 1 custom roles reference

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 1)

**Step 1: Add custom roles check**

In Phase 1, after step 1 "Identify independent work streams", add:

```markdown
5. **Check for custom roles** — if `docs/custom-roles.md` exists in the project, read it. Use custom roles alongside built-in roles when they match the task requirements.
```

**Step 2: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add custom roles reference to Phase 1"
```

---

### Task 14: Bump version to 1.4.0, validate, and tag

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `package.json` — version to "1.4.0"
- Modify: `CHANGELOG.md` — add v1.4.0 section

**Step 1: Update CHANGELOG.md**

Add at the top of the changelog (after the header, before `## [1.3.0]`):

```markdown
## [1.4.0] - 2026-02-27

### Added
- Re-read workspace instruction in all spawn templates (prevents context drift)
- Team metrics section in final report template
- Custom roles reference in Phase 1 decomposition

### Changed
- `tasks.md` workspace template now groups tasks by status (In Progress / Blocked / Pending / Completed)
- TeammateIdle hook updated to parse grouped tasks.md format
```

**Step 2: Update version in all 3 files**

Change `"1.3.0"` to `"1.4.0"` in plugin.json, marketplace.json, and package.json.

**Step 3: Run full test suite**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 4: Validate plugin**

Run: `claude plugin validate .`
Expected: No errors

**Step 5: Commit and tag**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json package.json CHANGELOG.md
git commit -m "chore: bump version to 1.4.0"
git tag v1.4.0
```

---

## Release 3: v1.5.0 — New Hooks (Medium Risk)

Files changed: `hooks/hooks.json`, `scripts/` (3 new, 1 modified), `skills/agent-team/SKILL.md`, `tests/hooks/` (3 new test files)

### Task 15: Write tests for SessionStart(compact) hook

**Files:**
- Create: `tests/hooks/test-recover-context.sh`

**Step 1: Write the test file**

```bash
#!/bin/bash
# Tests for scripts/recover-context.sh (SessionStart compact hook)

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/recover-context.sh"

echo "SessionStart(compact) hook tests"
echo "================================="

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed\n"
  exit 0
fi

# --- Test 1: No workspace directory — outputs nothing, exits 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
HOOK_STDOUT=$(echo '{"hook_event_name":"SessionStart","matcher":"compact","cwd":"'"$TEST_TEMP_DIR"'"}' | bash "$HOOK" 2>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "1: No workspace exits 0"
assert_true "1: No output when no workspace" '[ -z "$HOOK_STDOUT" ]'
cleanup_temp_dir

# --- Test 2: Active workspace — outputs summary ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "my-team"
# Set status to active
sed -i.bak 's/Status: active/Status: active/' "$WORKSPACE_DIR/progress.md" 2>/dev/null || \
  sed -i '' 's/Status: active/Status: active/' "$WORKSPACE_DIR/progress.md"
HOOK_STDOUT=$(echo '{"hook_event_name":"SessionStart","matcher":"compact","cwd":"'"$TEST_TEMP_DIR"'"}' | bash "$HOOK" 2>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "2: Active workspace exits 0"
assert_true "2: Output contains workspace path" 'echo "$HOOK_STDOUT" | grep -q ".agent-team/my-team"'
cleanup_temp_dir

# --- Test 3: Done workspace — no output (not active) ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "done-team"
sed -i.bak 's/Status: active/Status: done/' "$WORKSPACE_DIR/progress.md" 2>/dev/null || \
  sed -i '' 's/Status: active/Status: done/' "$WORKSPACE_DIR/progress.md"
HOOK_STDOUT=$(echo '{"hook_event_name":"SessionStart","matcher":"compact","cwd":"'"$TEST_TEMP_DIR"'"}' | bash "$HOOK" 2>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "3: Done workspace exits 0"
assert_true "3: No output for done workspace" '[ -z "$HOOK_STDOUT" ]'
cleanup_temp_dir

# --- Test 4: Graceful degradation without jq ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
ORIG_PATH="$PATH"
SHADOW_BIN="$TEST_TEMP_DIR/shadow-bin"
mkdir -p "$SHADOW_BIN"
for bin_dir in /usr/bin /bin; do
  if [ -d "$bin_dir" ]; then
    for exe in "$bin_dir"/*; do
      base=$(basename "$exe")
      [ "$base" = "jq" ] && continue
      [ ! -e "$SHADOW_BIN/$base" ] && ln -sf "$exe" "$SHADOW_BIN/$base" 2>/dev/null || true
    done
  fi
done
HOOK_STDOUT=$(echo '{}' | PATH="$SHADOW_BIN" bash "$HOOK" 2>/dev/null)
HOOK_EXIT=$?
PATH="$ORIG_PATH"
assert_exit_code 0 "$HOOK_EXIT" "4: Graceful degradation without jq"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
```

**Step 2: Run the test to verify it fails**

Run: `bash tests/hooks/test-recover-context.sh`
Expected: FAIL (script doesn't exist yet)

---

### Task 16: Implement SessionStart(compact) hook

**Files:**
- Create: `scripts/recover-context.sh`

**Step 1: Write the script**

```bash
#!/bin/bash
# Hook: SessionStart (compact matcher)
# After context compaction, outputs active workspace state to help the lead recover.
# Exit 0 always (non-blocking). Summary output goes to stdout (injected into context).

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Use cwd from input, fall back to current directory
SEARCH_DIR="${CWD:-.}"

# Find active workspaces (status != done)
FOUND_ACTIVE=false
for progress_file in "$SEARCH_DIR"/.agent-team/*/progress.md; do
  [ -f "$progress_file" ] || continue

  # Check if workspace is active (not done)
  STATUS=$(grep -oP '\*\*Status\*\*:\s*\K\S+' "$progress_file" 2>/dev/null || \
           grep '^\*\*Status\*\*:' "$progress_file" | sed 's/.*: *//' | tr -d ' ')
  if [ "$STATUS" = "done" ]; then
    continue
  fi

  TEAM_DIR=$(dirname "$progress_file")
  TEAM_NAME=$(basename "$TEAM_DIR")
  FOUND_ACTIVE=true

  echo "=== CONTEXT RECOVERY: Active team workspace found ==="
  echo ""
  echo "Team: $TEAM_NAME"
  echo "Workspace: .agent-team/$TEAM_NAME/"
  echo "Status: $STATUS"
  echo ""
  echo "Recovery action: Read these files to restore your awareness:"
  echo "  1. .agent-team/$TEAM_NAME/progress.md  (team state, decisions, handoffs)"
  echo "  2. .agent-team/$TEAM_NAME/tasks.md     (task ledger with statuses)"
  echo "  3. .agent-team/$TEAM_NAME/issues.md    (open issues)"
  echo ""
  echo "Then read ~/.claude/teams/$TEAM_NAME/config.json for live team members."
  echo "Then call TaskList for live task state."
  echo "=== END CONTEXT RECOVERY ==="
done

exit 0
```

**Step 2: Make executable**

Run: `chmod +x scripts/recover-context.sh`

**Step 3: Run the tests**

Run: `bash tests/hooks/test-recover-context.sh`
Expected: All tests pass

**Step 4: Commit**

```bash
git add scripts/recover-context.sh tests/hooks/test-recover-context.sh
git commit -m "feat: add SessionStart(compact) hook for context recovery"
```

---

### Task 17: Write tests for PreToolUse file ownership hook

**Files:**
- Create: `tests/hooks/test-check-file-ownership.sh`

**Step 1: Write the test file**

```bash
#!/bin/bash
# Tests for scripts/check-file-ownership.sh (PreToolUse file ownership hook)

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/check-file-ownership.sh"

echo "PreToolUse file ownership hook tests"
echo "====================================="

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed\n"
  exit 0
fi

# Helper: create file-locks.json
create_file_locks() {
  local workspace_dir="$1"
  cat > "$workspace_dir/file-locks.json" <<'EOF'
{
  "backend-impl": ["src/auth/", "src/middleware/auth.ts"],
  "frontend-impl": ["src/components/", "src/pages/"]
}
EOF
}

# --- Test 1: No file-locks.json — allow (graceful degradation) ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/auth/login.ts"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "1: No file-locks.json allows (graceful degradation)"
cleanup_temp_dir

# --- Test 2: Teammate writes to owned file — allow ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
create_file_locks "$WORKSPACE_DIR"
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/auth/login.ts"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "2: Write to owned file allows"
cleanup_temp_dir

# --- Test 3: Teammate writes to unowned file — first violation warns ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
create_file_locks "$WORKSPACE_DIR"
# Clear any existing violation counters
rm -rf /tmp/agent-team-ownership-violations 2>/dev/null
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/components/Button.tsx"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "3: First violation warns (exit 0)"
assert_stderr_contains "ownership" "$HOOK_STDERR" "3: Warning message mentions ownership"
cleanup_temp_dir

# --- Test 4: Second violation on same file — blocks ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
create_file_locks "$WORKSPACE_DIR"
rm -rf /tmp/agent-team-ownership-violations 2>/dev/null
# First violation (warn)
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/components/Button.tsx"},"teammate_name":"backend-impl","team_name":"test"}'
# Second violation (block)
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/components/Button.tsx"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 2 "$HOOK_EXIT" "4: Second violation blocks (exit 2)"
cleanup_temp_dir

# --- Test 5: Workspace files always allowed ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
create_file_locks "$WORKSPACE_DIR"
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":".agent-team/test/tasks.md"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "5: Workspace file write always allowed"
cleanup_temp_dir

# --- Test 6: No teammate_name — allow (not a team context) ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/foo.ts"}}'
assert_exit_code 0 "$HOOK_EXIT" "6: No teammate_name allows"
cleanup_temp_dir

# --- Test 7: Directory ownership matches file inside directory ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
create_file_locks "$WORKSPACE_DIR"
run_hook "$HOOK" '{"tool_name":"Edit","tool_input":{"file_path":"src/auth/middleware/validate.ts"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "7: File inside owned directory is allowed"
cleanup_temp_dir

# Cleanup violation counters
rm -rf /tmp/agent-team-ownership-violations 2>/dev/null

print_summary
exit "$TESTS_FAILED"
```

**Step 2: Run to verify it fails**

Run: `bash tests/hooks/test-check-file-ownership.sh`
Expected: FAIL (script doesn't exist yet)

---

### Task 18: Implement PreToolUse file ownership hook

**Files:**
- Create: `scripts/check-file-ownership.sh`

**Step 1: Write the script**

```bash
#!/bin/bash
# Hook: PreToolUse (matcher: Write|Edit)
# Enforces file ownership — warns on first violation, blocks on second.
# Exit 0 = allow, Exit 2 = block with feedback.

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // empty')
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if not in team context
if [ -z "$TEAMMATE" ] || [ -z "$TEAM" ] || [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Always allow workspace file writes
if echo "$FILE_PATH" | grep -q '^\.agent-team/'; then
  exit 0
fi

# Find file-locks.json
LOCKS_FILE=".agent-team/$TEAM/file-locks.json"
if [ ! -f "$LOCKS_FILE" ]; then
  # Try -fix suffix (remediation team)
  BASE_NAME="${TEAM%-fix}"
  if [ "$BASE_NAME" != "$TEAM" ] && [ -f ".agent-team/$BASE_NAME/file-locks.json" ]; then
    LOCKS_FILE=".agent-team/$BASE_NAME/file-locks.json"
  else
    exit 0  # No locks file — graceful degradation
  fi
fi

# Check if teammate owns this file
# file-locks.json: {"teammate-name": ["path/", "path/file.ext"], ...}
OWNED_PATHS=$(jq -r --arg t "$TEAMMATE" '.[$t] // [] | .[]' "$LOCKS_FILE" 2>/dev/null)

if [ -z "$OWNED_PATHS" ]; then
  # Teammate not in file-locks.json — warn but allow
  echo "Warning: $TEAMMATE is not listed in file-locks.json. Contact the lead to update file ownership." >&2
  exit 0
fi

# Check if file matches any owned path
OWNS_FILE=false
while IFS= read -r owned_path; do
  [ -z "$owned_path" ] && continue
  # Directory ownership: owned_path ends with /
  if [[ "$owned_path" == */ ]]; then
    if [[ "$FILE_PATH" == "$owned_path"* ]]; then
      OWNS_FILE=true
      break
    fi
  else
    # Exact file match
    if [ "$FILE_PATH" = "$owned_path" ]; then
      OWNS_FILE=true
      break
    fi
  fi
done <<< "$OWNED_PATHS"

if [ "$OWNS_FILE" = true ]; then
  exit 0
fi

# --- Violation detected ---
# Warn-then-block: track violations per teammate+file
VIOLATION_DIR="/tmp/agent-team-ownership-violations"
mkdir -p "$VIOLATION_DIR"
chmod 700 "$VIOLATION_DIR"

# Use md5/shasum for file path hash to avoid path characters in filename
FILE_HASH=$(echo -n "$FILE_PATH" | md5 2>/dev/null || echo -n "$FILE_PATH" | md5sum 2>/dev/null | cut -d' ' -f1 || echo -n "$FILE_PATH" | shasum 2>/dev/null | cut -d' ' -f1)
VIOLATION_FILE="$VIOLATION_DIR/${TEAM}--${TEAMMATE}--${FILE_HASH}"

if [ -f "$VIOLATION_FILE" ]; then
  # Second violation — block
  echo "BLOCKED: $TEAMMATE does not own '$FILE_PATH'. This is the second attempt. Message the lead to request ownership reassignment." >&2
  exit 2
else
  # First violation — warn
  echo "1" > "$VIOLATION_FILE"
  echo "WARNING: $TEAMMATE does not own '$FILE_PATH'. The owner should handle this file. If you need to modify it, message the lead. Next attempt will be blocked." >&2
  exit 0
fi
```

**Step 2: Make executable**

Run: `chmod +x scripts/check-file-ownership.sh`

**Step 3: Run the tests**

Run: `bash tests/hooks/test-check-file-ownership.sh`
Expected: All tests pass

**Step 4: Commit**

```bash
git add scripts/check-file-ownership.sh tests/hooks/test-check-file-ownership.sh
git commit -m "feat: add PreToolUse file ownership hook (warn-then-block)"
```

---

### Task 19: Write tests for SubagentStart/Stop lifecycle hook

**Files:**
- Create: `tests/hooks/test-track-teammate-lifecycle.sh`

**Step 1: Write the test file**

```bash
#!/bin/bash
# Tests for scripts/track-teammate-lifecycle.sh

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/track-teammate-lifecycle.sh"

echo "SubagentStart/Stop lifecycle hook tests"
echo "========================================"

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed\n"
  exit 0
fi

# --- Test 1: SubagentStart appends to events.log ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
HOOK_STDERR=$(echo '{"hook_event_name":"SubagentStart","teammate_name":"backend-impl","team_name":"test","agent_type":"general-purpose"}' | bash "$HOOK" 2>&1 1>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "1: SubagentStart exits 0"
assert_true "1: events.log created" '[ -f ".agent-team/test/events.log" ]'
assert_true "1: events.log contains spawn entry" 'grep -q "spawn" ".agent-team/test/events.log"'
cleanup_temp_dir

# --- Test 2: SubagentStop appends to events.log ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
echo '{"ts":"2026-01-01T00:00:00Z","type":"spawn","agent":"backend-impl"}' > ".agent-team/test/events.log"
HOOK_STDERR=$(echo '{"hook_event_name":"SubagentStop","teammate_name":"backend-impl","team_name":"test"}' | bash "$HOOK" 2>&1 1>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "2: SubagentStop exits 0"
assert_true "2: events.log has 2 entries" '[ "$(wc -l < .agent-team/test/events.log | tr -d " ")" -ge 2 ]'
assert_true "2: events.log contains stop entry" 'grep -q "stop" ".agent-team/test/events.log"'
cleanup_temp_dir

# --- Test 3: No team_name — exits 0 silently ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
HOOK_STDERR=$(echo '{"hook_event_name":"SubagentStart","teammate_name":"test"}' | bash "$HOOK" 2>&1 1>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "3: No team_name exits 0"
cleanup_temp_dir

# --- Test 4: No workspace — exits 0 silently ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
HOOK_STDERR=$(echo '{"hook_event_name":"SubagentStart","teammate_name":"impl","team_name":"nonexistent"}' | bash "$HOOK" 2>&1 1>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "4: No workspace exits 0"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
```

**Step 2: Run to verify it fails**

Run: `bash tests/hooks/test-track-teammate-lifecycle.sh`
Expected: FAIL

---

### Task 20: Implement SubagentStart/Stop lifecycle hook

**Files:**
- Create: `scripts/track-teammate-lifecycle.sh`

**Step 1: Write the script**

```bash
#!/bin/bash
# Hook: SubagentStart / SubagentStop
# Appends lifecycle events to .agent-team/{team}/events.log.
# Non-blocking — always exits 0.

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // empty')
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')

# Skip if we can't identify the team
if [ -z "$TEAM" ]; then
  exit 0
fi

# Find workspace directory
WORKSPACE_DIR=".agent-team/$TEAM"
if [ ! -d "$WORKSPACE_DIR" ]; then
  BASE_NAME="${TEAM%-fix}"
  if [ "$BASE_NAME" != "$TEAM" ] && [ -d ".agent-team/$BASE_NAME" ]; then
    WORKSPACE_DIR=".agent-team/$BASE_NAME"
  else
    exit 0  # No workspace — nothing to log
  fi
fi

EVENTS_LOG="$WORKSPACE_DIR/events.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

case "$EVENT" in
  SubagentStart)
    echo "{\"ts\":\"$TIMESTAMP\",\"type\":\"spawn\",\"agent\":\"$TEAMMATE\",\"agent_type\":\"$AGENT_TYPE\"}" >> "$EVENTS_LOG"
    ;;
  SubagentStop)
    echo "{\"ts\":\"$TIMESTAMP\",\"type\":\"stop\",\"agent\":\"$TEAMMATE\"}" >> "$EVENTS_LOG"
    ;;
esac

exit 0
```

**Step 2: Make executable**

Run: `chmod +x scripts/track-teammate-lifecycle.sh`

**Step 3: Run the tests**

Run: `bash tests/hooks/test-track-teammate-lifecycle.sh`
Expected: All tests pass

**Step 4: Commit**

```bash
git add scripts/track-teammate-lifecycle.sh tests/hooks/test-track-teammate-lifecycle.sh
git commit -m "feat: add SubagentStart/Stop lifecycle tracking hook"
```

---

### Task 21: Enhance TaskCompleted hook with task_id and teammate_name

**Files:**
- Modify: `scripts/verify-task-complete.sh`
- Modify: `tests/hooks/test-verify-task-complete.sh` (add new tests)

**Step 1: Write new tests for enhanced behavior**

Add to `tests/hooks/test-verify-task-complete.sh` before `print_summary`:

```bash
# --- Test 13: teammate_name scopes git check to owned files ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
# Create file-locks.json
cat > "$WORKSPACE_DIR/file-locks.json" <<'LOCKS'
{"backend-impl": ["src/auth/"]}
LOCKS
setup_mock_git_repo "dirty"
# The dirty file is uncommitted-file.txt (not in src/auth/)
# With scoping, backend-impl should see no changes in their owned files
# But we're testing that the hook READS task_id and teammate_name — the scoping
# is best-effort (only when file-locks.json exists)
run_hook "$HOOK" '{"task_subject":"Implement auth","team_name":"test","task_id":"task-001","teammate_name":"backend-impl"}'
# Should still pass because there ARE dirty files in the repo
assert_exit_code 0 "$HOOK_EXIT" "13: Enhanced hook reads task_id and teammate_name"
cleanup_temp_dir
```

**Step 2: Update the script**

In `scripts/verify-task-complete.sh`, after parsing `TASK_SUBJECT` and `TEAM_NAME`, add:

```bash
TASK_ID=$(echo "$INPUT" | jq -r '.task_id // empty')
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // empty')
```

Update the git change check to optionally scope to teammate's owned files when file-locks.json exists:

Replace the current git check block:
```bash
if echo "$TASK_SUBJECT" | grep -qiE 'implement|create|add|build|write|refactor|fix|migrate'; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CHANGES" = "0" ]; then
```

With the enhanced version that checks teammate-scoped files first, falling back to repo-wide check:

```bash
if echo "$TASK_SUBJECT" | grep -qiE 'implement|create|add|build|write|refactor|fix|migrate'; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CHANGES="0"
    # Try scoped check first: if we know the teammate and their owned files, only check those
    if [ -n "$TEAMMATE_NAME" ] && [ -n "$WORKSPACE_DIR" ] && [ -f "$WORKSPACE_DIR/file-locks.json" ]; then
      OWNED_PATHS=$(jq -r --arg t "$TEAMMATE_NAME" '.[$t] // [] | .[]' "$WORKSPACE_DIR/file-locks.json" 2>/dev/null)
      if [ -n "$OWNED_PATHS" ]; then
        while IFS= read -r owned_path; do
          [ -z "$owned_path" ] && continue
          PATH_CHANGES=$(git status --porcelain -- "$owned_path" 2>/dev/null | wc -l | tr -d ' ')
          CHANGES=$((CHANGES + PATH_CHANGES))
        done <<< "$OWNED_PATHS"
      else
        # Teammate not in file-locks — fall back to repo-wide
        CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
      fi
    else
      # No scoping info — fall back to repo-wide (original behavior)
      CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ "$CHANGES" = "0" ]; then
```

**Step 3: Run all tests**

Run: `bash tests/run-tests.sh`
Expected: All tests pass (including existing tests for backward compatibility)

**Step 4: Commit**

```bash
git add scripts/verify-task-complete.sh tests/hooks/test-verify-task-complete.sh
git commit -m "feat: enhance TaskCompleted hook with task_id and teammate-scoped git checks"
```

---

### Task 22: Register new hooks in hooks.json

**Files:**
- Modify: `hooks/hooks.json`

**Step 1: Add all new hook registrations**

Replace the full hooks.json content:

```json
{
  "description": "Agent Team quality gates — prevents premature task completion, nudges idle teammates, enforces file ownership, recovers context after compaction, and tracks teammate lifecycle",
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/verify-task-complete.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/check-teammate-idle.sh",
            "timeout": 15
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/recover-context.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/check-file-ownership.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "SubagentStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/track-teammate-lifecycle.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/track-teammate-lifecycle.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Step 2: Validate plugin**

Run: `claude plugin validate .`
Expected: No errors

**Step 3: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat: register new hooks (SessionStart, PreToolUse, SubagentStart/Stop)"
```

---

### Task 23: Add file-locks.json to SKILL.md workspace and update Hooks section

**Files:**
- Modify: `skills/agent-team/SKILL.md`

**Step 1: Update Phase 3 step 3 to create 4 files**

In Phase 3, update the workspace initialization to include file-locks.json:

Add after the issues.md template:

```markdown
   #### file-locks.json

   ```json
   {
     "{teammate-name}": ["{owned-directory}/", "{owned-file}"],
     "{teammate-name}": ["{owned-directory}/"]
   }
   ```

   Populated from the Phase 2 plan's file ownership mapping. Used by the PreToolUse hook to enforce ownership.
```

Update the `mkdir -p` / `Write` list to include file-locks.json as the 4th file.

**Step 2: Update the Hooks section**

Replace the existing Hooks section with:

```markdown
## Hooks

This plugin registers hooks at the plugin level via `hooks/hooks.json`. They enforce team discipline automatically:

- **TaskCompleted** (`scripts/verify-task-complete.sh`): Blocks premature task completion — checks workspace files exist and implementation tasks have actual file changes. Uses `teammate_name` and `file-locks.json` to scope git checks to the teammate's owned files when available. Requires `jq`.
- **TeammateIdle** (`scripts/check-teammate-idle.sh`): Nudges idle teammates that still have in-progress tasks. Includes loop protection (allows idle after 3 blocked attempts). Requires `jq`.
- **SessionStart(compact)** (`scripts/recover-context.sh`): After context compaction, automatically outputs active workspace paths and recovery instructions. Non-blocking.
- **PreToolUse(Write|Edit)** (`scripts/check-file-ownership.sh`): Enforces file ownership via `file-locks.json`. Warn-then-block: first violation warns, second blocks. Workspace files (`.agent-team/`) always allowed. Requires `jq`.
- **SubagentStart / SubagentStop** (`scripts/track-teammate-lifecycle.sh`): Logs teammate spawn and stop events to `.agent-team/{team}/events.log`. Non-blocking.

All hooks exit 0 (allow) if their dependencies are missing — they degrade gracefully. Hook paths use `${CLAUDE_PLUGIN_ROOT}`.
```

**Step 3: Update Phase 5 cleanup step**

In Phase 5 step 10 (Cleanup), add to the cleanup line:

```bash
rm -f /tmp/agent-team-idle-counters/{team-name}--* 2>/dev/null || true
rm -rf /tmp/agent-team-ownership-violations 2>/dev/null || true
```

**Step 4: Validate plugin**

Run: `claude plugin validate .`
Expected: No errors

**Step 5: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add file-locks.json workspace file and update Hooks section"
```

---

### Task 24: Bump version to 1.5.0, validate, and tag

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `package.json` — version to "1.5.0"
- Modify: `CHANGELOG.md`

**Step 1: Update CHANGELOG.md**

Add v1.5.0 section:

```markdown
## [1.5.0] - 2026-02-27

### Added
- **SessionStart(compact) hook** — auto-recovers workspace context after compaction
- **PreToolUse(Write|Edit) hook** — enforces file ownership (warn-then-block)
- **SubagentStart/SubagentStop hooks** — tracks teammate lifecycle in events.log
- `file-locks.json` workspace file — maps teammates to owned files/directories

### Changed
- TaskCompleted hook now uses `task_id` and `teammate_name` for scoped git checks
- Hooks section in SKILL.md updated to document all 5 hooks
```

**Step 2: Update version in all 3 files**

**Step 3: Run full test suite**

Run: `bash tests/run-tests.sh`
Expected: All tests pass

**Step 4: Validate plugin**

Run: `claude plugin validate .`
Expected: No errors

**Step 5: Commit and tag**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json package.json CHANGELOG.md
git commit -m "chore: bump version to 1.5.0"
git tag v1.5.0
```

---

## Release 4: v1.6.0 — Structural Improvements (Medium-High Risk)

Files changed: `skills/agent-team/SKILL.md`, `docs/worker-roles.md`, `docs/coordination-patterns.md`

### Task 25: Add auto-branch per teammate to spawn templates

**Files:**
- Modify: `docs/worker-roles.md` (Implementer spawn template)
- Modify: `skills/agent-team/SKILL.md` (Phase 3, Phase 5)

**Step 1: Update Implementer spawn template**

In `docs/worker-roles.md`, add to the Implementer spawn prompt template Rules section:

```
- At the start of your first task, create a feature branch: `git checkout -b {team-name}/{your-name}`. All your work goes on this branch. If git is not available, skip branching and work directly.
```

**Step 2: Update Phase 3 spawn guidance**

In SKILL.md Phase 3 step 5, add to the "Each spawn prompt MUST include" list:

```markdown
   - **Branch instruction** (implementers only): "Create branch `{team-name}/{your-name}` before starting work. If git is unavailable, skip."
```

**Step 3: Add Branch Merge step to Phase 5**

In Phase 5, after step 3 (Pre-shutdown commit) and before step 4 (Check integration), insert:

```markdown
4. **Merge branches** (if auto-branching was used):
   - List all teammate branches: `git branch --list '{team-name}/*'`
   - For each branch, merge into the base branch: `git merge --no-ff {team-name}/{teammate-name}`
   - If merge conflicts occur: log in `issues.md`, assign the relevant implementer to resolve before shutdown
   - Clean up branches after merge: `git branch -d {team-name}/{teammate-name}`
   - If git is not available or no teammate branches exist, skip this step
```

Renumber subsequent steps.

**Step 4: Validate plugin**

Run: `claude plugin validate .`
Expected: No errors

**Step 5: Commit**

```bash
git add docs/worker-roles.md skills/agent-team/SKILL.md
git commit -m "feat: add auto-branch per teammate"
```

---

### Task 26: Add event log file to workspace

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 3, Phase 4)

**Step 1: Add events.log to Phase 3 workspace init**

In Phase 3 step 3, after the file-locks.json section, add:

```markdown
   #### events.log

   Initially empty. Append-only, one JSON line per event. The SubagentStart/Stop hooks write to this file automatically. The lead also appends events during Phase 4 coordination.

   Event types: `spawn`, `stop`, `task_start`, `task_complete`, `blocked`, `handoff`, `decision`, `replan`.

   Format:
   ```json
   {"ts":"2026-02-27T10:30:00Z","type":"spawn","agent":"backend-impl","role":"implementer"}
   ```
```

**Step 2: Update workspace update protocol in Phase 4**

Add new rows to the Workspace Update Protocol table:

```markdown
| Teammate spawned | events.log | Append spawn event (also auto-logged by SubagentStart hook) |
| Task started | events.log | Append task_start event |
| Task completed | events.log | Append task_complete event |
| Blocked event | events.log | Append blocked event |
| Handoff occurs | events.log | Append handoff event |
| Decision made | events.log | Append decision event |
```

**Step 3: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add events.log to workspace and update protocol"
```

---

### Task 27: Add Direct Handoff coordination pattern

**Files:**
- Modify: `docs/coordination-patterns.md`
- Modify: `skills/agent-team/SKILL.md` (Phase 4 brief note)

**Step 1: Add the pattern**

Append to `docs/coordination-patterns.md`:

```markdown
## Direct Handoff

For pre-approved information transfers between specific teammates, bypassing the lead for efficiency.

### When to Use

- Two teammates have a clear dependency (A produces → B consumes)
- The handoff content is straightforward (file paths, interface definitions)
- The lead has explicitly authorized the direct channel in their spawn prompts

### When NOT to Use

- The handoff requires interpretation or decision-making (route through lead)
- The information needs to be visible to multiple teammates (use lead routing)
- First-time handoffs between teammates who haven't worked together in this session

### Protocol

1. **Lead authorizes** in spawn prompts: "For handoffs to [teammate-name], you may message them directly. Include the lead in a summary."
2. **Sender** messages the recipient directly using SendMessage with `type: "message"` and the recipient's name
3. **Sender also messages the lead** with a brief summary: "HANDOFF #N: Sent [details] directly to [recipient]"
4. **Lead logs** the handoff in `progress.md` Handoffs section (audit trail preserved)

### Key Rule

The audit trail MUST be maintained. Direct handoffs save time but must still be logged via the lead's workspace updates.
```

**Step 2: Add brief note to SKILL.md Phase 4**

In the Phase 4 communication section, after "Use `message` (1:1) for all task-specific communication", add:

```markdown
For high-frequency handoffs between specific teammates, you may authorize direct communication — see the Direct Handoff pattern in [coordination-patterns.md](../../docs/coordination-patterns.md). The audit trail must still be maintained in `progress.md`.
```

**Step 3: Commit**

```bash
git add docs/coordination-patterns.md skills/agent-team/SKILL.md
git commit -m "feat: add Direct Handoff coordination pattern"
```

---

### Task 28: Bump version to 1.6.0, validate, and tag

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `package.json` — version to "1.6.0"
- Modify: `CHANGELOG.md`

**Step 1: Update CHANGELOG.md**

```markdown
## [1.6.0] - 2026-02-27

### Added
- Auto-branch per teammate — implementers create `{team-name}/{name}` branches, merged in Phase 5
- `events.log` workspace file — structured JSON event log for post-mortem analysis
- Direct Handoff coordination pattern — authorized peer-to-peer messaging with audit trail
- Branch Merge step in Phase 5
```

**Step 2: Update version, run tests, validate, commit, tag**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json package.json CHANGELOG.md
git commit -m "chore: bump version to 1.6.0"
git tag v1.6.0
```

---

## Release 5: v2.0.0 — Major Features (High Risk)

Files changed: `skills/agent-team/SKILL.md`, `scripts/` (2 new), `docs/worker-roles.md`

### Task 29: Write tests for worktree setup script

**Files:**
- Create: `tests/hooks/test-setup-worktree.sh`

**Step 1: Write tests**

```bash
#!/bin/bash
# Tests for scripts/setup-worktree.sh

source "$(dirname "$0")/../lib/test-helpers.sh"

SCRIPT="$PROJECT_ROOT/scripts/setup-worktree.sh"

echo "Worktree setup script tests"
echo "============================"

# --- Test 1: Creates worktree in git repo ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_git_repo "clean"
RESULT=$(bash "$SCRIPT" "test-team" "backend-impl" 2>/dev/null)
SCRIPT_EXIT=$?
assert_exit_code 0 "$SCRIPT_EXIT" "1: Creates worktree (exit code)"
assert_true "1: Worktree directory exists" '[ -d ".claude/worktrees/test-team--backend-impl" ]'
assert_true "1: Output contains worktree path" 'echo "$RESULT" | grep -q "worktrees/test-team--backend-impl"'
cleanup_temp_dir

# --- Test 2: Not a git repo — exits with error ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
RESULT=$(bash "$SCRIPT" "test-team" "backend-impl" 2>/dev/null)
SCRIPT_EXIT=$?
assert_exit_code 1 "$SCRIPT_EXIT" "2: Not a git repo exits 1"
cleanup_temp_dir

# --- Test 3: Missing arguments — exits with error ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_git_repo "clean"
RESULT=$(bash "$SCRIPT" 2>/dev/null)
SCRIPT_EXIT=$?
assert_exit_code 1 "$SCRIPT_EXIT" "3: Missing arguments exits 1"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
```

**Step 2: Run to verify it fails**

---

### Task 30: Implement worktree setup script

**Files:**
- Create: `scripts/setup-worktree.sh`

**Step 1: Write the script**

```bash
#!/bin/bash
# Creates a git worktree for an isolated teammate workspace.
# Usage: setup-worktree.sh <team-name> <teammate-name>
# Outputs the worktree path to stdout on success.
# Exit 0 = success, Exit 1 = error.

set -euo pipefail

TEAM_NAME="${1:-}"
TEAMMATE_NAME="${2:-}"

if [ -z "$TEAM_NAME" ] || [ -z "$TEAMMATE_NAME" ]; then
  echo "Usage: setup-worktree.sh <team-name> <teammate-name>" >&2
  exit 1
fi

# Must be in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: not inside a git repository" >&2
  exit 1
fi

WORKTREE_DIR=".claude/worktrees/${TEAM_NAME}--${TEAMMATE_NAME}"
BRANCH_NAME="${TEAM_NAME}/${TEAMMATE_NAME}"

# Create worktree with a new branch
git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" HEAD 2>/dev/null

echo "$WORKTREE_DIR"
```

**Step 2: Make executable, run tests, commit**

```bash
chmod +x scripts/setup-worktree.sh
git add scripts/setup-worktree.sh tests/hooks/test-setup-worktree.sh
git commit -m "feat: add worktree setup script"
```

---

### Task 31: Write tests for worktree merge script

**Files:**
- Create: `tests/hooks/test-merge-worktrees.sh`

**Step 1: Write tests**

```bash
#!/bin/bash
# Tests for scripts/merge-worktrees.sh

source "$(dirname "$0")/../lib/test-helpers.sh"

SCRIPT="$PROJECT_ROOT/scripts/merge-worktrees.sh"

echo "Worktree merge script tests"
echo "============================"

# --- Test 1: Merges worktree branch back ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_git_repo "clean"
# Create a worktree and make a change in it
git worktree add .claude/worktrees/test--impl -b test/impl HEAD 2>/dev/null
(cd .claude/worktrees/test--impl && echo "new file" > feature.txt && git add feature.txt && git commit -q -m "add feature")
RESULT=$(bash "$SCRIPT" "test" 2>&1)
SCRIPT_EXIT=$?
assert_exit_code 0 "$SCRIPT_EXIT" "1: Merge succeeds"
assert_true "1: Feature file exists on main branch" '[ -f "feature.txt" ]'
cleanup_temp_dir

# --- Test 2: No worktrees to merge — exits 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_git_repo "clean"
RESULT=$(bash "$SCRIPT" "nonexistent" 2>&1)
SCRIPT_EXIT=$?
assert_exit_code 0 "$SCRIPT_EXIT" "2: No worktrees exits 0"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
```

---

### Task 32: Implement worktree merge script

**Files:**
- Create: `scripts/merge-worktrees.sh`

**Step 1: Write the script**

```bash
#!/bin/bash
# Merges all teammate worktree branches back to the current branch and cleans up.
# Usage: merge-worktrees.sh <team-name>
# Exit 0 = success (or nothing to merge), Exit 1 = merge conflict (logged to stderr).

set -euo pipefail

TEAM_NAME="${1:-}"

if [ -z "$TEAM_NAME" ]; then
  echo "Usage: merge-worktrees.sh <team-name>" >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repo — skipping merge" >&2
  exit 0
fi

# Find teammate branches for this team
BRANCHES=$(git branch --list "${TEAM_NAME}/*" 2>/dev/null | sed 's/^[ *]*//')

if [ -z "$BRANCHES" ]; then
  echo "No branches found for team ${TEAM_NAME}" >&2
  exit 0
fi

CONFLICT_BRANCHES=""

while IFS= read -r branch; do
  [ -z "$branch" ] && continue
  echo "Merging $branch..."

  # Remove worktree first (if it exists)
  WORKTREE_PATH=$(echo "$branch" | sed "s|/|--|g")
  if [ -d ".claude/worktrees/$WORKTREE_PATH" ]; then
    git worktree remove ".claude/worktrees/$WORKTREE_PATH" --force 2>/dev/null || true
  fi

  if git merge --no-ff "$branch" -m "Merge teammate branch $branch" 2>/dev/null; then
    git branch -d "$branch" 2>/dev/null || true
    echo "  Merged successfully"
  else
    git merge --abort 2>/dev/null || true
    CONFLICT_BRANCHES="$CONFLICT_BRANCHES $branch"
    echo "  CONFLICT — merge aborted" >&2
  fi
done <<< "$BRANCHES"

if [ -n "$CONFLICT_BRANCHES" ]; then
  echo "Merge conflicts on branches:$CONFLICT_BRANCHES" >&2
  echo "Resolve manually or assign to an implementer." >&2
  exit 1
fi

exit 0
```

**Step 2: Make executable, run tests, commit**

```bash
chmod +x scripts/merge-worktrees.sh
git add scripts/merge-worktrees.sh tests/hooks/test-merge-worktrees.sh
git commit -m "feat: add worktree merge script"
```

---

### Task 33: Add worktree isolation to SKILL.md

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 2, Phase 3, Phase 5)

**Step 1: Add isolation field to Phase 2 plan template**

In Phase 2, add to the plan presentation template:

```markdown
Isolation: shared (default) | worktree
  (if worktree) Each implementer gets a git worktree with a dedicated branch. Zero conflict risk.
```

**Step 2: Add Phase 3 worktree setup**

In Phase 3, after step 5 (Spawn teammates), add:

```markdown
5b. **Create worktrees** (if `isolation: worktree`):
    - For each implementer, run `scripts/setup-worktree.sh {team-name} {teammate-name}`
    - Include the worktree path in the implementer's spawn prompt as their working directory
    - If worktree creation fails for any teammate, fall back to shared mode for that teammate and log a warning in `issues.md`
    - File ownership hook (PreToolUse) is redundant in worktree mode but remains active as a safety net
```

**Step 3: Add Phase 5 worktree merge**

In Phase 5, update the Branch Merge step (from v1.6.0) to handle worktrees:

```markdown
4. **Merge branches** (if auto-branching or worktree isolation was used):
   - If worktree isolation: run `scripts/merge-worktrees.sh {team-name}` to merge all teammate branches and clean up worktrees
   - If auto-branching only: for each branch, `git merge --no-ff {team-name}/{teammate-name}`
   - If merge conflicts: log in `issues.md`, assign the relevant implementer to resolve
   - If neither branching nor worktrees were used, skip this step
```

**Step 4: Validate and commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add opt-in worktree isolation to Phase 2/3/5"
```

---

### Task 34: Add nested task decomposition to SKILL.md and worker-roles

**Files:**
- Modify: `skills/agent-team/SKILL.md` (Phase 3)
- Modify: `docs/worker-roles.md` (Implementer section, Subagent Usage section)

**Step 1: Update Implementer role for nested decomposition**

In `docs/worker-roles.md`, update the "Subagent Usage Within Teammates" section:

```markdown
## Subagent Usage Within Teammates

Teammates can spawn subagents (Task tool) for self-contained subtasks that don't need cross-teammate communication.

### Standard Usage
Use subagents to parallelize within your own scope — e.g., writing tests while implementing, or reading multiple files simultaneously. Do NOT use subagents when the subtask needs input from another teammate.

### Nested Task Decomposition (Senior Implementers)
When explicitly authorized by the lead in the spawn prompt, senior implementers may:
- Create sub-tasks using TaskCreate with IDs prefixed by their parent task (e.g., if working on task #3, create sub-tasks described as "#3.1 — [subject]", "#3.2 — [subject]")
- Spawn subagents to work on sub-tasks in parallel
- Report rolled-up results to the lead (the lead sees sub-tasks in TaskList but only interacts at the parent level)

**Limits:**
- One level of nesting max — sub-subagents cannot create further sub-tasks
- Sub-tasks must be within the teammate's owned file scope
- The teammate is responsible for coordinating their sub-agents (the lead does not manage them)
```

**Step 2: Add to SKILL.md Phase 3**

In Phase 3 step 5 spawn guidance, add:

```markdown
   - **Nested decomposition** (optional): For large tasks, tell senior implementers: "You may create sub-tasks and spawn subagents for independent portions of your work. Report rolled-up results to me. One level of nesting max."
```

**Step 3: Commit**

```bash
git add docs/worker-roles.md skills/agent-team/SKILL.md
git commit -m "feat: add nested task decomposition for senior implementers"
```

---

### Task 35: Update README for v2.0.0 features

**Files:**
- Modify: `README.md`

**Step 1: Update Hooks section**

Update the README Hooks section to list all hooks (now 5+).

**Step 2: Update Workspace section**

Add `file-locks.json` and `events.log` to the workspace structure.

**Step 3: Update Plugin Structure**

Add new scripts to the tree.

**Step 4: Commit**

```bash
git add README.md
git commit -m "docs: update README for v2.0.0 features"
```

---

### Task 36: Bump version to 2.0.0, validate, and tag

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `package.json` — version to "2.0.0"
- Modify: `CHANGELOG.md`

**Step 1: Update CHANGELOG.md**

```markdown
## [2.0.0] - 2026-02-27

### Added
- **Git worktree isolation** (opt-in) — `isolation: worktree` in Phase 2 plan gives each implementer a dedicated worktree
- **Nested task decomposition** — senior implementers can create sub-tasks and spawn sub-agents
- Worktree setup and merge scripts (`scripts/setup-worktree.sh`, `scripts/merge-worktrees.sh`)

### Changed
- Major version bump: nested decomposition changes the team coordination model
```

**Step 2: Update version, run full test suite, validate, commit, tag**

```bash
bash tests/run-tests.sh
claude plugin validate .
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json package.json CHANGELOG.md
git commit -m "chore: bump version to 2.0.0"
git tag v2.0.0
```

---

## Summary

| Release | Tasks | New Files | Modified Files |
|---------|-------|-----------|----------------|
| v1.3.0 | 1-9 | `docs/custom-roles.md`, `CHANGELOG.md` | `docs/coordination-patterns.md`, `hooks/hooks.json`, `SKILL.md`, `package.json`, plugin.json, marketplace.json |
| v1.4.0 | 10-14 | — | `docs/worker-roles.md`, `docs/report-format.md`, `SKILL.md`, `scripts/check-teammate-idle.sh`, `tests/lib/test-helpers.sh` |
| v1.5.0 | 15-24 | `scripts/recover-context.sh`, `scripts/check-file-ownership.sh`, `scripts/track-teammate-lifecycle.sh`, 3 test files | `hooks/hooks.json`, `scripts/verify-task-complete.sh`, `SKILL.md` |
| v1.6.0 | 25-28 | — | `docs/worker-roles.md`, `docs/coordination-patterns.md`, `SKILL.md` |
| v2.0.0 | 29-36 | `scripts/setup-worktree.sh`, `scripts/merge-worktrees.sh`, 2 test files | `docs/worker-roles.md`, `SKILL.md`, `README.md` |

**Total: 36 tasks, 8 new files, ~15 modified files.**
