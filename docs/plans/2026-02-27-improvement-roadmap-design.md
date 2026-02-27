# Agent Team Plugin Improvement Roadmap — Design

**Date**: 2026-02-27
**Status**: Approved
**Scope**: Full roadmap (Phase A+B+C) across 5 incremental releases
**Strategy**: Layer by Risk — docs first, then prompts, then hooks, then structural, then major features

---

## Context

Research across 3 streams identified 24 improvement opportunities:

- **Docs research**: 12 gaps, 10 recommendations from Claude Code official documentation
- **Competitor research**: 12+ tools analyzed, 7 strengths confirmed, 13 improvement opportunities
- **GitHub research**: 15+ repos analyzed, 10 patterns worth adopting, 3 ecosystem gaps we fill

Research artifacts:
- `.agent-team/research-improvements/docs-findings.md`
- `.agent-team/research-improvements/competitor-findings.md`
- `.agent-team/research-improvements/github-deep-dive.md`

### Key Strengths to Preserve

1. Industry-leading inter-agent communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF)
2. Persistent, auditable workspace (.agent-team/ with progress/tasks/issues)
3. Best-in-class task dependency system (TaskCreate + blockedBy)
4. Unique hook enforcement mechanism (TaskCompleted + TeammateIdle)
5. Competitive role-based team composition (6 roles with spawn templates)
6. Unique remediation gate pattern (max 1 cycle)
7. Unique coordination patterns library (14 patterns)

### Design Decisions

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Release strategy | Layer by Risk (5 releases) | Each release has consistent risk profile; safest progression |
| File ownership enforcement | Warn-then-block | First violation warns, second blocks. Balances safety with flexibility |
| Git worktree isolation | Opt-in via Phase 2 flag | Backward compatible; not all projects need hard isolation |

---

## Release Plan

### v1.3.0 — Documentation & Patterns (Zero Risk)

**Files changed**: `docs/coordination-patterns.md`, `docs/custom-roles.md` (new), `hooks/hooks.json` (description field), `README.md`, `CHANGELOG.md` (new)

| # | Item | Source | File |
|---|------|--------|------|
| 1 | Re-plan on Block pattern | Competitor 4.3 | docs/coordination-patterns.md |
| 2 | Adversarial review rounds pattern | GitHub G2 | docs/coordination-patterns.md |
| 3 | Quality gate before Phase 5 | GitHub G3 | docs/coordination-patterns.md |
| 4 | Auto-block on repeated failures | GitHub G5 | docs/coordination-patterns.md |
| 5 | Custom role definitions template | Competitor 4.7 | docs/custom-roles.md (new) |
| 6 | Companion plugins documentation | GitHub G4 | README.md |
| 7 | MCP tool extension documentation | Competitor 4.10 | README.md |
| 8 | hooks.json description field | Docs R2 | hooks/hooks.json |
| 9 | CHANGELOG.md | Docs R5 | CHANGELOG.md (new) |

**Details:**

#### 1. Re-plan on Block Pattern
New section in `docs/coordination-patterns.md`. When a critical BLOCKED arrives:
1. Lead assesses if original plan is still viable
2. If not, presents a revised plan to the user for approval
3. Reassigns tasks accordingly
Keeps human-in-the-loop while enabling plan adaptation. Inspired by Devin's dynamic re-planning.

#### 2. Adversarial Review Rounds
New section in `docs/coordination-patterns.md`:
1. Reviewer A produces findings
2. Reviewer B cross-reviews Reviewer A's findings
3. Lead synthesizes disagreements
4. Iterate until convergence or escalate to user
Inspired by adversarial-spec multi-LLM debate pattern.

#### 3. Quality Gate Before Phase 5
New section in `docs/coordination-patterns.md`. Before synthesis, lead assigns quick verification tasks to remaining active teammates as a final validation pass. Inspired by ClaudeCodeAgents quality pipeline.

#### 4. Auto-Block on Repeated Failures
New section in `docs/coordination-patterns.md`. If a teammate reports BLOCKED on the same task 3 times, lead escalates immediately instead of allowing retries. Inspired by Flow-Next's auto-block pattern.

