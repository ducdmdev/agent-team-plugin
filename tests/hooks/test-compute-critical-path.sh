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
