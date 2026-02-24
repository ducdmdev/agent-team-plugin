#!/bin/bash
# Hook: TaskCompleted
# Prevents premature task completion by checking for actual work artifacts.
# Exit 0 = allow completion, Exit 2 = block with feedback to model.

# Graceful jq fallback
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty')

# Skip validation if no task subject
if [ -z "$TASK_SUBJECT" ]; then
  exit 0
fi

# Check for workspace existence (if this is a team task)
if [ -n "$TEAM_NAME" ]; then
  # Check for workspace in project directory
  WORKSPACE_DIR=".agent-team/$TEAM_NAME"
  if [ -d "$WORKSPACE_DIR" ]; then
    # Workspace exists in project — check for tracking files
    for f in progress.md tasks.md issues.md; do
      if [ ! -f "$WORKSPACE_DIR/$f" ]; then
        echo "Workspace file missing: $WORKSPACE_DIR/$f. The lead must initialize all workspace files (Phase 3, step 3) before tasks can be completed." >&2
        exit 2
      fi
    done
  else
    # Fallback: check legacy journal location
    JOURNAL="$HOME/.claude/teams/$TEAM_NAME/progress.md"
    if [ ! -f "$JOURNAL" ] && [ ! -d "$WORKSPACE_DIR" ]; then
      echo "Workspace missing at $WORKSPACE_DIR/. The lead must initialize the workspace (Phase 3, step 3) before any tasks can be completed." >&2
      exit 2
    fi
  fi
fi

# Check for implementation tasks: verify files were actually modified
if echo "$TASK_SUBJECT" | grep -qiE 'implement|create|add|build|write|refactor|fix|migrate'; then
  # Check git for changes (if in a git repo)
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CHANGES" = "0" ]; then
      echo "Implementation task marked complete but no file changes detected. Verify your work was saved, then mark complete again." >&2
      exit 2
    fi
  fi
fi

# All checks passed
exit 0
