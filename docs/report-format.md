# Final Report Format

The final report is a persistent artifact generated at completion. It lives in the workspace directory alongside the tracking files, giving the user a complete record in one place.

## Contents

- [Location](#location) — where the report lives
- [Template](#template) — full report structure
- [Generation Protocol](#generation-protocol) — how the lead generates it
- [Guidelines](#guidelines) — writing conventions

## Location

`.agent-team/{team-name}/report.md` (relative to project root)

This file is generated during Phase 5, step 6. It is the last file written before shutdown.

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

---

## Full Audit Trail

### Team Composition

| Name | Role | Tasks Completed | Files Owned |
|------|------|----------------|-------------|
| {name} | {role} | {count} ({task IDs}) | {files/areas} |

### Task Ledger

| ID | Subject | Owner | Status | Notes |
|----|---------|-------|--------|-------|
| {id} | {subject} | {owner} | completed / deferred | {outcome notes} |

### Decision Log

Chronological record of all decisions made during the session.

- [{timestamp}] {decision and reasoning}

### Handoff Log

Record of cross-teammate information transfers.

- [{timestamp}] {source} -> {target}: {what was handed off}

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

The lead generates the report during Phase 5 (MANDATORY — do not skip):

1. Read all workspace files:
   - `.agent-team/{team-name}/progress.md` — team members, decisions, handoffs
   - `.agent-team/{team-name}/tasks.md` — task ledger
   - `.agent-team/{team-name}/issues.md` — issue tracker
2. Read TaskList for final task states (source of truth for status)
3. Incorporate teammate summaries collected via structured request in Phase 5 step 2
4. Write `.agent-team/{team-name}/report.md` using the template above
5. **Self-check**: read the file back — does it contain the Executive Summary section? If not, regenerate

## Guidelines

- The executive summary should be useful on its own — a user who reads only the top section should understand what happened
- The audit trail preserves full history for detailed review
- If issues are OPEN or MITIGATED, highlight them prominently in the executive summary
- File paths should be relative to the project root where possible
- Keep the report factual — no speculation about what "might" need attention unless backed by evidence from the session
- The report draws from workspace files, not from memory — this ensures accuracy after context compaction
