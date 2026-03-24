# Tier 2: Execution Robustness — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 3 new hook scripts and enhance 1 existing script to improve execution robustness — workspace completeness, plan-mode revision limits, pre-shutdown commit enforcement, and integration point file validation.

**Architecture:** 3 new bash scripts registered as hooks in `hooks/hooks.json` (SubagentStart, PreToolUse(SendMessage), PreToolUse(TeamDelete)), plus ~15 lines added to existing `check-integration-point.sh`. Each script follows project conventions: `#!/bin/bash`, jq graceful fallback, exit 0 (allow) / exit 2 (block).

**Tech Stack:** Bash scripts, jq for JSON parsing, git for status checks. All markdown documentation.

**Spec:** `docs/specs/2026-03-24-tier2-execution-robustness-design.md`

---

## Chunk 1: Scripts + Tests

### Task 1: Workspace completeness check

**Files:**
- Create: `scripts/check-workspace-completeness.sh`
- Create: `tests/hooks/test-check-workspace-completeness.sh`
- Modify: `tests/lib/test-helpers.sh` (add `**Archetype**` to default progress.md template)

- [ ] **Step 1: Create the hook script**

Create `scripts/check-workspace-completeness.sh`:

```bash
#!/bin/bash
# Hook: SubagentStart
# Validates workspace has all required tracking files before teammate spawn.
# Exit 0 = allow, Exit 2 = block with feedback.

if ! command -v jq &>/dev/null; then exit 0; fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty')

if [ -z "$CWD" ] || [ -z "$TEAM" ]; then exit 0; fi

# Resolve workspace (with -fix suffix fallback)
WS="$CWD/.agent-team/$TEAM"
if [ ! -d "$WS" ]; then
  BASE="${TEAM%-fix}"
  if [ "$BASE" != "$TEAM" ] && [ -d "$CWD/.agent-team/$BASE" ]; then
    WS="$CWD/.agent-team/$BASE"
  else
    exit 0  # No workspace yet — team may be initializing
  fi
fi

MISSING=""

# Check 1: progress.md exists with Archetype
if [ ! -f "$WS/progress.md" ]; then
  MISSING="$MISSING\n  - progress.md (missing)"
elif ! grep -q '\*\*Archetype\*\*' "$WS/progress.md"; then
  MISSING="$MISSING\n  - progress.md missing **Archetype** field"
fi

# Check 2: tasks.md exists and non-empty (beyond header)
if [ ! -f "$WS/tasks.md" ]; then
  MISSING="$MISSING\n  - tasks.md (missing)"
elif [ "$(wc -l < "$WS/tasks.md" | tr -d ' ')" -lt 2 ]; then
  MISSING="$MISSING\n  - tasks.md (empty — no tasks defined)"
fi

# Check 3: issues.md exists
if [ ! -f "$WS/issues.md" ]; then
  MISSING="$MISSING\n  - issues.md (missing)"
fi

# Check 4: task-graph.json exists (schema validated by validate-task-graph.sh)
if [ ! -f "$WS/task-graph.json" ]; then
  MISSING="$MISSING\n  - task-graph.json (missing)"
fi

# Check 5: Pipeline status valid if present
if [ -f "$WS/progress.md" ]; then
  PIPELINE_STATUS=$(sed -n 's/.*\*\*Pipeline status\*\*: \([^ ]*\).*/\1/p' "$WS/progress.md" 2>/dev/null)
  if [ -n "$PIPELINE_STATUS" ]; then
    case "$PIPELINE_STATUS" in
      approved|executed|audited) ;;  # valid
      *) MISSING="$MISSING\n  - Pipeline status has invalid value: '$PIPELINE_STATUS' (expected: approved, executed, or audited)" ;;
    esac
  fi
fi

if [ -n "$MISSING" ]; then
  echo "BLOCKED: Workspace incomplete at $WS. Missing:" >&2
  echo -e "$MISSING" >&2
  echo "Fix the workspace before spawning teammates." >&2
  exit 2
fi

exit 0
```

```bash
chmod +x scripts/check-workspace-completeness.sh
```

- [ ] **Step 1.5: Update test-helpers.sh — add Archetype to default progress.md**

In `tests/lib/test-helpers.sh`, find the `setup_mock_workspace` function's `progress.md` template (lines 54-59). Add `**Archetype**: implementation` to the default template so workspace completeness tests pass:

```bash
  cat > "$WORKSPACE_DIR/progress.md" <<'EOF'
# Team: test

**Task**: test task
**Status**: active
**Archetype**: implementation
EOF
```

Verify no existing tests break: `bash tests/run-tests.sh`

- [ ] **Step 2: Create the test file**

Create `tests/hooks/test-check-workspace-completeness.sh` following the pattern from `test-validate-task-graph.sh`.

