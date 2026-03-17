# Team Archetypes Reference

The lead auto-detects the team archetype from the user's request in Phase 1. Each archetype defines default roles and output type. Phase profile overrides, completion gates, and report variants are now in each archetype's dedicated skill.

## Contents

- [Archetype Detection](#archetype-detection) — how the lead selects an archetype
- [Implementation Team](#implementation-team) — build, refactor, fix code
- [Research Team](#research-team) — investigate, analyze, compare
- [Audit Team](#audit-team) — review, assess, evaluate
- [Planning Team](#planning-team) — design, architect, propose
- [Hybrid Team](#hybrid-team) — mixed work types
- [Strictest Gate Rule](#strictest-gate-rule) — gate composition for Hybrid teams

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

**Plan-aware detection:** When a plan file is available (from Phase 1a), the lead also considers plan content for archetype detection. A plan with implementation tasks maps to Implementation, research tasks to Research, etc. Plan content takes precedence over trigger word matching when the two disagree — the plan represents the user's confirmed intent.

> **Disambiguation — "evaluate"**: "Evaluate against a standard/checklist" (e.g., "evaluate our security posture") → Audit. "Evaluate alternatives/options" (e.g., "evaluate database options") → Research or Planning. When ambiguous, the Phase 2 override lets the user correct.

> **Disambiguation — "write/document"**: "Write code/feature" → Implementation. "Write documentation/docs/ADRs" or "document X" → Planning (if producing design artifacts) or Hybrid (if updating existing project docs). The Phase 2 override lets the user correct.

## Implementation Team

**Purpose**: Build, refactor, fix, or migrate code.

**Default roles**: 1-2 Implementers + Reviewer (standard) or + Reviewer + Tester (complex)

## Research Team

**Purpose**: Investigate, analyze, compare approaches, report findings. No code modifications.

**Default roles**: 2-3 Researchers (different angles/hypotheses) + optional Analyst or Challenger

## Audit Team

**Purpose**: Systematic review, assessment, or evaluation against standards/checklists.

**Default roles**: 2-3 Reviewers or Auditors (different lenses: security, performance, compliance) + optional Challenger

## Planning Team

**Purpose**: Produce specs, architecture designs, decision documents, or strategic recommendations.

**Default roles**: 1-2 Planners or Strategists + Researcher + optional Challenger

## Hybrid Team

**Purpose**: Tasks that clearly combine multiple work types (e.g., "research X then implement Y", "audit and fix").

> **Mid-session archetype change**: If the user requests an archetype change after Phase 3 (e.g., "also fix the issues you found" during an audit), treat it as a re-plan: present the updated plan as Hybrid, get user approval, then adjust workspace (add file-locks.json if needed) and spawn additional teammates. See coordination-patterns.md Re-plan on Block pattern.

**Default roles**: Lead composes from the full role catalog based on the combined task types.

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

> **Lead judgment**: When the implementation component is minor (e.g., a single config change), the lead may mark checks as N/A with a brief note in `progress.md`. The gate is a safety net, not a blocker for obviously inapplicable checks.

## Design Notes

Intentional design choices documented for future reference:

- **Documentation sprint archetype**: Classified as Hybrid (not Implementation) because Writers produce documentation rather than code — the Hybrid archetype correctly handles conditional file-locks and mixed read/write teams.
- **Phase 2 team type display**: Uses `[detected-type] (auto-detected)` user-friendly format instead of a literal enum. This makes the override mechanism more intuitive for users.

## Scaling Patterns

When team size exceeds the default 4-6 limit, use these patterns. They are ordered by complexity — try simpler patterns first.

### Read-Only Extension (5-6 agents)

Add 1-2 read-only teammates (Researchers, Reviewers with `subagent_type: "Explore"`) to a standard 4-agent team. Zero file conflict risk, minimal coordination overhead.

**When to use**: Need parallel investigation alongside implementation.

**Example Phase 2 plan**:
```
Teammates (6 total):
⚠ Team size check: 6 agents (4 core + 2 read-only researchers)
- impl-1 (Implementer): backend auth refactor -> owns src/auth/
- impl-2 (Implementer): frontend auth UI -> owns src/components/auth/
- reviewer (Reviewer): code quality review -> read-only
- tester (Tester): verify auth flows -> read-only
- perf-analyst (Researcher): performance impact analysis -> read-only (Explore)
- sec-researcher (Researcher): security implications -> read-only (Explore)
```

### Phased Execution (12-16+ agents over time)

Break large projects into sequential team waves. Each phase is an independent team (4-6 agents). Workspace carries forward between phases.

**When to use**: Clear sequential stages (research → design → implement → test).

**Protocol**:
1. Run Phase 1 team (e.g., 3 researchers), collect findings
2. Present findings to user, get approval for Phase 2
3. TeamDelete Phase 1, create Phase 2 team (e.g., 4 implementers) reusing same workspace
4. Repeat for Phase 3 (verification)

**Key constraint**: Each phase waits for the previous to complete. High wall-clock time but low concurrent token cost.

### Sub-Agent Specialization (within 4-6 agents)

Senior implementers spawn subagents for independent subtasks within their scope. Multiplies throughput without multiplying team coordination.

**When to use**: A single teammate's task is large enough to parallelize internally.

**Already supported**: See [teammate-roles.md Nested Task Decomposition](teammate-roles.md#nested-task-decomposition-senior-implementers). One level of nesting max.

## See Also

- `/agent-implement` — Implementation archetype skill
- `/agent-research` — Research archetype skill
- `/agent-audit` — Audit archetype skill
- `/agent-plan` — Planning archetype skill
- `/agent-team` — Hybrid/catch-all orchestrator skill
