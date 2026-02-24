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
    # Fallback: check legacy workspace location
    WORKSPACE_FALLBACK="$HOME/.claude/teams/$TEAM_NAME/progress.md"
    if [ ! -f "$WORKSPACE_FALLBACK" ]; then
      echo "Workspace missing at $WORKSPACE_DIR/. The lead must initialize the workspace (Phase 3, step 3) before any tasks can be completed." >&2
      exit 2
    fi
  fi
fi

# Check for implementation tasks: verify files were actually modified.
# Skip git check for workspace-only tasks (reports, audits, reviews, analyses)
# whose output goes to .agent-team/ workspace files rather than git-tracked code.
# Implementation keywords take precedence over skip keywords.
# This prevents "Write tests for audit module" from being treated as workspace-only.
if echo "$TASK_SUBJECT" | grep -qiE 'implement|create|add|build|write|refactor|fix|migrate'; then
  # Check git for changes (if in a git repo).
  # Trade-off: this checks ALL repo changes (staged + unstaged + untracked),
  # not just changes made by this specific teammate. Unrelated dirty files
  # will cause this to always pass; conversely, a teammate who only modifies
  # workspace files may be falsely blocked. Accepted as good-enough heuristic.
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CHANGES" = "0" ]; then
      echo "Implementation task marked complete but no file changes detected. Verify your work was saved, then mark complete again." >&2
      exit 2
    fi
  fi
elif echo "$TASK_SUBJECT" | grep -qiE 'report|audit|review|analyze|analyse'; then
  : # Workspace-only task — skip git change check
fi

# All checks passed
exit 0
