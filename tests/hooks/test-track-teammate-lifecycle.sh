#!/bin/bash
# Tests for scripts/track-teammate-lifecycle.sh

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/track-teammate-lifecycle.sh"

echo "SubagentStart/Stop lifecycle hook tests"
echo "========================================"

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed\n"
  exit 0
fi

# --- Test 1: SubagentStart appends to events.log ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
HOOK_STDERR=$(echo '{"hook_event_name":"SubagentStart","teammate_name":"backend-impl","team_name":"test","agent_type":"general-purpose"}' | bash "$HOOK" 2>&1 1>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "1: SubagentStart exits 0"
assert_true "1: events.log created" '[ -f ".agent-team/test/events.log" ]'
assert_true "1: events.log contains spawn entry" 'grep -q "spawn" ".agent-team/test/events.log"'
cleanup_temp_dir

# --- Test 2: SubagentStop appends to events.log ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
echo '{"ts":"2026-01-01T00:00:00Z","type":"spawn","agent":"backend-impl"}' > ".agent-team/test/events.log"
HOOK_STDERR=$(echo '{"hook_event_name":"SubagentStop","teammate_name":"backend-impl","team_name":"test"}' | bash "$HOOK" 2>&1 1>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "2: SubagentStop exits 0"
assert_true "2: events.log has 2 entries" '[ "$(wc -l < .agent-team/test/events.log | tr -d " ")" -ge 2 ]'
assert_true "2: events.log contains stop entry" 'grep -q "stop" ".agent-team/test/events.log"'
cleanup_temp_dir

# --- Test 3: No team_name — exits 0 silently ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
HOOK_STDERR=$(echo '{"hook_event_name":"SubagentStart","teammate_name":"test"}' | bash "$HOOK" 2>&1 1>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "3: No team_name exits 0"
cleanup_temp_dir

# --- Test 4: No workspace — exits 0 silently ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
HOOK_STDERR=$(echo '{"hook_event_name":"SubagentStart","teammate_name":"impl","team_name":"nonexistent"}' | bash "$HOOK" 2>&1 1>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "4: No workspace exits 0"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
