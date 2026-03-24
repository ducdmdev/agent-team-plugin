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

# --- Test 7: Convergence with all output files present — no missing warning ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T10:45:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:30:00Z","output_files":["src/a.ts"],"critical_path":true,"convergence_point":false},
    "#2": {"subject":"Session","owner":"impl-2","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:45:00Z","output_files":["src/b.ts"],"critical_path":false,"convergence_point":false},
    "#3": {"subject":"Middleware","owner":"impl-1","status":"pending","depends_on":["#1","#2"],"completed_at":null,"output_files":["src/mw.ts"],"critical_path":true,"convergence_point":true}
  },
  "critical_path": ["#1","#3"],
  "critical_path_length": 2
}
JSON
)"
# Create the output files so they exist on disk
mkdir -p "$TEST_TEMP_DIR/src"
echo "export const a = 1;" > "$TEST_TEMP_DIR/src/a.ts"
echo "export const b = 1;" > "$TEST_TEMP_DIR/src/b.ts"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "7: Convergence with output files present exits 0"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if echo "$HOOK_STDERR" | grep -qi "missing"; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "  ${RED}FAIL${RESET} 7: Should not warn about missing files when all present\n"
  printf "        stderr was: %s\n" "$HOOK_STDERR"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "  ${GREEN}PASS${RESET} 7: No missing-file warning when all output files exist\n"
fi
cleanup_temp_dir

# --- Test 8: Convergence with missing output file — warns ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_task_graph "test" "$(cat <<'JSON'
{
  "team": "test",
  "created": "2026-03-20T10:00:00Z",
  "updated": "2026-03-20T10:45:00Z",
  "nodes": {
    "#1": {"subject":"Auth","owner":"impl-1","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:30:00Z","output_files":["src/a.ts"],"critical_path":true,"convergence_point":false},
    "#2": {"subject":"Session","owner":"impl-2","status":"completed","depends_on":[],"completed_at":"2026-03-20T10:45:00Z","output_files":["src/b.ts"],"critical_path":false,"convergence_point":false},
    "#3": {"subject":"Middleware","owner":"impl-1","status":"pending","depends_on":["#1","#2"],"completed_at":null,"output_files":["src/mw.ts"],"critical_path":true,"convergence_point":true}
  },
  "critical_path": ["#1","#3"],
  "critical_path_length": 2
}
JSON
)"
# Do NOT create src/a.ts — it should be reported as missing
# Create only src/b.ts
mkdir -p "$TEST_TEMP_DIR/src"
echo "export const b = 1;" > "$TEST_TEMP_DIR/src/b.ts"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "8: Convergence with missing output file exits 0"
assert_stderr_contains "missing" "$HOOK_STDERR" "8: Warns about missing upstream output file"
assert_stderr_contains "src/a.ts" "$HOOK_STDERR" "8: Mentions the specific missing file"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
