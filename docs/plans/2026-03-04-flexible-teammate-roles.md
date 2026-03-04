# Flexible Teammate Roles & Team Archetypes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add team archetypes that auto-detect work type and adapt role composition, phase behavior, and output format. Expand role catalog from 6 to 12.

**Architecture:** New `docs/team-archetypes.md` defines 5 archetypes with phase profiles. SKILL.md gets a single dispatch point in Phase 1 to load the archetype, then one-liner override checks in Phases 2-5. `worker-roles.md` gets 6 new roles. `report-format.md` gets 3 report variants.

**Tech Stack:** Markdown documentation (no code changes to hooks or scripts)

**Design doc:** `docs/plans/2026-03-04-flexible-teammate-roles-design.md`

---

### Task 1: Create `docs/team-archetypes.md`

**Files:**
- Create: `docs/team-archetypes.md`

**Step 1: Create the archetype reference document**

```markdown
# Team Archetypes Reference

The lead auto-detects the team archetype from the user's request in Phase 1. Each archetype defines default roles, phase profile overrides, and output type. The user can override the auto-detected archetype during Phase 2 plan approval.

## Contents

- [Archetype Detection](#archetype-detection) — how the lead selects an archetype
- [Implementation Team](#implementation-team) — build, refactor, fix code
- [Research Team](#research-team) — investigate, analyze, compare
- [Audit Team](#audit-team) — review, assess, evaluate
- [Planning Team](#planning-team) — design, architect, propose
- [Hybrid Team](#hybrid-team) — mixed work types

## Archetype Detection

The lead matches the user's task description against trigger patterns. If multiple archetypes match, use the **primary intent** — the first verb/action in the request determines the archetype. If the task clearly combines types (e.g., "research X then implement Y"), use Hybrid.

| Archetype | Trigger Patterns |
|-----------|-----------------|
| Implementation | "implement", "build", "create", "refactor", "fix", "migrate", "add feature", "update", "write code" |
| Research | "research", "investigate", "explore", "analyze", "compare", "understand", "find out", "study" |
| Audit | "audit", "review", "assess", "evaluate", "check compliance", "security review", "code review", "inspect" |
| Planning | "plan", "design", "architect", "spec", "propose", "strategy", "roadmap", "decide" |
| Hybrid | Task combines 2+ of the above (e.g., "research and implement", "audit and fix") |

**Fallback**: If no clear match, default to Implementation (the most common case). Present the detected archetype in Phase 2 — the user can override.

## Implementation Team

**Purpose**: Build, refactor, fix, or migrate code.

**Default roles**: 1-2 Implementers + Reviewer (standard) or + Reviewer + Tester (complex)

**Phase profile**:

| Phase | Behavior |
|-------|----------|
| Phase 1 | Standard analysis and decomposition |
| Phase 2 | Standard plan presentation |
| Phase 3 | Full workspace: progress.md, tasks.md, issues.md, file-locks.json, events.log. Branch instructions for implementers |
| Phase 4 | Full coordination with file ownership enforcement |
| Phase 5 | **All 8 completion gate checks**. Pre-shutdown commit required. Branch merge if applicable |

**Completion gate**: All 8 checks (#1-#8)

**Report variant**: Standard report (current `report-format.md` template)

## Research Team

**Purpose**: Investigate, analyze, compare approaches, report findings. No code modifications.

**Default roles**: 2-3 Researchers (different angles/hypotheses) + optional Analyst or Challenger

**Phase profile**:

| Phase | Behavior | Override from default |
|-------|----------|---------------------|
| Phase 1 | Standard analysis. Decompose by research angle/question, not by module | Decomposition strategy: by question/hypothesis |
| Phase 2 | Standard plan. Show `Team type: research-team` | Add team type line |
| Phase 3 | Workspace: progress.md, tasks.md, issues.md, events.log. **SKIP file-locks.json** (all read-only). **SKIP branch instructions** (no code branches) | No file-locks, no branches |
| Phase 4 | Standard coordination. File ownership hook is N/A (no file-locks.json) | No file ownership enforcement |
| Phase 5 | **SKIP**: pre-shutdown commit (#3), branch merge (#4). **Completion gate**: only #6 (workspace issues) + #7 (plan completion). **SKIP**: #1-#5, #8 | Reduced gate, no commits |

**Completion gate**: #6 (workspace issues) + #7 (plan completion) only

**Report variant**: Findings report — see [report-format.md](report-format.md#findings-report)

## Audit Team

**Purpose**: Systematic review, assessment, or evaluation against standards/checklists.

**Default roles**: 2-3 Reviewers or Auditors (different lenses: security, performance, compliance) + optional Challenger

**Phase profile**:

| Phase | Behavior | Override from default |
|-------|----------|---------------------|
| Phase 1 | Standard analysis. Decompose by audit lens/checklist area | Decomposition strategy: by audit lens |
| Phase 2 | Standard plan. Show `Team type: audit-team` | Add team type line |
| Phase 3 | Workspace: progress.md, tasks.md, issues.md, events.log. **SKIP file-locks.json**. **SKIP branch instructions** | No file-locks, no branches |
| Phase 4 | Standard coordination. File ownership hook is N/A | No file ownership enforcement |
| Phase 5 | **SKIP**: pre-shutdown commit (#3), branch merge (#4). **Completion gate**: #4 (integration) + #5 (security) + #6 (workspace issues) + #7 (plan completion). **SKIP**: #1-#3, #8 | Partial gate, no commits |

**Completion gate**: #4 (integration) + #5 (security) + #6 (workspace issues) + #7 (plan completion)

**Report variant**: Audit report — see [report-format.md](report-format.md#audit-report)

## Planning Team

**Purpose**: Produce specs, architecture designs, decision documents, or strategic recommendations.

**Default roles**: 1-2 Planners or Strategists + Researcher + optional Challenger

**Phase profile**:

| Phase | Behavior | Override from default |
|-------|----------|---------------------|
| Phase 1 | Standard analysis. Decompose by planning concern (architecture, data model, API design, etc.) | Decomposition strategy: by planning concern |
| Phase 2 | Standard plan. Show `Team type: planning-team` | Add team type line |
| Phase 3 | Workspace: progress.md, tasks.md, issues.md, events.log. **SKIP file-locks.json** (Planners/Writers write docs to workspace, not project files). **SKIP branch instructions** | No file-locks, no branches |
| Phase 4 | Standard coordination. File ownership hook is N/A | No file ownership enforcement |
| Phase 5 | **SKIP**: pre-shutdown commit (#3), branch merge (#4). **Completion gate**: only #6 (workspace issues) + #7 (plan completion). **SKIP**: #1-#5, #8 | Reduced gate, no commits |

**Completion gate**: #6 (workspace issues) + #7 (plan completion) only

**Report variant**: Plan report — see [report-format.md](report-format.md#plan-report)

## Hybrid Team

**Purpose**: Tasks that clearly combine multiple work types (e.g., "research X then implement Y", "audit and fix").

**Default roles**: Lead composes from the full role catalog based on the combined task types.

**Phase profile**:

| Phase | Behavior | Override from default |
|-------|----------|---------------------|
| Phase 1 | Standard analysis. Identify which parts map to which archetype | Standard |
| Phase 2 | Standard plan. Show `Team type: hybrid (research + implementation)` listing component types | Add team type line with component types |
| Phase 3 | Full workspace. **file-locks.json**: create if ANY teammate writes project files. **Branch instructions**: for implementers only | Conditional file-locks |
| Phase 4 | Full coordination | Standard |
| Phase 5 | Uses the **strictest** gate from component archetypes. If any Implementer present → full 8-check gate. If all read-only → reduced gate | Strictest component gate |

**Completion gate**: Strictest gate from component archetypes

**Report variant**: Standard report

### Strictest Gate Rule

When combining archetypes, the completion gate includes any check required by ANY component:

| Check | Required if... |
|-------|---------------|
| #1 Uncommitted changes | Any Implementer present |
| #2 Build & tests | Any Implementer present |
| #3 Lint/format | Any Implementer present |
| #4 Integration | Any Implementer present OR Audit component |
| #5 Security scan | Any Implementer present OR Audit component |
| #6 Workspace issues | Always |
| #7 Plan completion | Always |
| #8 Documentation sync | Any Implementer present |
```

