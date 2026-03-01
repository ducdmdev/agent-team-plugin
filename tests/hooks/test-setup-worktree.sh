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
