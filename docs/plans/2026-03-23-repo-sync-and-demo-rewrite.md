# Repo Sync & Demo Rewrite — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sync all repo metadata, README demo, and GitHub release notes with the v3.0.0 pipeline architecture.

**Architecture:** Update repo description and topics via `gh` CLI. Rewrite the README "See It In Action" demo to show the 3-team pipeline flow. Replace auto-generated release notes with structured CHANGELOG content.

**Tech Stack:** GitHub CLI (`gh`), markdown editing. No code changes.

---

## Chunk 1: All Tasks

### Task 1: Update GitHub repo description and topics

**Files:** None (GitHub API only)

- [ ] **Step 1: Update repo description**

```bash
gh repo edit --description "Orchestrate parallel AI teammates in Claude Code — pipeline stages (plan, execute, audit) with team-per-stage, hook enforcement, and workspace tracking"
```

- [ ] **Step 2: Remove redundant topic**

```bash
gh repo edit --remove-topic claude-plugin
```

- [ ] **Step 3: Add new topics**

```bash
gh repo edit --add-topic pipeline --add-topic code-review --add-topic error-recovery
```

- [ ] **Step 4: Verify**

```bash
gh repo view --json description,repositoryTopics | jq '{description, topics: [.repositoryTopics[].name]}'
```

Expected: description updated, topics include `pipeline`, `code-review`, `error-recovery`, no `claude-plugin` duplicate.

---

### Task 2: Rewrite README "What It Does" and "See It In Action"

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update "What It Does" section (lines 7-14)**

Replace:

```markdown
## What It Does

This plugin adds an **Agent Team** skill to Claude Code that decomposes complex tasks into parallel work streams executed by multiple AI teammates.

- A **team lead** coordinates but never writes code
- **Teammates** (implementers, reviewers, researchers) work in parallel — each owning distinct files
- **Hooks** enforce discipline: block premature completion, nudge idle teammates
- A **persistent workspace** tracks progress, tasks, issues, decisions, and generates a final report
```

With:

```markdown
## What It Does

This plugin adds **Agent Team pipeline skills** to Claude Code that decompose complex tasks into parallel work streams executed by multiple AI teammates across 3 stages.

- A **team lead** coordinates each stage but never writes code
- **3 pipeline stages** — plan (decompose), execute (build), audit (verify) — each with its own team
- **Teammates** (implementers, reviewers, researchers, analysts) work in parallel — each owning distinct files
- **Hooks** enforce discipline: block premature completion, nudge idle teammates
- **Inter-stage review agents** validate output before handoff between stages
- A **persistent workspace** tracks progress, tasks, issues, decisions, and generates a final report
```

- [ ] **Step 2: Rewrite "See It In Action" demo (lines 16-104)**

Replace the entire demo section with a v3.0.0 pipeline demo showing 3 teams. The new demo:

```markdown
## See It In Action

![Agent Team Demo](assets/demo.gif)

Here's what happens when you say: *"use agent team to refactor the auth module"*

` ` `
You > use agent team to refactor the auth module