#### 5. Custom Role Definitions Template
New file `docs/custom-roles.md` with a template:
```markdown
# Custom Roles: {project-name}

## {Role Name}
**Purpose**: {what this role does}
**When to use**: {task types}
**Typical tools**: {tool list}
**Spawn prompt template**: {full prompt}
```
Lead reads this during Phase 1 and uses custom roles alongside built-in ones. Inspired by Roo Code's Custom Modes.

#### 6. Companion Plugins Documentation
New README section:
- `claude-code-safety-net`: Blocks destructive bash commands during team sessions
- `claude-code-hooks-multi-agent-observability`: Real-time monitoring dashboard

#### 7. MCP Tool Extension Documentation
README note that MCP-provided tools are automatically available to all team members. No plugin changes needed.

#### 8. hooks.json Description
```json
{
  "description": "Agent Team quality gates — prevents premature task completion and nudges idle teammates",
  "hooks": { ... }
}
```

#### 9. CHANGELOG.md
Initial changelog covering v1.0.0 through v1.3.0.

---

### v1.4.0 — Prompt & Template Improvements (Low Risk)

**Files changed**: `skills/agent-team/SKILL.md`, `docs/worker-roles.md`, `docs/report-format.md`

| # | Item | Source | File |
|---|------|--------|------|
| 1 | Re-read workspace in spawn templates | GitHub G6 | docs/worker-roles.md |
| 2 | Memory persistence step (Phase 5) | Competitor 4.4, GitHub G9 | skills/agent-team/SKILL.md |
| 3 | Team metrics in final report | Competitor 4.9 | docs/report-format.md |
| 4 | Grouped tasks.md by status | GitHub G10 | skills/agent-team/SKILL.md |
| 5 | Phase 1 custom roles reference | Competitor 4.7 | skills/agent-team/SKILL.md |

**Details:**

#### 1. Re-read Workspace in Spawn Templates
Add to all role spawn templates in `docs/worker-roles.md`:
> "Before starting each new task, re-read workspace files (progress.md, tasks.md, issues.md) to ensure you have current state."

Prevents context drift. Inspired by Flow-Next's re-anchoring pattern.

#### 2. Memory Persistence Step
New step 5.5 in SKILL.md Phase 5:
> "Save key decisions, architectural patterns, and lessons learned to `.claude/memory/` for future team sessions."

Bridges the session memory gap (Windsurf and Augment Code have persistent memories).

#### 3. Team Metrics in Final Report
New section in `docs/report-format.md` template:
```markdown
### Team Metrics
- Tasks: {completed}/{total}
- Issues: {resolved}/{total} ({critical}C {high}H {medium}M {low}L)
- Handoffs: {count}
- Blocked events: {count}
- Remediation cycles: {count}
```

#### 4. Grouped tasks.md by Status
Update workspace template in SKILL.md Phase 3:
```markdown
## In Progress
| ID | Subject | Owner | Notes |
## Blocked
| ID | Subject | Owner | Blocked By | Notes |
## Pending
| ID | Subject | Owner | Blocked By | Notes |
## Completed
| ID | Subject | Owner | Notes |
```

#### 5. Phase 1 Custom Roles Reference
Add to Phase 1:
> "Check for `docs/custom-roles.md` in the project. If it exists, read it and include custom roles in the decomposition alongside built-in roles."

---

### v1.5.0 — New Hooks (Medium Risk)

**Files changed**: `hooks/hooks.json`, `scripts/` (3 new scripts, 1 updated), `skills/agent-team/SKILL.md`

| # | Item | Source | File |
|---|------|--------|------|
| 1 | SessionStart(compact) hook | Docs R1 | scripts/recover-context.sh, hooks.json |
| 2 | PreToolUse file ownership hook | GitHub G1 | scripts/check-file-ownership.sh, hooks.json |
| 3 | SubagentStart/Stop lifecycle hooks | Docs R6, GitHub G8 | scripts/track-teammate-lifecycle.sh, hooks.json |
| 4 | Enhanced TaskCompleted hook | Docs R3 | scripts/verify-task-complete.sh |
| 5 | file-locks.json workspace file | GitHub G1 | skills/agent-team/SKILL.md |
| 6 | SKILL.md Hooks section update | — | skills/agent-team/SKILL.md |

