# Skill Best-Practices Compliance Overhaul — Design

**Date**: 2026-03-06
**Status**: Approved
**Goal**: Maximize compliance with official Claude skill authoring best practices from platform.claude.com

## Problem Statement

An audit against the official skill best practices revealed 6 areas needing improvement:

1. Communication protocol duplicated 123 times across 3 files (~700 wasted tokens on load)
2. No concrete input/output examples in SKILL.md (best practices strongly recommend them)
3. Inconsistent terminology: "worker" in filenames, "teammate" in content, "agent" in descriptions
4. No quick start section for fast orientation
5. SKILL.md at 420/500 lines with no room for additions
6. Sections in SKILL.md that belong in docs (setup failures, workspace update protocol, file-locks/events.log details)

## Design

### 1. Communication Protocol Consolidation

**New file**: `docs/communication-protocol.md` (~30 lines)

Contains the canonical protocol block:

```
STARTING #N: {what I plan to do, which files I'll touch}
COMPLETED #N: {what I did, files changed, any concerns}
BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
HANDOFF #N: {what I produced that another teammate needs, key details}
QUESTION: {what I need to know, what I already checked}
```

Plus the findings format for reviewers/auditors and results format for testers — all structured message formats in one place.

**SKILL.md Phase 3 change**: Add instruction for the lead to read `communication-protocol.md` at spawn time and inject it into each teammate's prompt.

**SKILL.md Phase 4 change**: Keep lead processing rules (what the lead does per prefix). This is lead-specific behavior, not duplication.

**`teammate-roles.md` change**: Each spawn template replaces the repeated protocol block with `{COMMUNICATION_PROTOCOL}` placeholder and a note: "Lead reads docs/communication-protocol.md and substitutes here at spawn time."

**`coordination-patterns.md` change**: Remove the "Structured Messages" section. Reference `communication-protocol.md` for the canonical definition.

### 2. Terminology Standardization

**Rename**: `docs/worker-roles.md` → `docs/teammate-roles.md`

**Standardize to "teammate"** everywhere content refers to team members. Keep "agent" only in technical identifiers (`agent-team`, `subagent_type`, `.agent-team/`, `subagent`).

**Files to update references in**:
- `skills/agent-team/SKILL.md` (4 links to worker-roles.md)
- `CLAUDE.md` (3 mentions)
- `README.md` (1 mention in plugin structure)
- `docs/coordination-patterns.md` (0-1 links)
- `docs/custom-roles.md` (1 mention)

### 3. Trim SKILL.md — Move Sections to Docs

**Move to `docs/coordination-patterns.md`**:
- Setup Failures table (Phase 3, ~10 lines) — fits as an error recovery pattern

**Move to `docs/workspace-templates.md`**:
- Workspace Update Protocol table (Phase 4, ~20 lines) — template-adjacent
- file-locks.json details (Phase 3, ~10 lines) — already partially described there
- events.log details (Phase 3, ~10 lines) — already partially described there

**Replace with**: One-line references. ~50 lines freed.

**Keep inline**: Completion Gate table (Phase 5) — too critical to move. Lead must see it without following a reference.

### 4. Add Quick Start Section

Insert after the role definition link, before Prerequisites:

```markdown
## Quick Start

1. **Analyze** — identify 2+ independent streams, detect archetype
2. **Plan** — present to user, wait for approval (hard gate)
3. **Create** — team, workspace, tasks, spawn teammates
4. **Coordinate** — track progress, route messages, resolve blockers
5. **Synthesize** — completion gate, report, shutdown
```

~7 lines. Gives Claude instant orientation.

### 5. Add Concrete Examples

**Example 1 — Phase 2 plan presentation** (~20 lines):
Located in Phase 2 section. Shows a complete plan output for "refactor auth module" with real file paths, roles, task breakdown, dependencies, and isolation mode.

**Example 2 — Spawn prompt assembly** (~15 lines):
Located in Phase 3 section. Shows the lead reading `communication-protocol.md`, substituting `{COMMUNICATION_PROTOCOL}` into a spawn template, and calling the Task tool.

### 6. Line Budget

| Change | Lines |
|---|---|
| Current SKILL.md | 420 |
| Remove: setup failures table | -10 |
| Remove: workspace update protocol | -20 |
| Remove: file-locks.json details | -10 |
| Remove: events.log details | -10 |
| Add: quick start | +7 |
| Add: Phase 2 example | +20 |
| Add: Phase 3 spawn example | +15 |
| Add: protocol import instruction | +5 |
| **Estimated total** | **~417** |

Stays well under the 500-line limit with room for future growth.

## File Impact Matrix

| File | Action |
|---|---|
| `skills/agent-team/SKILL.md` | Trim 4 sections, add quick start, add 2 examples, add protocol import instruction, update refs worker→teammate |
| `docs/worker-roles.md` | Rename → `teammate-roles.md`, replace 12 protocol blocks with `{COMMUNICATION_PROTOCOL}` placeholder |
| `docs/communication-protocol.md` | **New** — canonical protocol definition (~30 lines) |
| `docs/coordination-patterns.md` | Remove protocol copy, absorb setup failures table, update refs |
| `docs/workspace-templates.md` | Absorb workspace update protocol table, absorb file-locks/events.log detail sections |
| `CLAUDE.md` | Update file references (worker-roles → teammate-roles) |
| `README.md` | Update file references |
| `docs/custom-roles.md` | Update terminology references |
| `docs/team-archetypes.md` | Update refs if any point to worker-roles.md |
| `docs/report-format.md` | No changes expected |

## Decisions

- **Skill name stays `agent-team`** — established, renaming has low ROI
- **"Teammate" is the standard term** — "worker" eliminated from filenames and content, "agent" reserved for technical identifiers
- **Protocol canonical source is `docs/communication-protocol.md`** — lead injects at spawn time
- **Completion Gate stays inline in SKILL.md** — too critical to move behind a reference

## Risks

- **Rename breaks grep/search for "worker-roles"** — mitigated by updating all references in the same commit
- **Placeholder pattern `{COMMUNICATION_PROTOCOL}` is new** — lead must understand to read and substitute. The Phase 3 spawn example demonstrates this explicitly.
- **Moving sections out of SKILL.md** — lead might miss moved content. Mitigated by keeping one-line references with clear file links.
