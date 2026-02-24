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

TASK_DIR="$HOME/.claude/tasks/$TEAM"

# Skip if task directory doesn't exist
if [ ! -d "$TASK_DIR" ]; then
  exit 0
fi

# --- Loop protection ---
# Track how many times this teammate has been blocked from going idle.
# After MAX_RETRIES, allow idle to prevent infinite loops.
MAX_RETRIES=3
COUNTER_DIR="/tmp/agent-team-idle-counters"
mkdir -p "$COUNTER_DIR"
COUNTER_FILE="$COUNTER_DIR/${TEAM}_${TEAMMATE}"

RETRY_COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  RETRY_COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
fi

if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
  # Reset counter and allow idle — the teammate is genuinely stuck
  rm -f "$COUNTER_FILE"
  exit 0
fi

# Count in-progress tasks owned by this teammate
IN_PROGRESS=0
for task_file in "$TASK_DIR"/*.json; do
  [ -f "$task_file" ] || continue
  OWNER=$(jq -r '.owner // empty' "$task_file" 2>/dev/null)
  STATUS=$(jq -r '.status // empty' "$task_file" 2>/dev/null)
  if [ "$OWNER" = "$TEAMMATE" ] && [ "$STATUS" = "in_progress" ]; then
    IN_PROGRESS=$((IN_PROGRESS + 1))
  fi
done

if [ "$IN_PROGRESS" -gt 0 ]; then
  # Increment retry counter
  echo $((RETRY_COUNT + 1)) > "$COUNTER_FILE"
  echo "You have $IN_PROGRESS task(s) still in progress (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES). Complete them and mark as done, or update status before stopping." >&2
  exit 2
fi

# No in-progress tasks — reset counter and allow idle
rm -f "$COUNTER_FILE"
exit 0