━━ Stage 1 — Plan ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [Planning team created: 2 Researchers + 1 Plan Reviewer]

  researcher-1:  FINDING: auth module has 3 sub-modules (token, session, middleware), relevance=high
  researcher-2:  FINDING: token interface shared across 4 consumers, relevance=high
  researcher-1:  FINDING: no tests for session management, relevance=medium
  plan-reviewer: PLAN_REVIEW: status=approved

  Team plan for: refactor auth module
  Archetype: implementation (auto-detected — say "change to [type]" to override)
  Complexity: standard

  Teammates (3):
  - auth-impl-1 (Implementer, plan-mode): token validation + middleware
  - auth-impl-2 (Implementer): session management
  - auth-reviewer (Reviewer): validate all changes

  Task breakdown:
  1. Refactor token validation logic        -> auth-impl-1
  2. Extract session management             -> auth-impl-2
  3. Update middleware to use new interfaces -> auth-impl-1 (blocked by #2)
  4. Review all changes                     -> auth-reviewer (blocked by #1, #3)

  Pipeline status: approved
  Workspace: .agent-team/0323-refactor-auth/

  [Planning team shut down]
  Approve?

You > y

━━ Stage 2 — Execute ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [Execution team created: 2 Implementers + 1 Reviewer + 1 Execute Reviewer]

  auth-impl-1:  PLAN_PROPOSAL #1: Adapter pattern for token validation...
  Lead:         PLAN_APPROVED #1
  auth-impl-1:  STARTING #1: Refactoring token validation, touching src/auth/token.ts
  auth-impl-2:  STARTING #2: Extracting session logic to src/auth/session.ts
  auth-impl-1:  COMPLETED #1: Token validation refactored, 3 files changed
  auth-impl-2:  BLOCKED #2: severity=medium, error_type=recoverable, need token interface shape
  Lead:         Recovery: forwarding token interface from impl-1 to impl-2
  auth-impl-2:  COMPLETED #2: Session management extracted, 2 files changed
  auth-impl-1:  STARTING #3: Updating middleware to use new interfaces
  auth-impl-1:  COMPLETED #3: Middleware updated, 1 file changed
  auth-reviewer: STARTING #4: Reviewing all changes across both scopes
  auth-reviewer: COMPLETED #4: 5 issues found — 0 high, 3 medium, 2 low

  exec-reviewer: EXECUTE_REVIEW: status=ready_for_audit, 4/4 tasks done, 6 files changed

  Pipeline status: executed
  [Execution team shut down]

━━ Stage 3 — Audit ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [Audit team created: 1 Reviewer + 1 Elegance Reviewer + 1 Audit Reviewer]

  reviewer:          Completion gate (8/8 passed):
                       ✓ Uncommitted changes  ✓ Build & tests    ✓ Lint/format
                       ✓ Integration          ✓ Security scan    ✓ Workspace issues
                       ✓ Plan completion      ✓ Documentation sync

  elegance-reviewer: ELEGANCE_REVIEW: overall_score=4.2
                       simplicity=4, consistency=5, readability=4, testability=4, minimal_impact=4
                       2 findings: 1 improve, 1 nitpick

  Lessons captured -> .agent-team/0323-refactor-auth/lessons.md
  Pattern library updated (1 new pattern from resolved BLOCKED issue)

  audit-reviewer:    AUDIT_REVIEW: status=approved

  Report: .agent-team/0323-refactor-auth/report.md
  Pipeline status: audited
  [Audit team shut down]

  Total: 6 files changed, 4/4 tasks completed, 0 open issues, elegance score 4.2/5
` ` `

The workspace persists at `.agent-team/0323-refactor-auth/` with the full audit trail: tasks, issues, decisions, lessons, and final report.
```

**IMPORTANT**: Replace the triple backtick placeholders (` ` `) with actual triple backticks. They are escaped here to avoid markdown parsing issues.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README demo for v3.0.0 pipeline architecture"
```

---

### Task 3: Update GitHub release notes

**Files:** None (GitHub API only)

- [ ] **Step 1: Read CHANGELOG for v3.0.0 content**

```bash
head -45 CHANGELOG.md
```

- [ ] **Step 2: Update release notes**

```bash
gh release edit v3.0.0 --notes "$(cat <<'NOTES'
## Breaking Changes
- **Skill restructure**: 5 archetype skills replaced with 4 pipeline stages (`agent-team:start`, `agent-team:plan`, `agent-team:execute`, `agent-team:audit`)
- **Migrated shared docs into stage skills**: `shared-phases.md`, `spawn-templates.md`, `communication-protocol.md`, `coordination-patterns.md`, `coordination-advanced.md`, `report-format.md` moved into stage-specific `references/`, `agents/`, `examples/` subfolders

## Added
- **Pipeline entry point** (`skills/start/SKILL.md`) — type detection, routing to plan/execute/audit
- **Team per stage** — each stage creates its own ephemeral team (plan: Researcher+Analyst+Plan Reviewer, execute: Implementers+Tester+Reviewer+Execute Reviewer, audit: Reviewer+Elegance Reviewer+Audit Reviewer)
- **Prior context loading** — plan stage loads lessons and error patterns from prior teams
- **Plan-mode gate** — teammates propose approach before executing; lead reviews and approves
- **Error recovery loop** — classifies errors (retry/recoverable/design_flaw), bounded auto-recovery
- **Elegance review** — 5-dimension quality assessment (advisory, not blocking)
- **Lessons capture** — post-execution insights for future teams
- **Error pattern library** — global `~/.claude/agent-team-patterns.json` shared across projects
- **Inter-stage review agents** — plan-reviewer, execute-reviewer, audit-reviewer validate output between stages
- **Elegance Reviewer role** — new teammate role (13 total)
- **`recovery_class` field** — each role declares error recovery behavior
- **Pipeline status handoff** — `Pipeline status`, `Stage`, `Archetype` fields in progress.md
- New spawn templates: `researcher.md`, `analyst.md` (plan stage), `reviewer.md` (audit stage)
- `FINDING`, `ANALYSIS`, `PLAN_PROPOSAL`, `PLAN_APPROVED`, `PLAN_REVISION`, `PLAN_REVIEW`, `EXECUTE_REVIEW`, `ELEGANCE_REVIEW`, `AUDIT_REVIEW` message types

## Removed
- `skills/agent-team/`, `skills/agent-implement/`, `skills/agent-research/`, `skills/agent-audit/`, `skills/agent-plan/`
- `docs/shared-phases.md`, `docs/spawn-templates.md`, `docs/communication-protocol.md`, `docs/coordination-patterns.md`, `docs/coordination-advanced.md`, `docs/report-format.md`
NOTES
)"
```

- [ ] **Step 3: Verify**

```bash
gh release view v3.0.0 | head -30
```

---

### Task 4: Run tests and push

**Files:** None (verification only)

- [ ] **Step 1: Run tests**

```bash
bash tests/run-tests.sh
```

All must pass.

- [ ] **Step 2: Push**

```bash
git push origin main
```

- [ ] **Step 3: Verify repo page**

```bash
gh repo view --web
```
