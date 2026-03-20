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
mkdir -p "$TEST_TEMP_DIR/src"
echo "original" > "$TEST_TEMP_DIR/src/auth.ts"
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