**Details:**

#### 1. SessionStart(compact) Hook — `scripts/recover-context.sh`
- Fires after context compaction (matcher: "compact")
- Scans for active workspace: `.agent-team/*/progress.md` where status != "done"
- Outputs workspace paths and key state summary to stdout (injected into context)
- Timeout: 10s
- Registration:
  ```json
  "SessionStart": [{
    "matcher": "compact",
    "hooks": [{
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/recover-context.sh",
      "timeout": 10
    }]
  }]
  ```

#### 2. PreToolUse File Ownership Hook — `scripts/check-file-ownership.sh`
- Matcher: `Write|Edit` (matches Write and Edit tool calls)
- Reads ownership from `.agent-team/{team}/file-locks.json`
- **Warn-then-block behavior**:
  - First violation on a file by a teammate → exit 0 + stderr warning
  - Second violation on same file by same teammate → exit 2 (block)
- Violation tracking: `/tmp/agent-team-ownership-violations/{team}--{teammate}--{file-hash}`
- `file-locks.json` format:
  ```json
  {
    "backend-impl": ["src/auth/", "src/middleware/auth.ts"],
    "frontend-impl": ["src/components/", "src/pages/"]
  }
  ```
- Workspace-only files (`.agent-team/`) always allowed
- Graceful degradation: exit 0 if no file-locks.json, no jq, or no team active

#### 3. SubagentStart/SubagentStop Hooks — `scripts/track-teammate-lifecycle.sh`
- SubagentStart: Appends spawn event to `.agent-team/{team}/events.log`
- SubagentStop: Appends stop event with exit reason
- Non-blocking (async or always exit 0)
- Event format: JSON lines (one per line)
- Registration:
  ```json
  "SubagentStart": [{
    "hooks": [{
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/track-teammate-lifecycle.sh",
      "timeout": 5
    }]
  }],
  "SubagentStop": [{
    "hooks": [{
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/track-teammate-lifecycle.sh",
      "timeout": 5
    }]
  }]
  ```

#### 4. Enhanced TaskCompleted Hook
Update `scripts/verify-task-complete.sh`:
- Read `task_id` and `teammate_name` from input JSON
- Use `teammate_name` to scope git checks: only verify changes in files owned by this teammate (via file-locks.json)
- Log task_id for tracking
- Backward compatible: if teammate_name or file-locks.json missing, fall back to current behavior

#### 5. file-locks.json Workspace File
- New 4th workspace file initialized during Phase 3
- Populated from Phase 2 plan's file ownership mapping
- Phase 3 step 3 updated to create 4 files instead of 3
- Cleanup step in Phase 5 step 10 updated

#### 6. SKILL.md Hooks Section Update
Document all hooks (now 5 total): TaskCompleted, TeammateIdle, SessionStart(compact), PreToolUse(Write|Edit), SubagentStart, SubagentStop.

---

### v1.6.0 — Structural Improvements (Medium-High Risk)

**Files changed**: `skills/agent-team/SKILL.md` (Phase 3 + 5), `docs/worker-roles.md`, `docs/coordination-patterns.md`

| # | Item | Source | File |
|---|------|--------|------|
| 1 | Auto-branch per teammate | Competitor 4.5 | SKILL.md, worker-roles.md |
| 2 | Event log file | GitHub G7 | SKILL.md, coordination-patterns.md |
| 3 | Direct agent communication | Competitor 4.6 | coordination-patterns.md, SKILL.md |

**Details:**

#### 1. Auto-Branch Per Teammate
- **Phase 3**: Implementer spawn prompts include: `git checkout -b {team-name}/{teammate-name}`
- **Phase 5**: After pre-shutdown commits, lead (or designated teammate) merges all feature branches
- **New step**: "Branch Merge" before report generation
- **Fallback**: If not in git repo, skip branching (current behavior)
- Backward compatible: existing behavior is the fallback

