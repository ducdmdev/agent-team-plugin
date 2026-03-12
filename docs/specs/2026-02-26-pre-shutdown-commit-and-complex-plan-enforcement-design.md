# Design: Pre-Shutdown Commit & Complex Plan Enforcement

**Date**: 2026-02-26
**Status**: Implemented

---

## Feature 1: Pre-Shutdown Commit

### Problem

Teammates can be shut down without committing their work. File changes exist on disk but are not captured in git history, making it hard to trace what each teammate produced.

### Design

Add a new step to Phase 5 between "collect results" (step 2) and "check integration" (step 4). The lead messages each implementer to commit their owned files before shutdown proceeds.

### Flow

1. Lead verifies all tasks completed (existing step 1)
2. Lead collects results (existing step 2)
3. **Lead messages each implementer: "Commit your owned files before shutdown"** (NEW)
4. Each implementer runs `git add <owned files> && git commit -m "<convention-following message>"`
5. Implementer sends COMPLETED to lead with commit hash
6. If commit fails: implementer sends BLOCKED, must fix and retry. Shutdown cannot proceed until commit succeeds
7. Lead waits for all commit confirmations before continuing
8. Lead proceeds to integration check (existing step 4, now step 5)

### Scope

- **Only implementers commit** — reviewers, researchers, challengers, and testers are read-only with no files to commit
- **Commit message**: follows project convention, teammate describes what they did
- **Failure blocks shutdown** — teammate must fix and retry. Lead logs the failure in `issues.md`

### Files changed

| File | Change |
|------|--------|
| `skills/agent-team/SKILL.md` | Add step 3 to Phase 5, add commit instruction to implementer spawn prompt rules |
| `docs/worker-roles.md` | Add pre-shutdown commit rule to Implementer role template |
| `docs/coordination-patterns.md` | Add "Pre-Shutdown Commit" pattern |

---

## Feature 2: Complex Plan — Mandatory Reviewer + Tester

### Problem

Complex plans with multiple implementers, cross-module changes, or risky refactors can ship without dedicated quality gates. The lead may skip reviewer/tester roles when they are most needed.

### Design

Add a complexity assessment step to Phase 2. The lead evaluates the plan contextually and, if complex, must include a dedicated **reviewer** and a dedicated **tester** as separate teammates (not combined into one).

### Complexity signals

No hard threshold — the lead uses contextual judgment. Signals that suggest complexity:

- Changes span multiple modules/areas (backend + frontend, multiple services)
- Tasks involve architectural decisions or risky refactors
- Multiple implementers with cross-dependencies
- Security-sensitive or data-sensitive changes
- New system integrations or API boundaries

### Plan presentation format

```
Team plan for: [task summary]
Complexity: standard | complex
  (if complex) Reason: [why this is complex]
  (if complex) Dedicated reviewer included
  (if complex) Dedicated tester included

Teammates (N total):
...
```

### Self-check gate

Added to SKILL.md Phase 2:

> "Is this plan complex? If yes, does the teammate list include a dedicated reviewer AND a dedicated tester (separate teammates, not combined)? If no, add them before presenting."

### New role: Tester

Separate from Reviewer. Key differences:

| Aspect | Reviewer | Tester |
|--------|----------|--------|
| Purpose | Validate code quality by reading | Verify behavior by executing |
| Approach | Read code, find issues, report | Run tests, verify builds, check runtime |
| Tools | Read, Grep, Glob, Bash | Read, Grep, Glob, Bash |
| Output | Issue list with severity | Test results, pass/fail, reproduction steps |

### Files changed

| File | Change |
|------|--------|
| `skills/agent-team/SKILL.md` | Add complexity assessment + self-check to Phase 2, add Tester to Phase 3 spawn guidance |
| `docs/worker-roles.md` | Add Tester role definition + spawn template, update Role Selection Guide |
| `README.md` | Add Tester to Teammate Roles table |