**Step 2: Verify the file was created correctly**

Read `docs/team-archetypes.md` and confirm all 5 archetypes are defined with phase profiles.

**Step 3: Commit**

```bash
git add docs/team-archetypes.md
git commit -m "feat: add team archetypes reference with 5 team types and phase profiles"
```

---

### Task 2: Add 6 new roles to `docs/worker-roles.md`

**Files:**
- Modify: `docs/worker-roles.md`

**Step 1: Update Contents section**

Add new role links after the Tester entry (line 12) and before the Spawn Example entry (line 13):

```markdown
- [Analyst](#analyst) — deep-dive into data, metrics, performance
- [Planner](#planner) — produce specs, architecture designs, decision docs
- [Writer](#writer) — produce documentation, ADRs, guides
- [Strategist](#strategist) — evaluate trade-offs, recommend direction
- [Auditor](#auditor) — systematic checks against standards/checklists
- [Scout](#scout) — quick reconnaissance, structure and findings
```

**Step 2: Add variant notes to existing roles**

After the Challenger spawn template closing ``` (line 212), before `### Tester`, add:

```markdown
**Variants**:
- **Facilitator**: Same tools and rules, but focuses on synthesizing conflicting viewpoints and driving consensus rather than challenging. Use in planning teams where debate needs resolution.
```

