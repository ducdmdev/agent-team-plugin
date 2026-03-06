#!/bin/bash
# Record a terminal demo GIF for the README
#
# Prerequisites:
#   brew install asciinema
#   pip install asciinema-agg   # converts .cast to .gif
#
# Usage:
#   bash scripts/record-demo.sh          # generates demo.cast
#   agg demo.cast demo.gif --cols 90 --rows 30 --speed 2  # convert to GIF
#
# Alternative: use https://asciinema.org to host and embed
#
# This script simulates a terminal session showing agent-team in action.
# It types commands and outputs with realistic timing.

set -e

CAST_FILE="demo.cast"

# Check for asciinema
if ! command -v asciinema &> /dev/null; then
    echo "asciinema not found. Install with: brew install asciinema"
    echo ""
    echo "Alternative: run this script manually and screen-record it."
    echo "The script will simulate the demo with realistic typing delays."
    echo ""
    read -p "Run the visual simulation instead? [y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    SIMULATE=true
else
    SIMULATE=false
fi

# Typing simulation
type_text() {
    local text="$1"
    local delay="${2:-0.04}"
    for (( i=0; i<${#text}; i++ )); do
        printf '%s' "${text:$i:1}"
        sleep "$delay"
    done
}

pause() {
    sleep "${1:-1}"
}

clear_screen() {
    printf '\033[2J\033[H'
}

# Colors
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
BLUE='\033[34m'
YELLOW='\033[33m'
CYAN='\033[36m'
MAGENTA='\033[35m'
RESET='\033[0m'

run_demo() {
    clear_screen

    # Prompt
    printf "${BOLD}$${RESET} "
    type_text "claude" 0.06
    pause 0.5
    echo ""
    pause 1

    # User input
    printf "\n${BOLD}You >${RESET} "
    type_text "use agent team to refactor the auth module into separate concerns" 0.03
    echo ""
    pause 1.5

    # Phase 1
    printf "\n${BLUE}${BOLD}Phase 1 - Analyze${RESET}\n"
    pause 0.5
    printf "${DIM}  Scanning project structure...${RESET}\n"
    pause 0.8
    printf "  Found 3 independent streams:\n"
    pause 0.3
    printf "    ${GREEN}1.${RESET} Token validation    ${DIM}(src/auth/token.ts, src/auth/validate.ts)${RESET}\n"
    pause 0.2
    printf "    ${GREEN}2.${RESET} Session management  ${DIM}(src/auth/session.ts, src/auth/store.ts)${RESET}\n"
    pause 0.2
    printf "    ${GREEN}3.${RESET} Middleware layer     ${DIM}(src/middleware/auth.ts)${RESET}\n"
    pause 0.3
    printf "  ${GREEN}No file overlaps detected${RESET}\n"
    pause 1

    # Phase 2
    printf "\n${BLUE}${BOLD}Phase 2 - Plan${RESET}\n"
    pause 0.5
    printf "  Team type: ${CYAN}implementation${RESET} (auto-detected)\n"
    pause 0.3
    printf "  Proposed team:\n"
    printf "    ${MAGENTA}auth-impl-1${RESET}  (Implementer) ${DIM}owns src/auth/token.ts, src/auth/validate.ts${RESET}\n"
    pause 0.2
    printf "    ${MAGENTA}auth-impl-2${RESET}  (Implementer) ${DIM}owns src/auth/session.ts, src/middleware/auth.ts${RESET}\n"
    pause 0.2
    printf "    ${MAGENTA}auth-review${RESET}  (Reviewer)     ${DIM}reviews all changes${RESET}\n"
    pause 0.5
    printf "\n  ${YELLOW}Approve this plan? [y/n]${RESET} "
    pause 1
    type_text "y" 0.1
    echo ""
    pause 1

    # Phase 3
    printf "\n${BLUE}${BOLD}Phase 3 - Create${RESET}\n"
    pause 0.5
    printf "  ${GREEN}Created${RESET} team \"0306-refactor-auth\"\n"
    pause 0.3
    printf "  ${GREEN}Initialized${RESET} workspace at .agent-team/0306-refactor-auth/\n"
    pause 0.3
    printf "  ${GREEN}Spawned${RESET} 3 teammates in parallel\n"
    pause 1

    # Phase 4
    printf "\n${BLUE}${BOLD}Phase 4 - Coordinate${RESET}\n"
    pause 0.8
    printf "  ${MAGENTA}auth-impl-1${RESET}  ${CYAN}STARTING #1${RESET}: Refactoring token validation logic\n"
    pause 0.4
    printf "  ${MAGENTA}auth-impl-2${RESET}  ${CYAN}STARTING #2${RESET}: Extracting session management\n"
    pause 1.5
    printf "  ${MAGENTA}auth-impl-1${RESET}  ${GREEN}COMPLETED #1${RESET}: Token validation refactored, 3 files changed\n"
    pause 0.6
    printf "  ${MAGENTA}auth-impl-1${RESET}  ${YELLOW}HANDOFF #3${RESET}: New token interface ready for reviewer\n"
    pause 0.8
    printf "  ${MAGENTA}auth-impl-2${RESET}  ${GREEN}COMPLETED #2${RESET}: Session management extracted, 2 files changed\n"
    pause 0.6
    printf "  ${MAGENTA}auth-review${RESET}  ${CYAN}STARTING #4${RESET}: Reviewing all changes\n"
    pause 1.5
    printf "  ${MAGENTA}auth-review${RESET}  ${GREEN}COMPLETED #4${RESET}: 0 high, 2 medium, 1 low issues found\n"
    pause 1

    # Phase 5
    printf "\n${BLUE}${BOLD}Phase 5 - Synthesize${RESET}\n"
    pause 0.5
    printf "  Tasks: ${GREEN}4/4 completed${RESET}\n"
    pause 0.3
    printf "  Completion gate: ${GREEN}PASSED${RESET} (build, tests, lint, integration)\n"
    pause 0.3
    printf "  Issues: 0 open, 3 resolved\n"
    pause 0.3
    printf "  Report: ${DIM}.agent-team/0306-refactor-auth/report.md${RESET}\n"
    pause 0.5
    printf "\n  ${GREEN}${BOLD}Done.${RESET} 6 files changed, 0 open issues.\n"
    pause 2

    echo ""
}

if [ "$SIMULATE" = true ]; then
    run_demo
else
    echo "Recording demo with asciinema..."
    echo "The demo will play automatically. Press Ctrl+C when it finishes."
    asciinema rec "$CAST_FILE" -c "bash -c '$(declare -f type_text pause clear_screen run_demo); BOLD=\"\033[1m\" DIM=\"\033[2m\" GREEN=\"\033[32m\" BLUE=\"\033[34m\" YELLOW=\"\033[33m\" CYAN=\"\033[36m\" MAGENTA=\"\033[35m\" RESET=\"\033[0m\"; run_demo'"
    echo ""
    echo "Recorded to $CAST_FILE"
    echo ""
    echo "To convert to GIF:"
    echo "  pip install asciinema-agg"
    echo "  agg $CAST_FILE demo.gif --cols 90 --rows 30 --speed 2"
    echo ""
    echo "To upload to asciinema.org:"
    echo "  asciinema upload $CAST_FILE"
    echo "Then embed in README with: [![demo](https://asciinema.org/a/XXXXX.svg)](https://asciinema.org/a/XXXXX)"
fi
