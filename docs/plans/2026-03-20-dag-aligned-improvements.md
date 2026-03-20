# DAG-Aligned Improvements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add critical path identification, task-level resume, and early integration checkpoints to the agent-team-plugin (v2.6.0), all powered by a shared `task-graph.json` DAG file.

**Architecture:** Three new bash hook scripts read from a centralized `task-graph.json` workspace file that the lead maintains. Each script attaches to an existing hook event (TaskCompleted or SessionStart) as a separate entry. Documentation updates propagate the new concepts (critical path, convergence points, resume) through all 5 phases.

**Tech Stack:** Bash scripts, jq for JSON parsing, git for staleness checks. All markdown documentation.

**Spec:** `docs/specs/2026-03-20-dag-aligned-improvements-design.md`

---

## Chunk 1: Scripts + Tests

### Task 1: Add test helper for mock task-graph.json

**Files:**
- Modify: `tests/lib/test-helpers.sh`

- [ ] **Step 1: Add `setup_mock_task_graph` helper**

Add after `setup_mock_workspace` function in `tests/lib/test-helpers.sh`:

```bash
# --- Mock task-graph.json ---
# Creates a task-graph.json inside an existing mock workspace.
# Usage: setup_mock_task_graph "my-team" '{...json...}'
# If no JSON provided, creates a default 4-task graph (2 parallel + 1 convergence + 1 review)
setup_mock_task_graph() {
  local team_name="$1"
  local custom_json="${2:-}"
  local graph_file="$TEST_TEMP_DIR/.agent-team/$team_name/task-graph.json"

  if [ -n "$custom_json" ]; then
    echo "$custom_json" > "$graph_file"
    return
  fi

  cat > "$graph_file" <<'GRAPH'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T10:00:00Z",
  "nodes": {
    "#1": {
      "subject": "Implement auth",
      "owner": "impl-1",
      "status": "pending",
      "depends_on": [],
      "completed_at": null,
      "output_files": ["src/auth.ts"],
      "critical_path": true,
      "convergence_point": false
    },
    "#2": {
      "subject": "Implement session",
      "owner": "impl-2",
      "status": "pending",
      "depends_on": [],
      "completed_at": null,
      "output_files": ["src/session.ts"],
      "critical_path": false,
      "convergence_point": false
    },
    "#3": {
      "subject": "Integrate middleware",
      "owner": "impl-1",
      "status": "pending",
      "depends_on": ["#1", "#2"],
      "completed_at": null,
      "output_files": ["src/middleware.ts"],
      "critical_path": true,
      "convergence_point": true
    },
    "#4": {
      "subject": "Review all",
      "owner": "reviewer",
      "status": "pending",
      "depends_on": ["#3"],
      "completed_at": null,
      "output_files": [],
      "critical_path": true,
      "convergence_point": false
    }
  },
  "critical_path": ["#1", "#3", "#4"],
  "critical_path_length": 3
}
GRAPH
}

# --- Run hook capturing stdout separately ---
# Like run_hook but also captures stdout (needed for detect-resume.sh which outputs to stdout).
# Usage: run_hook_full "$script" "$json_input"
# Sets: HOOK_EXIT, HOOK_STDOUT, HOOK_STDERR
HOOK_STDOUT=""

run_hook_full() {
  local script="$1"
  local input="$2"
  local stdout_file
  stdout_file=$(mktemp "${TMPDIR:-/tmp}/hook-stdout.XXXXXX")
  HOOK_STDERR=$(echo "$input" | bash "$script" 2>&1 1>"$stdout_file")
  HOOK_EXIT=$?
  HOOK_STDOUT=$(cat "$stdout_file")
  rm -f "$stdout_file"
}

assert_stdout_contains() {
  local pattern="$1"
  local stdout_output="$2"
  local test_name="$3"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if echo "$stdout_output" | grep -qi "$pattern"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "  ${RED}FAIL${RESET} %s (stdout missing pattern '%s')\n" "$test_name" "$pattern"
    printf "        stdout was: %s\n" "$stdout_output"
  fi
}
```

- [ ] **Step 2: Commit**

```bash
git add tests/lib/test-helpers.sh
git commit -m "test: add task-graph.json mock helper and stdout capture for DAG hooks"
```

### Task 2: Write `compute-critical-path.sh` + tests

**Files:**
- Create: `scripts/compute-critical-path.sh`
- Create: `tests/hooks/test-compute-critical-path.sh`

- [ ] **Step 1: Write the test file**

Create `tests/hooks/test-compute-critical-path.sh`:

