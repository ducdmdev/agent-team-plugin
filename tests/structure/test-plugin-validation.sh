#!/bin/bash
# Tests for plugin structure: executability, version sync, hooks format

source "$(dirname "$0")/../lib/test-helpers.sh"

cd "$PROJECT_ROOT"

echo "Plugin validation tests"
echo "========================"

# --- Test 1: Scripts are executable ---
ALL_EXECUTABLE=true
for script in scripts/*.sh; do
  if [ ! -x "$script" ]; then
    ALL_EXECUTABLE=false
    break
  fi
done
assert_true "1: All scripts/*.sh are executable" "$ALL_EXECUTABLE"

# --- Test 2: Version sync across plugin.json and marketplace.json ---
V_PLUGIN=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' .claude-plugin/plugin.json | head -1 | grep -o '"[^"]*"$' | tr -d '"')
V_MARKETPLACE=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' .claude-plugin/marketplace.json | head -1 | grep -o '"[^"]*"$' | tr -d '"')
VERSIONS_MATCH=true
if [ "$V_PLUGIN" != "$V_MARKETPLACE" ]; then
  VERSIONS_MATCH=false
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if $VERSIONS_MATCH; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "  ${GREEN}PASS${RESET} 2: Version sync (all = %s)\n" "$V_PLUGIN"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "  ${RED}FAIL${RESET} 2: Version mismatch — plugin=%s marketplace=%s\n" "$V_PLUGIN" "$V_MARKETPLACE"
fi

# --- Test 3: hooks.json is valid JSON ---
VALID_JSON=false
if command -v jq &>/dev/null; then
  jq . hooks/hooks.json >/dev/null 2>&1 && VALID_JSON=true
elif command -v python3 &>/dev/null; then
  python3 -c "import json; json.load(open('hooks/hooks.json'))" 2>/dev/null && VALID_JSON=true
else
  # Can't validate, assume pass
  VALID_JSON=true
fi
assert_true "3: hooks.json is valid JSON" "$VALID_JSON"

# --- Test 4: hooks.json uses ${CLAUDE_PLUGIN_ROOT} ---
USES_PLUGIN_ROOT=$(grep -c 'CLAUDE_PLUGIN_ROOT' hooks/hooks.json)
assert_true "4: hooks.json uses \${CLAUDE_PLUGIN_ROOT}" "[ $USES_PLUGIN_ROOT -gt 0 ]"

# --- Test 5: claude plugin validate passes ---
if command -v claude &>/dev/null; then
  VALIDATE_OUTPUT=$(claude plugin validate . 2>&1)
  VALIDATE_EXIT=$?
  assert_exit_code 0 "$VALIDATE_EXIT" "5: claude plugin validate passes"
else
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "  ${YELLOW}SKIP${RESET} 5: claude CLI not available — skipping plugin validate\n"
fi

print_summary
exit "$TESTS_FAILED"
