#!/bin/bash
# Hook: TaskCompleted
# Detects when all upstream tasks of a convergence point complete.
# Nudges the lead to verify interface compatibility.
# Informational only — always exits 0.

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty')

if [ -z "$CWD" ] || [ -z "$TEAM_NAME" ]; then
  exit 0
fi

# Resolve workspace path (with -fix suffix fallback)
GRAPH_FILE="$CWD/.agent-team/$TEAM_NAME/task-graph.json"
if [ ! -f "$GRAPH_FILE" ]; then
  BASE_NAME="${TEAM_NAME%-fix}"
  if [ "$BASE_NAME" != "$TEAM_NAME" ] && [ -f "$CWD/.agent-team/$BASE_NAME/task-graph.json" ]; then
    GRAPH_FILE="$CWD/.agent-team/$BASE_NAME/task-graph.json"
  else
    exit 0
  fi
fi

# Parse JSON — warn if malformed
GRAPH=$(jq '.' "$GRAPH_FILE" 2>/dev/null)
if [ -z "$GRAPH" ]; then
  echo "Warning: task-graph.json exists but failed to parse. Integration checkpoint hooks disabled until JSON is fixed." >&2
  exit 0
fi

# Find convergence points (convergence_point == true, status == pending)
CONV_IDS=$(echo "$GRAPH" | jq -r '
  .nodes | to_entries[] |
  select(.value.convergence_point == true) |
  select(.value.status == "pending") |
  .key
' 2>/dev/null)

[ -z "$CONV_IDS" ] && exit 0

# For each convergence point, check if ALL depends_on nodes are completed
for conv_id in $CONV_IDS; do
  # Get depends_on list for this convergence node
  DEPS=$(echo "$GRAPH" | jq -r --arg id "$conv_id" '.nodes[$id].depends_on[]' 2>/dev/null)
  [ -z "$DEPS" ] && continue

  # Check if all dependencies are completed
  ALL_DONE=true
  for dep_id in $DEPS; do
    DEP_STATUS=$(echo "$GRAPH" | jq -r --arg id "$dep_id" '.nodes[$id].status // "unknown"' 2>/dev/null)
    if [ "$DEP_STATUS" != "completed" ]; then
      ALL_DONE=false
      break
    fi
  done

  [ "$ALL_DONE" = false ] && continue

  # All deps completed and convergence node is pending — emit nudge
  SUBJECT=$(echo "$GRAPH" | jq -r --arg id "$conv_id" '.nodes[$id].subject')

  echo "Integration checkpoint reached: Task $conv_id ($SUBJECT)" >&2
  echo "  All upstream tasks completed:" >&2
  for dep_id in $DEPS; do
    DEP_OWNER=$(echo "$GRAPH" | jq -r --arg id "$dep_id" '.nodes[$id].owner')
    echo "    $dep_id ($DEP_OWNER)" >&2
  done
  echo "  These streams produced independent changes that must integrate at $conv_id." >&2
  echo "  Recommend: verify interface compatibility before $conv_id starts." >&2

  # List output files from upstream tasks
  HAS_FILES=false
  FILE_LIST=""
  for dep_id in $DEPS; do
    FILES=$(echo "$GRAPH" | jq -r --arg id "$dep_id" '.nodes[$id].output_files[]' 2>/dev/null)
    if [ -n "$FILES" ]; then
      HAS_FILES=true
      FILE_LIST="${FILE_LIST}${FILES}"$'\n'
    fi
  done
  if [ "$HAS_FILES" = true ]; then
    echo "  Shared interfaces: check these output files for contract alignment:" >&2
    echo "$FILE_LIST" | while IFS= read -r f; do
      [ -n "$f" ] && echo "    - $f" >&2
    done
  fi
done

exit 0
