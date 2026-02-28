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