After the Tester spawn template closing ``` (line 253), before `## Spawn Example`, add:

```markdown
**Variants**:
- **Validator**: Same tools and rules, but focuses on end-to-end integration verification rather than unit-level testing. Use when cross-module wiring is the primary concern.
```

**Step 3: Add 6 new role definitions**

After the Tester section (including its new Variants note) and before `## Spawn Example`, add all 6 new roles:

```markdown
### Analyst
**Purpose**: Deep-dive into data, metrics, logs, performance profiling. More quantitative than Researcher.
**When to use**: Performance analysis, data investigation, metrics review, log analysis.
**Typical tools**: Read, Grep, Glob, Bash (read-only commands for data queries)

**Spawn prompt template**:
```
You are an analyst on this team. Your job is to analyze data, metrics, and performance characteristics, and report quantitative findings.

Your assigned tasks: [TASK_IDS]
Your analysis scope: [SCOPE]

Workspace: .agent-team/[TEAM_NAME]/ — read these files for context on team progress, tasks, and known issues.

Project conventions: If CLAUDE.md exists in the project root, read it before starting. Follow its conventions.

Communication protocol — send structured messages to the lead:
- STARTING #N: {what I plan to analyze, data sources}
- COMPLETED #N: {analysis summary, key metrics, data points}
- BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
- HANDOFF #N: {analysis results that another teammate needs}
- QUESTION: {what I need to know, what I already checked in workspace}

Results format — use consistent structure:
- **Metric**: name, value, baseline/comparison, significance
- **Pattern**: description, evidence (file:line or data references), confidence (high/medium/low)
- **Anomaly**: description, affected area, severity

Rules:
- Read and analyze only. Do not modify any files.
- Before starting each new task, re-read workspace files (progress.md, tasks.md, issues.md) to ensure you have current state.
- Back every finding with specific data: numbers, file:line references, concrete measurements.
- Distinguish between correlation and causation in your findings.
- Read workspace files before asking the lead questions — the answer may already be there.
- When blocked, message the lead immediately with the BLOCKED format above.
- After completing each task, send COMPLETED to the lead, mark it complete via TaskUpdate, and check TaskList for more work.
- For large data sets, use subagents (Task tool with subagent_type=Explore) to parallelize analysis.
```

### Planner
**Purpose**: Produce specs, architecture designs, decision documents.
**When to use**: Architecture design, technical specification, decision documents, migration planning.
**Typical tools**: Read, Write (docs only), Grep, Glob, WebSearch

**Spawn prompt template**:
```
You are a planner on this team. Your job is to produce clear, actionable design documents and specifications.

Your assigned tasks: [TASK_IDS]
Your planning scope: [SCOPE]
Your output location: .agent-team/[TEAM_NAME]/ (write design artifacts here)

Workspace: .agent-team/[TEAM_NAME]/ — read these files for context on team progress, tasks, and known issues.

Project conventions: If CLAUDE.md exists in the project root, read it before starting. Follow its conventions.

