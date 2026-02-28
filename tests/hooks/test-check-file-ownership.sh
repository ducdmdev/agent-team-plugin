#!/bin/bash
# Tests for scripts/check-file-ownership.sh (PreToolUse file ownership hook)

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/check-file-ownership.sh"

echo "PreToolUse file ownership hook tests"
echo "====================================="

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed\n"
  exit 0
fi

# Helper: create file-locks.json
create_file_locks() {
  local workspace_dir="$1"
  cat > "$workspace_dir/file-locks.json" <<'EOF'
{
  "backend-impl": ["src/auth/", "src/middleware/auth.ts"],
  "frontend-impl": ["src/components/", "src/pages/"]
}
EOF
}

# --- Test 1: No file-locks.json — allow (graceful degradation) ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/auth/login.ts"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "1: No file-locks.json allows (graceful degradation)"
cleanup_temp_dir

# --- Test 2: Teammate writes to owned file — allow ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
create_file_locks "$WORKSPACE_DIR"
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/auth/login.ts"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "2: Write to owned file allows"
cleanup_temp_dir

# --- Test 3: Teammate writes to unowned file — first violation warns ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
create_file_locks "$WORKSPACE_DIR"
# Clear any existing violation counters
rm -rf /tmp/agent-team-ownership-violations 2>/dev/null
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/components/Button.tsx"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "3: First violation warns (exit 0)"
assert_stderr_contains "ownership" "$HOOK_STDERR" "3: Warning message mentions ownership"
cleanup_temp_dir

# --- Test 4: Second violation on same file — blocks ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
create_file_locks "$WORKSPACE_DIR"
rm -rf /tmp/agent-team-ownership-violations 2>/dev/null
# First violation (warn)
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/components/Button.tsx"},"teammate_name":"backend-impl","team_name":"test"}'
# Second violation (block)
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/components/Button.tsx"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 2 "$HOOK_EXIT" "4: Second violation blocks (exit 2)"
cleanup_temp_dir

# --- Test 5: Workspace files always allowed ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
create_file_locks "$WORKSPACE_DIR"
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":".agent-team/test/tasks.md"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "5: Workspace file write always allowed"
cleanup_temp_dir

# --- Test 6: No teammate_name — allow (not a team context) ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"src/foo.ts"}}'
assert_exit_code 0 "$HOOK_EXIT" "6: No teammate_name allows"
cleanup_temp_dir

# --- Test 7: Directory ownership matches file inside directory ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
create_file_locks "$WORKSPACE_DIR"
run_hook "$HOOK" '{"tool_name":"Edit","tool_input":{"file_path":"src/auth/middleware/validate.ts"},"teammate_name":"backend-impl","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "7: File inside owned directory is allowed"
cleanup_temp_dir

# Cleanup violation counters
rm -rf /tmp/agent-team-ownership-violations 2>/dev/null

print_summary
exit "$TESTS_FAILED"