```bash
#!/bin/bash
# Tests for scripts/compute-critical-path.sh (TaskCompleted hook — critical path)

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/compute-critical-path.sh"

echo "Critical path hook tests"
echo "========================"

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed\n"
  exit 0
fi

# --- Test 1: No task-graph.json exits 0 silently ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "1: No task-graph.json exits 0 silently"
cleanup_temp_dir

# --- Test 2: Empty input exits 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{}'
assert_exit_code 0 "$HOOK_EXIT" "2: Empty input exits 0"
cleanup_temp_dir

# --- Test 3: Critical path task completes — shows remaining path ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
# Mark #1 as completed in the graph
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T10:30:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:30:00Z","output_files":["src/auth.ts"],"critical_path":true,"convergence_point":false},
    "#2": {"subject":"Session","owner":"impl-2","status":"pending","depends_on":[],"completed_at":null,"output_files":["src/session.ts"],"critical_path":false,"convergence_point":false},
    "#3": {"subject":"Middleware","owner":"impl-1","status":"pending","depends_on":["#1","#2"],"completed_at":null,"output_files":["src/mw.ts"],"critical_path":true,"convergence_point":true},
    "#4": {"subject":"Review","owner":"reviewer","status":"pending","depends_on":["#3"],"completed_at":null,"output_files":[],"critical_path":true,"convergence_point":false}
  },
  "critical_path": ["#1","#3","#4"],
  "critical_path_length": 3
}
JSON
)"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "3: Critical path task complete exits 0"
assert_stderr_contains "Remaining critical path" "$HOOK_STDERR" "3: Shows remaining critical path"
cleanup_temp_dir

# --- Test 4: Non-critical task completes — shows unchanged path ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T10:30:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"pending","depends_on":[],"completed_at":null,"output_files":["src/auth.ts"],"critical_path":true,"convergence_point":false},
    "#2": {"subject":"Session","owner":"impl-2","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:30:00Z","output_files":["src/session.ts"],"critical_path":false,"convergence_point":false},
    "#3": {"subject":"Middleware","owner":"impl-1","status":"pending","depends_on":["#1","#2"],"completed_at":null,"output_files":["src/mw.ts"],"critical_path":true,"convergence_point":true}
  },
  "critical_path": ["#1","#3"],
  "critical_path_length": 2
}
JSON
)"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "4: Non-critical task complete exits 0"
assert_stderr_contains "not on critical path" "$HOOK_STDERR" "4: Shows not on critical path"
cleanup_temp_dir

# --- Test 5: All tasks complete — no critical path ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T11:00:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:30:00Z","output_files":["src/auth.ts"],"critical_path":false,"convergence_point":false},
    "#2": {"subject":"Session","owner":"impl-2","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:45:00Z","output_files":["src/session.ts"],"critical_path":false,"convergence_point":false}
  },
  "critical_path": [],
  "critical_path_length": 0
}
JSON
)"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "5: All complete exits 0"
assert_stderr_contains "all remaining tasks can run in parallel\|No critical path" "$HOOK_STDERR" "5: Shows no critical path"
cleanup_temp_dir

# --- Test 6: Malformed JSON — warns but exits 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
echo "NOT VALID JSON" > "$TEST_TEMP_DIR/.agent-team/test/task-graph.json"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "6: Malformed JSON exits 0"
assert_stderr_contains "warning\|parse" "$HOOK_STDERR" "6: Warns about parse failure"
cleanup_temp_dir

# --- Test 7: Remediation team -fix suffix fallback ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-fix"}'
assert_exit_code 0 "$HOOK_EXIT" "7: -fix suffix falls back to base workspace"
cleanup_temp_dir

# --- Test 8: Blocked critical task warning ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T10:30:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:30:00Z","output_files":["src/auth.ts"],"critical_path":true,"convergence_point":false},
    "#2": {"subject":"Session","owner":"impl-2","status":"pending","depends_on":[],"completed_at":null,"output_files":["src/session.ts"],"critical_path":false,"convergence_point":false},
    "#3": {"subject":"Middleware","owner":"impl-1","status":"blocked","depends_on":["#1","#2"],"completed_at":null,"output_files":["src/mw.ts"],"critical_path":true,"convergence_point":true}
  },
  "critical_path": ["#1","#3"],
  "critical_path_length": 2
}
JSON
)"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "8: Blocked critical task exits 0"
assert_stderr_contains "blocked" "$HOOK_STDERR" "8: Warns about blocked critical task"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
```

