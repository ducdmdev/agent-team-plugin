#!/bin/bash
# Shared test helpers for agent-team-plugin test suite.
# Source this file from test scripts: source "$(dirname "$0")/../lib/test-helpers.sh"

# --- Project root ---
# Resolve from the tests/lib/ location to the repo root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --- Counters ---
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# --- Colors ---
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN=''
  RED=''
  YELLOW=''
  BOLD=''
  RESET=''
fi

# --- Temp directory management ---
TEST_TEMP_DIR=""

setup_temp_dir() {
  TEST_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/agent-team-test.XXXXXX")
}

cleanup_temp_dir() {
  if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
  TEST_TEMP_DIR=""
}

# --- Mock workspace ---
# Creates .agent-team/$team_name/ with progress.md, tasks.md, issues.md
# Usage: setup_mock_workspace "my-team"
# Sets WORKSPACE_DIR to the created path (inside TEST_TEMP_DIR)
WORKSPACE_DIR=""

setup_mock_workspace() {
  local team_name="$1"
  WORKSPACE_DIR="$TEST_TEMP_DIR/.agent-team/$team_name"
  mkdir -p "$WORKSPACE_DIR"

  cat > "$WORKSPACE_DIR/progress.md" <<'EOF'
# Team: test

**Task**: test task
**Status**: active
**Archetype**: implementation
EOF

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

  cat > "$WORKSPACE_DIR/issues.md" <<'EOF'
# Issues: test

**Open**: 0 | **Resolved**: 0
EOF
}

# --- Mock git repo ---
# Creates a git repo inside TEST_TEMP_DIR with one committed file.
# Pass "dirty" as $1 to also leave an uncommitted change.
setup_mock_git_repo() {
  local mode="${1:-clean}"
  (
    cd "$TEST_TEMP_DIR" || exit 1
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "initial" > committed-file.txt
    # Ignore .agent-team/ like the real plugin does (SKILL.md Phase 3)
    echo ".agent-team/" > .gitignore
    git add committed-file.txt .gitignore
    git commit -q -m "init"
    if [ "$mode" = "dirty" ]; then
      echo "change" > uncommitted-file.txt
    fi
  )
}

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

# --- Run a hook script ---
# Feeds JSON via stdin, captures exit code and stderr.
# Usage: run_hook "$script" "$json_input"
# Sets: HOOK_EXIT, HOOK_STDERR
HOOK_EXIT=0
HOOK_STDERR=""

run_hook() {
  local script="$1"
  local input="$2"
  HOOK_STDERR=$(echo "$input" | bash "$script" 2>&1 1>/dev/null)
  HOOK_EXIT=$?
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

# --- Assertions ---

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local test_name="$3"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "  ${RED}FAIL${RESET} %s (expected exit %s, got %s)\n" "$test_name" "$expected" "$actual"
  fi
}

assert_stderr_contains() {
  local pattern="$1"
  local stderr_output="$2"
  local test_name="$3"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if echo "$stderr_output" | grep -qi "$pattern"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "  ${RED}FAIL${RESET} %s (stderr missing pattern '%s')\n" "$test_name" "$pattern"
    printf "        stderr was: %s\n" "$stderr_output"
  fi
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

assert_true() {
  local test_name="$1"
  local condition="$2"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if eval "$condition"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "  ${RED}FAIL${RESET} %s\n" "$test_name"
  fi
}

# --- Summary ---
print_summary() {
  echo ""
  if [ "$TESTS_FAILED" -eq 0 ]; then
    printf "${GREEN}${BOLD}All %d tests passed${RESET}\n" "$TESTS_TOTAL"
  else
    printf "${RED}${BOLD}%d of %d tests failed${RESET}\n" "$TESTS_FAILED" "$TESTS_TOTAL"
  fi
}
