# Tier 2: Execution Robustness Enhancements — Design Spec

**Date**: 2026-03-24
**Status**: Draft
**Version target**: 3.2.0

## Overview

4 hook-based enhancements to improve execution robustness. All are hard or advisory enforcement via bash scripts registered in `hooks/hooks.json`.

---

## Enhancement 5: Workspace Completeness Check

**Script**: `scripts/check-workspace-completeness.sh`
**Hook event**: `SubagentStart` (alongside validate-task-graph and track-teammate-lifecycle)

### Checks

1. `progress.md` exists and contains `**Archetype**` field
2. `tasks.md` exists and is non-empty
3. `issues.md` exists
4. `task-graph.json` exists
5. If `**Pipeline status**` field exists, value is valid (`approved`, `executed`, or `audited`)

### Behavior

- All files present → exit 0 (allow spawn)
- Missing files/fields → exit 2 (block) with stderr listing what's missing
- No workspace directory found → exit 0 (team may be initializing)

### Graceful Degradation

- No jq → exit 0
- No workspace → exit 0

---

## Enhancement 6: Plan-Mode Revision Limit

**Script**: `scripts/enforce-plan-revision-limit.sh`
**Hook event**: `PreToolUse(SendMessage)`

### How It Works

1. Read stdin — get message content
2. Check if message contains `PLAN_REVISION` prefix
3. If not a revision → exit 0
4. If revision → read `progress.md` Plan Proposals table
5. Count revisions for the targeted teammate's task
6. If count >= 2 → exit 2: "Plan-mode revision limit reached (2/2) for {teammate} on task #{N}. Accept the current proposal or reassign the task."
7. If count < 2 → exit 0

### Edge Cases

- No workspace → exit 0 (not in a team session)
- No Plan Proposals table → exit 0 (plan-mode not active)
- Message doesn't match PLAN_REVISION → exit 0

### Graceful Degradation

- No jq → exit 0

---

## Enhancement 7: Pre-Shutdown Commit Enforcement

**Script**: `scripts/enforce-pre-shutdown-commit.sh`
**Hook event**: `PreToolUse(TeamDelete)`

### How It Works

1. Read workspace `file-locks.json` to get owned file paths
2. For each owner with write-access (Implementer, Tester), run `git status --porcelain` on their files
3. Uncommitted changes found → exit 2: "Uncommitted changes detected. {teammate} has dirty files: {list}. Commit or stash before shutdown."
4. All clean → exit 0

### Graceful Degradation

- No git → exit 0
- No file-locks.json → exit 0
- No workspace → exit 0

---

## Enhancement 8: Integration Point File Validation

**Script**: Enhance existing `scripts/check-integration-point.sh`
**Hook event**: `TaskCompleted` (existing)

### Changes to Existing Script

After the current convergence detection block, add output file validation:

1. When convergence point detected (all upstream deps complete), read each upstream task's `output_files` array from `task-graph.json`
2. Check each file exists on disk via `test -f`
3. Missing files → stderr warning: "Integration point {task}: upstream output files missing: {list}. Verify before starting downstream task."
4. Still exit 0 (advisory, not blocking)

**Why advisory**: Missing output files could be legitimate (renamed, in-memory, different than declared). Blocking would cause false positives.

### Estimated Change

~15 lines added after the existing convergence detection block.

---

## Summary of File Changes

### New Files

| File | Purpose |
|------|---------|
| `scripts/check-workspace-completeness.sh` | Workspace completeness check |
| `scripts/enforce-plan-revision-limit.sh` | Plan-mode revision limit |
| `scripts/enforce-pre-shutdown-commit.sh` | Pre-shutdown commit check |
| `tests/hooks/test-check-workspace-completeness.sh` | Tests for #5 |
| `tests/hooks/test-enforce-plan-revision-limit.sh` | Tests for #6 |
| `tests/hooks/test-enforce-pre-shutdown-commit.sh` | Tests for #7 |

### Modified Files

| File | Change |
|------|--------|
| `scripts/check-integration-point.sh` | Add output file existence check (~15 lines) |
| `hooks/hooks.json` | Register 3 new hooks (SubagentStart, PreToolUse(SendMessage), PreToolUse(TeamDelete)) |
| `tests/hooks/test-check-integration-point.sh` | Add test for output file warning |
| `CLAUDE.md` | Update hook count (13), script count (16), test count |
| `README.md` | Update hook count, add 3 new hook descriptions, update structure tree |
| `CHANGELOG.md` | Add v3.2.0 entry |
| `.claude-plugin/plugin.json` | Version 3.2.0 |
| `.claude-plugin/marketplace.json` | Version 3.2.0 |

### Hook Registration Changes

Current hooks.json has 10 entries across 6 event types. After changes:

| Event | Current | After |
|-------|---------|-------|
| TaskCompleted | 3 entries | 3 entries (no change) |
| TeammateIdle | 1 entry | 1 entry (no change) |
| SessionStart | 2 entries | 2 entries (no change) |
| PreToolUse(Write\|Edit) | 1 entry | 1 entry (no change) |
| PreToolUse(SendMessage) | — | 1 entry (NEW) |
| PreToolUse(TeamDelete) | — | 1 entry (NEW) |
| SubagentStart | 2 entries | 3 entries (+1) |
| SubagentStop | 1 entry | 1 entry (no change) |

**Total**: 10 → 13 hook entries.

---

## Testing Plan

### New Tests

| Script | Test Cases |
|--------|-----------|
| check-workspace-completeness | All files present (pass), missing progress.md (block), missing issues.md (block), missing Archetype field (block), invalid Pipeline status (block), no workspace (pass), empty tasks.md (block) |
| enforce-plan-revision-limit | Non-revision message (pass), first revision (pass), second revision (pass), third revision (block), no workspace (pass), no Plan Proposals (pass) |
| enforce-pre-shutdown-commit | All clean (pass), dirty files (block), no git (pass), no file-locks (pass), no workspace (pass) |

### Modified Tests

| Script | New Test Cases |
|--------|---------------|
| test-check-integration-point | Convergence with missing output files (warning in stderr), convergence with all files present (no warning) |

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| PreToolUse(SendMessage) fires on every message, not just PLAN_REVISION | High (by design) | Script checks for PLAN_REVISION prefix first; exits 0 immediately for non-revisions |
| PreToolUse(TeamDelete) blocks legitimate cleanup | Low | Graceful degradation: no git/file-locks → allow |
| SubagentStart has 3 hooks now (validate-task-graph, check-workspace, track-lifecycle) | Medium | Each has short timeout (5-15s); total < 30s |
| False positive on integration file check | Low | Advisory only (exit 0), loud warning |
