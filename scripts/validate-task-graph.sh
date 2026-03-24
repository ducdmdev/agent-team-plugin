#!/bin/bash
# Hook: SubagentStart
# Validates task-graph.json schema and checks for circular dependencies
# BEFORE teammates are spawned. Blocks if invalid or cyclic.
#
# Exit 0 = valid (allow spawn)
# Exit 2 = invalid (block spawn with feedback)

# Graceful jq fallback — can't validate without jq
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty')

# Need both to locate task-graph.json
if [ -z "$CWD" ] || [ -z "$TEAM" ]; then
  exit 0
fi

# Resolve workspace path (with -fix suffix fallback for remediation teams)
GRAPH_FILE="$CWD/.agent-team/$TEAM/task-graph.json"
if [ ! -f "$GRAPH_FILE" ]; then
  BASE_NAME="${TEAM%-fix}"
  if [ "$BASE_NAME" != "$TEAM" ] && [ -f "$CWD/.agent-team/$BASE_NAME/task-graph.json" ]; then
    GRAPH_FILE="$CWD/.agent-team/$BASE_NAME/task-graph.json"
  else
    # No task-graph.json — allow spawn (workspace may not be initialized yet)
    exit 0
  fi
fi

# --- Check 1: Valid JSON ---
GRAPH=$(jq '.' "$GRAPH_FILE" 2>/dev/null)
if [ -z "$GRAPH" ]; then
  echo "BLOCKED: task-graph.json exists but is not valid JSON. Fix the file before spawning teammates." >&2
  echo "File: $GRAPH_FILE" >&2
  exit 2
fi

# --- Check 2: Has nodes object with at least 1 entry ---
NODE_COUNT=$(echo "$GRAPH" | jq '.nodes | length // 0' 2>/dev/null)
if [ -z "$NODE_COUNT" ] || [ "$NODE_COUNT" -eq 0 ]; then
  # Empty nodes is OK — plan stage may not have populated yet
  exit 0
fi

# --- Check 3: Required fields on each node ---
MISSING_FIELDS=$(echo "$GRAPH" | jq -r '
  [.nodes | to_entries[] |
    select(
      (.value.subject == null) or
      (.value.status == null) or
      (.value.depends_on == null)
    ) | .key
  ] | join(", ")
' 2>/dev/null)

if [ -n "$MISSING_FIELDS" ] && [ "$MISSING_FIELDS" != "" ]; then
  echo "BLOCKED: task-graph.json nodes missing required fields (subject, status, depends_on)." >&2
  echo "Affected nodes: $MISSING_FIELDS" >&2
  echo "Fix the task-graph.json schema before spawning teammates." >&2
  exit 2
fi

# --- Check 4: depends_on references point to existing node IDs ---
DANGLING=$(echo "$GRAPH" | jq -r '
  .nodes as $nodes |
  [.nodes | to_entries[] | .value.depends_on[]? |
    select($nodes[.] == null)
  ] | unique | join(", ")
' 2>/dev/null)

if [ -n "$DANGLING" ] && [ "$DANGLING" != "" ]; then
  echo "BLOCKED: task-graph.json has dangling dependency references." >&2
  echo "Missing node IDs: $DANGLING" >&2
  echo "All depends_on entries must reference existing node IDs." >&2
  exit 2
fi

# --- Check 5: Cycle detection (DFS) ---
HAS_CYCLE=$(echo "$GRAPH" | jq '
  def has_cycle(id; visited):
    if (visited | index(id)) then true
    elif (.nodes[id] == null) then false
    else
      . as $g |
      any(.nodes[id].depends_on[]; . as $dep | $g | has_cycle($dep; visited + [id]))
    end;
  . as $root |
  any(.nodes | keys[]; . as $k | $root | has_cycle($k; []))
' 2>/dev/null)

if [ "$HAS_CYCLE" = "true" ]; then
  # Find the cycle for error message
  CYCLE_NODES=$(echo "$GRAPH" | jq -r '
    def find_cycle(id; visited):
      if (visited | index(id)) then [id]
      elif (.nodes[id] == null) then []
      else
        . as $g |
        [.nodes[id].depends_on[] | . as $dep | $g | find_cycle($dep; visited + [id])] |
        add // []
      end;
    . as $root |
    [.nodes | keys[] | . as $k | $root | find_cycle($k; [])] | add | unique | join(" -> ")
  ' 2>/dev/null)
  echo "BLOCKED: Circular dependency detected in task-graph.json." >&2
  echo "Cycle involves: $CYCLE_NODES" >&2
  echo "Fix the dependency graph before spawning teammates. Remove or reorder depends_on entries to break the cycle." >&2
  exit 2
fi

# All checks passed
exit 0
