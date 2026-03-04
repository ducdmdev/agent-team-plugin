#!/bin/bash
# Tests for scripts/verify-task-complete.sh (TaskCompleted hook)

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/verify-task-complete.sh"

echo "TaskCompleted hook tests"
echo "========================"

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed (hooks degrade gracefully without it)\n"
  exit 0
fi

# --- Test 1: Empty subject skips all checks ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"task_subject":""}'
assert_exit_code 0 "$HOOK_EXIT" "1: Empty subject skips all checks"
cleanup_temp_dir

# --- Test 2: No team_name skips workspace check ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"task_subject":"Build feature"}'
assert_exit_code 0 "$HOOK_EXIT" "2: No team_name skips workspace check"
cleanup_temp_dir

# --- Test 3: Missing workspace blocks ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"task_subject":"Build feature","team_name":"no-exist"}'
assert_exit_code 2 "$HOOK_EXIT" "3: Missing workspace blocks (exit code)"
assert_stderr_contains "Workspace missing" "$HOOK_STDERR" "3: Missing workspace blocks (stderr)"
cleanup_temp_dir

# --- Test 4: Workspace exists but missing files blocks ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
mkdir -p ".agent-team/test"
echo "# progress" > ".agent-team/test/progress.md"
# tasks.md and issues.md are missing
run_hook "$HOOK" '{"task_subject":"Build something","team_name":"test"}'
assert_exit_code 2 "$HOOK_EXIT" "4: Workspace with missing files blocks (exit code)"
assert_stderr_contains "file missing" "$HOOK_STDERR" "4: Workspace with missing files blocks (stderr)"
cleanup_temp_dir

# --- Test 5: Complete workspace + impl task + no git changes blocks ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_git_repo "clean"
run_hook "$HOOK" '{"task_subject":"Implement auth","team_name":"test"}'
assert_exit_code 2 "$HOOK_EXIT" "5: Impl task with no git changes blocks (exit code)"
assert_stderr_contains "no file changes" "$HOOK_STDERR" "5: Impl task with no git changes blocks (stderr)"
cleanup_temp_dir

# --- Test 6: Complete workspace + impl task + git changes allows ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_git_repo "dirty"
run_hook "$HOOK" '{"task_subject":"Implement auth","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "6: Impl task with git changes allows"
cleanup_temp_dir

# --- Test 7: Workspace-only task (audit/review) skips git check ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_git_repo "clean"
run_hook "$HOOK" '{"task_subject":"Review code quality","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "7: Workspace-only task skips git check"
cleanup_temp_dir

# --- Test 8: Malformed JSON degrades gracefully ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" 'not-json'
assert_exit_code 0 "$HOOK_EXIT" "8: Malformed JSON degrades gracefully"
cleanup_temp_dir

# --- Test 9: Graceful degradation when jq is not installed ---
# Temporarily hide jq from PATH to simulate it not being installed
setup_temp_dir
cd "$TEST_TEMP_DIR"
ORIG_PATH="$PATH"
# Create a minimal PATH that excludes jq but keeps bash builtins working
MINIMAL_PATH=""
for p in /usr/bin /bin; do
  [ -d "$p" ] && MINIMAL_PATH="${MINIMAL_PATH:+$MINIMAL_PATH:}$p"
done
# Remove any directory containing jq from PATH
FILTERED_PATH=""
IFS=':' read -ra DIRS <<< "$MINIMAL_PATH"
for d in "${DIRS[@]}"; do
  if [ ! -x "$d/jq" ]; then
    FILTERED_PATH="${FILTERED_PATH:+$FILTERED_PATH:}$d"
  fi
