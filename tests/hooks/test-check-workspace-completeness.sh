#!/bin/bash
# Tests for scripts/check-workspace-completeness.sh (SubagentStart hook)
# Validates workspace has minimum required files and fields before teammate spawn

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/check-workspace-completeness.sh"

echo "CheckWorkspaceCompleteness hook tests"
echo "======================================"

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed (hooks degrade gracefully without it)\n"
  exit 0
fi

# --- Test 1: Complete workspace — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
setup_mock_task_graph "test-team"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 0 "$HOOK_EXIT" "1: Allow complete workspace"
cleanup_temp_dir

# --- Test 2: Missing progress.md — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
setup_mock_task_graph "test-team"
rm "$WORKSPACE_DIR/progress.md"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 2 "$HOOK_EXIT" "2: Block missing progress.md"
assert_stderr_contains "progress.md" "$HOOK_STDERR" "2: Error mentions progress.md"
cleanup_temp_dir

# --- Test 3: Missing Archetype field — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
setup_mock_task_graph "test-team"
cat > "$WORKSPACE_DIR/progress.md" <<'EOF'
# Team: test

**Task**: test task
**Status**: active
EOF
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 2 "$HOOK_EXIT" "3: Block missing Archetype field"
assert_stderr_contains "Archetype" "$HOOK_STDERR" "3: Error mentions Archetype"
cleanup_temp_dir

# --- Test 4: Missing tasks.md — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
setup_mock_task_graph "test-team"
rm "$WORKSPACE_DIR/tasks.md"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 2 "$HOOK_EXIT" "4: Block missing tasks.md"
assert_stderr_contains "tasks.md" "$HOOK_STDERR" "4: Error mentions tasks.md"
cleanup_temp_dir

# --- Test 5: Empty tasks.md (1 line only) — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
setup_mock_task_graph "test-team"
echo "# Tasks" > "$WORKSPACE_DIR/tasks.md"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 2 "$HOOK_EXIT" "5: Block empty tasks.md"
assert_stderr_contains "empty" "$HOOK_STDERR" "5: Error mentions empty"
cleanup_temp_dir

# --- Test 6: Missing issues.md — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
setup_mock_task_graph "test-team"
rm "$WORKSPACE_DIR/issues.md"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 2 "$HOOK_EXIT" "6: Block missing issues.md"
assert_stderr_contains "issues.md" "$HOOK_STDERR" "6: Error mentions issues.md"
cleanup_temp_dir

# --- Test 7: Missing task-graph.json — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
# Deliberately NOT calling setup_mock_task_graph
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 2 "$HOOK_EXIT" "7: Block missing task-graph.json"
assert_stderr_contains "task-graph.json" "$HOOK_STDERR" "7: Error mentions task-graph.json"
cleanup_temp_dir

# --- Test 8: Invalid Pipeline status — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
setup_mock_task_graph "test-team"
cat > "$WORKSPACE_DIR/progress.md" <<'EOF'
# Team: test

**Task**: test task
**Status**: active
**Archetype**: implementation
**Pipeline status**: bogus
EOF
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 2 "$HOOK_EXIT" "8: Block invalid Pipeline status"
assert_stderr_contains "invalid" "$HOOK_STDERR" "8: Error mentions invalid"
cleanup_temp_dir

# --- Test 9: No workspace directory — allow (exit 0) ---
setup_temp_dir
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"nonexistent-team","hook_event_name":"SubagentStart"}'
assert_exit_code 0 "$HOOK_EXIT" "9: Allow when no workspace directory"
cleanup_temp_dir

# --- Test 10: Valid Pipeline status "approved" — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
setup_mock_task_graph "test-team"
cat > "$WORKSPACE_DIR/progress.md" <<'EOF'
# Team: test

**Task**: test task
**Status**: active
**Archetype**: implementation
**Pipeline status**: approved
EOF
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","hook_event_name":"SubagentStart"}'
assert_exit_code 0 "$HOOK_EXIT" "10: Allow valid Pipeline status 'approved'"
cleanup_temp_dir

# --- Test 11: Team with -fix suffix — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
setup_mock_task_graph "test-team"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team-fix","hook_event_name":"SubagentStart"}'
assert_exit_code 0 "$HOOK_EXIT" "11: Allow -fix suffix team (falls back to base workspace)"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
