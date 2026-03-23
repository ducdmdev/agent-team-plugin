#!/bin/bash
# Tests for documentation integrity: frontmatter, doc cross-references, conventions

source "$(dirname "$0")/../lib/test-helpers.sh"

cd "$PROJECT_ROOT"

echo "Documentation reference tests"
echo "=============================="

# --- Tests: Loop over all skills/*/SKILL.md ---
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

# --- Test: Pipeline stage skills exist ---
assert_true "skills/start/SKILL.md exists" "[ -f skills/start/SKILL.md ]"
assert_true "skills/plan/SKILL.md exists" "[ -f skills/plan/SKILL.md ]"
assert_true "skills/execute/SKILL.md exists" "[ -f skills/execute/SKILL.md ]"
assert_true "skills/audit/SKILL.md exists" "[ -f skills/audit/SKILL.md ]"

# --- Test: Stage skills have required subfolders ---
assert_true "skills/plan/references/ exists" "[ -d skills/plan/references ]"
assert_true "skills/plan/examples/ exists" "[ -d skills/plan/examples ]"
assert_true "skills/plan/agents/ exists" "[ -d skills/plan/agents ]"
assert_true "skills/execute/references/ exists" "[ -d skills/execute/references ]"
assert_true "skills/execute/agents/ exists" "[ -d skills/execute/agents ]"
assert_true "skills/audit/references/ exists" "[ -d skills/audit/references ]"
assert_true "skills/audit/examples/ exists" "[ -d skills/audit/examples ]"
assert_true "skills/audit/agents/ exists" "[ -d skills/audit/agents ]"

# --- Test: recovery_class in teammate-roles.md ---
RC_COUNT=$(grep -c 'Recovery class' docs/teammate-roles.md)
assert_true "teammate-roles.md has recovery_class entries" "[ $RC_COUNT -gt 0 ]"

# --- Test: Elegance Reviewer role in teammate-roles.md ---
ER_COUNT=$(grep -c 'Elegance Reviewer' docs/teammate-roles.md)
assert_true "teammate-roles.md has Elegance Reviewer role" "[ $ER_COUNT -gt 0 ]"

# --- Test: plan-mode defaults in team-archetypes.md ---
PM_COUNT=$(grep -c 'plan-mode\|Plan-Mode' docs/team-archetypes.md)
assert_true "team-archetypes.md has plan-mode defaults" "[ $PM_COUNT -gt 0 ]"

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
SEPARATOR_EXPECTED=2

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

# coordination-patterns in execute/references
if grep -q '\-\-\*' skills/execute/references/coordination-patterns.md 2>/dev/null || grep -q '{team-name}--' skills/execute/references/coordination-patterns.md 2>/dev/null; then
  SEPARATOR_MATCHES=$((SEPARATOR_MATCHES + 1))
fi

assert_true "Counter separator '--' consistent across $SEPARATOR_MATCHES/$SEPARATOR_EXPECTED sources" "[ $SEPARATOR_MATCHES -ge 2 ]"

# --- Test: workspace-templates.md references task-graph.json ---
TASK_GRAPH_REF=$(grep -c 'task-graph.json' docs/workspace-templates.md)
assert_true "workspace-templates.md references task-graph.json" "[ $TASK_GRAPH_REF -gt 0 ]"

# --- Test: DAG scripts referenced in docs ---
for script_name in compute-critical-path.sh detect-resume.sh check-integration-point.sh; do
  SCRIPT_REF=$(grep -rl "$script_name" docs/ skills/ | wc -l | tr -d ' ')
  assert_true "$script_name referenced in docs/ or skills/" "[ $SCRIPT_REF -gt 0 ]"
done

print_summary
exit "$TESTS_FAILED"