Communication protocol — send structured messages to the lead:
- STARTING #N: {what I plan to design/specify}
- COMPLETED #N: {design summary, artifact location, key decisions}
- BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
- HANDOFF #N: {design decisions that another teammate needs to know}
- QUESTION: {what I need to know, what I already checked in workspace}

Rules:
- Write design artifacts to the workspace directory, not project files.
- Before starting each new task, re-read workspace files (progress.md, tasks.md, issues.md) to ensure you have current state.
- Every design must include: problem statement, proposed approach, alternatives considered, trade-offs, and action items.
- Be specific — use file paths, interface names, and concrete examples rather than abstract descriptions.
- Read workspace files and existing project docs before starting to avoid duplicating existing decisions.
- When blocked, message the lead immediately with the BLOCKED format above.
- After completing each task, send COMPLETED to the lead, mark it complete via TaskUpdate, and check TaskList for more work.
```

### Writer
**Purpose**: Produce documentation, ADRs, guides, user-facing content.
**When to use**: Documentation creation, ADR writing, README updates, user guides, API docs.
**Typical tools**: Read, Write (docs only), Grep, Glob

**Spawn prompt template**:
```
You are a writer on this team. Your job is to produce clear, accurate documentation.

Your assigned tasks: [TASK_IDS]
Your writing scope: [SCOPE]
Your file ownership: [FILES/DIRECTORIES]

Workspace: .agent-team/[TEAM_NAME]/ — read these files for context on team progress, tasks, and known issues.

Project conventions: If CLAUDE.md exists in the project root, read it before starting. Follow its conventions for documentation style.

Communication protocol — send structured messages to the lead:
- STARTING #N: {what I plan to write, which files I'll create/modify}
- COMPLETED #N: {what I wrote, files changed, any open questions}
- BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
- HANDOFF #N: {documentation that another teammate needs to review or reference}
- QUESTION: {what I need to know, what I already checked in workspace}

Rules:
- ONLY modify files in your owned area. If you need changes elsewhere, message the lead.
- Before starting each new task, re-read workspace files (progress.md, tasks.md, issues.md) to ensure you have current state.
- Read existing documentation first to match the project's writing style and avoid contradictions.
- Every document must be accurate — verify claims against source code when possible.
- Read workspace files before asking the lead questions — the answer may already be there.
- When blocked, message the lead immediately with the BLOCKED format above.
- After completing each task, send COMPLETED to the lead, mark it complete via TaskUpdate, and check TaskList for more work.
- Before shutdown: when the lead asks you to commit, stage ONLY your owned files and commit with a descriptive message. Send the commit hash to the lead.
```

**Variants**:
- **Documenter**: Same tools and rules, but focuses on code-level documentation (JSDoc, docstrings, README, API reference) rather than user-facing content. Use when the task is specifically about code documentation.

### Strategist
**Purpose**: Evaluate trade-offs, compare alternatives, recommend direction.
**When to use**: Technology evaluation, approach comparison, decision support, roadmap input.
**Typical tools**: Read, Grep, Glob, WebFetch, WebSearch

**Spawn prompt template**:
```
You are a strategist on this team. Your job is to evaluate alternatives, analyze trade-offs, and recommend a direction.

Your assigned tasks: [TASK_IDS]
Your evaluation scope: [SCOPE]

Workspace: .agent-team/[TEAM_NAME]/ — read these files for context on team progress, tasks, and known issues.

Project conventions: If CLAUDE.md exists in the project root, read it before starting. Follow its conventions.

Communication protocol — send structured messages to the lead:
- STARTING #N: {what alternatives I plan to evaluate}
- COMPLETED #N: {evaluation summary, recommendation, confidence level}
- BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
- HANDOFF #N: {recommendation that another teammate needs for their work}
- QUESTION: {what I need to know, what I already checked in workspace}

Evaluation format — use consistent structure:
- **Option**: name, brief description
- **Pros**: specific advantages with evidence
- **Cons**: specific disadvantages with evidence
- **Risk**: likelihood and impact of failure
- **Recommendation**: chosen option with reasoning

