#!/bin/bash
# Tests for documentation integrity: frontmatter, doc cross-references, conventions

source "$(dirname "$0")/../lib/test-helpers.sh"

cd "$PROJECT_ROOT"

SKILL_MD="skills/agent-team/SKILL.md"

echo "Documentation reference tests"
echo "=============================="

# --- Test 1: SKILL.md has name field ---
HAS_NAME=$(grep -c '^name:' "$SKILL_MD")
assert_true "1: SKILL.md has name field in frontmatter" "[ $HAS_NAME -gt 0 ]"

# --- Test 2: allowed-tools is comma-separated string (no brackets) ---
ALLOWED_LINE=$(grep '^allowed-tools:' "$SKILL_MD")
HAS_BRACKET=$(echo "$ALLOWED_LINE" | grep -c '[\[\]]')
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if [ -n "$ALLOWED_LINE" ] && [ "$HAS_BRACKET" -eq 0 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "  ${GREEN}PASS${RESET} 2: allowed-tools is plain comma-separated string\n"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "  ${RED}FAIL${RESET} 2: allowed-tools has brackets or is missing\n"
  printf "        line: %s\n" "$ALLOWED_LINE"
fi

# --- Test 3: All relative doc refs in SKILL.md resolve ---
REF_ERRORS=0
while IFS= read -r ref_path; do
  # Resolve relative to SKILL.md's directory
  resolved="skills/agent-team/$ref_path"
  if [ ! -f "$resolved" ]; then
    printf "  missing: %s -> %s\n" "$ref_path" "$resolved"
    REF_ERRORS=$((REF_ERRORS + 1))
  fi
done < <(grep -oE '\]\([^)]*\.md\)' "$SKILL_MD" | sed 's/\](//;s/)$//')
assert_true "3: All SKILL.md doc refs resolve ($REF_ERRORS missing)" "[ $REF_ERRORS -eq 0 ]"

# --- Test 4: All relative refs in docs/*.md resolve ---
DOC_REF_ERRORS=0
for doc in docs/*.md; do
  while IFS= read -r ref_path; do
    # Skip absolute URLs
    if echo "$ref_path" | grep -qE '^https?://'; then
      continue
    fi
    resolved="docs/$ref_path"
    if [ ! -f "$resolved" ]; then
      printf "  missing: %s:%s -> %s\n" "$doc" "$ref_path" "$resolved"
      DOC_REF_ERRORS=$((DOC_REF_ERRORS + 1))
    fi
  done < <(grep -oE '\]\([^)]*\.md\)' "$doc" 2>/dev/null | sed 's/\](//;s/)$//')
done
assert_true "4: All docs/*.md refs resolve ($DOC_REF_ERRORS missing)" "[ $DOC_REF_ERRORS -eq 0 ]"

# --- Test 5: Counter separator uses -- consistently ---
# The separator between team-name and teammate-name in counter files should be "--"
# Check script, SKILL.md, and coordination-patterns.md
SEPARATOR_MATCHES=0
SEPARATOR_EXPECTED=3

# Script: check-teammate-idle.sh
if grep -q '${TEAM}--${TEAMMATE}' scripts/check-teammate-idle.sh; then
  SEPARATOR_MATCHES=$((SEPARATOR_MATCHES + 1))
fi

# SKILL.md cleanup reference
if grep -q '\-\-\*' "$SKILL_MD" 2>/dev/null || grep -q '{team-name}--' "$SKILL_MD" 2>/dev/null; then
  SEPARATOR_MATCHES=$((SEPARATOR_MATCHES + 1))
fi

# coordination-patterns.md
if grep -q '\-\-\*' docs/coordination-patterns.md 2>/dev/null || grep -q '{team-name}--' docs/coordination-patterns.md 2>/dev/null; then
  SEPARATOR_MATCHES=$((SEPARATOR_MATCHES + 1))
fi

assert_true "5: Counter separator '--' consistent across $SEPARATOR_MATCHES/$SEPARATOR_EXPECTED sources" "[ $SEPARATOR_MATCHES -ge 2 ]"

print_summary
exit "$TESTS_FAILED"
