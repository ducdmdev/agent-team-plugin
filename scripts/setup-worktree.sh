#!/bin/bash
# Creates a git worktree for an isolated teammate workspace.
# Usage: setup-worktree.sh <team-name> <teammate-name>
# Outputs the worktree path to stdout on success.
# Exit 0 = success, Exit 1 = error.

set -euo pipefail

TEAM_NAME="${1:-}"
TEAMMATE_NAME="${2:-}"

if [ -z "$TEAM_NAME" ] || [ -z "$TEAMMATE_NAME" ]; then
  echo "Usage: setup-worktree.sh <team-name> <teammate-name>" >&2
  exit 1
fi

# Must be in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: not inside a git repository" >&2
  exit 1
fi

WORKTREE_DIR=".claude/worktrees/${TEAM_NAME}--${TEAMMATE_NAME}"
BRANCH_NAME="${TEAM_NAME}/${TEAMMATE_NAME}"

# Create worktree with a new branch
git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" HEAD 2>/dev/null

echo "$WORKTREE_DIR"
