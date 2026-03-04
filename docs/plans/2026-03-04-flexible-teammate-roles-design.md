# Design: Flexible Teammate Roles & Team Archetypes

**Date**: 2026-03-04
**Status**: Approved
**Problem**: The current role system is implementation-centric (6 fixed roles). Teams for research, planning, or auditing must force-fit into implementation roles and phases.
**Solution**: Introduce team archetypes that auto-detect work type and adapt role composition, phase behavior, and output format accordingly. Expand the role catalog from 6 to 12.

---

## 1. Consolidated Role Catalog (12 Roles)

### Core Roles (existing, refined)

| # | Role | Purpose | Can Write Files? |
|---|------|---------|-----------------|
| 1 | **Leader** | Coordination only, never writes code | Workspace only |
| 2 | **Implementer** | Write code, build features, fix bugs | Yes |
| 3 | **Reviewer** | Validate quality, find issues, code review | No |
| 4 | **Researcher** | Investigate, analyze, report findings | No |
| 5 | **Challenger** | Stress-test assumptions, debate alternatives. *Variant: Facilitator* — synthesizes conflicting views | No |
| 6 | **Tester** | Run tests, verify builds, validate runtime. *Variant: Validator* — end-to-end integration verification | No (runs commands) |

### New Roles

| # | Role | Purpose | Can Write Files? |
|---|------|---------|-----------------|
| 7 | **Analyst** | Deep-dive into data, metrics, logs, performance. More quantitative than Researcher | No |
| 8 | **Planner** | Produce specs, architecture designs, decision documents | Yes (docs only) |
| 9 | **Writer** | Produce documentation, ADRs, guides, user-facing content. *Variant: Documenter* — code-level docs | Yes (docs only) |
| 10 | **Strategist** | Evaluate trade-offs, compare alternatives, recommend direction | No |
| 11 | **Auditor** | Systematic checks against a standard/checklist (security, compliance, accessibility) | No |
| 12 | **Scout** | Quick recon — scan codebase/API/docs, report structure and key findings fast | No |

### Merged Variants (not separate roles — customization hints for the lead)

- Migrator → Implementer variant (spawn prompt adds migration-specific rules)
- Integrator → Implementer variant (spawn prompt focuses on cross-module wiring)
- Debugger → Implementer variant (spawn prompt adds systematic debugging protocol)
- Validator → Tester variant
- Facilitator → Challenger variant
- Documenter → Writer variant

---

## 2. Team Archetypes (5 Types)

The lead auto-detects the archetype from the user's request in Phase 1. Presented in Phase 2 plan for user confirmation.

### 2.1 Implementation Team

- **Triggers**: "implement", "build", "create", "refactor", "fix", "migrate", "add feature"
- **Default roles**: 1-2 Implementers + Reviewer + Tester (complex adds dedicated Tester)
- **Phase profile**: All 5 phases, full flow (current behavior)
- **Output**: Code changes + standard `report.md`
- **Completion gate**: All 8 checks

### 2.2 Research Team

- **Triggers**: "research", "investigate", "explore", "analyze", "compare", "understand"
- **Default roles**: 2-3 Researchers (different angles) + optional Analyst or Challenger
- **Phase profile**: Phase 1-4 same. Phase 5 skips: pre-shutdown commit, build/lint/integration gates, branch merge
- **Output**: Findings report variant
- **Completion gate**: Only #6 (workspace issues) + #7 (plan completion)

### 2.3 Audit Team

- **Triggers**: "audit", "review", "assess", "evaluate", "check compliance", "security review"
- **Default roles**: 2-3 Reviewers/Auditors (different lenses) + optional Challenger
- **Phase profile**: Phase 1-4 same. Phase 5 skips: pre-shutdown commit, build/lint gates, branch merge
- **Output**: Audit report variant
- **Completion gate**: #4 (integration) + #5 (security) + #6 (issues) + #7 (plan completion)

### 2.4 Planning Team

- **Triggers**: "plan", "design", "architect", "spec", "propose", "strategy"
- **Default roles**: 1-2 Planners/Strategists + Researcher + optional Challenger
- **Phase profile**: Phase 1-4 same. Phase 5 skips: pre-shutdown commit, build/lint/integration/security gates, branch merge
- **Output**: Plan report variant
- **Completion gate**: Only #6 (workspace issues) + #7 (plan completion)

### 2.5 Hybrid Team