done
# If jq is in /usr/bin or /bin, create a shadow bin dir without jq
if [ -z "$FILTERED_PATH" ] || command -v jq &>/dev/null; then
  SHADOW_BIN="$TEST_TEMP_DIR/shadow-bin"
  mkdir -p "$SHADOW_BIN"
  # Symlink all executables except jq
  for bin_dir in /usr/bin /bin; do
    if [ -d "$bin_dir" ]; then
      for exe in "$bin_dir"/*; do
        base=$(basename "$exe")
        [ "$base" = "jq" ] && continue
        [ ! -e "$SHADOW_BIN/$base" ] && ln -sf "$exe" "$SHADOW_BIN/$base" 2>/dev/null || true
      done
    fi
  done
  FILTERED_PATH="$SHADOW_BIN"
fi
HOOK_STDERR=$(echo '{"task_subject":"Build feature","team_name":"test"}' | PATH="$FILTERED_PATH" bash "$HOOK" 2>&1 1>/dev/null)
HOOK_EXIT=$?
PATH="$ORIG_PATH"
assert_exit_code 0 "$HOOK_EXIT" "9: Graceful degradation when jq is not installed"
cleanup_temp_dir

# --- Test 10: Legacy workspace fallback allows when progress.md exists ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
# Don't create .agent-team/legacy-test (primary path), only the legacy fallback
LEGACY_DIR="$HOME/.claude/teams/legacy-test"
mkdir -p "$LEGACY_DIR"
echo "# progress" > "$LEGACY_DIR/progress.md"
setup_mock_git_repo "dirty"
run_hook "$HOOK" '{"task_subject":"Implement feature","team_name":"legacy-test"}'
LEGACY_ALLOW_EXIT=$HOOK_EXIT
# Cleanup legacy dir
rm -rf "$LEGACY_DIR"
rmdir "$HOME/.claude/teams" 2>/dev/null || true
assert_exit_code 0 "$LEGACY_ALLOW_EXIT" "10: Legacy workspace fallback allows when progress.md exists"
cleanup_temp_dir

# --- Test 11: Legacy workspace fallback blocks when progress.md missing ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
# Neither .agent-team/legacy-test nor legacy fallback exist
run_hook "$HOOK" '{"task_subject":"Build feature","team_name":"legacy-test"}'
assert_exit_code 2 "$HOOK_EXIT" "11: Legacy workspace fallback blocks when progress.md missing"
assert_stderr_contains "Workspace missing" "$HOOK_STDERR" "11: Legacy workspace fallback blocks (stderr)"
cleanup_temp_dir

# --- Test 12: Remediation team (-fix suffix) finds original workspace ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "my-project"   # workspace at .agent-team/my-project/
setup_mock_git_repo "dirty"
run_hook "$HOOK" '{"task_subject":"Fix README issues","team_name":"my-project-fix"}'
assert_exit_code 0 "$HOOK_EXIT" "12: Remediation team (-fix suffix) finds original workspace"
cleanup_temp_dir

# --- Test 13: teammate_name scopes git check to owned files ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
# Create file-locks.json
cat > "$WORKSPACE_DIR/file-locks.json" <<'LOCKS'
{"backend-impl": ["src/auth/"]}
LOCKS
setup_mock_git_repo "dirty"
# Add a dirty file inside the owned path so scoped check finds changes
mkdir -p src/auth
echo "change" > src/auth/login.ts
run_hook "$HOOK" '{"task_subject":"Implement auth","team_name":"test","task_id":"task-001","teammate_name":"backend-impl"}'
# Should pass because there are dirty files in the owned path (src/auth/)
assert_exit_code 0 "$HOOK_EXIT" "13: Enhanced hook reads task_id and teammate_name"
cleanup_temp_dir

# --- Test 14: Impl keyword task with workspace output allows ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
setup_mock_workspace "test"
setup_mock_git_repo "clean"
echo "# Report" > ".agent-team/test/report.md"
run_hook "$HOOK" '{"task_subject":"Write verification report","team_name":"test"}'
assert_exit_code 0 "$HOOK_EXIT" "14: Impl keyword task with workspace output allows"
cleanup_temp_dir

print_summary
exit "$TESTS_FAILED"