- [ ] **Step 2: Run tests — verify all fail (script doesn't exist yet)**

```bash
bash tests/hooks/test-compute-critical-path.sh
```

Expected: failures (script not found)

- [ ] **Step 3: Write `compute-critical-path.sh`**

Create `scripts/compute-critical-path.sh`:

```bash
#!/bin/bash
# Hook: TaskCompleted
# Recomputes and displays the critical path from task-graph.json.
# Informational only — always exits 0.

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty')

# Need both cwd and team_name to locate task-graph.json
if [ -z "$CWD" ] || [ -z "$TEAM_NAME" ]; then
  exit 0
fi

# Resolve workspace path (with -fix suffix fallback for remediation teams)
GRAPH_FILE="$CWD/.agent-team/$TEAM_NAME/task-graph.json"
if [ ! -f "$GRAPH_FILE" ]; then
  BASE_NAME="${TEAM_NAME%-fix}"
  if [ "$BASE_NAME" != "$TEAM_NAME" ] && [ -f "$CWD/.agent-team/$BASE_NAME/task-graph.json" ]; then
    GRAPH_FILE="$CWD/.agent-team/$BASE_NAME/task-graph.json"
  else
    exit 0
  fi
fi

# Parse JSON — warn if malformed
GRAPH=$(jq '.' "$GRAPH_FILE" 2>/dev/null)
if [ -z "$GRAPH" ]; then
  echo "Warning: task-graph.json exists but failed to parse. Critical path hooks disabled until JSON is fixed." >&2
  exit 0
fi

# Count remaining (non-completed) nodes
REMAINING=$(echo "$GRAPH" | jq '[.nodes | to_entries[] | select(.value.status != "completed")] | length')

if [ "$REMAINING" -eq 0 ]; then
  echo "No critical path — all remaining tasks can run in parallel." >&2
  exit 0
fi

# Find which nodes just completed (status=completed) and were on critical path
# Build the remaining dependency chains to find the longest path
# Use jq to compute: for each remaining node, trace depends_on depth

# Get all remaining node IDs
REMAINING_IDS=$(echo "$GRAPH" | jq -r '[.nodes | to_entries[] | select(.value.status != "completed") | .key] | .[]')

# DFS longest path computation via jq
# For each remaining node, compute depth = 1 + max(depth of remaining dependencies)
# Cycle guard: track visited nodes
CRITICAL_PATH=$(echo "$GRAPH" | jq -r '
  def depth(id; visited):
    if (visited | index(id)) then 0  # cycle guard
    elif (.nodes[id].status == "completed") then 0
    else
      .nodes[id].depends_on as $deps |
      ([$deps[] | select(. as $d | .nodes[$d].status != "completed") | depth(.; visited + [id])] | max // 0) + 1
    end;

  [.nodes | to_entries[] | select(.value.status != "completed") |
    {id: .key, depth: depth(.key; [])}
  ] | sort_by(-.depth, .id) |
  if length == 0 then empty
  else
    .[0] as $root |
    # Trace the path from the deepest node forward through its remaining deps
    def trace_path(id):
      if (.nodes[id].status == "completed") then []
      else
        .nodes[id].depends_on as $deps |
        [$deps[] | select(. as $d | .nodes[$d].status != "completed")] as $remaining_deps |
        if ($remaining_deps | length) == 0 then [id]
        else
          ([$remaining_deps[] | {id: ., depth: depth(.; [])}] | sort_by(-.depth, .id) | .[0].id) as $next |
          trace_path($next) + [id]
        end
      end;
    trace_path($root.id) | join(" → ")
  end
' 2>/dev/null)

# Get the previously recorded critical path
OLD_CP=$(echo "$GRAPH" | jq -r '.critical_path | join(" → ")')
CP_LENGTH=$(echo "$CRITICAL_PATH" | tr '→' '\n' | sed 's/ //g' | grep -c '.')

# Check if any completed node was on the old critical path
WAS_ON_CP=false
COMPLETED_NODES=$(echo "$GRAPH" | jq -r '[.nodes | to_entries[] | select(.value.status == "completed") | .key] | .[]')
OLD_CP_NODES=$(echo "$GRAPH" | jq -r '.critical_path[]')
for node in $COMPLETED_NODES; do
  if echo "$OLD_CP_NODES" | grep -q "^${node}$"; then
    WAS_ON_CP=true
    break
  fi
done

# Find next critical task details
NEXT_CRITICAL=$(echo "$CRITICAL_PATH" | cut -d'→' -f1 | sed 's/ //g')
if [ -n "$NEXT_CRITICAL" ]; then
  NEXT_SUBJECT=$(echo "$GRAPH" | jq -r --arg id "$NEXT_CRITICAL" '.nodes[$id].subject // "unknown"')
  NEXT_OWNER=$(echo "$GRAPH" | jq -r --arg id "$NEXT_CRITICAL" '.nodes[$id].owner // "unassigned"')
  NEXT_STATUS=$(echo "$GRAPH" | jq -r --arg id "$NEXT_CRITICAL" '.nodes[$id].status // "unknown"')
fi

if [ "$WAS_ON_CP" = true ]; then
  echo "Critical path update: completed task was on critical path." >&2
  echo "Remaining critical path: $CRITICAL_PATH (length: $CP_LENGTH)" >&2
  if [ -n "$NEXT_CRITICAL" ]; then
    echo "Next critical task: $NEXT_CRITICAL $NEXT_SUBJECT (owner: $NEXT_OWNER, status: $NEXT_STATUS)" >&2
    if [ "$NEXT_STATUS" = "blocked" ]; then
      BLOCKED_BY=$(echo "$GRAPH" | jq -r --arg id "$NEXT_CRITICAL" '[.nodes[$id].depends_on[] | select(. as $d | .nodes[$d].status != "completed")] | join(", ")' 2>/dev/null)
      echo "⚠ Critical task $NEXT_CRITICAL is blocked — resolve blocker(s) ${BLOCKED_BY:-unknown} to maintain throughput." >&2
    fi
  fi
else
  echo "Task completed (not on critical path). Critical path unchanged: $OLD_CP (length: $(echo "$GRAPH" | jq '.critical_path_length'))" >&2
fi

exit 0
```

- [ ] **Step 4: Make executable**

```bash
chmod +x scripts/compute-critical-path.sh
```

- [ ] **Step 5: Run tests — verify they pass**

```bash
bash tests/hooks/test-compute-critical-path.sh
```

Expected: all 8 tests pass

- [ ] **Step 6: Commit**

```bash
git add scripts/compute-critical-path.sh tests/hooks/test-compute-critical-path.sh
git commit -m "feat: add compute-critical-path.sh hook with tests"
```

### Task 3: Write `detect-resume.sh` + tests

**Files:**
- Create: `scripts/detect-resume.sh`
- Create: `tests/hooks/test-detect-resume.sh`

- [ ] **Step 1: Write the test file**

Create `tests/hooks/test-detect-resume.sh`:

```bash
#!/bin/bash
# Tests for scripts/detect-resume.sh (SessionStart hook — resume detection)

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/detect-resume.sh"

echo "Resume detection hook tests"
echo "============================"

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed\n"
  exit 0
fi

# --- Test 1: No .agent-team/ directories — silent exit 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook_full "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'"}'
assert_exit_code 0 "$HOOK_EXIT" "1: No workspaces exits 0"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if [ -z "$HOOK_STDOUT" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "  ${GREEN}PASS${RESET} 1: Silent when no workspaces\n"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "  ${RED}FAIL${RESET} 1: Expected silent, got stdout: %s\n" "$HOOK_STDOUT"
fi
cleanup_temp_dir

# --- Test 2: All completed workspace — silent ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T11:00:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:30:00Z","output_files":["src/auth.ts"],"critical_path":false,"convergence_point":false}
  },
  "critical_path": [],
  "critical_path_length": 0
}
JSON
)"
run_hook_full "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'"}'
assert_exit_code 0 "$HOOK_EXIT" "2: All completed exits 0"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if [ -z "$HOOK_STDOUT" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "  ${GREEN}PASS${RESET} 2: Silent when all complete\n"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "  ${RED}FAIL${RESET} 2: Expected silent, got stdout: %s\n" "$HOOK_STDOUT"
fi
cleanup_temp_dir

# --- Test 3: Incomplete workspace — shows resume context ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test"
run_hook_full "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'"}'
assert_exit_code 0 "$HOOK_EXIT" "3: Incomplete workspace exits 0"
assert_stdout_contains "Resumable workspace" "$HOOK_STDOUT" "3: Shows resumable workspace"
cleanup_temp_dir

# --- Test 4: Staleness detection — file modified after completion ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_git_repo "clean"
# Create the output file and commit it
echo "original" > src/auth.ts 2>/dev/null || (mkdir -p src && echo "original" > src/auth.ts)
(cd "$TEST_TEMP_DIR" && git add src/auth.ts && git commit -q -m "add auth")
# Create graph with #1 completed in the past
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T10:30:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"completed","depends_on":[],"completed_at":"2026-01-01T00:00:00Z","output_files":["src/auth.ts"],"critical_path":true,"convergence_point":false},
    "#2": {"subject":"Session","owner":"impl-2","status":"pending","depends_on":[],"completed_at":null,"output_files":["src/session.ts"],"critical_path":false,"convergence_point":false}
  },
  "critical_path": ["#1"],
  "critical_path_length": 1
}
JSON
)"
# Modify the file AFTER the completed_at timestamp
sleep 1
echo "modified" > "$TEST_TEMP_DIR/src/auth.ts"
(cd "$TEST_TEMP_DIR" && git add src/auth.ts && git commit -q -m "modify auth")
run_hook_full "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'"}'
assert_exit_code 0 "$HOOK_EXIT" "4: Stale detection exits 0"
assert_stdout_contains "stale" "$HOOK_STDOUT" "4: Detects stale output file"
cleanup_temp_dir

# --- Test 5: Empty cwd falls back to current dir ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test"
run_hook_full "$HOOK" '{"cwd":""}'
assert_exit_code 0 "$HOOK_EXIT" "5: Empty cwd exits 0"
cleanup_temp_dir

# --- Test 6: Empty input exits 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook_full "$HOOK" '{}'
assert_exit_code 0 "$HOOK_EXIT" "6: Empty input exits 0"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
bash tests/hooks/test-detect-resume.sh
```

Expected: failures (script not found)

- [ ] **Step 3: Write `detect-resume.sh`**

Create `scripts/detect-resume.sh`:

```bash
#!/bin/bash
# Hook: SessionStart (no matcher — fires on all session starts)
# Detects existing workspaces with incomplete tasks and validates staleness.
# Output goes to stdout (injected into conversation context, matching recover-context.sh).
# Always exits 0 (informational only).

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
CWD="${CWD:-.}"

# Scan for task-graph.json files
GRAPHS=()
for graph_file in "$CWD"/.agent-team/*/task-graph.json; do
  [ -f "$graph_file" ] || continue
  GRAPHS+=("$graph_file")
done

if [ ${#GRAPHS[@]} -eq 0 ]; then
  exit 0
fi

# Sort by updated timestamp (most recent first)
SORTED_GRAPHS=()
while IFS= read -r line; do
  SORTED_GRAPHS+=("$line")
done < <(
  for g in "${GRAPHS[@]}"; do
    ts=$(jq -r '.updated // .created // "1970-01-01"' "$g" 2>/dev/null)
    echo "$ts|$g"
  done | sort -r | cut -d'|' -f2
)

HAS_OUTPUT=false

for graph_file in "${SORTED_GRAPHS[@]}"; do
  GRAPH=$(jq '.' "$graph_file" 2>/dev/null)
  [ -z "$GRAPH" ] && continue

  TEAM=$(echo "$GRAPH" | jq -r '.team // "unknown"')
  WORKSPACE_DIR=$(dirname "$graph_file")

  # Count total and completed
  TOTAL=$(echo "$GRAPH" | jq '[.nodes | to_entries[]] | length')
  COMPLETED=$(echo "$GRAPH" | jq '[.nodes | to_entries[] | select(.value.status == "completed")] | length')
  REMAINING=$((TOTAL - COMPLETED))

  # Skip fully completed workspaces
  if [ "$REMAINING" -eq 0 ]; then
    continue
  fi

  # Validate completed tasks for staleness
  VALID_LIST=""
  STALE_LIST=""
  REMAINING_LIST=""

  while IFS= read -r entry; do
    ID=$(echo "$entry" | jq -r '.key')
    STATUS=$(echo "$entry" | jq -r '.value.status')
    SUBJECT=$(echo "$entry" | jq -r '.value.subject')

    if [ "$STATUS" = "completed" ]; then
      COMPLETED_AT=$(echo "$entry" | jq -r '.value.completed_at // empty')
      OUTPUT_FILES=$(echo "$entry" | jq -r '.value.output_files[]' 2>/dev/null)
      IS_STALE=false

      if [ -n "$OUTPUT_FILES" ] && [ -n "$COMPLETED_AT" ] && command -v git &>/dev/null; then
        while IFS= read -r ofile; do
          [ -z "$ofile" ] && continue
          FULL_PATH="$CWD/$ofile"
          if [ -f "$FULL_PATH" ]; then
            FILE_DATE=$(cd "$CWD" && git log -1 --format=%cI -- "$ofile" 2>/dev/null)
            if [ -n "$FILE_DATE" ] && [[ "$FILE_DATE" > "$COMPLETED_AT" ]]; then
              IS_STALE=true
              STALE_LIST="${STALE_LIST}  Completed (stale): $ID ($SUBJECT) — $ofile modified after completion\n"
              break
            fi
          fi
        done <<< "$OUTPUT_FILES"
      fi

      if [ "$IS_STALE" = false ]; then
        if command -v git &>/dev/null; then
          VALID_LIST="${VALID_LIST}  Completed (valid): $ID ($SUBJECT) — output files unchanged\n"
        else
          VALID_LIST="${VALID_LIST}  Completed (valid, unverified): $ID ($SUBJECT) — git unavailable\n"
        fi
      fi
    else
      REMAINING_LIST="${REMAINING_LIST}  Remaining: $ID ($SUBJECT) — status: $STATUS\n"
    fi
  done < <(echo "$GRAPH" | jq -c '.nodes | to_entries[]')

  # Output resume context to stdout
  HAS_OUTPUT=true
  REL_PATH="${WORKSPACE_DIR#$CWD/}"
  echo ""
  echo "Resumable workspace found: $REL_PATH/"
  echo "  Tasks: $COMPLETED/$TOTAL completed, $REMAINING remaining"
  [ -n "$VALID_LIST" ] && printf "$VALID_LIST"
  [ -n "$STALE_LIST" ] && printf "$STALE_LIST"
  [ -n "$REMAINING_LIST" ] && printf "$REMAINING_LIST"

  # Show remaining critical path if available
  CP=$(echo "$GRAPH" | jq -r '[.critical_path[] | select(. as $id | .nodes[$id].status != "completed")] | join(" → ")' 2>/dev/null)
  [ -n "$CP" ] && echo "  Critical path (remaining): $CP"

  echo ""
  echo "  To resume: \"resume team $TEAM\""
  echo "  To start fresh: proceed normally (existing workspace will be archived)"
done

exit 0
```

- [ ] **Step 4: Make executable**

```bash
chmod +x scripts/detect-resume.sh
```

- [ ] **Step 5: Run tests — verify they pass**

```bash
bash tests/hooks/test-detect-resume.sh
```

Expected: all 6 tests pass

- [ ] **Step 6: Commit**

```bash
git add scripts/detect-resume.sh tests/hooks/test-detect-resume.sh
git commit -m "feat: add detect-resume.sh hook with staleness validation and tests"
```

### Task 4: Write `check-integration-point.sh` + tests

**Files:**
- Create: `scripts/check-integration-point.sh`
- Create: `tests/hooks/test-check-integration-point.sh`

- [ ] **Step 1: Write the test file**

Create `tests/hooks/test-check-integration-point.sh`:

```bash
#!/bin/bash
# Tests for scripts/check-integration-point.sh (TaskCompleted hook — integration checkpoints)

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/check-integration-point.sh"

echo "Integration checkpoint hook tests"
echo "==================================="

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed\n"
  exit 0
fi

# --- Test 1: No task-graph.json exits 0 silently ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "1: No task-graph.json exits 0 silently"
cleanup_temp_dir

# --- Test 2: No convergence points fully unblocked — silent ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
# #1 completed, #2 still pending, #3 is convergence but not all deps done
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T10:30:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:30:00Z","output_files":["src/auth.ts"],"critical_path":true,"convergence_point":false},
    "#2": {"subject":"Session","owner":"impl-2","status":"pending","depends_on":[],"completed_at":null,"output_files":["src/session.ts"],"critical_path":false,"convergence_point":false},
    "#3": {"subject":"Middleware","owner":"impl-1","status":"pending","depends_on":["#1","#2"],"completed_at":null,"output_files":["src/mw.ts"],"critical_path":true,"convergence_point":true}
  },
  "critical_path": ["#1","#3"],
  "critical_path_length": 2
}
JSON
)"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "2: Partial convergence exits 0"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if [ -z "$HOOK_STDERR" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "  ${GREEN}PASS${RESET} 2: Silent when convergence not fully unblocked\n"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "  ${RED}FAIL${RESET} 2: Expected silent, got: %s\n" "$HOOK_STDERR"
fi
cleanup_temp_dir

# --- Test 3: All deps of convergence point completed — nudge ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T10:45:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:30:00Z","output_files":["src/auth.ts"],"critical_path":true,"convergence_point":false},
    "#2": {"subject":"Session","owner":"impl-2","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:45:00Z","output_files":["src/session.ts"],"critical_path":false,"convergence_point":false},
    "#3": {"subject":"Middleware","owner":"impl-1","status":"pending","depends_on":["#1","#2"],"completed_at":null,"output_files":["src/mw.ts"],"critical_path":true,"convergence_point":true}
  },
  "critical_path": ["#1","#3"],
  "critical_path_length": 2
}
JSON
)"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "3: Convergence unblocked exits 0"
assert_stderr_contains "Integration checkpoint" "$HOOK_STDERR" "3: Shows integration checkpoint nudge"
assert_stderr_contains "Middleware" "$HOOK_STDERR" "3: Mentions the convergence task"
cleanup_temp_dir

# --- Test 4: Convergence point already in_progress — skip ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T10:45:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:30:00Z","output_files":["src/auth.ts"],"critical_path":true,"convergence_point":false},
    "#2": {"subject":"Session","owner":"impl-2","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:45:00Z","output_files":["src/session.ts"],"critical_path":false,"convergence_point":false},
    "#3": {"subject":"Middleware","owner":"impl-1","status":"in_progress","depends_on":["#1","#2"],"completed_at":null,"output_files":["src/mw.ts"],"critical_path":true,"convergence_point":true}
  },
  "critical_path": ["#1","#3"],
  "critical_path_length": 2
}
JSON
)"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "4: In-progress convergence exits 0"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if [ -z "$HOOK_STDERR" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "  ${GREEN}PASS${RESET} 4: Silent when convergence already in_progress\n"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "  ${RED}FAIL${RESET} 4: Expected silent, got: %s\n" "$HOOK_STDERR"
fi
cleanup_temp_dir

# --- Test 5: No convergence points in graph — silent ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T10:30:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:30:00Z","output_files":["src/auth.ts"],"critical_path":true,"convergence_point":false},
    "#2": {"subject":"Session","owner":"impl-2","status":"pending","depends_on":[],"completed_at":null,"output_files":["src/session.ts"],"critical_path":false,"convergence_point":false}
  },
  "critical_path": ["#1"],
  "critical_path_length": 1
}
JSON
)"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "5: No convergence points exits 0"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if [ -z "$HOOK_STDERR" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "  ${GREEN}PASS${RESET} 5: Silent when no convergence points\n"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "  ${RED}FAIL${RESET} 5: Expected silent, got: %s\n" "$HOOK_STDERR"
fi
cleanup_temp_dir

# --- Test 6: Empty input exits 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{}'
assert_exit_code 0 "$HOOK_EXIT" "6: Empty input exits 0"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
bash tests/hooks/test-check-integration-point.sh
```

Expected: failures (script not found)

- [ ] **Step 3: Write `check-integration-point.sh`**

Create `scripts/check-integration-point.sh`:

```bash
#!/bin/bash
# Hook: TaskCompleted
# Detects when all upstream tasks of a convergence point complete.
# Nudges the lead to verify interface compatibility.
# Informational only — always exits 0.

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty')

if [ -z "$CWD" ] || [ -z "$TEAM_NAME" ]; then
  exit 0
fi

# Resolve workspace path (with -fix suffix fallback)
GRAPH_FILE="$CWD/.agent-team/$TEAM_NAME/task-graph.json"
if [ ! -f "$GRAPH_FILE" ]; then
  BASE_NAME="${TEAM_NAME%-fix}"
  if [ "$BASE_NAME" != "$TEAM_NAME" ] && [ -f "$CWD/.agent-team/$BASE_NAME/task-graph.json" ]; then
    GRAPH_FILE="$CWD/.agent-team/$BASE_NAME/task-graph.json"
  else
    exit 0
  fi
fi

# Parse JSON — warn if malformed
GRAPH=$(jq '.' "$GRAPH_FILE" 2>/dev/null)
if [ -z "$GRAPH" ]; then
  echo "Warning: task-graph.json exists but failed to parse. Integration checkpoint hooks disabled until JSON is fixed." >&2
  exit 0
fi

# Find convergence points that are fully unblocked and still pending
echo "$GRAPH" | jq -r '
  .nodes | to_entries[] |
  select(.value.convergence_point == true) |
  select(.value.status == "pending") |
  .key as $id |
  .value.depends_on as $deps |
  if ([$deps[] | . as $d | $GRAPH.nodes[$d].status] | all(. == "completed")) then
    $id
  else
    empty
  end
' 2>/dev/null | while IFS= read -r conv_id; do
  [ -z "$conv_id" ] && continue

  SUBJECT=$(echo "$GRAPH" | jq -r --arg id "$conv_id" '.nodes[$id].subject')
  DEPS=$(echo "$GRAPH" | jq -r --arg id "$conv_id" '.nodes[$id].depends_on[]')

  echo "Integration checkpoint reached: Task $conv_id ($SUBJECT)" >&2
  echo "  All upstream tasks completed:" >&2
  for dep_id in $DEPS; do
    DEP_OWNER=$(echo "$GRAPH" | jq -r --arg id "$dep_id" '.nodes[$id].owner')
    echo "    $dep_id ($DEP_OWNER)" >&2
  done
  echo "  These streams produced independent changes that must integrate at $conv_id." >&2
  echo "  Recommend: verify interface compatibility before $conv_id starts." >&2

  # List output files from upstream tasks
  OUTPUT_FILES=""
  for dep_id in $DEPS; do
    FILES=$(echo "$GRAPH" | jq -r --arg id "$dep_id" '.nodes[$id].output_files[]' 2>/dev/null)
    [ -n "$FILES" ] && OUTPUT_FILES="${OUTPUT_FILES}${FILES}\n"
  done
  if [ -n "$OUTPUT_FILES" ]; then
    echo "  Shared interfaces: check these output files for contract alignment:" >&2
    printf "$OUTPUT_FILES" | while IFS= read -r f; do
      [ -n "$f" ] && echo "    - $f" >&2
    done
  fi
done

exit 0
```

- [ ] **Step 4: Make executable**

```bash
chmod +x scripts/check-integration-point.sh
```

- [ ] **Step 5: Run tests — verify they pass**

```bash
bash tests/hooks/test-check-integration-point.sh
```

Expected: all 6 tests pass

- [ ] **Step 6: Commit**

```bash
git add scripts/check-integration-point.sh tests/hooks/test-check-integration-point.sh
git commit -m "feat: add check-integration-point.sh hook with convergence detection and tests"
```

### Task 5: Register hooks in hooks.json

**Files:**
- Modify: `hooks/hooks.json`

- [ ] **Step 1: Add 3 new hook entries**

Add to the `TaskCompleted` array (after the existing `verify-task-complete.sh` entry):
```json
    {
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/compute-critical-path.sh",
          "timeout": 15
        }
      ]
    },
    {
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/check-integration-point.sh",
          "timeout": 15
        }
      ]
    }
```

Add to the `SessionStart` array (after the existing `recover-context.sh` entry):
```json
    {
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/detect-resume.sh",
          "timeout": 15
        }
      ]
    }
```

Note: the new `SessionStart` entry has **no matcher** (fires on all session starts), unlike the existing `compact` matcher entry.

- [ ] **Step 2: Validate JSON**

```bash
jq . hooks/hooks.json
```

Expected: valid JSON output

- [ ] **Step 3: Run full test suite**

```bash
bash tests/run-tests.sh
```

Expected: all existing + new tests pass

- [ ] **Step 4: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat: register 3 new DAG hook entries in hooks.json"
```

## Chunk 2: Documentation Changes

### Task 6: Update `docs/workspace-templates.md`

**Files:**
- Modify: `docs/workspace-templates.md`

- [ ] **Step 1: Add `task-graph.json` section**

After the `### file-locks.json` section (and before `### events.log`), add the full `task-graph.json` section from the spec: schema, field reference, lifecycle, and applicability table. See spec section "Shared Data Structure: task-graph.json" for exact content.

- [ ] **Step 2: Add Workspace Update Protocol rows**

Add these rows to the existing "Workspace Update Protocol" table:

```markdown
| Tasks created | task-graph.json | Initialize full graph with nodes, compute critical path and convergence points |
| Task started | task-graph.json | Node status → `in_progress` |
| Task completed | task-graph.json | Node status → `completed`, set `completed_at` and `output_files`, recompute `critical_path`. Self-check: read back to verify valid JSON. |
| Task blocked | task-graph.json | Node status → `blocked` |
| Re-plan occurs | task-graph.json | Rebuild graph from revised tasks |
```

- [ ] **Step 3: Add CP column to `tasks.md` template**

In all four task tables (In Progress, Blocked, Pending, Completed), add the `CP` column:

```markdown
| ID | Subject | Owner | Ref | CP | Notes |
|----|---------|-------|-----|----|-------|
```

For Blocked and Pending tables (which have Blocked By):

```markdown
| ID | Subject | Owner | Ref | CP | Blocked By | Notes |
|----|---------|-------|-----|----|-----------|-------|
```

- [ ] **Step 4: Commit**

```bash
git add docs/workspace-templates.md
git commit -m "docs: add task-graph.json schema and CP column to workspace-templates"
```

### Task 7: Update `docs/shared-phases.md`

**Files:**
- Modify: `docs/shared-phases.md`

- [ ] **Step 1: Add Phase 1b step 5a**

After the existing step 5 ("Integration points — for each pair of streams, identify where plan tasks reference shared interfaces, contracts, or outputs. These become explicit handoff points in Phase 2."), add:

```markdown
6. **Mark convergence points** — for each task that depends on 2+ upstream tasks, flag it as a convergence point. These become integration checkpoints during Phase 4 — the `check-integration-point.sh` hook will nudge the lead to verify interface compatibility when all upstream tasks complete. Include convergence points in the Phase 2 presentation.
```

Renumber existing steps 6-7 to 7-8.

- [ ] **Step 2: Add critical path and convergence to Phase 2 plan template**

After the `Task breakdown:` section in the Phase 2 template, add:

```markdown
Critical path: [#X → #Y → #Z] (length: N)
  Non-critical (can slip without affecting total time): [#A, #B]
  Integration checkpoints: [#Y (converges #X + #A — verify interface compatibility)]
```

Add to the Phase 2 self-check list (after item 3):

```markdown
4. "Have I identified the critical path? Is it displayed in the plan? Are convergence points marked?"
```

- [ ] **Step 3: Add Phase 3 step 1a (resume detection)**

Before the existing step 1 ("Check for existing team"), add:

```markdown
1a. **Check for resumable workspace** — if the `detect-resume.sh` hook surfaced a resumable workspace at session start, present the resume option to the user:
```

Include the full resume protocol from the spec (options, if-resuming behavior, if-starting-fresh behavior).

- [ ] **Step 4: Add Phase 3 step 4a (create task-graph.json)**

After the existing step 4 (Create ALL tasks upfront), add:

```markdown
4a. **Create `task-graph.json`** — immediately after creating all tasks, generate `.agent-team/{team-name}/task-graph.json` with the full dependency graph. Compute the initial critical path (longest chain, tie-break by lowest task ID) and mark convergence points (nodes with 2+ dependencies). Validate the graph is acyclic — if a cycle is detected, fix it before proceeding (see Circular Dependency Detection in coordination-advanced.md). Update `tasks.md` with ★ markers on critical-path tasks and convergence notes. See [workspace-templates.md](workspace-templates.md#task-graphjson) for schema.
```

- [ ] **Step 5: Add Phase 4 updates**

Add `task-graph.json` update instruction to the COMPLETED row in the Lead Processing Rules table:

```markdown
| COMPLETED | Update `tasks.md` status to `completed`, add file list and notes. Update `task-graph.json`: set node status to `completed`, record `completed_at` and `output_files`. Self-check: read `task-graph.json` back to verify valid JSON. Check: does this unblock other tasks? If yes, message the dependent teammate |
```

Add integration checkpoint processing row:

```markdown
| (hook: integration checkpoint) | Read the nudge from `check-integration-point.sh`. Before unblocking the convergence task, verify interface compatibility between upstream outputs. If compatible, message the convergence task owner to proceed. If unclear, log in `issues.md` as medium severity. Log checkpoint in `progress.md` Decision Log. |
```

Add new subsection after "Communication Protocol":

```markdown
### Critical Path Awareness

The critical path determines total execution time. The `compute-critical-path.sh` hook outputs the remaining critical path after every task completion. Use it to prioritize:

- **BLOCKED on critical path** → resolve immediately (highest-priority coordination action)
- **BLOCKED on non-critical path** → resolve normally (slippage has slack)
- **Teammate idle on critical path** → reassign work to keep the critical chain moving
- **Teammate idle on non-critical path** → lower priority, consider assigning critical-path support tasks

After every task completion, read the hook output. If the critical path shifted, update `task-graph.json` and the ★ markers in `tasks.md`.
```

- [ ] **Step 6: Update Contents/TOC**

Add anchor links for the new sections to the Contents list at the top of the file.

- [ ] **Step 7: Commit**

```bash
git add docs/shared-phases.md
git commit -m "docs: add critical path, resume detection, and convergence points to shared phases"
```

### Task 8: Update `docs/coordination-patterns.md`

**Files:**
- Modify: `docs/coordination-patterns.md`

- [ ] **Step 1: Add "Resume from Existing Workspace" section**

After the "Setup Failures" section, add the full resume protocol from the spec: Valid Completed Tasks, Stale Completed Tasks, Remaining Tasks, Archive Protocol.

- [ ] **Step 2: Add "Integration Checkpoint Response" section**

After the "Direct Handoff" section, add the full integration checkpoint response protocol from the spec.

- [ ] **Step 3: Update Contents/TOC**

Add new section links.

- [ ] **Step 4: Commit**

```bash
git add docs/coordination-patterns.md
git commit -m "docs: add resume and integration checkpoint patterns to coordination-patterns"
```

### Task 9: Update `docs/coordination-advanced.md`

**Files:**
- Modify: `docs/coordination-advanced.md`

- [ ] **Step 1: Add critical-path awareness to Deadline Escalation**

In the "Deadline Escalation" section, add to the protocol step 2:

```markdown
When checking stalled tasks, prioritize **critical-path tasks** (marked in `task-graph.json`). A stalled critical-path task directly delays total completion. Adjust escalation urgency:
- Critical-path task stalled → skip Nudge, go directly to **Warn**
- Non-critical task stalled → follow normal Nudge → Warn → Escalate ladder
```

- [ ] **Step 2: Commit**

```bash
git add docs/coordination-advanced.md
git commit -m "docs: integrate critical path awareness into deadline escalation"
```

### Task 10: Update `docs/report-format.md`

**Files:**
- Modify: `docs/report-format.md`

- [ ] **Step 1: Add metrics to Team Metrics table**

Add these rows:

```markdown
| Critical path length | {initial} → {final} (shifted {count} times) |
| Integration checkpoints | {count} ({passed}/{flagged}) |
| Resumed tasks | {count valid}/{count stale}/{count remaining} (or "N/A — fresh start") |
```

- [ ] **Step 2: Add CP column to Task Ledger**

Update the Task Ledger table in Full Audit Trail:

```markdown
| ID | Subject | Owner | Status | CP | Notes |
|----|---------|-------|--------|----|-------|
```

- [ ] **Step 3: Commit**

```bash
git add docs/report-format.md
git commit -m "docs: add critical path metrics and CP column to report format"
```

### Task 11: Update all 5 archetype SKILL.md files

**Files:**
- Modify: `skills/agent-team/SKILL.md`
- Modify: `skills/agent-implement/SKILL.md`
- Modify: `skills/agent-research/SKILL.md`
- Modify: `skills/agent-audit/SKILL.md`
- Modify: `skills/agent-plan/SKILL.md`

- [ ] **Step 1: Add step 4a reference to all 5 skills**

In each skill's Phase 3 Override section, add after the shared Phase 3 reference:

```markdown
After shared Phase 3 step 4 (create tasks), execute step 4a: create `task-graph.json` with initial critical path and convergence points. See [shared-phases.md](../../docs/shared-phases.md) and [workspace-templates.md](../../docs/workspace-templates.md#task-graphjson).
```

- [ ] **Step 2: Add convergence-point awareness to agent-implement completion gate**

In `skills/agent-implement/SKILL.md`, update Completion Gate check #4 (Integration):

```markdown
| 4 | **Integration** | Assign teammate: "Verify cross-module connections". If any convergence points in `task-graph.json` were flagged during Phase 4, verify they were resolved. | Cross-teammate outputs connect, flagged convergence points resolved | Create integration fix task |
```

- [ ] **Step 3: Commit**

```bash
git add skills/*/SKILL.md
git commit -m "docs: add task-graph.json step 4a reference to all archetype skills"
```

## Chunk 3: User-Facing Docs + Release

### Task 12: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add `task-graph.json` to workspace file tree**

```markdown
.agent-team/0304-refactor-auth/
├── progress.md      # Team status, members, decisions, handoffs
├── tasks.md         # Task ledger with status tracking
├── issues.md        # Issue tracker with severity and resolution
├── file-locks.json  # File ownership map (teammate -> files/directories)
├── task-graph.json  # DAG: task dependencies, critical path, convergence points
├── events.log       # Structured JSON event log for post-mortem analysis
└── report.md        # Final report (generated at completion)
```

- [ ] **Step 2: Add 3 new hooks to Hooks section**

After the existing SubagentStart/SubagentStop entry:

```markdown
### ComputeCriticalPath (TaskCompleted)

Recomputes and displays the critical path after each task completion:
- Reads `task-graph.json` for the dependency graph
- Outputs remaining critical path and identifies blocked critical tasks
- Informational only — always allows task completion

### DetectResume (SessionStart)

Detects resumable workspaces at session start:
- Scans for incomplete `task-graph.json` files in `.agent-team/`
- Validates completed task output files via git timestamps (valid/stale/missing)
- Outputs resume context with options to resume or start fresh

### CheckIntegrationPoint (TaskCompleted)

Detects when convergence points become fully unblocked:
- Checks if all upstream tasks of a convergence point are completed
- Nudges the lead to verify interface compatibility before downstream task starts
- Informational only — silent when no convergence point is ready
```

- [ ] **Step 3: Add 3 new scripts to Plugin Structure tree**

```markdown
├── scripts/
│   ├── verify-task-complete.sh
│   ├── check-teammate-idle.sh
│   ├── recover-context.sh
│   ├── check-file-ownership.sh
│   ├── track-teammate-lifecycle.sh
│   ├── setup-worktree.sh
│   ├── merge-worktrees.sh
│   ├── compute-critical-path.sh       # NEW — critical path hook
│   ├── detect-resume.sh               # NEW — resume detection hook
│   └── check-integration-point.sh     # NEW — integration checkpoint hook
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add DAG hooks and task-graph.json to README"
```

### Task 13: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update File Ownership table**

Add row for `task-graph.json`:

```markdown
| `docs/workspace-templates.md` | Workspace file templates + `task-graph.json` schema | Update when adding new workspace files or changing DAG schema |
```

Update hooks.json row:

```markdown
| `hooks/hooks.json` | Hook registration (9 hook entries) | Update timeout values, add new hooks, or update hook command paths |
```

Update scripts row:

```markdown
| `scripts/*.sh` | Hook enforcement logic (12 scripts) | Written in bash (`#!/bin/bash`), degrade gracefully without `jq` |
```

- [ ] **Step 2: Add 3 new verification scenarios to Verify Hooks**

```markdown
7. **ComputeCriticalPath** — complete a task and check stderr for critical path update
8. **DetectResume** — start a new session with an incomplete workspace and check stdout for resume context
9. **CheckIntegrationPoint** — complete both upstream tasks of a convergence point and check stderr for integration nudge
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md file ownership and hook counts for v2.6.0"
```

### Task 14: Update existing test assertions

**Files:**
- Modify: `tests/structure/test-doc-references.sh`

- [ ] **Step 1: Add `task-graph.json` reference assertion**

After the existing doc reference tests, add:

```bash
# --- Test: workspace-templates.md references task-graph.json ---
TASK_GRAPH_REF=$(grep -c 'task-graph.json' docs/workspace-templates.md)
assert_true "workspace-templates.md references task-graph.json" "[ $TASK_GRAPH_REF -gt 0 ]"

# --- Test: All SKILL.md files reference step 4a ---
for SKILL_MD in skills/*/SKILL.md; do
  SKILL_NAME=$(basename "$(dirname "$SKILL_MD")")
  STEP4A_REF=$(grep -c 'step 4a\|task-graph.json' "$SKILL_MD")
  assert_true "$SKILL_NAME: SKILL.md references step 4a or task-graph.json" "[ $STEP4A_REF -gt 0 ]"
done

# --- Test: New scripts referenced in docs ---
for script in compute-critical-path.sh detect-resume.sh check-integration-point.sh; do
  SCRIPT_REF=$(grep -rl "$script" docs/ | wc -l | tr -d ' ')
  assert_true "$script referenced in docs/" "[ $SCRIPT_REF -gt 0 ]"
done
```

- [ ] **Step 2: Commit**

```bash
git add tests/structure/test-doc-references.sh
git commit -m "test: add task-graph.json and DAG script reference assertions"
```

### Task 15: Update CHANGELOG.md + bump version

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Add v2.6.0 entry to CHANGELOG.md**

At the top (after the header), add:

```markdown
## [2.6.0] - 2026-03-20

### Added
- **`task-graph.json` workspace file** — centralized DAG with task dependencies, critical path, and convergence points. Created in Phase 3, maintained by lead, read by 3 new hook scripts
- **`compute-critical-path.sh` hook** (TaskCompleted) — recomputes and displays remaining critical path after each task completion, warns about blocked critical tasks
- **`detect-resume.sh` hook** (SessionStart) — detects resumable workspaces with smart staleness validation via git timestamps (valid/stale/missing output files)
- **`check-integration-point.sh` hook** (TaskCompleted) — detects when convergence points (diamond dependencies) become fully unblocked, nudges lead to verify interface compatibility
- **Critical Path Awareness** in Phase 4 — lead prioritizes critical-path blockers over non-critical work
- **Resume from Existing Workspace** coordination pattern — valid/stale/remaining protocol with archive option
- **Integration Checkpoint Response** coordination pattern — lead response protocol for convergence nudges
- **CP column** in `tasks.md` — ★ marks critical path tasks, convergence notes in the Notes column

### Changed
- Phase 1b gains convergence point marking (step 5a/6 after integration points)
- Phase 2 gains critical path display and integration checkpoint preview
- Phase 3 gains resume detection (step 1a) and `task-graph.json` creation (step 4a)
- Phase 4 gains critical-path-weighted prioritization and integration checkpoint processing
- Deadline Escalation gains critical-path acceleration (skip Nudge, go to Warn)
- Report gains critical path metrics (initial → final length, shift count) and integration checkpoint counts
- All 5 archetype SKILL.md files reference step 4a
- `agent-implement` completion gate check #4 gains convergence-point awareness
```

- [ ] **Step 2: Bump version in plugin.json**

Change `"version": "2.5.1"` to `"version": "2.6.0"`.

- [ ] **Step 3: Bump version in marketplace.json**

Change `"version": "2.5.1"` to `"version": "2.6.0"`.

- [ ] **Step 4: Run full test suite**

```bash
bash tests/run-tests.sh
```

Expected: 12 test files, all passing

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore: bump version to 2.6.0"
```

- [ ] **Step 6: Update spec status**

Change spec status from `DRAFT` to `IMPLEMENTED`:

```bash
sed -i '' 's/^**Status**: DRAFT/**Status**: IMPLEMENTED/' docs/specs/2026-03-20-dag-aligned-improvements-design.md
git add docs/specs/2026-03-20-dag-aligned-improvements-design.md
git commit -m "docs: mark DAG improvements spec as IMPLEMENTED"
```