#### 2. Event Log File
- New workspace artifact: `.agent-team/{team}/events.log`
- Structured JSON lines, append-only:
  ```json
  {"ts":"...","type":"spawn","agent":"...","role":"..."}
  {"ts":"...","type":"task_start","agent":"...","task":"#1"}
  {"ts":"...","type":"task_complete","agent":"...","task":"#1"}
  {"ts":"...","type":"blocked","agent":"...","task":"#3","severity":"high"}
  ```
- Lead appends during Phase 4 (workspace update protocol gets new rows)
- SubagentStart/Stop hooks (v1.5.0) also append
- Data source for team metrics and future dashboard

#### 3. Direct Agent Communication (Optional)
- New section in `docs/coordination-patterns.md`: "Direct Handoff"
- For pre-approved transfers, lead authorizes direct messaging between specific teammates
- Lead still logs handoff in progress.md (audit trail preserved)
- Brief note in SKILL.md Phase 4

---

### v2.0.0 — Major Features (High Risk)

**Files changed**: `skills/agent-team/SKILL.md` (Phase 2, 3, 5), `scripts/` (2 new), `docs/worker-roles.md`

| # | Item | Source | File |
|---|------|--------|------|
| 1 | Git worktree isolation (opt-in) | Competitor 4.1 | SKILL.md, scripts/ |
| 2 | Nested task decomposition | GitHub G11 | SKILL.md, worker-roles.md |
| 3 | HTML progress dashboard | Competitor 4.8, GitHub G12 | scripts/ or skill |

**Details:**

#### 1. Git Worktree Isolation (Opt-in)
- **Phase 2**: Plan includes `isolation` field: `shared` (default) or `worktree`
- **When `isolation: worktree`**:
  - Phase 3: Create worktree per implementer (`git worktree add` or `EnterWorktree`)
  - Phase 4: Same coordination, teammates in isolated directories
  - Phase 5: Merge worktrees, resolve conflicts, cleanup
  - File ownership hook becomes redundant (hard isolation)
- **When `isolation: shared`**: Current behavior unchanged
- **Fallback**: If worktree creation fails, fall back to shared + warning
- **New scripts**: `scripts/setup-worktree.sh`, `scripts/merge-worktrees.sh`

#### 2. Nested Task Decomposition
- Senior implementers can create sub-tasks (TaskCreate) and assign to subagents
- Sub-tasks prefixed with parent ID: `#3.1`, `#3.2`
- Results roll up to parent task
- One level of nesting max
- Spawn prompt permission: "You may create sub-tasks and spawn subagents for independent portions of your work"
- Lead sees sub-tasks in TaskList but interacts at parent level

#### 3. HTML Progress Dashboard
- Generates `.agent-team/{team}/dashboard.html` — static, single file
- Reads workspace files, renders: team composition, task kanban, event timeline, issue tracker
- Inline CSS/JS, no server needed
- Generated on demand by the lead
- Could be a separate skill or a script

---

## Testing Strategy

| Release | Test Approach |
|---------|---------------|
| v1.3.0 | `claude plugin validate .` + manual review of new docs |
| v1.4.0 | Manual team session to verify prompt changes work |
| v1.5.0 | Unit tests for new hook scripts + manual team session |
| v1.6.0 | Integration test: spawn team with auto-branch, verify branches created and merged |
| v2.0.0 | Integration test: worktree isolation end-to-end, nested task creation |

## Migration Notes

- v1.3.0 → v1.4.0: No breaking changes. Existing workspaces continue to work.
- v1.4.0 → v1.5.0: New `file-locks.json` file. Old workspaces without it degrade gracefully (hooks skip validation).
- v1.5.0 → v1.6.0: Auto-branch is additive. Old behavior is the fallback.
- v1.6.0 → v2.0.0: Worktree is opt-in. Default behavior unchanged. Major version because nested decomposition changes the team model.
