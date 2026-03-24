#!/bin/bash
# Hook: SubagentStart
# Validates that the workspace has the minimum required files and fields
# BEFORE teammates are spawned. Blocks if incomplete.
#
# Checks:
# 1. progress.md exists and contains **Archetype** field
# 2. tasks.md exists and non-empty (more than 1 line)
# 3. issues.md exists
# 4. task-graph.json exists (schema validated by separate hook)
# 5. If **Pipeline status** field exists, value is valid
#
# Exit 0 = valid (allow spawn)
# Exit 2 = incomplete (block spawn with feedback)

# Graceful jq fallback — can't parse hook input without jq
if ! command -v jq &>/dev/null; then
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
    # No workspace directory — allow spawn (workspace may not be initialized yet)
    exit 0
  fi
fi

# --- Check 1: progress.md exists and contains Archetype field ---
if [ ! -f "$WS/progress.md" ]; then
  echo "BLOCKED: Workspace missing progress.md. Create it before spawning teammates." >&2
  echo "Expected at: $WS/progress.md" >&2
  exit 2
fi

if ! grep -q '\*\*Archetype\*\*' "$WS/progress.md" 2>/dev/null; then
  echo "BLOCKED: progress.md missing **Archetype** field. Add the team archetype before spawning." >&2
  echo "Example: **Archetype**: implementation" >&2
  exit 2
fi

# --- Check 2: tasks.md exists and non-empty ---
if [ ! -f "$WS/tasks.md" ]; then
  echo "BLOCKED: Workspace missing tasks.md. Create it before spawning teammates." >&2
  echo "Expected at: $WS/tasks.md" >&2
  exit 2
fi

LINE_COUNT=$(wc -l < "$WS/tasks.md" 2>/dev/null | tr -d ' ')
if [ -z "$LINE_COUNT" ] || [ "$LINE_COUNT" -le 1 ]; then
  echo "BLOCKED: tasks.md is empty or has only a header. Populate task table before spawning teammates." >&2
  exit 2
fi

# --- Check 3: issues.md exists ---
if [ ! -f "$WS/issues.md" ]; then
  echo "BLOCKED: Workspace missing issues.md. Create it before spawning teammates." >&2
  echo "Expected at: $WS/issues.md" >&2
  exit 2
fi

# --- Check 4: task-graph.json exists ---
if [ ! -f "$WS/task-graph.json" ]; then
  echo "BLOCKED: Workspace missing task-graph.json. Create the task dependency graph before spawning teammates." >&2
  echo "Expected at: $WS/task-graph.json" >&2
  exit 2
fi

# --- Check 5: If Pipeline status field exists, value must be valid ---
PIPELINE_STATUS=$(sed -n 's/.*\*\*Pipeline status\*\*: \([^ ]*\).*/\1/p' "$WS/progress.md" 2>/dev/null)
if [ -n "$PIPELINE_STATUS" ]; then
  case "$PIPELINE_STATUS" in
    approved|executed|audited)
      # Valid status
      ;;
    *)
      echo "BLOCKED: progress.md has invalid **Pipeline status**: '$PIPELINE_STATUS'." >&2
      echo "Valid values: approved, executed, audited" >&2
      exit 2
      ;;
  esac
fi

# All checks passed
exit 0
