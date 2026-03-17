# Skill Best Practices Audit — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address 5 improvements identified by auditing skills against the official Claude Code skill best practices guide.

**Architecture:** All changes are documentation restructuring. Two large files get split to stay under the 500-line guidance. Three skills get concrete examples added. One file gets a TOC. All cross-references are updated to point to the correct split files. No scripts, hooks, or code changes.

**Tech Stack:** Markdown documentation files, bash test scripts
**Status:** COMPLETED — Implemented via team 0317-skill-best-practices (2026-03-17)

**Reference:** `docs/specs/2026-03-17-plan-aware-phase1-design.md` (context only — not the target of this plan)

---

## Chunk 1: Split Large Files

### Task 1: Split coordination-patterns.md into core + advanced

**Files:**
- Modify: `docs/coordination-patterns.md` (633 → ~310 lines)
- Create: `docs/coordination-advanced.md` (~330 lines)

The split point is at `## Re-plan on Block` (line 295). Everything before it is core patterns used in every team session. Everything after is advanced/specialized patterns.

**Exception:** `## Direct Handoff` (lines 584-610) stays in the core file because `shared-phases.md` references it directly. Move it before the end of the core file.

- [ ] **Step 1: Read the full file**

Read `docs/coordination-patterns.md` to confirm section boundaries:
- Core sections: lines 1-294 (Communication Protocol through Issue Triage)
- Advanced sections: lines 295-583 (Re-plan through Auto-Block)
- Direct Handoff: lines 584-610 (move to core)
- Anti-Pattern Catalog: lines 611-633 (stays in advanced)

- [ ] **Step 2: Create `docs/coordination-advanced.md`**

Create the new file with:
- Title: `# Advanced Coordination Patterns`
- Description line: `Advanced and specialized coordination patterns. For core patterns, see [coordination-patterns.md](coordination-patterns.md).`
- Contents section listing all advanced patterns
- Full content of these sections from the original file:
  - Re-plan on Block
  - Adversarial Review Rounds
  - Quality Gate
  - Checkpoint/Rollback
  - Deadline Escalation
  - Circular Dependency Detection
  - Graceful Degradation
  - Auto-Block on Repeated Failures
  - Anti-Pattern Catalog

- [ ] **Step 3: Trim `docs/coordination-patterns.md`**

Remove the advanced sections (lines 295-633) from the original file. Move Direct Handoff (from the removed block) to the end of the core file. Update the Contents section to:
- Remove entries for moved sections
- Add a line at the bottom: `- [Advanced Patterns](coordination-advanced.md) — re-plan, adversarial review, checkpoint/rollback, deadline escalation, and more`

- [ ] **Step 4: Add cross-reference between the two files**

At the end of `coordination-patterns.md`, add:
```markdown
## See Also

- [coordination-advanced.md](coordination-advanced.md) — Re-plan on Block, Adversarial Review, Quality Gate, Checkpoint/Rollback, Deadline Escalation, Circular Dependency Detection, Graceful Degradation, Auto-Block, Anti-Patterns
```

At the end of `coordination-advanced.md`, add:
```markdown
## See Also

- [coordination-patterns.md](coordination-patterns.md) — core patterns (batch updates, shutdown, commit, handoff, conflict resolution, error recovery)
```

- [ ] **Step 5: Verify line counts**

Run `wc -l` on both files. Core should be ~310 lines, advanced ~330 lines. Both under 500.

- [ ] **Step 6: Commit**

```bash
git add docs/coordination-patterns.md docs/coordination-advanced.md
git commit -m "refactor: split coordination-patterns into core + advanced (both under 500 lines)"
```

### Task 2: Split teammate-roles.md into overview + spawn-templates

**Files:**
- Modify: `docs/teammate-roles.md` (536 → ~140 lines)
- Create: `docs/spawn-templates.md` (~400 lines)

The split: `teammate-roles.md` keeps the Leader section, brief role descriptions (name, purpose, tools for each role), Role Selection Guide, Team Size Limits, and Subagent Usage. `spawn-templates.md` gets all the detailed spawn prompt templates.

- [ ] **Step 1: Read the full file**

Read `docs/teammate-roles.md` to identify:
- Leader section (lines 24-72): stays
- Available Roles section (line 73): contains both descriptions and spawn templates interleaved. Need to identify where descriptions end and templates begin for each role.
- Spawn Example (line 444): moves to spawn-templates.md
- Role Selection Guide (line 490): stays
- Team Size Limits: stays
- Subagent Usage (line 520): stays

- [ ] **Step 2: Create `docs/spawn-templates.md`**

