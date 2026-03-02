#!/bin/bash
# Tests for scripts/recover-context.sh (SessionStart compact hook)

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/recover-context.sh"

echo "SessionStart(compact) hook tests"
echo "================================="

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed\n"
  exit 0
fi

# --- Test 1: No workspace directory — outputs nothing, exits 0 ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
HOOK_STDOUT=$(echo '{"hook_event_name":"SessionStart","matcher":"compact","cwd":"'"$TEST_TEMP_DIR"'"}' | bash "$HOOK" 2>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "1: No workspace exits 0"
assert_true "1: No output when no workspace" '[ -z "$HOOK_STDOUT" ]'
cleanup_temp_dir

# --- Test 2: Active workspace — outputs summary ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "my-team"
# Status is already active from setup_mock_workspace
HOOK_STDOUT=$(echo '{"hook_event_name":"SessionStart","matcher":"compact","cwd":"'"$TEST_TEMP_DIR"'"}' | bash "$HOOK" 2>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "2: Active workspace exits 0"
assert_true "2: Output contains workspace path" 'echo "$HOOK_STDOUT" | grep -q ".agent-team/my-team"'
cleanup_temp_dir

# --- Test 3: Done workspace — no output (not active) ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "done-team"
sed -i.bak 's/\*\*Status\*\*: active/**Status**: done/' "$WORKSPACE_DIR/progress.md" 2>/dev/null || \
  sed -i '' 's/\*\*Status\*\*: active/**Status**: done/' "$WORKSPACE_DIR/progress.md"
HOOK_STDOUT=$(echo '{"hook_event_name":"SessionStart","matcher":"compact","cwd":"'"$TEST_TEMP_DIR"'"}' | bash "$HOOK" 2>/dev/null)
HOOK_EXIT=$?
assert_exit_code 0 "$HOOK_EXIT" "3: Done workspace exits 0"
assert_true "3: No output for done workspace" '[ -z "$HOOK_STDOUT" ]'
cleanup_temp_dir

# --- Test 4: Graceful degradation without jq ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
ORIG_PATH="$PATH"
SHADOW_BIN="$TEST_TEMP_DIR/shadow-bin"
mkdir -p "$SHADOW_BIN"
for bin_dir in /usr/bin /bin; do
  if [ -d "$bin_dir" ]; then
    for exe in "$bin_dir"/*; do
      base=$(basename "$exe")
      [ "$base" = "jq" ] && continue
      [ ! -e "$SHADOW_BIN/$base" ] && ln -sf "$exe" "$SHADOW_BIN/$base" 2>/dev/null || true
    done
  fi
done
HOOK_STDOUT=$(echo '{}' | PATH="$SHADOW_BIN" bash "$HOOK" 2>/dev/null)
HOOK_EXIT=$?
PATH="$ORIG_PATH"
assert_exit_code 0 "$HOOK_EXIT" "4: Graceful degradation without jq"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
