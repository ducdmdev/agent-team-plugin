#!/bin/bash
# Hook: PreToolUse(SendMessage)
# Enforces a maximum of 2 plan-mode revision rounds per teammate.
# Checks progress.md Plan Proposals table for revision count.
#
# Exit 0 = allow (under limit or can't determine)
# Exit 2 = block (revision limit reached)

# Graceful jq fallback — can't parse input without jq
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only applies to SendMessage
if [ "$TOOL_NAME" != "SendMessage" ]; then
  exit 0
fi

MESSAGE=$(echo "$INPUT" | jq -r '.tool_input.message // empty')
RECIPIENT=$(echo "$INPUT" | jq -r '.tool_input.to // empty')

# Fast path: if message doesn't start with PLAN_REVISION → allow
if [[ "$MESSAGE" != PLAN_REVISION* ]]; then
  exit 0
fi

# Need recipient to check revision count
if [ -z "$RECIPIENT" ]; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty')

# Need both to locate workspace
if [ -z "$CWD" ] || [ -z "$TEAM" ]; then
  exit 0
fi

# Resolve workspace path (with -fix suffix fallback for remediation teams)
PROGRESS="$CWD/.agent-team/$TEAM/progress.md"
if [ ! -f "$PROGRESS" ]; then
  BASE_NAME="${TEAM%-fix}"
  if [ "$BASE_NAME" != "$TEAM" ] && [ -f "$CWD/.agent-team/$BASE_NAME/progress.md" ]; then
    PROGRESS="$CWD/.agent-team/$BASE_NAME/progress.md"
  else
    # No progress.md — allow (workspace may not be initialized yet)
    exit 0
  fi
fi

# Parse Plan Proposals table for revision count
REVISION_COUNT=$(awk -v teammate="$RECIPIENT" '
  /## Plan Proposals/ { in_section=1; next }
  in_section && /^## / { in_section=0 }
  in_section && $0 ~ "\\| *" teammate " *\\|" {
    n = split($0, cols, "|")
    gsub(/^[ \t]+|[ \t]+$/, "", cols[n-1])
    if (cols[n-1] ~ /^[0-9]+$/) {
      total += cols[n-1]
    }
  }
  END { print total+0 }
' "$PROGRESS")

if [ "$REVISION_COUNT" -ge 2 ]; then
  echo "BLOCKED: Plan-mode revision limit reached (2/2) for $RECIPIENT." >&2
  echo "The teammate has already gone through the maximum number of plan revision rounds." >&2
  echo "Accept the current proposal or reassign the task to a different teammate." >&2
  exit 2
fi

# Under limit — allow
exit 0