Rules:
- Read and analyze only. Do not modify any files.
- Before starting each new task, re-read workspace files (progress.md, tasks.md, issues.md) to ensure you have current state.
- Always evaluate at least 2 alternatives — never present a single option as the only choice.
- Back recommendations with evidence: benchmarks, documentation, real-world examples.
- Explicitly state assumptions and what would change the recommendation if those assumptions are wrong.
- Read workspace files before asking the lead questions — the answer may already be there.
- When blocked, message the lead immediately with the BLOCKED format above.
- After completing each task, send COMPLETED to the lead, mark it complete via TaskUpdate, and check TaskList for more work.
```

### Auditor
**Purpose**: Systematic checks against a standard, checklist, or compliance requirement.
**When to use**: Security audit, compliance check, accessibility review, best-practices assessment.
**Typical tools**: Read, Grep, Glob, Bash (read-only commands)

**Spawn prompt template**:
```
You are an auditor on this team. Your job is to systematically check the codebase against specific standards or checklists and report compliance status.

Your assigned tasks: [TASK_IDS]
Your audit scope: [SCOPE]
Your audit standard: [STANDARD/CHECKLIST]

Workspace: .agent-team/[TEAM_NAME]/ — read these files for context on team progress, tasks, and known issues.

Project conventions: If CLAUDE.md exists in the project root, read it before starting. Follow its conventions.

Communication protocol — send structured messages to the lead:
- STARTING #N: {what I plan to audit, which standard/checklist}
- COMPLETED #N: {audit summary, pass/fail/warning counts, critical findings}
- BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
- HANDOFF #N: {findings that another teammate needs to act on}
- QUESTION: {what I need to know, what I already checked in workspace}

Findings format — use consistent structure:
- **PASS**: checklist item, what was verified, evidence
- **FAIL**: checklist item, what's wrong, file:line, recommended fix, severity
- **WARNING**: checklist item, potential concern, file:line, recommendation
In COMPLETED messages, include total counts: "N items checked: X pass, Y fail, Z warning"

Rules:
- Read and analyze only. Do not modify any files.
- Before starting each new task, re-read workspace files (progress.md, tasks.md, issues.md) to ensure you have current state.
- Check every item in your assigned standard/checklist — do not skip items.
- Include specific file:line references and fix suggestions for every FAIL finding.
- Read workspace issues.md to avoid reporting known/duplicate issues.
- When you find a critical finding, report it via HANDOFF immediately — don't wait for task completion.
- After completing each task, send COMPLETED to the lead, mark it complete via TaskUpdate, and check TaskList for more work.
- For large audit scopes, use subagents (Task tool with subagent_type=Explore) to parallelize file reads.
```

### Scout
**Purpose**: Quick reconnaissance — scan a codebase, API, or documentation and report structure and key findings.
**When to use**: Codebase orientation, API surface mapping, dependency inventory, quick assessment before deeper work.
**Typical tools**: Read, Grep, Glob, Bash (read-only)

**Spawn prompt template**:
```
You are a scout on this team. Your job is to quickly scan and map the territory — report structure, key findings, and anything noteworthy.

Your assigned tasks: [TASK_IDS]
Your recon scope: [SCOPE]

Workspace: .agent-team/[TEAM_NAME]/ — read these files for context on team progress, tasks, and known issues.

Project conventions: If CLAUDE.md exists in the project root, read it before starting. Follow its conventions.

Communication protocol — send structured messages to the lead:
- STARTING #N: {what I plan to scan}
- COMPLETED #N: {structure overview, key findings, notable items}
- BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
- HANDOFF #N: {findings that another teammate needs before starting their work}
- QUESTION: {what I need to know, what I already checked in workspace}

Report format — use consistent structure:
- **Structure**: directory layout, key files, entry points
- **Dependencies**: external libraries, internal module relationships
- **Patterns**: coding patterns, conventions, architectural style
- **Risks**: potential issues, technical debt, areas of concern
- **Recommendations**: suggested focus areas for deeper investigation

Rules:
- Read and analyze only. Do not modify any files.
- Before starting each new task, re-read workspace files (progress.md, tasks.md, issues.md) to ensure you have current state.
- Prioritize breadth over depth — map the whole territory first, flag areas for deeper investigation.
- Be fast — scouts provide quick orientation, not exhaustive analysis.
- Read workspace files before asking the lead questions — the answer may already be there.
- When blocked, message the lead immediately with the BLOCKED format above.
- After completing each task, send COMPLETED to the lead, mark it complete via TaskUpdate, and check TaskList for more work.
- Use subagents (Task tool with subagent_type=Explore) liberally to parallelize scanning.
```
```

