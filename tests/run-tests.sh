#!/bin/bash
# Test runner for agent-team-plugin.
# Discovers and runs all tests/**/test-*.sh files.
# Optional filter: ./tests/run-tests.sh <pattern> — runs only matching files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

# Colors
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN=''
  RED=''
  BOLD=''
  RESET=''
fi

FILTER="${1:-}"
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_FILES=0
FAILED_FILES=()

# Discover test files
TEST_FILES=()
while IFS= read -r f; do
  if [ -n "$FILTER" ]; then
    if ! echo "$f" | grep -qi "$FILTER"; then
      continue
    fi
  fi
  TEST_FILES+=("$f")
done < <(find "$SCRIPT_DIR" -name 'test-*.sh' -type f -not -path '*/lib/*' | sort)

if [ ${#TEST_FILES[@]} -eq 0 ]; then
  echo "No test files found${FILTER:+ matching '$FILTER'}"
  exit 1
fi

echo ""
printf "${BOLD}Running %d test file(s)${RESET}\n" "${#TEST_FILES[@]}"
echo ""

for test_file in "${TEST_FILES[@]}"; do
  rel_path="${test_file#$SCRIPT_DIR/}"
  printf "%s--- %s ---%s\n" "$BOLD" "$rel_path" "$RESET"
  TOTAL_FILES=$((TOTAL_FILES + 1))

  # Run in subshell, capture exit code
  set +e
  bash "$test_file"
  file_exit=$?
  set -e

  if [ "$file_exit" -ne 0 ]; then
    TOTAL_FAIL=$((TOTAL_FAIL + file_exit))
    FAILED_FILES+=("$rel_path")
  fi
  echo ""
done

# Grand summary
echo "=============================="
printf "${BOLD}Test suite summary${RESET}\n"
printf "Files run: %d\n" "$TOTAL_FILES"

if [ ${#FAILED_FILES[@]} -eq 0 ]; then
  printf "${GREEN}${BOLD}All test files passed${RESET}\n"
  exit 0
else
  printf "${RED}${BOLD}%d file(s) with failures:${RESET}\n" "${#FAILED_FILES[@]}"
  for f in "${FAILED_FILES[@]}"; do
    printf "  ${RED}• %s${RESET}\n" "$f"
  done
  exit 1
fi
