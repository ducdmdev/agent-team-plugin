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
TASK_ID=$(echo "$INPUT" | jq -r '.task_id // empty')
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // empty')

# Skip validation if no task subject
if [ -z "$TASK_SUBJECT" ]; then
  exit 0
fi

# Check for workspace existence (if this is a team task)
if [ -n "$TEAM_NAME" ]; then
  # Check for workspace in project directory.
  # Remediation teams use name {original}-fix but reuse workspace at .agent-team/{original}/.
  WORKSPACE_DIR=".agent-team/$TEAM_NAME"
  if [ ! -d "$WORKSPACE_DIR" ]; then
    # Try stripping -fix suffix (remediation team convention)
    BASE_NAME="${TEAM_NAME%-fix}"
    if [ "$BASE_NAME" != "$TEAM_NAME" ] && [ -d ".agent-team/$BASE_NAME" ]; then
      WORKSPACE_DIR=".agent-team/$BASE_NAME"
    fi
  fi

  if [ -d "$WORKSPACE_DIR" ]; then
    # Workspace exists — check for tracking files
    for f in progress.md tasks.md issues.md; do
      if [ ! -f "$WORKSPACE_DIR/$f" ]; then
        echo "Workspace file missing: $WORKSPACE_DIR/$f. The lead must initialize all workspace files (Phase 3, step 3) before tasks can be completed." >&2
        exit 2
      fi
    done
  else
    # Fallback: check legacy workspace location (pre-v1.2.0 used ~/.claude/teams/)
    WORKSPACE_FALLBACK="$HOME/.claude/teams/$TEAM_NAME/progress.md"
    if [ ! -f "$WORKSPACE_FALLBACK" ]; then
      echo "Workspace missing at .agent-team/$TEAM_NAME/. The lead must initialize the workspace (Phase 3, step 3) before any tasks can be completed." >&2
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
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CHANGES="0"
    # Try scoped check first: if we know the teammate and their owned files, only check those
    if [ -n "$TEAMMATE_NAME" ] && [ -n "$WORKSPACE_DIR" ] && [ -f "$WORKSPACE_DIR/file-locks.json" ]; then
      OWNED_PATHS=$(jq -r --arg t "$TEAMMATE_NAME" '.[$t] // [] | .[]' "$WORKSPACE_DIR/file-locks.json" 2>/dev/null)
      if [ -n "$OWNED_PATHS" ]; then
        while IFS= read -r owned_path; do
          [ -z "$owned_path" ] && continue
          PATH_CHANGES=$(git status --porcelain -- "$owned_path" 2>/dev/null | wc -l | tr -d ' ')
          CHANGES=$((CHANGES + PATH_CHANGES))
        done <<< "$OWNED_PATHS"
      else
        # Teammate not in file-locks — fall back to repo-wide
        CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
      fi
    else
      # No scoping info — fall back to repo-wide (original behavior)
      CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    fi
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