**Step 4: Update Role Selection Guide table**

Replace the existing table at lines 303-312 with an expanded version that includes the new roles and archetype mapping:

```markdown
## Role Selection Guide

| Task Type | Archetype | Recommended Roles | Typical Size |
|---|---|---|---|
| Code review | Audit | 2-3 Reviewers with different lenses (security, performance, style) | 2-3 (all read-only) |
| New feature (standard) | Implementation | 1-2 Implementers (by module) + 1 Reviewer | 2-3 |
| New feature (complex) | Implementation | 1-2 Implementers + 1 Reviewer + 1 Tester | 3-4 |
| Bug investigation | Research | 2-3 Researchers with competing hypotheses | 2-3 (all read-only) |
| Refactoring | Implementation | 1-2 Implementers (by area) + 1 Reviewer | 2-3 |
| Architecture evaluation | Planning | 1 Strategist + 1 Challenger | 2 (all read-only) |
| Full-stack feature | Implementation | Implementer (backend) + Implementer (frontend) + Reviewer + Tester | 3-4 |
| Large audit / migration | Implementation | 2 Implementers + 3-4 Reviewers/Researchers | 5-6 (extras read-only) |
| Technology evaluation | Research | 1-2 Strategists + 1 Researcher | 2-3 (all read-only) |
| Security audit | Audit | 2 Auditors (different lenses) + 1 Challenger | 3 (all read-only) |
| Compliance check | Audit | 2-3 Auditors (per standard/area) | 2-3 (all read-only) |
| Architecture design | Planning | 1-2 Planners + 1 Researcher + 1 Challenger | 3-4 (Planners write docs) |
| Documentation sprint | Implementation | 2-3 Writers (by area) + 1 Reviewer | 3-4 |
| Performance analysis | Research | 1-2 Analysts + 1 Scout | 2-3 (all read-only) |
| Codebase orientation | Research | 2-3 Scouts (by area) | 2-3 (all read-only) |
| Research + implement | Hybrid | 1-2 Researchers + 1-2 Implementers + Reviewer | 3-4 |
| Audit + fix | Hybrid | 1-2 Auditors + 1 Implementer + Tester | 3-4 |
```

**Step 5: Add variant notes to Implementer role**

After the Implementer spawn template closing ``` (line 138), before `### Reviewer`, add:

```markdown
**Variants**:
- **Migrator**: Same tools and rules, but spawn prompt adds migration-specific rules (reversible migrations, rollback testing, data loss risk documentation). Use for schema/data migration tasks.
- **Integrator**: Same tools and rules, but spawn prompt focuses on cross-module wiring (API contracts, shared interfaces, import paths). Use when the primary task is connecting modules built by other teammates.
- **Debugger**: Same tools and rules, but spawn prompt adds systematic debugging protocol (reproduce, isolate, root-cause, fix). Use for focused bug-fixing tasks. Hint: "If available, use /systematic-debugging."
```

**Step 6: Verify changes**

Read `docs/worker-roles.md` and verify: 12 roles in Contents, 6 new role sections with spawn templates, variant notes on Implementer/Challenger/Tester, expanded Role Selection Guide.

**Step 7: Commit**

```bash
git add docs/worker-roles.md
git commit -m "feat: add 6 new roles (Analyst, Planner, Writer, Strategist, Auditor, Scout) and variant notes"
```

---

### Task 3: Add report variants to `docs/report-format.md`

**Files:**
- Modify: `docs/report-format.md`

**Step 1: Add Report Variants section**

After the Guidelines section (line 139, end of file), append:

````markdown
## Report Variants

All archetypes share the same outer structure (Executive Summary, Team Metrics, Full Audit Trail, Per-Teammate Summaries). Only the middle content sections differ. The lead selects the variant based on the team archetype detected in Phase 1.

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

