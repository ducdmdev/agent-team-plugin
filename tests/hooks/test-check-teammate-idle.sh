#!/bin/bash
# Tests for scripts/check-teammate-idle.sh (TeammateIdle hook)

source "$(dirname "$0")/../lib/test-helpers.sh"

HOOK="$PROJECT_ROOT/scripts/check-teammate-idle.sh"
COUNTER_DIR="/tmp/agent-team-idle-counters"

# Clean up counters before running tests
rm -rf "$COUNTER_DIR"

echo "TeammateIdle hook tests"
echo "========================"

if ! command -v jq &>/dev/null; then
  printf "  ${YELLOW}SKIP${RESET} all — jq not installed (hooks degrade gracefully without it)\n"
  exit 0
fi

# --- Test 1: Empty teammate skips ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"teammate_name":"","team_name":"t"}'
assert_exit_code 0 "$HOOK_EXIT" "1: Empty teammate skips"
cleanup_temp_dir

# --- Test 2: Empty team skips ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"teammate_name":"alice","team_name":""}'
assert_exit_code 0 "$HOOK_EXIT" "2: Empty team skips"
cleanup_temp_dir

# --- Test 3: No tasks.md allows idle ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" '{"teammate_name":"alice","team_name":"t"}'
assert_exit_code 0 "$HOOK_EXIT" "3: No tasks.md allows idle"
cleanup_temp_dir

# --- Test 4: Teammate with in-progress task blocks ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
mkdir -p ".agent-team/t"
cat > ".agent-team/t/tasks.md" <<'EOF'
# Tasks: t

**Last updated**: 2026-01-01

## In Progress

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
| 1 | Build feature | alice | working on it |

## Blocked

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Pending

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Completed

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
EOF
rm -f "$COUNTER_DIR/t--alice"
run_hook "$HOOK" '{"teammate_name":"alice","team_name":"t"}'
assert_exit_code 2 "$HOOK_EXIT" "4: In-progress task blocks (exit code)"
assert_stderr_contains "in progress" "$HOOK_STDERR" "4: In-progress task blocks (stderr)"
cleanup_temp_dir

# --- Test 5: Teammate with completed tasks allows ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
mkdir -p ".agent-team/t"
cat > ".agent-team/t/tasks.md" <<'EOF'
# Tasks: t

**Last updated**: 2026-01-01

## In Progress

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|

## Blocked

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Pending

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Completed

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
| 1 | Build feature | alice | done |
EOF
rm -f "$COUNTER_DIR/t--alice"
run_hook "$HOOK" '{"teammate_name":"alice","team_name":"t"}'
assert_exit_code 0 "$HOOK_EXIT" "5: Completed tasks allows idle"
cleanup_temp_dir

# --- Test 6: Loop protection — 4th attempt allows ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
mkdir -p ".agent-team/t"
cat > ".agent-team/t/tasks.md" <<'EOF'
# Tasks: t

**Last updated**: 2026-01-01

## In Progress

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
| 1 | Build feature | alice | stuck |

## Blocked

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Pending

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Completed

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
EOF
rm -f "$COUNTER_DIR/t--alice"

# Attempts 1-3 should block
for attempt in 1 2 3; do
  run_hook "$HOOK" '{"teammate_name":"alice","team_name":"t"}'
  assert_exit_code 2 "$HOOK_EXIT" "6: Loop protection — attempt $attempt blocks"
done

# Attempt 4 should allow (counter >= MAX_RETRIES)
run_hook "$HOOK" '{"teammate_name":"alice","team_name":"t"}'
assert_exit_code 0 "$HOOK_EXIT" "6: Loop protection — attempt 4 allows"
cleanup_temp_dir

# --- Test 7: Counter reset on no tasks ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
mkdir -p ".agent-team/t"

# First, create an in-progress task and block once to create a counter
cat > ".agent-team/t/tasks.md" <<'EOF'
# Tasks: t

**Last updated**: 2026-01-01

## In Progress

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
| 1 | Build feature | alice | stuck |

## Blocked

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Pending

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Completed

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
EOF
rm -f "$COUNTER_DIR/t--alice"
run_hook "$HOOK" '{"teammate_name":"alice","team_name":"t"}'
# Counter file should exist now
assert_true "7: Counter file created" "[ -f '$COUNTER_DIR/t--alice' ]"

# Now change task to completed (move from In Progress to Completed section)
cat > ".agent-team/t/tasks.md" <<'EOF'
# Tasks: t

**Last updated**: 2026-01-01

## In Progress

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|

## Blocked

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Pending

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Completed

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
| 1 | Build feature | alice | done |
EOF
run_hook "$HOOK" '{"teammate_name":"alice","team_name":"t"}'
assert_exit_code 0 "$HOOK_EXIT" "7: Counter reset — allows idle"
assert_true "7: Counter file removed" "[ ! -f '$COUNTER_DIR/t--alice' ]"
cleanup_temp_dir

# --- Test 8: Malformed JSON degrades gracefully ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
run_hook "$HOOK" 'not-json'
assert_exit_code 0 "$HOOK_EXIT" "8: Malformed JSON degrades gracefully"
cleanup_temp_dir

# --- Test 9: Remediation team (-fix suffix) finds original workspace ---
setup_temp_dir
cd "$TEST_TEMP_DIR"
# Create workspace at .agent-team/my-project/ (the original team)
setup_mock_workspace "my-project"
# Overwrite tasks.md with an in-progress task owned by the teammate
cat > "$WORKSPACE_DIR/tasks.md" <<'EOF'
# Tasks: test

**Last updated**: 2026-01-01

## In Progress

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
| 1 | Fix something | test-impl | — |

## Blocked

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Pending

| ID | Subject | Owner | Blocked By | Notes |
|----|---------|-------|-----------|-------|

## Completed

| ID | Subject | Owner | Notes |
|----|---------|-------|-------|
EOF
rm -f "$COUNTER_DIR/my-project-fix--test-impl"
run_hook "$HOOK" '{"teammate_name":"test-impl","team_name":"my-project-fix"}'
assert_exit_code 2 "$HOOK_EXIT" "9: Remediation team (-fix) finds original workspace and blocks idle"
cleanup_temp_dir

# Final cleanup
rm -rf "$COUNTER_DIR"

print_summary
exit "$TESTS_FAILED"
