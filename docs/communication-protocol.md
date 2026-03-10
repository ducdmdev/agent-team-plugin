# Communication Protocol

Canonical definition of structured messages used by all teammates. The lead reads this file during Phase 3 and injects the protocol into each teammate's spawn prompt.

## Contents

- [Structured Messages](#structured-messages)
- [Extended Messages (Optional)](#extended-messages-optional)
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
BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
HANDOFF #N: {what I produced that another teammate needs, key details}
QUESTION: {what I need to know, what I already checked in workspace}
```

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