Create the new file with:
- Title: `# Spawn Templates Reference`
- Description: `Detailed spawn prompt templates for each teammate role. Used by the Team Lead during Phase 3 when building spawn prompts. For role overview and selection guide, see [teammate-roles.md](teammate-roles.md).`
- For each role: the full spawn prompt template (the code blocks / detailed prompts)
- The Spawn Example section
- The Nested Task Decomposition section (if it exists)

- [ ] **Step 3: Slim down `teammate-roles.md`**

For each role in the Available Roles section, keep only:
- Role name (heading)
- Purpose (1-2 sentences)
- Tools list
- A reference line: `**Spawn template**: See [spawn-templates.md](spawn-templates.md#role-name)`

Remove the verbose spawn prompt text. The file should read like a quick reference guide.

- [ ] **Step 4: Update Contents section**

Update the Contents in `teammate-roles.md` to reflect the slimmed structure. Add:
```markdown
- [Spawn Templates](spawn-templates.md) — detailed spawn prompt templates for all roles
```

- [ ] **Step 5: Verify line counts**

Run `wc -l` on both files. Overview should be ~140 lines, templates ~400 lines. Both under 500.

- [ ] **Step 6: Commit**

```bash
git add docs/teammate-roles.md docs/spawn-templates.md
git commit -m "refactor: split teammate-roles into overview + spawn-templates (both under 500 lines)"
```

### Task 3: Update all cross-references for split files

**Files:**
- Modify: `docs/shared-phases.md` (references to coordination-patterns.md and teammate-roles.md)
- Modify: `docs/team-archetypes.md` (reference to coordination-patterns.md)
- Modify: `CLAUDE.md` (file ownership table)
- Modify: `README.md` (plugin structure tree)
- Modify: `tests/structure/test-doc-references.sh` (if it needs awareness of new files)

- [ ] **Step 1: Update `docs/shared-phases.md` references**

The existing references to `coordination-patterns.md` with anchors need checking:
- `coordination-patterns.md#setup-failures` — stays in core → no change
- `coordination-patterns.md#remediation-gate` — stays in core → no change
- `coordination-patterns.md` (general, Phase 4 list) — update to mention both files
- Direct Handoff reference — stays in core → no change
- `teammate-roles.md` references — add reference to `spawn-templates.md` where spawn templates are mentioned

In the Phase 4 Coordination Patterns list, add after existing entries:
```markdown
- See also [coordination-advanced.md](coordination-advanced.md) for specialized patterns
```

In the Phase 3 spawn step, after the existing `teammate-roles.md` reference, add:
```markdown
See [spawn-templates.md](spawn-templates.md) for the detailed prompt templates.
```

- [ ] **Step 2: Update `docs/team-archetypes.md`**

Check the reference to `coordination-patterns.md Re-plan on Block pattern` (line 63). This pattern moved to `coordination-advanced.md`. Update:
```markdown
See coordination-advanced.md Re-plan on Block pattern.
```

- [ ] **Step 3: Update `CLAUDE.md` file ownership table**

Add new rows for the two new files:
```markdown
| `docs/coordination-advanced.md` | Advanced coordination patterns | Update when adding new advanced patterns |
| `docs/spawn-templates.md` | Spawn prompt templates | Update when changing spawn prompts |
```

- [ ] **Step 4: Update `README.md` plugin structure tree**

In the Plugin Structure section, update:
```
│   ├── coordination-patterns.md   # Core conflict resolution and handoff patterns
│   ├── coordination-advanced.md   # Advanced patterns (re-plan, checkpoint, escalation)
│   ├── spawn-templates.md         # Spawn prompt templates for all roles
```

- [ ] **Step 5: Update `docs/shared-phases.md` Reference section**

At the bottom of shared-phases.md, add the new files:
```markdown
- [coordination-advanced.md](coordination-advanced.md) — advanced coordination patterns (re-plan, adversarial review, checkpoint/rollback, escalation)
- [spawn-templates.md](spawn-templates.md) — detailed spawn prompt templates for all teammate roles
```

- [ ] **Step 6: Commit**

```bash
git add docs/shared-phases.md docs/team-archetypes.md CLAUDE.md README.md
git commit -m "docs: update cross-references for split coordination-patterns and teammate-roles"
```

---

## Chunk 2: Examples, TOC, and Validation

### Task 4: Add concrete examples to agent-research, agent-audit, agent-plan

**Files:**
- Modify: `skills/agent-research/SKILL.md`
- Modify: `skills/agent-audit/SKILL.md`
- Modify: `skills/agent-plan/SKILL.md`

