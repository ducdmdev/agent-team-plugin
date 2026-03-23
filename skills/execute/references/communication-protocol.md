# Communication Protocol

Canonical definition of structured messages used by all teammates. The lead reads this file during Phase 3 and injects the protocol into each teammate's spawn prompt.

## Contents

- [Structured Messages](#structured-messages)
- [Extended Messages (Optional)](#extended-messages-optional)
- [Plan-Mode Messages](#plan-mode-messages)
- [Inter-Stage Review Messages](#inter-stage-review-messages)
- [Reviewer/Auditor Findings Format](#reviewerauditor-findings-format)
- [Tester Results Format](#tester-results-format)
- [Auditor Compliance Format](#auditor-compliance-format)
- [Analyst Results Format](#analyst-results-format)
- [Scout Report Format](#scout-report-format)

## Structured Messages

All teammates use these prefixes when communicating with the lead:

```
STARTING #N: {what I plan to do, which files I'll touch}
COMPLETED #N: {what I did, files changed, any concerns}
BLOCKED #N: severity={critical|high|medium|low}, error_type={retry|recoverable|design_flaw|unknown}, {what's blocking}, impact={what can't proceed}
HANDOFF #N: {what I produced that another teammate needs, key details}
QUESTION: {what I need to know, what I already checked in workspace}
```

### BLOCKED Extended Format

The `error_type` field helps the lead classify errors for the Error Recovery Loop (see [error-recovery-protocol.md](error-recovery-protocol.md)):

| error_type | When to use | Examples |
|------------|-------------|---------|
| `retry` | Transient/flaky failure | Timeout, rate limit, flaky test, network glitch |
| `recoverable` | Fixable with different approach, no re-plan needed | Wrong import path, missing dependency, type mismatch |
| `design_flaw` | Fundamental approach won't work | Interface incompatibility, wrong architecture |
| `unknown` | Can't classify | Novel errors, ambiguous failures |

If a teammate sends BLOCKED without `error_type`, the lead classifies it as `unknown`.

## Extended Messages (Optional)

These message types are optional enhancements. Teammates use them when the lead requests granular updates or when tasks are long-running.

### Progress Reporting

For long-running tasks (>5 minutes expected), teammates report intermediate progress:

```
PROGRESS #N: milestone={description}, percent={0-100}, eta={minutes or omitted}
```

Example:
```
PROGRESS #5: milestone="security scan phase 2 of 4", percent=50, eta=3
```

**Lead processing**: Log milestone in `tasks.md` Notes column. No workspace file update needed unless the milestone unblocks another task.

### Checkpoint (Partial Completion)

When a task produces intermediate artifacts that downstream tasks can consume early:

```
CHECKPOINT #N: {what was completed}, artifacts={file references}, ready_for=[task IDs]
```

Example:
```
CHECKPOINT #5: completed 50/100 tests, early findings: 3 failures in auth module, artifacts=.agent-team/{team}/test-results-partial.md, ready_for=[6]
```

**Lead processing**: If `ready_for` lists task IDs, message the dependent teammate with the checkpoint details. Log in `progress.md` Handoffs section.

### Priority Marking

Teammates can signal task urgency in STARTING and HANDOFF messages:

```
STARTING #N: priority={critical|high|normal|low}, {what I plan to do, which files I'll touch}
HANDOFF #N: priority={critical|high|normal|low}, {what I produced, key details}
```

Default is `normal` — omit the field for routine work. Use `critical` only when the task blocks multiple teammates or has a deadline.

**Lead processing**: Prioritize `critical` and `high` messages. For `critical` HANDOFF, forward immediately (don't batch).

## Plan-Mode Messages

Used by teammates spawned with plan-mode active. These teammates must propose their approach before writing code.

### PLAN_PROPOSAL

Sent by a plan-mode teammate before beginning implementation:

```
PLAN_PROPOSAL #N:
  approach={description of proposed approach}
  alternatives_considered={what else was evaluated and why rejected}
  files_to_touch={list}
  estimated_complexity={low|medium|high}
  risks={potential issues}
```

**Lead processing**: Evaluate the proposal against the overall plan. Respond with PLAN_APPROVED or PLAN_REVISION.

### PLAN_APPROVED

Sent by the lead to authorize a teammate's proposed approach:

```
PLAN_APPROVED #N
```

The teammate may now proceed with implementation.

### PLAN_REVISION

Sent by the lead when a proposal needs changes:

```
PLAN_REVISION #N: {specific feedback on what to change and why}
```

The teammate revises their approach and resubmits a PLAN_PROPOSAL. Max 2 revision rounds — after that, the lead decides and either approves or provides a directive.

## Inter-Stage Review Messages

Used by review agents that validate output between pipeline stages.

### PLAN_REVIEW

Sent by the plan review agent after validating the plan (before user approval):

```
PLAN_REVIEW:
  status={approved|issues_found}
  issues=[{check, severity=blocking|warning, description, suggestion}]
```

**Lead processing**: If `approved`, present plan to user. If `issues_found` with blocking issues, fix and re-review (max 2 cycles). If only warnings, present with warnings noted.

### EXECUTE_REVIEW

Sent by the execute review agent after smoke-testing the team's output (before audit handoff):

```
EXECUTE_REVIEW:
  status={ready_for_audit|issues_found}
  issues=[{check, severity=blocking|warning, description}]
  summary={N tasks completed, M files changed, K open issues}
```

**Lead processing**: If `ready_for_audit`, proceed to audit stage. If `issues_found` with blocking issues, attempt one remediation cycle. If still blocking, proceed to audit with issues flagged.

### ELEGANCE_REVIEW

Sent by the Elegance Reviewer during the audit stage (advisory, not blocking):

```
ELEGANCE_REVIEW:
  overall_score={average 1-5}
  dimensions={simplicity: N, consistency: N, readability: N, testability: N, minimal_impact: N}
  findings=[{file, line_range, dimension, suggestion, severity=nitpick|improve|refactor}]
```

**Lead processing**: Include findings in the final report. No fix tasks spawned unless user explicitly asks.

### AUDIT_REVIEW

Sent by the audit review agent after validating the final report (before presenting to user):

```
AUDIT_REVIEW:
  status={approved|revisions_needed}
  issues=[{check, severity=blocking|warning, description, fix_suggestion}]
```

**Lead processing**: If `approved`, present report to user and proceed to shutdown. If `revisions_needed`, fix report and re-review (max 2 cycles, then finalize as-is).

## Reviewer/Auditor Findings Format

Use consistent severity labels with sequential numbering per severity within each task:

- **H{n}** (high — must fix): file:line, description, suggested fix
- **M{n}** (medium — should fix): file:line, description
- **L{n}** (low — suggestion): file:line, description

**Optional confidence grade**: Append `[X%]` to any finding when confidence is meaningful:
- `H1[95%]: src/auth.py:15, SQL injection via unsanitized input, fix: use parameterized query`
- `M2[60%]: src/api.py:42, possible race condition under load`

Omit the grade when confidence is obviously high (most findings). Use it when a finding is uncertain or based on inference rather than direct evidence.

In COMPLETED messages, include total counts: "N issues: X high, Y medium, Z low"

## Tester Results Format

- **PASS**: test name, what was verified
- **FAIL**: test name, expected vs actual, reproduction steps, suggested fix
- **SKIP**: test name, reason skipped

In COMPLETED messages, include total counts: "N tests: X passed, Y failed, Z skipped"

## Auditor Compliance Format

- **PASS**: checklist item, what was verified, evidence
- **FAIL**: checklist item, what's wrong, file:line, recommended fix, severity
- **WARNING**: checklist item, potential concern, file:line, recommendation

In COMPLETED messages, include total counts: "N items checked: X pass, Y fail, Z warning"

## Analyst Results Format

- **Metric**: name, value, baseline/comparison, significance
- **Pattern**: description, evidence (file:line or data references), confidence (high/medium/low)
- **Anomaly**: description, affected area, severity

## Scout Report Format

- **Structure**: directory layout, key files, entry points
- **Dependencies**: external libraries, internal module relationships
- **Patterns**: coding patterns, conventions, architectural style
- **Risks**: potential issues, technical debt, areas of concern
- **Recommendations**: suggested focus areas for deeper investigation
