#!/bin/bash
# Hook: SubagentStart / SubagentStop
# Appends lifecycle events to .agent-team/{team}/events.log.
# Non-blocking — always exits 0.

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // empty')
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')

# Skip if we can't identify the team
if [ -z "$TEAM" ]; then
  exit 0
fi

# Find workspace directory
WORKSPACE_DIR=".agent-team/$TEAM"
if [ ! -d "$WORKSPACE_DIR" ]; then
  BASE_NAME="${TEAM%-fix}"
  if [ "$BASE_NAME" != "$TEAM" ] && [ -d ".agent-team/$BASE_NAME" ]; then
    WORKSPACE_DIR=".agent-team/$BASE_NAME"
  else
    exit 0  # No workspace — nothing to log
  fi
fi

EVENTS_LOG="$WORKSPACE_DIR/events.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

case "$EVENT" in
  SubagentStart)
    echo "{\"ts\":\"$TIMESTAMP\",\"type\":\"spawn\",\"agent\":\"$TEAMMATE\",\"agent_type\":\"$AGENT_TYPE\"}" >> "$EVENTS_LOG"
    ;;
  SubagentStop)
    echo "{\"ts\":\"$TIMESTAMP\",\"type\":\"stop\",\"agent\":\"$TEAMMATE\"}" >> "$EVENTS_LOG"
    ;;
esac

exit 0
