# Communication Protocol

Canonical definition of structured messages used by all teammates. The lead reads this file during Phase 3 and injects the protocol into each teammate's spawn prompt.

## Contents

- [Structured Messages](#structured-messages)
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

## Reviewer/Auditor Findings Format

Use consistent severity labels with sequential numbering per severity within each task:

- **H{n}** (high — must fix): file:line, description, suggested fix
- **M{n}** (medium — should fix): file:line, description
- **L{n}** (low — suggestion): file:line, description

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
