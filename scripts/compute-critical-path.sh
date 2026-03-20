#!/bin/bash
# Hook: TaskCompleted
# Recomputes and displays the critical path from task-graph.json.
# Informational only — always exits 0.

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty')

# Need both cwd and team_name to locate task-graph.json
if [ -z "$CWD" ] || [ -z "$TEAM_NAME" ]; then
  exit 0
fi

# Resolve workspace path (with -fix suffix fallback for remediation teams)
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
  echo "Warning: task-graph.json exists but failed to parse. Critical path hooks disabled until JSON is fixed." >&2
  exit 0
fi

# Count remaining (non-completed) nodes
REMAINING=$(echo "$GRAPH" | jq '[.nodes | to_entries[] | select(.value.status != "completed")] | length')

if [ "$REMAINING" -eq 0 ]; then
  echo "No critical path — all remaining tasks can run in parallel." >&2
  exit 0
fi

# DFS longest path computation via jq
# For each remaining node, compute depth = 1 + max(depth of remaining dependencies)
# Cycle guard: track visited nodes
# Key jq scoping note: inside recursive calls, we must capture the dep ID with
# `. as $dep_id | $root | depth($dep_id; ...)` to preserve the graph as `.` context.
CRITICAL_PATH=$(echo "$GRAPH" | jq -r '
  def depth(id; visited):
    if (visited | index(id)) then 0
    elif (.nodes[id].status == "completed") then 0
    elif (.nodes[id].depends_on | length == 0) then 1
    else
      . as $g |
      [.nodes[id].depends_on[] | select($g.nodes[.].status != "completed") | . as $dep_id | $g | depth($dep_id; visited + [id])] | max + 1
    end;

  . as $root |
  [.nodes | to_entries[] | select(.value.status != "completed") |
    .key as $k | $root | {id: $k, depth: depth($k; [])}
  ] | sort_by(-.depth, .id) |
  if length == 0 then empty
  else
    .[0] as $deepest |
    def trace_path(id):
      if ($root.nodes[id].status == "completed") then []
      else
        [$root.nodes[id].depends_on[] | select($root.nodes[.].status != "completed")] as $remaining_deps |
        if ($remaining_deps | length) == 0 then [id]
        else
          ([$remaining_deps[] | . as $dep_id | $root | {id: $dep_id, depth: depth($dep_id; [])}] | sort_by(-.depth, .id) | .[0].id) as $next |
          trace_path($next) + [id]
        end
      end;
    $root | trace_path($deepest.id) | join(" → ")
  end
' 2>/dev/null)

# Get the previously recorded critical path
OLD_CP=$(echo "$GRAPH" | jq -r '.critical_path | join(" → ")')
CP_LENGTH=$(echo "$CRITICAL_PATH" | tr '→' '\n' | sed 's/ //g' | grep -c '.')

# Check if any completed node was on the old critical path
WAS_ON_CP=false
COMPLETED_NODES=$(echo "$GRAPH" | jq -r '[.nodes | to_entries[] | select(.value.status == "completed") | .key] | .[]')
OLD_CP_NODES=$(echo "$GRAPH" | jq -r '.critical_path[]')
for node in $COMPLETED_NODES; do
  if echo "$OLD_CP_NODES" | grep -q "^${node}$"; then
    WAS_ON_CP=true
    break
  fi
done

# Find next critical task details
NEXT_CRITICAL=$(echo "$CRITICAL_PATH" | cut -d'→' -f1 | sed 's/ //g')
if [ -n "$NEXT_CRITICAL" ]; then
  NEXT_SUBJECT=$(echo "$GRAPH" | jq -r --arg id "$NEXT_CRITICAL" '.nodes[$id].subject // "unknown"')
  NEXT_OWNER=$(echo "$GRAPH" | jq -r --arg id "$NEXT_CRITICAL" '.nodes[$id].owner // "unassigned"')
  NEXT_STATUS=$(echo "$GRAPH" | jq -r --arg id "$NEXT_CRITICAL" '.nodes[$id].status // "unknown"')
fi

if [ "$WAS_ON_CP" = true ]; then
  echo "Critical path update: completed task was on critical path." >&2
  echo "Remaining critical path: $CRITICAL_PATH (length: $CP_LENGTH)" >&2
  if [ -n "$NEXT_CRITICAL" ]; then
    echo "Next critical task: $NEXT_CRITICAL $NEXT_SUBJECT (owner: $NEXT_OWNER, status: $NEXT_STATUS)" >&2
    if [ "$NEXT_STATUS" = "blocked" ]; then
      BLOCKED_BY=$(echo "$GRAPH" | jq -r --arg id "$NEXT_CRITICAL" '
        . as $g |
        [.nodes[$id].depends_on[] | select($g.nodes[.].status != "completed")] | join(", ")
      ' 2>/dev/null)
      echo "Warning: Critical task $NEXT_CRITICAL is blocked — resolve blocker(s) ${BLOCKED_BY:-unknown} to maintain throughput." >&2
    fi
  fi
else
  echo "Task completed (not on critical path). Critical path unchanged: $OLD_CP (length: $(echo "$GRAPH" | jq '.critical_path_length'))" >&2
fi

# Check for any blocked tasks on the computed critical path
if [ -n "$CRITICAL_PATH" ]; then
  CP_NODES=$(echo "$CRITICAL_PATH" | tr '→' '\n' | sed 's/ //g' | grep '.')
  for cp_node in $CP_NODES; do
    NODE_STATUS=$(echo "$GRAPH" | jq -r --arg id "$cp_node" '.nodes[$id].status // "unknown"')
    if [ "$NODE_STATUS" = "blocked" ]; then
      BLOCKED_BY=$(echo "$GRAPH" | jq -r --arg id "$cp_node" '
        . as $g |
        [.nodes[$id].depends_on[] | select($g.nodes[.].status != "completed")] | join(", ")
      ' 2>/dev/null)
      echo "Warning: Critical task $cp_node is blocked — resolve blocker(s) ${BLOCKED_BY:-unknown} to maintain throughput." >&2
      break
    fi
  done
fi

exit 0
