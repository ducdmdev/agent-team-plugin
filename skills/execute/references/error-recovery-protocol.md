# Error Recovery Protocol

Decision tree, classification guide, and bounds for handling teammate errors during Phase 4 coordination.

## Contents

- [Extended BLOCKED Format](#extended-blocked-format)
- [Error Type Classification Guide](#error-type-classification-guide)
- [Recovery Decision Tree](#recovery-decision-tree)
- [Fallback Approaches in task-graph.json](#fallback-approaches-in-task-graphjson)
- [Recovery Tracking in issues.md](#recovery-tracking-in-issuesmd)
- [Generic Recovery Behavior](#generic-recovery-behavior)
- [Recovery Bounds and Safety](#recovery-bounds-and-safety)

## Extended BLOCKED Format

When a teammate is blocked, they include an `error_type` field to help the lead classify the error:

```
BLOCKED #N: severity={critical|high|medium|low}, error_type={retry|recoverable|design_flaw|unknown},
           {blocker description}, impact={what can't proceed}
```

If a teammate sends BLOCKED without `error_type`, the lead classifies it as `unknown` and re-enters the decision tree.

## Error Type Classification Guide

| error_type | When to use | Examples |
|------------|-------------|---------|
| `retry` | Transient/flaky failure | Timeout, rate limit, flaky test, network glitch, temporary file lock |
| `recoverable` | Fixable with different approach, no re-plan needed | Wrong import path, missing dependency, incorrect API usage, type mismatch |
| `design_flaw` | Fundamental approach won't work | Interface incompatibility, wrong architecture, missing capability, unsupported platform |
| `unknown` | Can't classify | Novel errors, ambiguous failures, errors with no clear pattern |

### Classification Signals

When the lead needs to classify an `unknown` error:

1. **Check error message** — does it match a known pattern in `~/.claude/agent-team-patterns.json`?
2. **Check retry history** — has this exact error occurred before on this task? If yes, it's likely not `retry`
3. **Check scope** — does the error suggest the current approach is fundamentally wrong? If yes, `design_flaw`
4. **Check fixability** — can the teammate try a different method without changing the task definition? If yes, `recoverable`
5. **Default** — if still unclear after checks, treat as `recoverable` (attempt one fix before escalating)

## Recovery Decision Tree

```
On BLOCKED received:
|
+-- error_type = retry
|   +-- retries < 2 --> Tell teammate: "Retry with: {strategy from pattern library or 'try again'}"
|   +-- retries >= 2 --> Escalate (reclassify as recoverable or design_flaw)
|
+-- error_type = recoverable
|   +-- Pattern match found --> "Try: {strategy}, success rate: {N/M}"
|   +-- No match --> Lead suggests fix based on error context
|   +-- Fix fails --> Escalate (reclassify as design_flaw or surface to user)
|
+-- error_type = design_flaw
|   +-- Fallback exists in task-graph.json --> Reassign with fallback approach
|   +-- No fallback --> Trigger re-plan pattern (see coordination-patterns.md)
|
+-- error_type = unknown
    +-- Lead classifies using Classification Signals above
    +-- Re-enters tree with classified type
```

### Pattern Library Lookup

Before suggesting a recovery strategy, the lead checks `~/.claude/agent-team-patterns.json`:

1. Match the error message against `error_regex` patterns
2. If a match is found with `success_rate.successes / success_rate.attempts > 0.5`, suggest the pattern's strategies
3. If a match is found with low success rate, note it but suggest alternative approaches
4. If no match, the lead suggests a fix based on the error context and their understanding of the codebase

## Fallback Approaches in task-graph.json

Tasks can define optional fallback approaches that activate when the primary approach fails with a `design_flaw`:

```json
{
  "#3": {
    "subject": "Implement auth middleware",
    "owner": "backend-impl",
    "status": "blocked",
    "depends_on": ["#1"],
    "completed_at": null,
    "output_files": [],
    "critical_path": true,
    "convergence_point": false,
    "approach": "JWT-based with refresh tokens",
    "fallback_approach": "Session-based with server-side storage",
    "fallback_reason": "Use if JWT library has compatibility issues"
  }
}
```

When a `design_flaw` BLOCKED arrives for a task with a fallback:
1. Log the original approach failure in `issues.md`
2. Update the task description with the fallback approach
3. Message the teammate: "Switching to fallback approach: {fallback_approach}. Reason: {fallback_reason}"
4. Log the switch in `progress.md` Decision Log
5. Reset the task status to `pending` in `task-graph.json`

## Recovery Tracking in issues.md

Recovery attempts are tracked using extended fields appended below the issue table row:

```markdown
## ISS-003: Token validation timeout
- **Severity**: medium
- **Error type**: retry
- **Affected tasks**: #1
- **Recovery attempts**:
  1. Retry with increased timeout (30s -> 60s) — FAILED
  2. Retry with connection pooling — SUCCEEDED
- **Status**: RESOLVED
- **Pattern captured**: Yes (pattern-012)
```

Fields:
- **Error type**: The classified `error_type` from the BLOCKED message
- **Recovery attempts**: Numbered list of strategies attempted and their outcomes (SUCCEEDED/FAILED)
- **Pattern captured**: Whether the resolved issue was added to the global pattern library (Yes with pattern ID, or No)

## Generic Recovery Behavior

Recovery behavior is determined by the teammate's role, not the team archetype:

| Role characteristic | Recovery behavior |
|---------------------|-------------------|
| **Has write access** (Implementer, Tester) | Full: retry -> recover -> fallback -> escalate |
| **Read-only, produces findings** (Reviewer, Auditor, Analyst, Scout) | Flag as finding, continue with remaining scope |
| **Read-only, produces report** (Researcher, Challenger, Strategist) | Report as gap, move to next angle |
| **Produces docs** (Planner, Writer) | Recover only — try alternative framing |

The `recovery_class` field on each role in [../../docs/teammate-roles.md](../../docs/teammate-roles.md) maps to these behaviors:

| recovery_class | Behavior |
|----------------|----------|
| `full` | Apply the full decision tree: retry -> recover -> fallback -> escalate |
| `skip-and-continue` | Flag the error as a finding, skip the blocked item, continue with remaining scope |
| `report-gap` | Report the error as a gap in findings, move to next investigation angle |
| `recover-only` | Attempt one alternative approach; if that fails, escalate immediately |

## Recovery Bounds and Safety

Hard limits to prevent unbounded recovery loops:

| Bound | Limit | What happens at limit |
|-------|-------|-----------------------|
| Retries per task (`retry` type) | Max 2 | Reclassify as `recoverable` or `design_flaw` |
| Recovery attempts per task (`recoverable` type) | Max 1 | Reclassify as `design_flaw` or escalate to user |
| `design_flaw` | Always escalates immediately | Use fallback if available, otherwise re-plan or escalate |
| Total recovery cycles per team | Max 3 | Stop recovery, escalate all remaining blocked tasks to user |

### Tracking

- Per-task retries: count BLOCKED entries for the same task ID in `issues.md`
- Per-team recovery cycles: tracked in `progress.md` as `**Recovery cycles**: N`. Increment after each recovery attempt (regardless of outcome)
- All recovery attempts are logged in `issues.md` (extended format) and `events.log` (as `blocked` events)

### Safety Rules

1. **Recovery always terminates** — the bounds above guarantee finite recovery
2. **design_flaw never retries** — it always escalates (to fallback, re-plan, or user)
3. **unknown gets one chance** — classify and try once; if it fails again, escalate
4. **User is always the final escalation** — when all recovery options are exhausted, surface to user with full context (error, attempts, suggestions)
5. **All recovery is logged** — no silent retries; every attempt appears in `issues.md`