- [ ] **Step 1: Add example to `skills/agent-research/SKILL.md`**

After the Phase 1 Override section, before Phase 3, add:

```markdown
**Example decomposition**: For "compare React vs Vue vs Svelte for our dashboard rewrite":
- Stream 1 (Researcher): React ecosystem — performance, community, migration path
- Stream 2 (Researcher): Vue ecosystem — same dimensions
- Stream 3 (Researcher): Svelte ecosystem — same dimensions
- Optional (Challenger): Cross-cut analysis — identify blind spots in each researcher's findings
```

- [ ] **Step 2: Add example to `skills/agent-audit/SKILL.md`**

After the Phase 1 Override section, before Phase 3, add:

```markdown
**Example decomposition**: For "security audit of the authentication module":
- Stream 1 (Auditor): OWASP Top 10 lens — injection, broken auth, XSS, etc.
- Stream 2 (Auditor): Dependency vulnerability lens — CVEs, outdated packages, supply chain
- Stream 3 (Reviewer): Secrets/credentials lens — hardcoded keys, env leakage, token storage
- Optional (Challenger): Threat modeling — attack surface analysis across all findings
```

- [ ] **Step 3: Add example to `skills/agent-plan/SKILL.md`**

After the Phase 1 Override section, before Phase 3, add:

```markdown
**Example decomposition**: For "design the microservices migration architecture":
- Stream 1 (Planner): API design concern — service boundaries, contracts, versioning
- Stream 2 (Planner): Data model concern — database per service, migration strategy, consistency
- Stream 3 (Strategist): Infrastructure concern — deployment topology, service mesh, observability
- Optional (Researcher): Prior art — how similar-scale companies approached the same migration
```

- [ ] **Step 4: Verify line counts still under 500**

Run `wc -l` on all three files. Each should add ~6 lines (still well under 500).

- [ ] **Step 5: Commit**

```bash
git add skills/agent-research/SKILL.md skills/agent-audit/SKILL.md skills/agent-plan/SKILL.md
git commit -m "docs: add concrete decomposition examples to research, audit, and plan skills"
```

### Task 5: Add TOC to shared-phases.md

**Files:**
- Modify: `docs/shared-phases.md` (add TOC after the first heading)

- [ ] **Step 1: Read the section headers**

Read `docs/shared-phases.md` and collect all `## ` level headers.

- [ ] **Step 2: Insert TOC after the opening description**

After line 3 (`Shared phase logic for all agent-team archetype skills...`), insert:

```markdown
## Contents

- [Orchestrator Identity](#orchestrator-identity)
- [Prerequisites](#prerequisites)
- [Hooks](#hooks)
- [Phase 1: Analyze and Decompose](#phase-1-analyze-and-decompose)
  - [Early Exit — Trivial Tasks](#early-exit--trivial-tasks)
  - [Budget Constraints](#budget-constraints)
  - [Phase 1a: Plan Detection & Preparation](#phase-1a-plan-detection--preparation)
  - [Phase 1b: Decompose from Plan](#phase-1b-decompose-from-plan)
- [Phase 2: Present Plan to User](#phase-2-present-plan-to-user-mandatory--do-not-skip)
- [Phase 3: Create Team](#phase-3-create-team-shared-steps)
- [Phase 4: Coordinate](#phase-4-coordinate)
- [Phase 5: Synthesis and Completion](#phase-5-synthesis-and-completion-shared-steps)
- [Anti-Patterns](#anti-patterns)
- [Reference](#reference)
```

- [ ] **Step 3: Verify the TOC anchors resolve**

Spot-check 3-4 anchor links against the actual headings in the file.

- [ ] **Step 4: Commit**

```bash
git add docs/shared-phases.md
git commit -m "docs: add table of contents to shared-phases.md"
```

### Task 6: Run tests and validate

**Files:**
- Read: `tests/run-tests.sh`

- [ ] **Step 1: Run the full test suite**

```bash
bash tests/run-tests.sh
```

Key concern: `test-doc-references.sh` checks that all markdown cross-references resolve. The new files (`coordination-advanced.md`, `spawn-templates.md`) must be reachable, and the existing references must not be broken.

- [ ] **Step 2: If any tests fail, fix the issues**

Common failures: broken markdown link after file split. Fix and re-commit.

- [ ] **Step 3: Run tests again to confirm all pass**

```bash
bash tests/run-tests.sh
```

Expected: same 97/98 (only the pre-existing `claude plugin validate` CLI issue).

- [ ] **Step 4: Final commit if fixes were needed**

```bash
git add -A
git commit -m "fix: resolve test failures from file splitting"
```