**IMPORTANT**: For "complete workspace" tests, call BOTH `setup_mock_workspace "team"` AND `setup_mock_task_graph "team"` since the hook checks all 4 files (progress.md, tasks.md, issues.md, task-graph.json). The helper creates 3 files; `setup_mock_task_graph` adds the 4th.

Test cases (~11 assertions):
1. Complete workspace (mock workspace + mock task graph) → exit 0
2. Missing progress.md (delete it after setup) → exit 2, stderr mentions "progress.md"
3. Missing Archetype field (overwrite progress.md without it) → exit 2, stderr mentions "Archetype"
4. Missing tasks.md → exit 2, stderr mentions "tasks.md"
5. Empty tasks.md (overwrite with single header line) → exit 2, stderr mentions "empty"
6. Missing issues.md → exit 2, stderr mentions "issues.md"
7. Missing task-graph.json (skip setup_mock_task_graph) → exit 2, stderr mentions "task-graph.json"
8. Invalid Pipeline status (add `**Pipeline status**: bogus` to progress.md) → exit 2, stderr mentions "invalid"
9. No workspace directory → exit 0
10. Valid Pipeline status "approved" (add field to progress.md) → exit 0
11. Team with -fix suffix → exit 0 (uses base team workspace)

Each test: `setup_temp_dir`, `setup_mock_workspace`, `setup_mock_task_graph` where needed, modify as needed, `run_hook`, `assert_exit_code`, `assert_stderr_contains` where applicable, `cleanup_temp_dir`.

- [ ] **Step 3: Run tests**

```bash
chmod +x tests/hooks/test-check-workspace-completeness.sh
bash tests/hooks/test-check-workspace-completeness.sh
```

Fix any failures.

- [ ] **Step 4: Commit**

```bash
git add scripts/check-workspace-completeness.sh tests/hooks/test-check-workspace-completeness.sh
git commit -m "feat: add workspace completeness check hook (SubagentStart)"
```

---

### Task 2: Plan-mode revision limit

**Files:**
- Create: `scripts/enforce-plan-revision-limit.sh`
- Create: `tests/hooks/test-enforce-plan-revision-limit.sh`

- [ ] **Step 1: Create the hook script**

Create `scripts/enforce-plan-revision-limit.sh`:

```bash
#!/bin/bash
# Hook: PreToolUse(SendMessage)
# Enforces max 2 plan-mode revision rounds per teammate.
# Exit 0 = allow, Exit 2 = block.

if ! command -v jq &>/dev/null; then exit 0; fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty')
MESSAGE=$(echo "$INPUT" | jq -r '.tool_input.message // empty')
RECIPIENT=$(echo "$INPUT" | jq -r '.tool_input.to // empty')

# Fast path: not a PLAN_REVISION message
if ! echo "$MESSAGE" | grep -q '^PLAN_REVISION'; then
  exit 0
fi

if [ -z "$CWD" ] || [ -z "$TEAM" ]; then exit 0; fi

# Find workspace
WS="$CWD/.agent-team/$TEAM"
if [ ! -d "$WS" ]; then
  BASE="${TEAM%-fix}"
  if [ "$BASE" != "$TEAM" ] && [ -d "$CWD/.agent-team/$BASE" ]; then
    WS="$CWD/.agent-team/$BASE"
  else
    exit 0
  fi
fi

PROGRESS="$WS/progress.md"
if [ ! -f "$PROGRESS" ]; then exit 0; fi

# Check for Plan Proposals table
if ! grep -q '## Plan Proposals' "$PROGRESS"; then exit 0; fi

# Count revisions for this recipient in the Plan Proposals table
# Table format: | Teammate | Task | Proposal | Status | Revisions |
# grep for rows matching the recipient, extract Revisions column
REVISION_COUNT=$(awk -v teammate="$RECIPIENT" '
  /## Plan Proposals/,/^## / {
    if ($0 ~ "\\| *" teammate " *\\|") {
      # Extract last column (Revisions)
      n = split($0, cols, "|")
      gsub(/^[ \t]+|[ \t]+$/, "", cols[n-1])
      if (cols[n-1] ~ /^[0-9]+$/) {
        total += cols[n-1]
      }
    }
  }
  END { print total+0 }
' "$PROGRESS")

if [ "$REVISION_COUNT" -ge 2 ]; then
  echo "BLOCKED: Plan-mode revision limit reached (2/2) for $RECIPIENT." >&2
  echo "Accept the current proposal or reassign the task." >&2
  exit 2
fi

exit 0
```

```bash
chmod +x scripts/enforce-plan-revision-limit.sh
```

- [ ] **Step 2: Create the test file**

Create `tests/hooks/test-enforce-plan-revision-limit.sh`:

Test cases (~8 assertions):
1. Non-PLAN_REVISION message → exit 0
2. First revision (count=0) → exit 0
3. Second revision (count=1) → exit 0
4. Third revision (count=2) → exit 2, stderr mentions "revision limit"
5. No workspace → exit 0
6. No Plan Proposals table → exit 0
7. Teammate not in table → exit 0
8. Malformed table → exit 0

For tests needing Plan Proposals, write a progress.md with the table and specific revision counts.

- [ ] **Step 3: Run tests**

```bash
chmod +x tests/hooks/test-enforce-plan-revision-limit.sh
bash tests/hooks/test-enforce-plan-revision-limit.sh
```

- [ ] **Step 4: Commit**

```bash
git add scripts/enforce-plan-revision-limit.sh tests/hooks/test-enforce-plan-revision-limit.sh
git commit -m "feat: add plan-mode revision limit hook (PreToolUse(SendMessage))"
```

---

### Task 3: Pre-shutdown commit enforcement

**Files:**
- Create: `scripts/enforce-pre-shutdown-commit.sh`
- Create: `tests/hooks/test-enforce-pre-shutdown-commit.sh`

- [ ] **Step 1: Create the hook script**

Create `scripts/enforce-pre-shutdown-commit.sh`:

```bash
#!/bin/bash
# Hook: PreToolUse(TeamDelete)
# Blocks TeamDelete if owned files have uncommitted changes.
# Exit 0 = allow, Exit 2 = block.

if ! command -v jq &>/dev/null; then exit 0; fi
if ! command -v git &>/dev/null; then exit 0; fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty')

if [ -z "$CWD" ] || [ -z "$TEAM" ]; then exit 0; fi

# Find workspace
WS="$CWD/.agent-team/$TEAM"
if [ ! -d "$WS" ]; then
  BASE="${TEAM%-fix}"
  if [ "$BASE" != "$TEAM" ] && [ -d "$CWD/.agent-team/$BASE" ]; then
    WS="$CWD/.agent-team/$BASE"
  else
    exit 0
  fi
fi

LOCKS="$WS/file-locks.json"
if [ ! -f "$LOCKS" ]; then exit 0; fi

# Parse file-locks.json: { "teammate": ["file1", "file2"], ... }
DIRTY_REPORT=""

for OWNER in $(jq -r 'keys[]' "$LOCKS" 2>/dev/null); do
  DIRTY_FILES=""
  for FILE in $(jq -r --arg o "$OWNER" '.[$o][]' "$LOCKS" 2>/dev/null); do
    FULL_PATH="$CWD/$FILE"
    if [ -f "$FULL_PATH" ]; then
      STATUS=$(cd "$CWD" && git status --porcelain -- "$FILE" 2>/dev/null)
      if [ -n "$STATUS" ]; then
        DIRTY_FILES="$DIRTY_FILES $FILE"
      fi
    fi
  done
  if [ -n "$DIRTY_FILES" ]; then
    DIRTY_REPORT="$DIRTY_REPORT\n  $OWNER:$DIRTY_FILES"
  fi
done

if [ -n "$DIRTY_REPORT" ]; then
  echo "BLOCKED: Uncommitted changes detected before shutdown." >&2
  echo -e "Dirty files by owner:$DIRTY_REPORT" >&2
  echo "Commit or stash all owned files before calling TeamDelete." >&2
  exit 2
fi

exit 0
```

```bash
chmod +x scripts/enforce-pre-shutdown-commit.sh
```

- [ ] **Step 2: Create the test file**

Create `tests/hooks/test-enforce-pre-shutdown-commit.sh`:

Test cases (~6 assertions):
1. All files clean → exit 0
2. Dirty owned file → exit 2, stderr mentions "Uncommitted"
3. No git → exit 0
4. No file-locks.json → exit 0
5. No workspace → exit 0
6. Empty file-locks `{}` → exit 0

Tests 1-2 need `setup_mock_git_repo` to create a git repo with committed and dirty files.

- [ ] **Step 3: Run tests**

```bash
chmod +x tests/hooks/test-enforce-pre-shutdown-commit.sh
bash tests/hooks/test-enforce-pre-shutdown-commit.sh
```

- [ ] **Step 4: Commit**

```bash
git add scripts/enforce-pre-shutdown-commit.sh tests/hooks/test-enforce-pre-shutdown-commit.sh
git commit -m "feat: add pre-shutdown commit enforcement hook (PreToolUse(TeamDelete))"
```

---

### Task 4: Enhance integration point file validation

**Files:**
- Modify: `scripts/check-integration-point.sh`
- Modify: `tests/hooks/test-check-integration-point.sh`

- [ ] **Step 1: Read existing script**

```bash
cat scripts/check-integration-point.sh
```

Identify the convergence detection block (where all upstream deps complete). The new file check goes after this block.

- [ ] **Step 2: Add output file existence check**

