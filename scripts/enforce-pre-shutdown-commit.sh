#!/bin/bash
# Hook: PreToolUse (matcher: TeamDelete)
# Blocks TeamDelete if owned files have uncommitted changes.
# Exit 0 = allow, Exit 2 = block with feedback.

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

# Graceful git fallback
if ! command -v git &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty')

# Need both to locate workspace
if [ -z "$CWD" ] || [ -z "$TEAM" ]; then
  exit 0
fi

# Resolve workspace path (with -fix suffix fallback for remediation teams)
WS="$CWD/.agent-team/$TEAM"
if [ ! -d "$WS" ]; then
  BASE_NAME="${TEAM%-fix}"
  if [ "$BASE_NAME" != "$TEAM" ] && [ -d "$CWD/.agent-team/$BASE_NAME" ]; then
    WS="$CWD/.agent-team/$BASE_NAME"
  else
    # No workspace directory — allow shutdown
    exit 0
  fi
fi

# Read file-locks.json
LOCKS_FILE="$WS/file-locks.json"
if [ ! -f "$LOCKS_FILE" ]; then
  exit 0
fi

# Get all owners from file-locks.json
OWNERS=$(jq -r 'keys[]' "$LOCKS_FILE" 2>/dev/null)
if [ -z "$OWNERS" ]; then
  exit 0
fi

# Check each owner's files for uncommitted changes
DIRTY_REPORT=""
while IFS= read -r owner; do
  [ -z "$owner" ] && continue

  OWNED_PATHS=$(jq -r --arg o "$owner" '.[$o] // [] | .[]' "$LOCKS_FILE" 2>/dev/null)
  [ -z "$OWNED_PATHS" ] && continue

  OWNER_DIRTY=""
  while IFS= read -r file_path; do
    [ -z "$file_path" ] && continue
    # Check git status for this file/path from the project directory
    STATUS=$(cd "$CWD" && git status --porcelain -- "$file_path" 2>/dev/null)
    if [ -n "$STATUS" ]; then
      if [ -z "$OWNER_DIRTY" ]; then
        OWNER_DIRTY="$file_path"
      else
        OWNER_DIRTY="$OWNER_DIRTY, $file_path"
      fi
    fi
  done <<< "$OWNED_PATHS"

  if [ -n "$OWNER_DIRTY" ]; then
    if [ -z "$DIRTY_REPORT" ]; then
      DIRTY_REPORT="$owner: $OWNER_DIRTY"
    else
      DIRTY_REPORT="$DIRTY_REPORT; $owner: $OWNER_DIRTY"
    fi
  fi
done <<< "$OWNERS"

if [ -n "$DIRTY_REPORT" ]; then
  echo "Uncommitted changes detected before shutdown. $DIRTY_REPORT" >&2
  exit 2
fi

# All clean
exit 0
