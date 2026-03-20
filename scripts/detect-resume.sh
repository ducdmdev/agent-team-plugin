#!/bin/bash
# Hook: SessionStart (no matcher — fires on all session starts)
# Detects existing workspaces with incomplete tasks and validates staleness.
# Output goes to stdout (injected into conversation context, matching recover-context.sh).
# Always exits 0 (informational only).

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
CWD="${CWD:-.}"

# Scan for task-graph.json files
GRAPHS=()
for graph_file in "$CWD"/.agent-team/*/task-graph.json; do
  [ -f "$graph_file" ] || continue
  GRAPHS+=("$graph_file")
done

if [ ${#GRAPHS[@]} -eq 0 ]; then
  exit 0
fi

# Sort by updated timestamp (most recent first)
SORTED_GRAPHS=()
while IFS= read -r line; do
  SORTED_GRAPHS+=("$line")
done < <(
  for g in "${GRAPHS[@]}"; do
    ts=$(jq -r '.updated // .created // "1970-01-01"' "$g" 2>/dev/null)
    echo "$ts|$g"
  done | sort -r | cut -d'|' -f2
)

HAS_OUTPUT=false

for graph_file in "${SORTED_GRAPHS[@]}"; do
  GRAPH=$(jq '.' "$graph_file" 2>/dev/null)
  [ -z "$GRAPH" ] && continue

  TEAM=$(echo "$GRAPH" | jq -r '.team // "unknown"')
  WORKSPACE_DIR=$(dirname "$graph_file")

  # Count total and completed
  TOTAL=$(echo "$GRAPH" | jq '[.nodes | to_entries[]] | length')
  COMPLETED=$(echo "$GRAPH" | jq '[.nodes | to_entries[] | select(.value.status == "completed")] | length')
  REMAINING=$((TOTAL - COMPLETED))

  # Skip fully completed workspaces
  if [ "$REMAINING" -eq 0 ]; then
    continue
  fi

  # Validate completed tasks for staleness
  VALID_LIST=""
  STALE_LIST=""
  REMAINING_LIST=""

  while IFS= read -r entry; do
    ID=$(echo "$entry" | jq -r '.key')
    STATUS=$(echo "$entry" | jq -r '.value.status')
    SUBJECT=$(echo "$entry" | jq -r '.value.subject')

    if [ "$STATUS" = "completed" ]; then
      COMPLETED_AT=$(echo "$entry" | jq -r '.value.completed_at // empty')
      OUTPUT_FILES=$(echo "$entry" | jq -r '.value.output_files[]' 2>/dev/null)
      IS_STALE=false

      if [ -n "$OUTPUT_FILES" ] && [ -n "$COMPLETED_AT" ] && command -v git &>/dev/null; then
        while IFS= read -r ofile; do
          [ -z "$ofile" ] && continue
          FULL_PATH="$CWD/$ofile"
          if [ ! -f "$FULL_PATH" ]; then
            # Output file was deleted — classify as missing
            IS_STALE=true
            STALE_LIST="${STALE_LIST}  Completed (missing): $ID ($SUBJECT) — $ofile no longer exists\n"
            break
          fi
          # Use epoch seconds for comparison to handle timezone differences
          # (git log returns local TZ, completed_at may be UTC)
          FILE_EPOCH=$(cd "$CWD" && git log -1 --format=%ct -- "$ofile" 2>/dev/null)
          COMPLETED_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$COMPLETED_AT" "+%s" 2>/dev/null || date -d "$COMPLETED_AT" "+%s" 2>/dev/null)
          if [ -n "$FILE_EPOCH" ] && [ -n "$COMPLETED_EPOCH" ] && [ "$FILE_EPOCH" -gt "$COMPLETED_EPOCH" ]; then
            IS_STALE=true
            STALE_LIST="${STALE_LIST}  Completed (stale): $ID ($SUBJECT) — $ofile modified after completion\n"
            break
          fi
        done <<< "$OUTPUT_FILES"
      fi

      if [ "$IS_STALE" = false ]; then
        if command -v git &>/dev/null; then
          VALID_LIST="${VALID_LIST}  Completed (valid): $ID ($SUBJECT) — output files unchanged\n"
        else
          VALID_LIST="${VALID_LIST}  Completed (valid, unverified): $ID ($SUBJECT) — git unavailable\n"
        fi
      fi
    else
      REMAINING_LIST="${REMAINING_LIST}  Remaining: $ID ($SUBJECT) — status: $STATUS\n"
    fi
  done < <(echo "$GRAPH" | jq -c '.nodes | to_entries[]')

  # Output resume context to stdout
  HAS_OUTPUT=true
  REL_PATH="${WORKSPACE_DIR#$CWD/}"
  echo ""
  echo "Resumable workspace found: $REL_PATH/"
  echo "  Tasks: $COMPLETED/$TOTAL completed, $REMAINING remaining"
  [ -n "$VALID_LIST" ] && printf "%b" "$VALID_LIST"
  [ -n "$STALE_LIST" ] && printf "%b" "$STALE_LIST"
  [ -n "$REMAINING_LIST" ] && printf "%b" "$REMAINING_LIST"

  # Show remaining critical path if available
  CP=$(echo "$GRAPH" | jq -r '
    . as $g |
    [.critical_path[] | select(. as $id | $g.nodes[$id].status != "completed")] | join(" → ")
  ' 2>/dev/null)
  [ -n "$CP" ] && echo "  Critical path (remaining): $CP"

  echo ""
  echo "  To resume: \"resume team $TEAM\""
  echo "  To start fresh: proceed normally (existing workspace will be archived)"
done

exit 0
