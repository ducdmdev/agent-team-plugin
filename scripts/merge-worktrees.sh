#!/bin/bash
# Merges all teammate worktree branches back to the current branch and cleans up.
# Usage: merge-worktrees.sh <team-name>
# Exit 0 = success (or nothing to merge), Exit 1 = merge conflict (logged to stderr).

set -euo pipefail

TEAM_NAME="${1:-}"

if [ -z "$TEAM_NAME" ]; then
  echo "Usage: merge-worktrees.sh <team-name>" >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repo — skipping merge" >&2
  exit 0
fi

# Find teammate branches for this team
BRANCHES=$(git branch --list "${TEAM_NAME}/*" 2>/dev/null | sed 's/^[ *+]*//')

if [ -z "$BRANCHES" ]; then
  echo "No branches found for team ${TEAM_NAME}" >&2
  exit 0
fi

CONFLICT_BRANCHES=""

while IFS= read -r branch; do
  [ -z "$branch" ] && continue
  echo "Merging $branch..."

  # Remove worktree first (if it exists)
  WORKTREE_PATH=$(echo "$branch" | sed "s|/|--|g")
  if [ -d ".claude/worktrees/$WORKTREE_PATH" ]; then
    git worktree remove ".claude/worktrees/$WORKTREE_PATH" --force 2>/dev/null || true
  fi

  if git merge --no-ff "$branch" -m "Merge teammate branch $branch" 2>/dev/null; then
    git branch -d "$branch" 2>/dev/null || true
    echo "  Merged successfully"
  else
    git merge --abort 2>/dev/null || true
    CONFLICT_BRANCHES="$CONFLICT_BRANCHES $branch"
    echo "  CONFLICT — merge aborted" >&2
  fi
done <<< "$BRANCHES"

if [ -n "$CONFLICT_BRANCHES" ]; then
  echo "Merge conflicts on branches:$CONFLICT_BRANCHES" >&2
  echo "Resolve manually or assign to an implementer." >&2
  exit 1
fi

exit 0
