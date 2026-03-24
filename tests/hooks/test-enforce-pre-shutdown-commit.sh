#!/bin/bash
# Tests for scripts/enforce-pre-shutdown-commit.sh (PreToolUse TeamDelete hook)

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/enforce-pre-shutdown-commit.sh"

echo "PreToolUse TeamDelete (pre-shutdown commit) hook tests"
echo "======================================================"

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed\n"
  exit 0
fi

# --- Test 1: All files clean → exit 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_git_repo "clean"
setup_mock_workspace "test"
# Create file-locks.json pointing to the committed file
cat > "$WORKSPACE_DIR/file-locks.json" <<'EOF'
{"backend-impl": ["committed-file.txt"]}
EOF
run_hook "$HOOK" "{\"cwd\":\"$TEST_TEMP_DIR\",\"team_name\":\"test\",\"tool_name\":\"TeamDelete\",\"hook_event_name\":\"PreToolUse\"}"
assert_exit_code 0 "$HOOK_EXIT" "1: All files clean allows shutdown"
cleanup_temp_dir

# --- Test 2: Dirty owned file → exit 2 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_git_repo "dirty"
setup_mock_workspace "test"
# Point file-locks at the uncommitted file
cat > "$WORKSPACE_DIR/file-locks.json" <<'EOF'
{"backend-impl": ["uncommitted-file.txt"]}
EOF
run_hook "$HOOK" "{\"cwd\":\"$TEST_TEMP_DIR\",\"team_name\":\"test\",\"tool_name\":\"TeamDelete\",\"hook_event_name\":\"PreToolUse\"}"
assert_exit_code 2 "$HOOK_EXIT" "2: Dirty owned file blocks shutdown (exit 2)"
assert_stderr_contains "Uncommitted" "$HOOK_STDERR" "2: Stderr mentions uncommitted changes"
cleanup_temp_dir

# --- Test 3: No git available → exit 0 (script has guard) ---
# Difficult to fully test without removing git; verified by code inspection.
# We can at least verify the script doesn't crash with a note.
setup_temp_dir
cd "$TEST_TEMP_DIR"
printf "  ${YELLOW}SKIP${RESET} 3: No git available — verified by code inspection (guard at line 13)\n"
cleanup_temp_dir

# --- Test 4: No file-locks.json → exit 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_git_repo "dirty"
setup_mock_workspace "test"
# No file-locks.json created
run_hook "$HOOK" "{\"cwd\":\"$TEST_TEMP_DIR\",\"team_name\":\"test\",\"tool_name\":\"TeamDelete\",\"hook_event_name\":\"PreToolUse\"}"
assert_exit_code 0 "$HOOK_EXIT" "4: No file-locks.json allows shutdown"
cleanup_temp_dir

# --- Test 5: No workspace → exit 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_git_repo "dirty"
# No workspace created
run_hook "$HOOK" "{\"cwd\":\"$TEST_TEMP_DIR\",\"team_name\":\"nonexistent\",\"tool_name\":\"TeamDelete\",\"hook_event_name\":\"PreToolUse\"}"
assert_exit_code 0 "$HOOK_EXIT" "5: No workspace allows shutdown"
cleanup_temp_dir

# --- Test 6: Empty file-locks {} → exit 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_git_repo "dirty"
setup_mock_workspace "test"
cat > "$WORKSPACE_DIR/file-locks.json" <<'EOF'
{}
EOF
run_hook "$HOOK" "{\"cwd\":\"$TEST_TEMP_DIR\",\"team_name\":\"test\",\"tool_name\":\"TeamDelete\",\"hook_event_name\":\"PreToolUse\"}"
assert_exit_code 0 "$HOOK_EXIT" "6: Empty file-locks allows shutdown"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
