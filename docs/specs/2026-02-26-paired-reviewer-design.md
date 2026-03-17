# Paired Reviewer per Implementer

**Date**: 2026-02-26
**Updated**: 2026-02-27
**Status**: Not Started (approved design, not implemented)

## Problem

Currently, the agent team uses a shared reviewer model — one reviewer for the entire team. This means:
- No guaranteed review coverage per implementer
- Review is optional for standard-complexity plans
- Issues may slip through when one reviewer is spread across multiple implementers

## Decision

Paired review is **optional** — the lead presents it as an option in Phase 2 and the user decides whether to enable it. When enabled, every implementer gets a dedicated paired reviewer who continuously reviews each task. When disabled, implementer tasks go straight from COMPLETED to completed (no review loop).

The lead **recommends** paired review for complex plans but the user always has the final say. This keeps teams fast for simple tasks while allowing review rigor when the user wants it.

## Requirements

1. **User opt-in**: Lead presents paired review option in Phase 2 plan. User approves or declines. Lead recommends it for complex plans
2. **1:1 pairing** (when enabled): Every implementer gets a paired reviewer
3. **Continuous review** (when enabled): Reviewer reviews each task as the implementer completes it (not batch after all tasks)
4. **Lead audits issues**: Reviewer reports findings to lead → lead validates → lead writes confirmed issues to issues.md → lead routes fixes to implementer
5. **Blocking gate** (when enabled): Task stays `in_progress` until reviewer approves (REVIEW-PASS)
6. **Adjusted team size**: Max 6 mixed (up from 4), up to 8 if extras are read-only
7. **No review overhead when disabled**: COMPLETED → lead marks task complete directly. No reviewer spawned, no review-log.md needed

## Review Loop Protocol

```
Implementer --COMPLETED #N--> Lead
Lead --"Review task #N, files: [...]"--> Paired Reviewer
Reviewer reviews, sends REVIEW-PASS or REVIEW-FAIL to Lead
Lead audits findings (if REVIEW-FAIL):
  - Validates each issue
  - Writes confirmed issues to issues.md
  - Routes confirmed issues to Implementer
Implementer fixes, sends COMPLETED #N again
Loop repeats until REVIEW-PASS
Lead marks task #N complete
```

### New Structured Messages (Reviewer)

```
REVIEW-PASS #N: {no issues found, task approved}
REVIEW-FAIL #N: {issues found — H1: ..., M1: ..., L1: ...}
```

### Lead Audit Step

When reviewer sends REVIEW-FAIL #N:
1. Read findings (H/M/L with file:line references)
2. Validate each finding — is it real? Is severity correct?
3. Write confirmed issues to issues.md
4. Route confirmed issues to implementer for fixing
5. If lead disagrees with a finding, drop it (don't write to issues.md)

## Phase 2 Plan Format Change

The plan includes a `Paired review` line that the lead presents and the user approves or declines:

```
Team plan for: [task summary]
Complexity: standard | complex
Paired review: yes | no  ← lead recommends "yes" for complex plans
  (if yes) Each implementer gets a paired reviewer for continuous code review

Teammates (N total):
- backend-impl (implementer): auth module -> owns src/auth/
  └─ backend-reviewer (reviewer): reviews backend-impl's work  ← only if paired review = yes
- frontend-impl (implementer): UI components -> owns src/components/
  └─ frontend-reviewer (reviewer): reviews frontend-impl's work
```

If user declines paired review, the plan omits reviewer pairings and the team runs without the review loop.

## Phase 3 Spawn Rule

**If paired review is enabled**: for every implementer spawned, spawn a paired reviewer. The reviewer's prompt includes:
- Paired implementer name
- Implementer's file ownership (review scope)
- REVIEW-PASS / REVIEW-FAIL message format
- Instruction to wait for lead to route tasks for review

**If paired review is disabled**: do not spawn paired reviewers. COMPLETED messages from implementers go straight to task completion.

## Team Size Limits

| Limit | Old | New |
|-------|-----|-----|
| Mixed teams max | 4 | 6 |
| With read-only extras | 6 | 8 |

Paired reviewers use `subagent_type: "Explore"` (read-only) — zero file conflict risk.

## Updated Role Selection Guide

| Task Type | Recommended Roles | Typical Size | Paired Review |
|---|---|---|---|
| New feature (standard) | 1-2 implementers (+ paired reviewers if enabled) | 2-4 | Optional |
| New feature (complex) | 1-2 implementers + paired reviewers + 1 tester | 3-5 | Recommended |
| Full-stack feature | 2 implementers + 2 paired reviewers + 1 tester | 5 | Recommended |
| Refactoring | 1-2 implementers (+ paired reviewers if enabled) | 2-4 | Optional |
| Large audit / migration | 2 implementers + paired reviewers + 2-3 researchers | 6-7 | Recommended |

## Files to Change

| File | Change |
|---|---|
| `skills/agent-team/SKILL.md` | Phase 2 plan format (pairing), Phase 3 spawn rules (paired reviewer), Phase 4 review loop protocol, team size limits |
| `docs/worker-roles.md` | Updated Reviewer template (paired mode, REVIEW-PASS/FAIL), updated Role Selection Guide, updated Team Size Limits |
| `docs/coordination-patterns.md` | New "Review Loop" section |
