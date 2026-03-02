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

# --- Test 3: Missing argument — exits 1 with usage message ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
STDERR_OUTPUT=$(bash "$SCRIPT" 2>&1 1>/dev/null)
SCRIPT_EXIT=$?
assert_exit_code 1 "$SCRIPT_EXIT" "3: Missing argument exits 1"
assert_stderr_contains "Usage" "$STDERR_OUTPUT" "3: Missing argument prints usage to stderr"
cleanup_temp_dir

# --- Test 4: Merge conflict — exits 1 with conflict message ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_git_repo "clean"
# Create a teammate branch that modifies committed-file.txt
git worktree add .claude/worktrees/conflict--worker -b conflict/worker HEAD 2>/dev/null
(cd .claude/worktrees/conflict--worker && echo "teammate change" > committed-file.txt && git add committed-file.txt && git commit -q -m "teammate edits file")
# Also modify committed-file.txt on the main branch to create a conflict
echo "main branch change" > committed-file.txt
git add committed-file.txt
git commit -q -m "main edits same file"
# Now merging conflict/worker should fail with a conflict
RESULT=$(bash "$SCRIPT" "conflict" 2>&1)
SCRIPT_EXIT=$?
assert_exit_code 1 "$SCRIPT_EXIT" "4: Merge conflict exits 1"
assert_stderr_contains "CONFLICT" "$RESULT" "4: Merge conflict prints CONFLICT to stderr"
assert_stderr_contains "conflict/worker" "$RESULT" "4: Merge conflict names the conflicting branch"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
