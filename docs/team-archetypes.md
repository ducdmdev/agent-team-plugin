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
