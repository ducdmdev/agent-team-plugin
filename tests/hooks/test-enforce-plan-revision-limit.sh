#!/bin/bash
# Tests for scripts/enforce-plan-revision-limit.sh (PreToolUse(SendMessage) hook)
# Enforces max 2 plan-mode revision rounds per teammate

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/enforce-plan-revision-limit.sh"

echo "EnforcePlanRevisionLimit hook tests"
echo "===================================="

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed (hooks degrade gracefully without it)\n"
  exit 0
fi

# --- Test 1: Non-PLAN_REVISION message — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","tool_name":"SendMessage","tool_input":{"to":"auth-impl-1","message":"Please start working on task #1"},"hook_event_name":"PreToolUse"}'
assert_exit_code 0 "$HOOK_EXIT" "1: Allow non-PLAN_REVISION message"
cleanup_temp_dir

# --- Test 2: First revision (count=0 in table) — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
cat > "$WORKSPACE_DIR/progress.md" <<'EOF'
# Team: test

**Task**: test task
**Status**: active
**Archetype**: implementation

## Plan Proposals
| Teammate | Task | Proposal | Status | Revisions |
|----------|------|----------|--------|-----------|
| auth-impl-1 | #1 | Adapter pattern | Revision requested | 0 |
EOF
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","tool_name":"SendMessage","tool_input":{"to":"auth-impl-1","message":"PLAN_REVISION #1: please use factory pattern instead"},"hook_event_name":"PreToolUse"}'
assert_exit_code 0 "$HOOK_EXIT" "2: Allow first revision (count=0)"
cleanup_temp_dir

# --- Test 3: Second revision (count=1) — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
cat > "$WORKSPACE_DIR/progress.md" <<'EOF'
# Team: test

**Task**: test task
**Status**: active
**Archetype**: implementation

## Plan Proposals
| Teammate | Task | Proposal | Status | Revisions |
|----------|------|----------|--------|-----------|
| auth-impl-1 | #1 | Adapter pattern | Revision requested | 1 |
EOF
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","tool_name":"SendMessage","tool_input":{"to":"auth-impl-1","message":"PLAN_REVISION #1: still needs work on error handling"},"hook_event_name":"PreToolUse"}'
assert_exit_code 0 "$HOOK_EXIT" "3: Allow second revision (count=1)"
cleanup_temp_dir

# --- Test 4: Third revision (count=2) — block (exit 2) ---
setup_temp_dir
setup_mock_workspace "test-team"
cat > "$WORKSPACE_DIR/progress.md" <<'EOF'
# Team: test

**Task**: test task
**Status**: active
**Archetype**: implementation

## Plan Proposals
| Teammate | Task | Proposal | Status | Revisions |
|----------|------|----------|--------|-----------|
| auth-impl-1 | #1 | Adapter pattern | Revision requested | 2 |
EOF
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","tool_name":"SendMessage","tool_input":{"to":"auth-impl-1","message":"PLAN_REVISION #1: one more tweak needed"},"hook_event_name":"PreToolUse"}'
assert_exit_code 2 "$HOOK_EXIT" "4: Block third revision (count=2)"
assert_stderr_contains "revision limit" "$HOOK_STDERR" "4: Error mentions revision limit"
cleanup_temp_dir

# --- Test 5: No workspace — allow (exit 0) ---
setup_temp_dir
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"nonexistent-team","tool_name":"SendMessage","tool_input":{"to":"auth-impl-1","message":"PLAN_REVISION #1: feedback"},"hook_event_name":"PreToolUse"}'
assert_exit_code 0 "$HOOK_EXIT" "5: Allow when no workspace exists"
cleanup_temp_dir

# --- Test 6: No Plan Proposals table — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
# Default progress.md from setup_mock_workspace has no Plan Proposals table
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","tool_name":"SendMessage","tool_input":{"to":"auth-impl-1","message":"PLAN_REVISION #1: feedback"},"hook_event_name":"PreToolUse"}'
assert_exit_code 0 "$HOOK_EXIT" "6: Allow when no Plan Proposals table"
cleanup_temp_dir

# --- Test 7: Teammate not in table — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
cat > "$WORKSPACE_DIR/progress.md" <<'EOF'
# Team: test

**Task**: test task
**Status**: active
**Archetype**: implementation

## Plan Proposals
| Teammate | Task | Proposal | Status | Revisions |
|----------|------|----------|--------|-----------|
| auth-impl-1 | #1 | Adapter pattern | Revision requested | 2 |
EOF
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","tool_name":"SendMessage","tool_input":{"to":"session-impl-2","message":"PLAN_REVISION #2: feedback"},"hook_event_name":"PreToolUse"}'
assert_exit_code 0 "$HOOK_EXIT" "7: Allow when teammate not in table"
cleanup_temp_dir

# --- Test 8: Malformed progress.md — allow (exit 0) ---
setup_temp_dir
setup_mock_workspace "test-team"
echo "this is not a valid markdown file with no table structure at all" > "$WORKSPACE_DIR/progress.md"
run_hook "$HOOK" '{"cwd":"'"$TEST_TEMP_DIR"'","team_name":"test-team","tool_name":"SendMessage","tool_input":{"to":"auth-impl-1","message":"PLAN_REVISION #1: feedback"},"hook_event_name":"PreToolUse"}'
assert_exit_code 0 "$HOOK_EXIT" "8: Allow when progress.md is malformed"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
