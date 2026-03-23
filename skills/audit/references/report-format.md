# Final Report Format

The final report is a persistent artifact generated at completion. It lives in the workspace directory alongside the tracking files, giving the user a complete record in one place.

## Contents

- [Location](#location) — where the report lives
- [Template](#template) — full report structure
- [Generation Protocol](#generation-protocol) — how the lead generates it
- [Guidelines](#guidelines) — writing conventions
- [Elegance Review](#elegance-review) — code quality assessment section
- [Lessons Summary](#lessons-summary) — team execution insights section

## Location

`.agent-team/{team-name}/report.md` (relative to project root)

This file is generated during Phase 5 (Step 7), after the completion gate, remediation gate, and elegance gate, and before the audit review agent validates it.

## Template

```markdown
# Team Report: {team-name}

**Task**: {one-line description}
**Date**: {completion timestamp}
**Duration**: {approximate wall-clock time from team creation to completion}
**Status**: completed | completed with issues

---

## Executive Summary

### What Was Done
{2-5 bullet points summarizing the work completed}

### Files Changed
{Grouped by teammate, listing created/modified/deleted files}

### Key Decisions
{3-5 most important decisions made during execution, with brief reasoning}

### Issues Summary
- **Resolved**: {count} — {one-line summary of significant ones}
- **Open/Deferred**: {count} — {one-line each, these need user follow-up}
- **Remediation**: {applied | declined | not needed}

> **Unresolved issues (require manual follow-up):**
> _(Include this block only if OPEN issues remain after remediation was declined or after a remediation cycle completed with remaining issues.)_
> - Issue #N (severity): description
> - Issue #N (severity): description
> See `issues.md` for full details.

### Follow-up Items
{Bulleted list of anything that needs attention after the team disbanded}

### Team Metrics

| Metric | Value |
|--------|-------|
| Tasks | {completed}/{total} |
| Issues | {resolved}/{total} ({critical}C {high}H {medium}M {low}L) |
| Handoffs | {count} |
| Blocked events | {count} |
| Remediation cycles | {0 or 1} |
| Re-plans | {count, 0 if none} |
| Critical path length | {initial} → {final} (shifted {count} times) |
| Integration checkpoints | {count} ({passed}/{flagged}) |
| Resumed tasks | {count valid}/{count stale}/{count remaining} (or "N/A — fresh start") |

---

## Elegance Review

_(Include this section only if the elegance gate ran — i.e., the team had write-access teammates that completed tasks. Omit entirely for pure research/audit/planning teams.)_

### Overall Score: {N.N}/5

| Dimension | Score |
|-----------|-------|
| Simplicity | {1-5} |
| Consistency | {1-5} |
| Readability | {1-5} |
| Testability | {1-5} |
| Minimal impact | {1-5} |

### Findings

| File | Lines | Dimension | Severity | Suggestion |
|------|-------|-----------|----------|------------|
| {path} | {range} | {dimension} | {nitpick/improve/refactor} | {suggestion} |

_{If no findings: "No actionable findings — code meets elegance standards."}_

---

## Lessons Summary

_(Include this section if `lessons.md` was generated during the audit stage.)_

### Top Takeaways
{Top 3 most impactful lessons from the team execution — draw from What Worked and What Failed in lessons.md}

1. {takeaway with brief context}
2. {takeaway with brief context}
3. {takeaway with brief context}

### Estimation Accuracy

| Metric | Value |
|--------|-------|
| Tasks on target (+/- 20%) | {count}/{total} |
| Average overrun | {+N min or N/A} |
| Largest overrun | {task name: +N min} |
| Systematic bias | {over/under/none} |

_(Derived from the Estimation Accuracy table in lessons.md. "On target" means actual time was within 20% of estimated time.)_

---

## Full Audit Trail

### Team Composition

| Name | Role | Tasks Completed | Files Owned |
|------|------|----------------|-------------|
| {name} | {role} | {count} ({task IDs}) | {files/areas} |

### Task Ledger

| ID | Subject | Owner | Status | CP | Notes |
|----|---------|-------|--------|----|-------|
| {id} | {subject} | {owner} | completed / deferred | {★ if critical path} | {outcome notes} |

### Decision Log

Chronological record of all decisions made during the session.

- [{timestamp}] {decision and reasoning}

### Handoff Log

Record of cross-teammate information transfers.

- [{timestamp}] {source} -> {target}: {what was handed off}

### References

Source documents consulted during this team's work.

| Type | Path/URL | Description |
|------|----------|-------------|
| {spec/ADR/design/PR/doc} | {path or URL} | {one-line description} |

### Issues & Impact Tracker

| # | Severity | Reporter | Description | Impact | Affected Tasks | Status | Resolution |
|---|----------|----------|-------------|--------|---------------|--------|------------|
| {n} | {level} | {who} | {what} | {impact} | {IDs} | RESOLVED / MITIGATED / OPEN | {how fixed} |

### Per-Teammate Summaries

#### {teammate-name} ({role})
- **Completed**: {task IDs and brief descriptions}
- **Files modified**: {list}
- **Decisions made**: {any local decisions}
- **Open concerns**: {anything flagged}
```

## Generation Protocol

The lead generates the report during Phase 5 Step 7 (MANDATORY — do not skip):

1. Read all workspace files:
   - `.agent-team/{team-name}/progress.md` — team members, decisions, handoffs, **references**
   - `.agent-team/{team-name}/tasks.md` — task ledger
   - `.agent-team/{team-name}/issues.md` — issue tracker
   - `.agent-team/{team-name}/task-graph.json` — dependency graph with timestamps
2. Read TaskList for final task states (source of truth for status)
3. Incorporate teammate summaries collected via structured request in Phase 5 step 2 (from the execute stage)
4. Copy References section from `progress.md` into the report's References section
5. If the elegance gate ran (Step 4), include the Elegance Review section with scores and findings from the `ELEGANCE_REVIEW` message
6. If lessons were captured (Step 5), include the Lessons Summary section derived from `.agent-team/{team-name}/lessons.md`
7. Write `.agent-team/{team-name}/report.md` using the template above
8. **Self-check**: read the file back — does it contain the Executive Summary section? If not, regenerate

## Guidelines

- The executive summary should be useful on its own — a user who reads only the top section should understand what happened
- The audit trail preserves full history for detailed review
- If issues are OPEN or MITIGATED, highlight them prominently in the executive summary
- File paths should be relative to the project root where possible
- Keep the report factual — no speculation about what "might" need attention unless backed by evidence from the session
- The report draws from workspace files, not from memory — this ensures accuracy after context compaction
- The Elegance Review section is included only when the elegance gate ran; omit it entirely for read-only teams
- The Lessons Summary section distills the most impactful insights; the full lessons.md remains in the workspace for detailed reference

## Report Variants

All archetypes share the same outer structure (Executive Summary, Elegance Review, Lessons Summary, Team Metrics, Full Audit Trail, Per-Teammate Summaries). Only the middle content sections differ. The lead selects the variant based on the team archetype detected in Phase 1.

### Findings Report

Used by: **research-team**

Replaces the "Files Changed" section in the Executive Summary and adds a Findings section to the Full Audit Trail:

```markdown
### What Was Discovered
{2-5 bullet points summarizing the key findings}

### Findings

#### [Research Angle / Question 1]
- **Key finding**: {concise statement}
- **Evidence**: {file:line references, data points, external sources}
- **Confidence**: high | medium | low
- **Implications**: {what this means for the project/decision}

#### [Research Angle / Question 2]
...

### Synthesis
- **Agreements**: {findings confirmed by multiple researchers}
- **Contradictions**: {conflicting findings with evidence from each side}
- **Open questions**: {what couldn't be determined and why}
- **Recommended next steps**: {actionable items based on findings}
```

The "Files Changed" section is omitted (research teams don't modify files). The "Per-Teammate Summaries" section uses "Findings" instead of "Files modified". Elegance Review section is omitted (no code to review).

### Audit Report

Used by: **audit-team**

Replaces the "Files Changed" section and adds an Audit Results section:

```markdown
### What Was Audited
{2-5 bullet points summarizing the audit scope and standards checked}

### Audit Results

#### Summary
- **Items checked**: {total count}
- **Pass**: {count} | **Fail**: {count} | **Warning**: {count}
- **Overall compliance**: {percentage or qualitative assessment}

> PASS/FAIL/WARNING is the per-checklist-item status (Compliance Status table below). FAIL items are further classified by severity (Critical/High/Medium/Low) in the Findings section based on impact.

#### Findings by Severity

##### Critical
- {finding}: {file:line}, standard violated: {standard}, recommended fix: {fix}

##### High
- {finding}: {file:line}, standard violated: {standard}, recommended fix: {fix}

##### Medium
- {finding}: {file:line}, description

##### Low
- {finding}: {file:line}, description

### Compliance Status

| Standard/Checklist Item | Status | File(s) | Notes |
|------------------------|--------|---------|-------|
| {item} | PASS / FAIL / WARNING / N/A | {file references} | {details} |
```

The "Per-Teammate Summaries" section uses "Audit findings" and "Items checked" instead of "Files modified". Elegance Review section is omitted (no code to review).

### Plan Report

Used by: **planning-team**

Replaces the "Files Changed" section and adds design/planning sections:

```markdown
### What Was Planned
{2-5 bullet points summarizing the planning scope and deliverables}

### Proposed Approach
- {Architecture / design summary}
- {Key components and their responsibilities}
- {Data flow or interaction model}

### Alternatives Considered

| Approach | Pros | Cons | Why Rejected/Chosen |
|----------|------|------|-------------------|
| {approach 1} | {pros} | {cons} | {reasoning} |
| {approach 2} | {pros} | {cons} | {reasoning} |

### Decision Rationale
- {Why this approach over alternatives}
- {Key assumptions and what would invalidate them}
- {Risks and mitigations}

> If the team has Planners but no Strategist, the lead synthesizes the assumption analysis from Planners' "alternatives considered" and "trade-offs" outputs.

### Action Items
- [ ] {Next step to implement this plan, with owner if known}
- [ ] {Next step}
```

The "Per-Teammate Summaries" section uses "Design contributions" and "Decisions proposed" instead of "Files modified". Elegance Review section is omitted (no code to review).
