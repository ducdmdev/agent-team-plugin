#!/bin/bash
# Hook: PreToolUse (matcher: Write|Edit)
# Enforces file ownership — warns on first violation, blocks on second.
# Exit 0 = allow, Exit 2 = block with feedback.

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // empty')
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if not in team context
if [ -z "$TEAMMATE" ] || [ -z "$TEAM" ] || [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalize FILE_PATH to relative (strip git repo root prefix)
# Claude Code tools may provide absolute paths; ownership checks use relative paths.
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$GIT_ROOT" ]; then
  FILE_PATH="${FILE_PATH#$GIT_ROOT/}"
fi

# Always allow workspace file writes
if echo "$FILE_PATH" | grep -qE '(^|/)\.agent-team/'; then
  exit 0
fi

# Find file-locks.json
LOCKS_FILE=".agent-team/$TEAM/file-locks.json"
if [ ! -f "$LOCKS_FILE" ]; then
  # Try -fix suffix (remediation team)
  BASE_NAME="${TEAM%-fix}"
  if [ "$BASE_NAME" != "$TEAM" ] && [ -f ".agent-team/$BASE_NAME/file-locks.json" ]; then
    LOCKS_FILE=".agent-team/$BASE_NAME/file-locks.json"
  else
    exit 0  # No locks file — graceful degradation
  fi
fi

# Check if teammate owns this file
# file-locks.json: {"teammate-name": ["path/", "path/file.ext"], ...}
OWNED_PATHS=$(jq -r --arg t "$TEAMMATE" '.[$t] // [] | .[]' "$LOCKS_FILE" 2>/dev/null)

if [ -z "$OWNED_PATHS" ]; then
  # Teammate not in file-locks.json — warn but allow
  echo "Warning: $TEAMMATE is not listed in file-locks.json. Contact the lead to update file ownership." >&2
  exit 0
fi

# Check if file matches any owned path
OWNS_FILE=false
while IFS= read -r owned_path; do
  [ -z "$owned_path" ] && continue
  # Directory ownership: owned_path ends with /
  if [[ "$owned_path" == */ ]]; then
    if [[ "$FILE_PATH" == "$owned_path"* ]]; then
      OWNS_FILE=true
      break
    fi
  else
    # Exact file match
    if [ "$FILE_PATH" = "$owned_path" ]; then
      OWNS_FILE=true
      break
    fi
  fi
done <<< "$OWNED_PATHS"

if [ "$OWNS_FILE" = true ]; then
  exit 0
fi

# --- Violation detected ---
# Warn-then-block: track violations per teammate+file
VIOLATION_DIR="/tmp/agent-team-ownership-violations"
mkdir -p "$VIOLATION_DIR"
chmod 700 "$VIOLATION_DIR"

# Use md5/shasum for file path hash to avoid path characters in filename
FILE_HASH=$(echo -n "$FILE_PATH" | md5 2>/dev/null || echo -n "$FILE_PATH" | md5sum 2>/dev/null | cut -d' ' -f1 || echo -n "$FILE_PATH" | shasum 2>/dev/null | cut -d' ' -f1)
VIOLATION_FILE="$VIOLATION_DIR/${TEAM}--${TEAMMATE}--${FILE_HASH}"

if [ -f "$VIOLATION_FILE" ]; then
  # Second violation — block
  echo "BLOCKED: $TEAMMATE does not own '$FILE_PATH'. This is the second attempt. Message the lead to request ownership reassignment." >&2
  exit 2
else
  # First violation — warn
  echo "1" > "$VIOLATION_FILE"
  echo "WARNING: File ownership violation — $TEAMMATE does not own '$FILE_PATH'. The owner should handle this file. If you need to modify it, message the lead. Next attempt will be blocked." >&2
  exit 0
fi
