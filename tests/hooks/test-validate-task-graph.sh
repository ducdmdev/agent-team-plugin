#!/bin/bash
# Tests for scripts/validate-task-graph.sh (SubagentStart hook)
# Validates task-graph.json schema and cycle detection before teammate spawn

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/validate-task-graph.sh"

echo "ValidateTaskGraph hook tests"
echo "============================"

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed (hooks degrade gracefully without it)\n"
  exit 0
fi

# --- Test 1: No task-graph.json — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 0 "$HOOK_EXIT" "1: Allow when no task-graph.json"
cleanup_temp_dir

# --- Test 2: Valid task-graph.json — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
setup_mock_task_graph "test-team"
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 0 "$HOOK_EXIT" "2: Allow valid task-graph.json"
cleanup_temp_dir

# --- Test 3: Malformed JSON — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
echo "not valid json {{{" > "$TEST_TEMP_DIR/.agent-team/test-team/task-graph.json"
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 2 "$HOOK_EXIT" "3: Block malformed JSON"
assert_stderr_contains "not valid JSON" "$HOOK_STDERR" "3: Error mentions invalid JSON"
cleanup_temp_dir

# --- Test 4: Missing required fields — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
cat > "$TEST_TEMP_DIR/.agent-team/test-team/task-graph.json" <<'GRAPH'
{
  "team": "test",
  "nodes": {
    "#1": {
      "subject": "Task 1"
    }
  }
}
GRAPH
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 2 "$HOOK_EXIT" "4: Block missing required fields"
assert_stderr_contains "missing required fields" "$HOOK_STDERR" "4: Error mentions missing fields"
cleanup_temp_dir

# --- Test 5: Dangling dependency reference — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
cat > "$TEST_TEMP_DIR/.agent-team/test-team/task-graph.json" <<'GRAPH'
{
  "team": "test",
  "nodes": {
    "#1": {
      "subject": "Task 1",
      "owner": "impl-1",
      "status": "pending",
      "depends_on": ["#99"],
      "completed_at": null,
      "output_files": [],
      "critical_path": false,
      "convergence_point": false
    }
  }
}
GRAPH
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 2 "$HOOK_EXIT" "5: Block dangling dependency"
assert_stderr_contains "dangling dependency" "$HOOK_STDERR" "5: Error mentions dangling ref"
cleanup_temp_dir

# --- Test 6: Circular dependency — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
cat > "$TEST_TEMP_DIR/.agent-team/test-team/task-graph.json" <<'GRAPH'
{
  "team": "test",
  "nodes": {
    "#1": {
      "subject": "Task 1",
      "owner": "impl-1",
      "status": "pending",
      "depends_on": ["#2"],
      "completed_at": null,
      "output_files": [],
      "critical_path": false,
      "convergence_point": false
    },
    "#2": {
      "subject": "Task 2",
      "owner": "impl-2",
      "status": "pending",
      "depends_on": ["#1"],
      "completed_at": null,
      "output_files": [],
      "critical_path": false,
      "convergence_point": false
    }
  }
}
GRAPH
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 2 "$HOOK_EXIT" "6: Block circular dependency"
assert_stderr_contains "Circular dependency" "$HOOK_STDERR" "6: Error mentions cycle"
cleanup_temp_dir

# --- Test 7: Empty nodes — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
echo '{"team":"test","nodes":{}}' > "$TEST_TEMP_DIR/.agent-team/test-team/task-graph.json"
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 0 "$HOOK_EXIT" "7: Allow empty nodes"
cleanup_temp_dir

# --- Test 8: Valid graph with dependencies — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
cat > "$TEST_TEMP_DIR/.agent-team/test-team/task-graph.json" <<'GRAPH'
{
  "team": "test",
  "nodes": {
    "#1": {
      "subject": "Task 1",
      "owner": "impl-1",
      "status": "pending",
      "depends_on": [],
      "completed_at": null,
      "output_files": ["src/a.ts"],
      "critical_path": true,
      "convergence_point": false
    },
    "#2": {
      "subject": "Task 2",
      "owner": "impl-2",
      "status": "pending",
      "depends_on": ["#1"],
      "completed_at": null,
      "output_files": ["src/b.ts"],
      "critical_path": false,
      "convergence_point": false
    },
    "#3": {
      "subject": "Review",
      "owner": "reviewer",
      "status": "pending",
      "depends_on": ["#1", "#2"],
      "completed_at": null,
      "output_files": [],
      "critical_path": false,
      "convergence_point": true
    }
  }
}
GRAPH
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 0 "$HOOK_EXIT" "8: Allow valid graph with dependencies"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