- **Triggers**: Task clearly combines types (e.g., "research X then implement Y", "audit and fix")
- **Default roles**: Mix from relevant archetypes — lead composes from full catalog
- **Phase profile**: Uses the **strictest** gate from component archetypes (if any Implementer present, full completion gate applies)
- **Output**: Standard `report.md`

---

## 3. Phase Profile Mechanism

Each archetype defines a phase profile — a compact block read once in Phase 1 and applied throughout. Example for research-team:

```
Phase Profile: research-team
├── Phase 1: Same (analyze + decompose)
├── Phase 2: Same (present plan, user confirms)
│   └── Show: "Team type: research-team"
├── Phase 3: Create
│   ├── Workspace: same 3 files (progress.md, tasks.md, issues.md)
│   ├── file-locks.json: SKIP (no file ownership — all read-only)
│   ├── .gitignore update: same
│   └── Branch instruction: SKIP (no code branches)
├── Phase 4: Coordinate
│   ├── Communication protocol: same
│   ├── Workspace updates: same
│   └── File ownership hook: N/A (no file-locks.json)
└── Phase 5: Synthesize
    ├── Collect results: same
    ├── Pre-shutdown commit: SKIP
    ├── Merge branches: SKIP
    ├── Completion gate: only #6 + #7
    ├── Report: findings-report variant
    ├── Remediation gate: same
    └── Shutdown: same (parallel)
```

**Integration into SKILL.md:**

- Phase 1 adds: "Read team-archetypes.md. Match the user's task to an archetype. Apply its phase profile for all subsequent phases."
- Phase 2 adds: show team type in plan presentation
- Phases 3-5 each add one line at top: "Check archetype phase profile for overrides before proceeding."

No if/else spaghetti — the archetype doc owns variation logic.

---

## 4. Report Variants

All variants share the same outer structure (Executive Summary, Team Metrics, Full Audit Trail, Per-Teammate Summaries). Only the middle content sections differ.

### 4.1 Standard Report (implementation-team, hybrid-team)

Unchanged — current `report-format.md`.

### 4.2 Findings Report (research-team)

Replaces "Files Changed" and code-centric sections with:

```markdown
## Findings
### [Research Angle / Question]
- **Key finding**: ...
- **Evidence**: file:line references, data points, sources
- **Confidence**: high / medium / low
- **Implications**: ...

## Synthesis
- Agreements across researchers
- Contradictions / open questions
- Recommended next steps
```

### 4.3 Audit Report (audit-team)

Replaces code sections with:

```markdown
## Audit Results
### Summary
- Items checked: N
- Pass: N | Fail: N | Warning: N

### Findings by Severity
#### Critical
- [finding with file:line, standard violated, recommended fix]
#### High / Medium / Low
- ...

### Compliance Status
| Standard/Checklist Item | Status | Notes |
```

### 4.4 Plan Report (planning-team)

Replaces code sections with:

```markdown
## Proposed Approach
- Architecture / design summary
- Key components and their responsibilities

## Alternatives Considered
| Approach | Pros | Cons | Why rejected/chosen |

## Decision Rationale
- Why this approach over alternatives

## Action Items
- [ ] Next steps to implement this plan
```

---

## 5. Impact on Existing Files

| File | Change |
|------|--------|
| `docs/worker-roles.md` | Add 6 new roles with spawn templates. Add variant notes to existing roles. Update Role Selection Guide. |
| **`docs/team-archetypes.md`** (NEW) | 5 archetype definitions with trigger patterns, default roles, phase profiles, output type. |
| `docs/report-format.md` | Add Report Variants section with findings-report, audit-report, plan-report templates. |
| `skills/agent-team/SKILL.md` | Phase 1: archetype detection + reference. Phase 2: show team type. Phases 3-5: one-liner override check. |
| `docs/workspace-templates.md` | Note file-locks.json is optional (skipped for read-only teams). |
| `README.md` | Update Teammate Roles table (12 roles). Add Team Types section (5 archetypes). |
| `CLAUDE.md` | Add `docs/team-archetypes.md` to File Ownership table. |

### What does NOT change

- **Hooks** — already role-agnostic (file-locks, task state, idle counters)
- **Scripts** — no role names referenced
- **Phase structure (1-5)** — preserved; archetypes only override specific steps within phases
- **`docs/coordination-patterns.md`** — patterns are already role-agnostic
- **`docs/custom-roles.md`** — still works for project-specific roles beyond the 12