After the existing output file listing block (ends ~line 93, inside the `for conv_id` loop), add ~15 lines using the existing variables (`GRAPH`, `DEPS`, `dep_id`, `conv_id`, `CWD`):

```bash
    # Verify upstream output files exist on disk
    MISSING_OUTPUT=""
    for dep_id in $DEPS; do
      OUTPUT_FILES=$(echo "$GRAPH" | jq -r --arg id "$dep_id" '.nodes[$id].output_files // [] | .[]' 2>/dev/null)
      for ofile in $OUTPUT_FILES; do
        if [ ! -f "$CWD/$ofile" ]; then
          MISSING_OUTPUT="$MISSING_OUTPUT $ofile (from $dep_id)"
        fi
      done
    done
    if [ -n "$MISSING_OUTPUT" ]; then
      echo "  Warning: upstream output files missing:$MISSING_OUTPUT. Verify before starting $conv_id." >&2
    fi
```

Insert BEFORE the closing `done` of the `for conv_id` loop (~line 94).

- [ ] **Step 3: Add test case to existing test**

In `tests/hooks/test-check-integration-point.sh`, add 2 test cases:
1. Convergence with all output files present → no "missing" in stderr
2. Convergence with missing output file → stderr contains "missing"

- [ ] **Step 4: Run tests**

```bash
bash tests/hooks/test-check-integration-point.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/check-integration-point.sh tests/hooks/test-check-integration-point.sh
git commit -m "feat: add output file validation to integration point hook"
```

---

## Chunk 2: Hook Registration + Meta

### Task 5: Register hooks in hooks.json

**Files:**
- Modify: `hooks/hooks.json`

- [ ] **Step 1: Add workspace completeness to SubagentStart**

Insert at position 0 of the existing `SubagentStart` array (before `validate-task-graph.sh`). The resulting array will have 3 entries: `[check-workspace-completeness, validate-task-graph, track-teammate-lifecycle]`.

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/check-workspace-completeness.sh",
      "timeout": 10
    }
  ]
}
```

- [ ] **Step 2: Add plan revision limit to PreToolUse**

Append to the existing `PreToolUse` array (which currently has 1 entry for `"matcher": "Write|Edit"`). The resulting array will have 3 entries: `[Write|Edit, SendMessage, TeamDelete]`.

```json
{
  "matcher": "SendMessage",
  "hooks": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/enforce-plan-revision-limit.sh",
      "timeout": 10
    }
  ]
}
```

- [ ] **Step 3: Add pre-shutdown commit to PreToolUse**

Append to the same `PreToolUse` array after the SendMessage entry:

```json
{
  "matcher": "TeamDelete",
  "hooks": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/enforce-pre-shutdown-commit.sh",
      "timeout": 15
    }
  ]
}
```

- [ ] **Step 4: Validate**

```bash
jq '.' hooks/hooks.json > /dev/null && echo "Valid JSON"
bash tests/run-tests.sh
```

- [ ] **Step 5: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat: register 3 new hooks (workspace, revision limit, commit enforcement)"
```

---

### Task 6: Update meta docs and version

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Update CLAUDE.md**

- Hook count: 10 → 13
- Script count: 13 → 16
- Verify Hooks section: add 3 new entries (ValidateWorkspace, PlanRevisionLimit, PreShutdownCommit)

- [ ] **Step 2: Update README.md**

- Hook count: "Ten hooks" → "Thirteen hooks"
- Add 3 new hook subsections:
  - `### WorkspaceCompleteness (SubagentStart)` — validates all tracking files before spawn
  - `### PlanRevisionLimit (PreToolUse(SendMessage))` — enforces max 2 revision rounds
  - `### PreShutdownCommit (PreToolUse(TeamDelete))` — blocks shutdown with uncommitted changes
- Plugin Structure tree: add 3 new scripts
- Test runner count: 13 → 16

- [ ] **Step 3: Version bump**

Both `plugin.json` and `marketplace.json`: `3.1.0` → `3.2.0`

- [ ] **Step 4: CHANGELOG**

Add before `[3.1.0]`:

```markdown
## [3.2.0] - 2026-03-24

### Added
- **Workspace completeness hook** (SubagentStart) — validates all 4 tracking files and Archetype/Pipeline status fields before teammate spawn
- **Plan-mode revision limit hook** (PreToolUse(SendMessage)) — enforces max 2 revision rounds per teammate, blocks third PLAN_REVISION
- **Pre-shutdown commit hook** (PreToolUse(TeamDelete)) — blocks TeamDelete if any owned files have uncommitted changes
- **Integration point file validation** — enhanced existing hook to verify upstream task output files exist at convergence points
```

- [ ] **Step 5: Run full tests**

```bash
bash tests/run-tests.sh
```

All must pass.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md README.md CHANGELOG.md .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore: bump version to 3.2.0 with Tier 2 execution robustness hooks"
```
