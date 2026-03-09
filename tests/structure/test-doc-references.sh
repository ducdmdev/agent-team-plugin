#!/bin/bash
# Tests for documentation integrity: frontmatter, doc cross-references, conventions

source "$(dirname "$0")/../lib/test-helpers.sh"

cd "$PROJECT_ROOT"

echo "Documentation reference tests"
echo "=============================="

# --- Tests 1-3: Loop over all skills/*/SKILL.md ---
for SKILL_MD in skills/*/SKILL.md; do
  SKILL_NAME=$(basename "$(dirname "$SKILL_MD")")
  SKILL_DIR=$(dirname "$SKILL_MD")

  # --- Test: SKILL.md has name field ---
  HAS_NAME=$(grep -c '^name:' "$SKILL_MD")
  assert_true "$SKILL_NAME: SKILL.md has name field in frontmatter" "[ $HAS_NAME -gt 0 ]"

  # --- Test: allowed-tools is comma-separated string (no brackets) ---
  ALLOWED_LINE=$(grep '^allowed-tools:' "$SKILL_MD")
  HAS_BRACKET=$(echo "$ALLOWED_LINE" | grep -c '[\[\]]')
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if [ -n "$ALLOWED_LINE" ] && [ "$HAS_BRACKET" -eq 0 ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "  ${GREEN}PASS${RESET} $SKILL_NAME: allowed-tools is plain comma-separated string\n"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "  ${RED}FAIL${RESET} $SKILL_NAME: allowed-tools has brackets or is missing\n"
    printf "        line: %s\n" "$ALLOWED_LINE"
  fi

  # --- Test: All relative doc refs in SKILL.md resolve ---
  REF_ERRORS=0
  while IFS= read -r ref_path; do
    # Strip any anchor fragment (e.g., file.md#section -> file.md)
    clean_path=$(echo "$ref_path" | sed 's/#.*//')
    # Resolve relative to SKILL.md's directory
    resolved="$SKILL_DIR/$clean_path"
    if [ ! -f "$resolved" ]; then
      printf "  missing: %s -> %s\n" "$ref_path" "$resolved"
      REF_ERRORS=$((REF_ERRORS + 1))
    fi
  done < <(grep -oE '\]\([^)]*\.md[^)]*\)' "$SKILL_MD" | sed 's/\](//;s/)$//')
  assert_true "$SKILL_NAME: All SKILL.md doc refs resolve ($REF_ERRORS missing)" "[ $REF_ERRORS -eq 0 ]"
done

# --- Test: docs/shared-phases.md exists ---
assert_true "shared-phases.md exists" "[ -f docs/shared-phases.md ]"

# --- Test: All relative refs in docs/shared-phases.md resolve ---
SP_REF_ERRORS=0
if [ -f docs/shared-phases.md ]; then
  while IFS= read -r ref_path; do
    # Skip absolute URLs
    if echo "$ref_path" | grep -qE '^https?://'; then
      continue
    fi
    # Strip any anchor fragment
    clean_path=$(echo "$ref_path" | sed 's/#.*//')
    resolved="docs/$clean_path"
    if [ ! -f "$resolved" ]; then
      printf "  missing: shared-phases.md:%s -> %s\n" "$ref_path" "$resolved"
      SP_REF_ERRORS=$((SP_REF_ERRORS + 1))
    fi
  done < <(grep -oE '\]\([^)]*\.md[^)]*\)' docs/shared-phases.md | sed 's/\](//;s/)$//')
fi
assert_true "shared-phases.md: All doc refs resolve ($SP_REF_ERRORS missing)" "[ $SP_REF_ERRORS -eq 0 ]"

# --- Test: All relative refs in docs/*.md resolve ---
DOC_REF_ERRORS=0
for doc in docs/*.md; do
  while IFS= read -r ref_path; do
    # Skip absolute URLs
    if echo "$ref_path" | grep -qE '^https?://'; then
      continue
    fi
    # Strip any anchor fragment
    clean_path=$(echo "$ref_path" | sed 's/#.*//')
    resolved="docs/$clean_path"
    if [ ! -f "$resolved" ]; then
      printf "  missing: %s:%s -> %s\n" "$doc" "$ref_path" "$resolved"
      DOC_REF_ERRORS=$((DOC_REF_ERRORS + 1))
    fi
  done < <(grep -oE '\]\([^)]*\.md\)' "$doc" 2>/dev/null | sed 's/\](//;s/)$//')
done
assert_true "All docs/*.md refs resolve ($DOC_REF_ERRORS missing)" "[ $DOC_REF_ERRORS -eq 0 ]"

# --- Test: Counter separator uses -- consistently ---
# The separator between team-name and teammate-name in counter files should be "--"
# Check script, SKILL.md, and coordination-patterns.md
SEPARATOR_MATCHES=0
SEPARATOR_EXPECTED=3

# Script: check-teammate-idle.sh
if grep -q '${TEAM}--${TEAMMATE}' scripts/check-teammate-idle.sh; then
  SEPARATOR_MATCHES=$((SEPARATOR_MATCHES + 1))
fi

# Any SKILL.md with separator reference
for SKILL_MD in skills/*/SKILL.md; do
  if grep -q '\-\-\*' "$SKILL_MD" 2>/dev/null || grep -q '{team-name}--' "$SKILL_MD" 2>/dev/null; then
    SEPARATOR_MATCHES=$((SEPARATOR_MATCHES + 1))
    break
  fi
done

# coordination-patterns.md
if grep -q '\-\-\*' docs/coordination-patterns.md 2>/dev/null || grep -q '{team-name}--' docs/coordination-patterns.md 2>/dev/null; then
  SEPARATOR_MATCHES=$((SEPARATOR_MATCHES + 1))
fi

assert_true "Counter separator '--' consistent across $SEPARATOR_MATCHES/$SEPARATOR_EXPECTED sources" "[ $SEPARATOR_MATCHES -ge 2 ]"

print_summary
exit "$TESTS_FAILED"