The "Files Changed" section is omitted (research teams don't modify files). The "Per-Teammate Summaries" section uses "Findings" instead of "Files modified".

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

The "Per-Teammate Summaries" section uses "Audit findings" and "Items checked" instead of "Files modified".

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

### Action Items
- [ ] {Next step to implement this plan, with owner if known}
- [ ] {Next step}
```

The "Per-Teammate Summaries" section uses "Design contributions" and "Decisions proposed" instead of "Files modified".
````

**Step 2: Verify changes**

Read `docs/report-format.md` and verify: 3 new report variants (Findings, Audit, Plan) with templates.

**Step 3: Commit**

```bash
git add docs/report-format.md
git commit -m "feat: add findings, audit, and plan report variants for non-implementation archetypes"
```

---

### Task 4: Update `docs/workspace-templates.md` for optional file-locks

**Files:**
- Modify: `docs/workspace-templates.md:115-124`

**Step 1: Add conditional note to file-locks.json section**

Replace lines 115-124 (the file-locks.json section) with:

```markdown
### file-locks.json

Created during Phase 3 after spawning teammates. Maps each teammate to their owned files/directories. Used by the PreToolUse(Write|Edit) hook to enforce file ownership.

**When to create**: Only for archetypes with teammates that write project files (Implementation, Hybrid with implementers). **SKIP for read-only archetypes** (Research, Audit, Planning) — these teams have no file ownership to enforce.

```json
{
  "teammate-name": ["src/auth/", "src/middleware/auth.ts"],
  "other-teammate": ["src/api/", "tests/api/"]
}
```
```

**Step 2: Commit**

```bash
git add docs/workspace-templates.md
git commit -m "docs: note file-locks.json is optional for read-only team archetypes"
```

---

### Task 5: Update `skills/agent-team/SKILL.md` with archetype dispatch

**Files:**
- Modify: `skills/agent-team/SKILL.md`

**Step 1: Add archetype detection to Phase 1 (after step 8, line 53)**

After line 53 (`8. **Check for custom roles**...`), add:

```markdown
9. **Detect team archetype** — read [team-archetypes.md](../../docs/team-archetypes.md). Match the user's task to an archetype (implementation, research, audit, planning, or hybrid) using the trigger patterns. The archetype determines which phases, completion gate checks, and report variant to use. Apply the archetype's phase profile for all subsequent phases.
```

**Step 2: Add team type to Phase 2 plan presentation (line 63)**

After `Team plan for: [task summary]` (line 62), add:

```
Team type: implementation | research | audit | planning | hybrid
```

**Step 3: Add override note to Phase 3 (after line 98)**

After `## Phase 3: Create Team` heading, add:

```markdown
> **Archetype overrides**: Check [team-archetypes.md](../../docs/team-archetypes.md) for Phase 3 overrides. Key differences: read-only archetypes (research, audit, planning) SKIP file-locks.json and branch instructions.
```

**Step 4: Add override note to Phase 4 (after line 209)**

After `## Phase 4: Coordinate` heading, add:

```markdown
> **Archetype overrides**: Check [team-archetypes.md](../../docs/team-archetypes.md) for Phase 4 overrides. Key difference: file ownership enforcement is N/A for archetypes without file-locks.json.
```

**Step 5: Add override note to Phase 5 (after line 305)**

After `## Phase 5: Synthesis and Completion` heading, add:

```markdown
> **Archetype overrides**: Check [team-archetypes.md](../../docs/team-archetypes.md) for Phase 5 overrides. Key differences: read-only archetypes SKIP pre-shutdown commit, branch merge, and most completion gate checks. Use the archetype's report variant.
```

**Step 6: Add team-archetypes.md to Reference section (line 398)**

Add after the existing references:

```markdown
- [team-archetypes.md](../../docs/team-archetypes.md) — team type detection, phase profiles, and completion gate overrides
```

**Step 7: Verify changes**

Read `skills/agent-team/SKILL.md` and verify: archetype detection in Phase 1, team type in Phase 2, override notes in Phases 3-5, reference link.

**Step 8: Commit**

```bash
git add skills/agent-team/SKILL.md
git commit -m "feat: add archetype dispatch to SKILL.md phases 1-5"
```

---

### Task 6: Update `README.md`

**Files:**
- Modify: `README.md`

**Step 1: Expand Teammate Roles table (lines 77-87)**

Replace the existing 6-role table with:

```markdown
### Teammate Roles

| Role | Purpose | Tools |
|------|---------|-------|
| **Leader** | Coordinate team, track progress, never writes code | TaskCreate, TaskUpdate, SendMessage, Read, Write (workspace only) |
| **Implementer** | Write code, create files, build features | Read, Write, Edit, Bash, Grep, Glob |
| **Reviewer** | Validate quality, find issues | Read, Grep, Glob, Bash (read-only) |
| **Researcher** | Investigate, analyze, report findings | Read, Grep, Glob, WebFetch, WebSearch |
| **Challenger** | Stress-test assumptions, find edge cases | Read, Grep, Glob, Bash, WebSearch |
| **Tester** | Run tests, verify builds, check runtime behavior | Read, Grep, Glob, Bash |
| **Analyst** | Deep-dive into data, metrics, performance | Read, Grep, Glob, Bash (read-only) |
| **Planner** | Produce specs, architecture designs, decision docs | Read, Write (docs only), Grep, Glob |
| **Writer** | Produce documentation, ADRs, guides | Read, Write (docs only), Grep, Glob |
| **Strategist** | Evaluate trade-offs, recommend direction | Read, Grep, Glob, WebFetch, WebSearch |
| **Auditor** | Systematic checks against standards/checklists | Read, Grep, Glob, Bash (read-only) |
| **Scout** | Quick recon — scan and report structure | Read, Grep, Glob, Bash (read-only) |
```

**Step 2: Add Team Types section**

After the Teammate Roles table and before `### Communication Protocol` (line 88), add:

```markdown
### Team Types

The lead auto-detects the team type from your request and adapts the workflow accordingly:

| Team Type | When Used | Default Roles | Output |
|-----------|-----------|---------------|--------|
| **Implementation** | Build, refactor, fix, migrate code | Implementers + Reviewer + Tester | Code changes + report |
| **Research** | Investigate, analyze, compare approaches | Researchers + Analyst/Challenger | Findings report |
| **Audit** | Review, assess, evaluate against standards | Reviewers/Auditors + Challenger | Audit report |
| **Planning** | Design, architect, produce specs | Planners/Strategists + Researcher | Plan/spec document |
| **Hybrid** | Mixed work types (e.g., research then implement) | Mix from all roles | Standard report |

The team type determines which completion checks apply and what the final report looks like. You can override the auto-detected type during plan approval.
```

**Step 3: Add team-archetypes.md to Plugin Structure (line 181)**

In the docs section of the tree, add after `custom-roles.md`:

```
│   ├── team-archetypes.md     # Team type definitions and phase profiles
```

**Step 4: Verify changes**

Read `README.md` and verify: 12-role table, Team Types section, updated plugin structure.

**Step 5: Commit**

```bash
git add README.md
git commit -m "docs: update README with 12 roles, team types section, and archetype reference"
```

---

### Task 7: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add team-archetypes.md to File Ownership table**

After the `docs/custom-roles.md` row (line 38), add:

```markdown
| `docs/team-archetypes.md` | Team type definitions + phase profiles | Update when adding new archetypes or modifying phase overrides |
```

**Step 2: Update "Adding a New Teammate Role" section**

After the existing steps in "Adding a New Teammate Role" (lines 122-127), add a new section:

```markdown
### Adding a New Team Archetype

1. Add the archetype definition to `docs/team-archetypes.md`
2. Include: trigger patterns, default roles, phase profile table, completion gate checks, report variant
3. Add the report variant template to `docs/report-format.md`
4. Update `README.md` Team Types table
5. Test: trigger the skill with a matching phrase and verify the lead selects the correct archetype
```

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add team-archetypes.md to CLAUDE.md file ownership and common tasks"
```

---

### Task 8: Run tests and verify

**Files:**
- Read: `tests/run-tests.sh`

**Step 1: Run the full test suite**

```bash
bash tests/run-tests.sh
```

Expected: All 9 test files pass (78 assertions). No test should fail because we only changed documentation — no hooks or scripts were modified.

**Step 2: Validate plugin structure**

```bash
claude plugin validate .
```

Expected: Plugin validates successfully.

**Step 3: Commit (only if test fixes needed)**

If any tests fail due to structure changes, fix them and commit:

```bash
git add tests/
git commit -m "fix: update tests for team archetypes structure changes"
```
