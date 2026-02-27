#!/bin/bash
# Hook: TeammateIdle
# Prevents teammates from going idle when they have in-progress tasks.
# Exit 0 = allow idle, Exit 2 = keep working with feedback.
# Includes loop protection: after MAX_RETRIES blocks, allows idle to prevent infinite loops.

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // empty')
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty')

# Skip if we can't identify the teammate or team
if [ -z "$TEAMMATE" ] || [ -z "$TEAM" ]; then
  exit 0
fi

# Check workspace tasks.md for in-progress tasks owned by this teammate.
# Format: markdown table with columns: ID | Subject | Owner | Status | Blocked By | Notes
# Remediation teams use name {original}-fix but reuse workspace at .agent-team/{original}/.
TASKS_FILE=".agent-team/$TEAM/tasks.md"
if [ ! -f "$TASKS_FILE" ]; then
  BASE_NAME="${TEAM%-fix}"
  if [ "$BASE_NAME" != "$TEAM" ] && [ -f ".agent-team/$BASE_NAME/tasks.md" ]; then
    TASKS_FILE=".agent-team/$BASE_NAME/tasks.md"
  else
    # Skip if workspace tasks.md doesn't exist — graceful degradation
    exit 0
  fi
fi

# --- Loop protection ---
# Track how many times this teammate has been blocked from going idle.
# After MAX_RETRIES, allow idle to prevent infinite loops.
MAX_RETRIES=3
COUNTER_DIR="/tmp/agent-team-idle-counters"
mkdir -p "$COUNTER_DIR"
chmod 700 "$COUNTER_DIR"
# Counter file uses -- separator; Claude Code teammate names don't contain double-dashes
COUNTER_FILE="$COUNTER_DIR/${TEAM}--${TEAMMATE}"

RETRY_COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  RETRY_COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
fi

if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
  # Reset counter and allow idle — the teammate is genuinely stuck
  rm -f "$COUNTER_FILE"
  exit 0
fi

# Count in-progress tasks owned by this teammate by parsing the markdown table.
# Match Owner column (col 4) and Status column (col 5) in pipe-delimited table.
IN_PROGRESS=$(awk -F'|' -v owner="$TEAMMATE" 'tolower($4) ~ tolower(owner) && tolower($5) ~ /in_progress/' "$TASKS_FILE" 2>/dev/null | wc -l | tr -d ' ')

if [ "$IN_PROGRESS" -gt 0 ]; then
  # Increment retry counter
  echo $((RETRY_COUNT + 1)) > "$COUNTER_FILE"
  echo "You have $IN_PROGRESS task(s) still in progress (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES). Complete them and mark as done, or update status before stopping." >&2
  exit 2
fi

# No in-progress tasks — reset counter and allow idle
rm -f "$COUNTER_FILE"
exit 0
