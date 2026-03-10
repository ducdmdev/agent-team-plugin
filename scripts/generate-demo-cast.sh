#!/bin/bash
# Generate a demo.cast file (asciinema v2 format) programmatically.
# No TTY needed — writes the cast file directly.
#
# Usage:
#   bash scripts/generate-demo-cast.sh           # outputs demo.cast
#   agg demo.cast demo.gif --cols 100 --rows 35  # convert to GIF

set -e

CAST_FILE="${1:-demo.cast}"
COLS=100
ROWS=35
START=$(date +%s)

# Header
printf '{"version":2,"width":%d,"height":%d,"timestamp":%d,"env":{"SHELL":"/bin/zsh","TERM":"xterm-256color"}}\n' "$COLS" "$ROWS" "$START" > "$CAST_FILE"

# Time accumulator (in centiseconds to avoid floating point)
CS=0

emit() {
    local delay_cs="$1"  # delay in centiseconds (100 = 1 second)
    local text="$2"
    CS=$((CS + delay_cs))
    local secs=$((CS / 100))
    local frac=$((CS % 100))
    printf '[%d.%02d, "o", "%s"]\n' "$secs" "$frac" "$text" >> "$CAST_FILE"
}

type_chars() {
    local text="$1"
    local delay_cs="${2:-4}"
    for (( i=0; i<${#text}; i++ )); do
        local ch="${text:$i:1}"
        emit "$delay_cs" "$ch"
    done
}

nl() { emit 1 "\\r\\n"; }
pause() { emit "$1" ""; }

# ANSI codes
B="\\u001b[1m"       # bold
D="\\u001b[2m"       # dim
R="\\u001b[0m"       # reset
GRN="\\u001b[32m"
BLU="\\u001b[34m"
YLW="\\u001b[33m"
CYN="\\u001b[36m"
MAG="\\u001b[35m"
RED="\\u001b[31m"

# === Demo ===

# Clear screen
emit 50 "\\u001b[2J\\u001b[H"

# Shell prompt
emit 30 "${B}$ ${R}"
type_chars "claude" 6
pause 50
nl
pause 80

# User prompt
emit 30 "${B}You > ${R}"
type_chars "use agent team to refactor the auth module into separate concerns" 3
nl
pause 120

# Phase 1
nl
emit 30 "${BLU}${B}━━ Phase 1 — Analyze ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
nl
pause 50
emit 30 "${D}  Scanning project structure...${R}"
nl
pause 80
emit 20 "  Found 3 independent streams:"
nl
pause 30
emit 20 "    ${GRN}1.${R} Token validation    ${D}(src/auth/token.ts, src/auth/validate.ts)${R}"
nl
pause 20
emit 10 "    ${GRN}2.${R} Session management  ${D}(src/auth/session.ts, src/auth/store.ts)${R}"
nl
pause 20
emit 10 "    ${GRN}3.${R} Middleware layer     ${D}(src/middleware/auth.ts)${R}"
nl
pause 30
emit 20 "  File ownership mapped — ${GRN}no overlaps${R}"
nl
emit 20 "  Integration point: token interface shared between stream 1 and 3"
nl
pause 100

# Phase 2
nl
emit 30 "${BLU}${B}━━ Phase 2 — Plan (you approve before anything starts) ━━━━━━━━━━${R}"
nl
pause 50
emit 20 "  Team plan for: refactor auth module"
nl
emit 20 "  Team type: ${CYN}implementation${R} (auto-detected)"
nl
emit 20 "  Complexity: standard"
nl
pause 30
nl
emit 20 "  Teammates (3 total):"
nl
emit 15 "  ${D}⚠ Team size check: 3 agents (within default max of 4)${R}"
nl
pause 20
emit 15 "    ${MAG}auth-impl-1${R}  (Implementer) ${D}token validation + middleware -> owns src/auth/token.ts, src/auth/validate.ts${R}"
nl
pause 15
emit 15 "    ${MAG}auth-impl-2${R}  (Implementer) ${D}session management -> owns src/auth/session.ts, src/middleware/auth.ts${R}"
nl
pause 15
emit 15 "    ${MAG}auth-review${R}  (Reviewer)     ${D}validate all changes -> read-only${R}"
nl
pause 30
nl
emit 20 "  Task breakdown:"
nl
emit 15 "    1. Refactor token validation logic        -> auth-impl-1"
nl
emit 15 "    2. Extract session management             -> auth-impl-2"
nl
emit 15 "    3. Update middleware (new interfaces)      -> auth-impl-1 ${D}(blocked by #2)${R}"
nl
emit 15 "    4. Review all changes                     -> auth-review ${D}(blocked by #1, #3)${R}"
nl
pause 30
nl
emit 20 "  Isolation: shared (default)"
nl
emit 20 "  Workspace: .agent-team/0306-refactor-auth/"
nl
pause 50
nl
emit 30 "  ${YLW}Approve? ${R}"
pause 100
type_chars "y" 10
nl
pause 80

# Phase 3
nl
emit 30 "${BLU}${B}━━ Phase 3 — Create ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
nl
pause 50
emit 20 "  ${GRN}Created${R} team \\\"0306-refactor-auth\\\""
nl
pause 20
emit 20 "  ${GRN}Initialized${R} workspace at .agent-team/0306-refactor-auth/"
nl
emit 15 "    ${D}├── progress.md, tasks.md, issues.md${R}"
nl
emit 15 "    ${D}└── file-locks.json (ownership enforcement)${R}"
nl
pause 20
emit 20 "  ${GRN}Created${R} 4 tasks with dependencies"
nl
emit 20 "  ${GRN}Spawning${R} 3 teammates in parallel..."
nl
pause 100

# Phase 4
nl
emit 30 "${BLU}${B}━━ Phase 4 — Coordinate ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
nl
pause 80
emit 30 "  ${MAG}auth-impl-1${R}  ${CYN}STARTING #1${R}: Refactoring token validation, touching src/auth/token.ts"
nl
pause 40
emit 30 "  ${MAG}auth-impl-2${R}  ${CYN}STARTING #2${R}: Extracting session logic to src/auth/session.ts"
nl
pause 150
emit 30 "  ${MAG}auth-impl-1${R}  ${GRN}COMPLETED #1${R}: Token validation refactored, 3 files changed"
nl
pause 60
emit 30 "  ${MAG}auth-impl-2${R}  ${RED}BLOCKED #2${R}: severity=medium, need token interface shape, impact=#3 delayed"
nl
pause 40
emit 30 "  ${D}Lead:${R}         Warm handoff — forwarding token interface from impl-1 to impl-2"
nl
pause 80
emit 30 "  ${MAG}auth-impl-2${R}  ${GRN}COMPLETED #2${R}: Session management extracted, 2 files changed"
nl
pause 50
emit 30 "  ${MAG}auth-impl-1${R}  ${CYN}STARTING #3${R}: Updating middleware to use new interfaces"
nl
pause 100
emit 30 "  ${MAG}auth-impl-1${R}  ${GRN}COMPLETED #3${R}: Middleware updated, 1 file changed"
nl
pause 40
emit 30 "  ${MAG}auth-impl-1${R}  ${YLW}HANDOFF #3${R}: New token interface + middleware ready for review"
nl
pause 60
emit 30 "  ${MAG}auth-review${R}  ${CYN}STARTING #4${R}: Reviewing all changes across both scopes"
nl
pause 150
emit 30 "  ${MAG}auth-review${R}  ${GRN}COMPLETED #4${R}: 5 issues: 0 high, 3 medium, 2 low"
nl
pause 100

# Phase 5
nl
emit 30 "${BLU}${B}━━ Phase 5 — Synthesize ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
nl
pause 50
emit 20 "  Pre-shutdown commit:"
nl
emit 15 "    ${MAG}auth-impl-1${R}: committed ${D}(abc1234)${R} — 3 files"
nl
emit 15 "    ${MAG}auth-impl-2${R}: committed ${D}(def5678)${R} — 2 files"
nl
pause 40
nl
emit 20 "  Completion gate (8/8 passed):"
nl
emit 10 "    ${GRN}✓${R} Uncommitted changes    ${GRN}✓${R} Build & tests"
nl
emit 10 "    ${GRN}✓${R} Lint/format             ${GRN}✓${R} Integration"
nl
emit 10 "    ${GRN}✓${R} Security scan           ${GRN}✓${R} Workspace issues"
nl
emit 10 "    ${GRN}✓${R} Plan completion         ${GRN}✓${R} Documentation sync"
nl
pause 40
nl
emit 20 "  Report: ${D}.agent-team/0306-refactor-auth/report.md${R}"
nl
pause 30
emit 20 "  Team shut down (parallel). Cleanup complete."
nl
pause 50
nl
emit 30 "  ${GRN}${B}Done.${R} 6 files changed, 4/4 tasks, 0 open issues."
nl
pause 300

echo ""
echo "Generated $CAST_FILE ($(wc -c < "$CAST_FILE" | tr -d ' ') bytes)"
echo ""
echo "Convert to GIF:"
echo "  agg $CAST_FILE assets/demo.gif --cols $COLS --rows $ROWS"
