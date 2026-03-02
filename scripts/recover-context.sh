#!/bin/bash
# Hook: SessionStart (compact matcher)
# After context compaction, outputs active workspace state to help the lead recover.
# Exit 0 always (non-blocking). Summary output goes to stdout (injected into context).

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Use cwd from input, fall back to current directory
SEARCH_DIR="${CWD:-.}"

# Find active workspaces (status != done)
FOUND_ACTIVE=false
for progress_file in "$SEARCH_DIR"/.agent-team/*/progress.md; do
  [ -f "$progress_file" ] || continue

  # Check if workspace is active (not done)
  STATUS=$(sed -n 's/^\*\*Status\*\*: *//p' "$progress_file" | tr -d ' ')
  if [ "$STATUS" = "done" ]; then
    continue
  fi

  TEAM_DIR=$(dirname "$progress_file")
  TEAM_NAME=$(basename "$TEAM_DIR")
  FOUND_ACTIVE=true

  echo "=== CONTEXT RECOVERY: Active team workspace found ==="
  echo ""
  echo "Team: $TEAM_NAME"
  echo "Workspace: .agent-team/$TEAM_NAME/"
  echo "Status: $STATUS"
  echo ""
  echo "Recovery action: Read these files to restore your awareness:"
  echo "  1. .agent-team/$TEAM_NAME/progress.md  (team state, decisions, handoffs)"
  echo "  2. .agent-team/$TEAM_NAME/tasks.md     (task ledger with statuses)"
  echo "  3. .agent-team/$TEAM_NAME/issues.md    (open issues)"
  echo ""
  echo "Then read ~/.claude/teams/$TEAM_NAME/config.json for live team members."
  echo "Then call TaskList for live task state."
  echo "=== END CONTEXT RECOVERY ==="
done

exit 0
