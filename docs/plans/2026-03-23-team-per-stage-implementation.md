# Team Per Stage — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each pipeline stage (plan, execute, audit) creates and manages its own team, making stages truly independently invocable with workspace-only handoff.

**Architecture:** Plan stage gains TeamCreate/TeamDelete/SendMessage and creates the workspace. Execute stage now owns its own TeamDelete (no longer delegated to audit). Audit stage gains TeamDelete and creates its own team. Review agents (plan-reviewer, execute-reviewer, audit-reviewer, elegance-reviewer) become team members instead of subagents. All 3 teams share the same workspace directory.

**Tech Stack:** Markdown documentation, bash test scripts. No new runtime dependencies.

**Spec:** `docs/specs/2026-03-23-team-per-stage-design.md`

---

## Chunk 1: Team Per Stage

### Task 1: Add new spawn templates for plan and audit stage teams

**Files:**
- Create: `skills/plan/agents/researcher.md`
- Create: `skills/plan/agents/analyst.md`
- Create: `skills/audit/agents/reviewer.md`

- [ ] **Step 1: Create researcher spawn template**

Create `skills/plan/agents/researcher.md`. Follow the existing spawn template pattern from `skills/execute/agents/spawn-templates.md` (role H2, template in fenced code block, rules as bullets):

```markdown
# Researcher — Plan Stage Spawn Prompt

## Role

You are a **Researcher** on the planning team. Your job is to scan the codebase, understand dependencies, and report findings that inform the team lead's decomposition decisions.

## Tools

- **Read** — read source files, config files, documentation
- **Grep** — search for patterns, imports, usages
- **Glob** — find files by pattern
- **Bash** — read-only commands (`git log`, `git blame`, `wc`, `find`)

## Scope

Scan the files and directories relevant to the task description. Focus on:
- Existing code structure and patterns
- Dependencies between modules
- Test coverage and test patterns
- Configuration and build setup
- Documentation that may inform the plan

## Communication

Report findings using structured messages:

\`\`\`
FINDING: {what was found}, relevance={high|medium|low}, files=[{paths}]
\`\`\`

Send findings as you discover them — don't wait until you've scanned everything. Prioritize high-relevance findings first.

## Rules

- **Read-only** — do not write, edit, create, or delete any files
- **Stay in scope** — only scan files relevant to the task
- **Be specific** — include file paths and line references in findings
- **Flag risks** — if you find potential issues (circular dependencies, tight coupling, missing tests), report them as high-relevance findings
- **Report completion** — when done scanning, send: `COMPLETED #scan: {summary of N findings, M high-relevance}`
```

- [ ] **Step 2: Create analyst spawn template**

Create `skills/plan/agents/analyst.md`:

```markdown
# Analyst — Plan Stage Spawn Prompt

## Role

You are an **Analyst** on the planning team. Your job is to evaluate task complexity, estimate effort, and identify risks based on the researcher's findings and your own assessment.

## Tools

- **Read** — read source files and workspace files
- **Grep** — search for patterns
- **Glob** — find files by pattern
- **Bash** — read-only commands (`git log --oneline`, `wc -l`, `cloc`)

## Scope

Evaluate the task description and researcher findings to assess:
- Overall complexity (low/medium/high)
- Risk areas (what could go wrong)
- Effort estimates (relative sizing, not time)
- Dependencies that constrain ordering
- Potential for parallelization

## Communication

Report analysis using structured message:

\`\`\`
ANALYSIS: complexity={low|medium|high}, risks=[{risk list}], estimate={scope description}, parallelizable={yes|no|partial}
\`\`\`

## Rules

- **Read-only** — do not write, edit, create, or delete any files
- **Evidence-based** — reference specific files and findings in your assessment
- **Flag unknowns** — if you can't assess something, say so rather than guessing
- **One analysis per task** — if the lead asks for task-level breakdown, send one ANALYSIS per proposed task
- **Report completion** — when done: `COMPLETED #analysis: {summary}`
```

- [ ] **Step 3: Create audit-stage reviewer spawn template**

Create `skills/audit/agents/reviewer.md`:

```markdown
# Reviewer — Audit Stage Spawn Prompt

## Role

You are a **Reviewer** on the audit team. Your job is to validate the completed work against the original plan, run completion gate checks, and report findings.

## Tools

- **Read** — read source files, workspace files, plan documents
- **Grep** — search for patterns across the codebase
- **Glob** — find files by pattern
- **Bash** — read-only verification commands (`git status`, `git diff`, `npm test`, `npm run build`, `npm run lint`)

## Scope

Read the workspace files to understand what was planned and what was executed:
1. Read `progress.md` for the plan and archetype
2. Read `tasks.md` and `task-graph.json` for task status
3. Read `file-locks.json` for file ownership
4. Run the completion gate checks appropriate for the archetype (see `../references/completion-gates.md`)

## Communication

Report findings using structured message:

\`\`\`
COMPLETED #review: findings_summary={description}, issues={N high, M medium, L low}, gate_results={X/Y passed}
\`\`\`

For each failed gate check, send:
\`\`\`
FINDING: gate={check name}, status=FAIL, reason={why}, affected_files=[{paths}]
\`\`\`

## Rules

- **Read-only** — do not fix issues, only report them
- **Run all applicable gates** — check `../references/completion-gates.md` for the archetype's required checks
- **Be specific** — include file paths, test output, lint errors
- **Severity matters** — distinguish between blocking (must fix) and advisory (nice to fix)
- **Check the plan** — verify what was built matches what was planned, flag scope creep or missing deliverables
```

- [ ] **Step 4: Commit**

```bash
git add skills/plan/agents/researcher.md skills/plan/agents/analyst.md skills/audit/agents/reviewer.md
git commit -m "feat: add spawn templates for plan-stage researcher/analyst and audit-stage reviewer"
```

---

### Task 2: Update plan stage for team management

**Files:**
- Modify: `skills/plan/SKILL.md`
- Modify: `skills/plan/agents/plan-reviewer.md`

- [ ] **Step 1: Update plan SKILL.md frontmatter**

Change `allowed-tools` from:
```
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet
```
To:
```
allowed-tools: Read, Glob, Grep, Bash, Agent, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, TeamCreate, TeamDelete, SendMessage
```

- [ ] **Step 2: Add team lifecycle to plan SKILL.md**

After the `## Overview` section and before `## Phase 1: Analyze`, add a new section:

```markdown
## Team Management

The plan stage creates and manages its own planning team.

### Workspace Creation

The plan stage creates the workspace directory at the start (before Phase 1):
1. Generate team name: `MMDD-{task-slug}` (e.g., `0323-refactor-auth`)
2. Create `.agent-team/{team-name}/`
3. Initialize `progress.md` with `**Stage**: plan`, `**Archetype**: {detected type}`, Learned Context
4. Initialize empty `tasks.md` and `task-graph.json`

### Team Creation

After workspace initialization:
1. `TeamCreate` with the team name
2. Spawn teammates:
   - 1-2 Researchers (always) — scan codebase, report findings
   - 1 Analyst (complex tasks only) — evaluate complexity, estimate effort
   - 1 Plan Reviewer (always) — validate plan structure
3. Researchers and Analyst work in parallel during Phase 1a/1b
4. Plan Reviewer runs after lead completes decomposition (inter-stage review)

### Team Shutdown

After plan-reviewer completes (and any fix cycles):
1. Send parallel shutdown requests to all teammates
2. `TeamDelete`
3. Lead presents plan to user for approval (team no longer needed)
4. Write `**Pipeline status**: approved` to `progress.md` after user approves
```

- [ ] **Step 3: Update Phase 1 to reference team**

In the Phase 1 section, after the prior context loading pre-step, add a note:

```markdown
> **Team context**: Researchers scan the codebase in parallel during Phase 1a. Their FINDING messages inform the lead's plan detection and decomposition. The Analyst evaluates complexity after researchers report.
```

- [ ] **Step 4: Update Learned Context reference**

In Phase 1 Pre-step section, find the line "Written to `progress.md` after workspace creation (execute stage)" and update to: "Written to `progress.md` during plan stage workspace creation (Team Management section above)."

Also in "Step 0 -- Archetype Context" section (~line 54), update any references to "execute stage writes Archetype" to "plan stage writes `**Archetype**` during workspace creation."

- [ ] **Step 5: Update plan-reviewer.md for team communication**

Read current `skills/plan/agents/plan-reviewer.md`. The file already has `## Role`, `## Tools`, `## Checks`, `## Output`, `## Behavior` sections — it's structurally close to a spawn template. Minimal changes:
- Add `## Communication` section before `## Checks` explaining that this teammate uses `SendMessage` to send the `PLAN_REVIEW` message to the lead
- In the existing Output section, clarify messages are sent via SendMessage (not returned as a subagent report)
- Keep all 6 checks and behavior rules unchanged

- [ ] **Step 6: Commit**

```bash
git add skills/plan/SKILL.md skills/plan/agents/plan-reviewer.md
git commit -m "feat: add team management to plan stage"
```

---

### Task 3: Update execute stage for self-contained lifecycle

**Files:**
- Modify: `skills/execute/SKILL.md`
- Modify: `skills/execute/agents/execute-reviewer.md`

- [ ] **Step 1: Update execute SKILL.md — own TeamDelete**

In Phase 4, after the inter-stage review section, add a shutdown sequence:

```markdown
### Team Shutdown

After execute-reviewer passes (or one remediation cycle completes):
1. Send parallel shutdown requests to all teammates
2. Wait for confirmations
3. Write `**Pipeline status**: executed` to `progress.md`
4. Write `**Stage**: execute` to `progress.md`
5. `TeamDelete`
```

Remove any references to "audit stage handles shutdown" if present.

- [ ] **Step 2: Update execute SKILL.md preconditions**

In the Preconditions section, update the existing check from `**Status**: approved` to also accept `**Pipeline status**: approved`:

```markdown
> **Pipeline gate**: Check `progress.md` for `**Pipeline status**: approved`. If this field is absent (legacy/manual workspace), proceed without blocking — treat absence as "not gated" for backward compatibility.
```

- [ ] **Step 3: Gate workspace creation in Phase 3**

In Phase 3 Step 3 ("Initialize Workspace"), wrap the workspace creation in a conditional:

```markdown
> **Workspace**: If `.agent-team/{team-name}/progress.md` already exists (plan stage created it), skip workspace initialization — read and extend existing files. Only create workspace if it doesn't exist (independent invocation without plan stage).
```

This prevents the execute stage from overwriting plan-stage data (`**Stage**: plan`, `**Pipeline status**`, Learned Context, Archetype).

- [ ] **Step 4: Update execute-reviewer.md for team communication**

Read current `skills/execute/agents/execute-reviewer.md`. The file already has structured sections. Minimal changes:
- Add `## Communication` section explaining messages are sent via SendMessage
- In Output section, clarify EXECUTE_REVIEW is sent via SendMessage to lead
- Keep all 7 checks unchanged

- [ ] **Step 5: Commit**

```bash
git add skills/execute/SKILL.md skills/execute/agents/execute-reviewer.md
git commit -m "feat: execute stage owns full team lifecycle"
```

---

### Task 4: Update audit stage for own team creation

**Files:**
- Modify: `skills/audit/SKILL.md`
- Modify: `skills/audit/agents/elegance-reviewer.md`
- Modify: `skills/audit/agents/audit-reviewer.md`

- [ ] **Step 1: Update audit SKILL.md frontmatter**

Add `TeamDelete` to `allowed-tools` (TeamCreate already present):
```
allowed-tools: Read, Write, Glob, Grep, Bash, Agent, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, TeamCreate, TeamDelete, SendMessage
```

- [ ] **Step 2: Update Phase 5 ordering to 12 steps**

Replace the current 10-step ordering with the 12-step version from the spec:

```markdown
### Phase 5 Ordering

1. **TeamCreate** — create audit team with same team name from workspace
2. **Spawn audit teammates** — Reviewer, Elegance Reviewer (if code changes), Audit Reviewer
3. Reviewer validates work (completion gate checks per archetype)
4. Remediation gate (if open issues — lead coordinates fixes)
5. Elegance gate (Elegance Reviewer scores code)
6. Lessons capture (lead synthesizes)
7. Pattern library update (lead writes)
8. Report generation (lead writes)
9. Audit Reviewer validates report
10. **Shutdown teammates** (parallel)
11. **TeamDelete**
12. Cleanup — write `**Pipeline status**: audited`, `**Stage**: audit` to `progress.md`
```

- [ ] **Step 3: Add Pipeline status precondition**

In the Preconditions section of audit SKILL.md, add:

```markdown
> **Pipeline gate**: Check `progress.md` for `**Pipeline status**: executed`. If absent (legacy/manual workspace), proceed with a warning but do not block — treat absence as "not gated" for backward compatibility.
```

- [ ] **Step 4: Update Elegance Reviewer lifecycle note**

In the Elegance Gate section, add a note clarifying the new lifecycle:

```markdown
The Elegance Reviewer is spawned with the audit team at stage start (step 2). It is a regular team member, not a post-step addition.
```

- [ ] **Step 5: Update elegance-reviewer.md for team communication**

Read current `skills/audit/agents/elegance-reviewer.md`. Already has structured sections. Minimal changes:
- Add `## Communication` section explaining ELEGANCE_REVIEW is sent via SendMessage
- Update existing Output section to reference SendMessage
- Keep rubric and scope unchanged

- [ ] **Step 6: Update audit-reviewer.md for team communication**

Read current `skills/audit/agents/audit-reviewer.md`. Already has structured sections. Minimal changes:
- Add `## Communication` section explaining AUDIT_REVIEW is sent via SendMessage
- Update existing Output section to reference SendMessage
- Keep 6 checks and behavior rules unchanged

- [ ] **Step 7: Commit**

```bash
git add skills/audit/SKILL.md skills/audit/agents/elegance-reviewer.md skills/audit/agents/audit-reviewer.md
git commit -m "feat: audit stage creates and manages its own team"
```

---

### Task 5: Update start skill and shared docs

**Files:**
- Modify: `skills/start/SKILL.md`
- Modify: `docs/workspace-templates.md`
- Modify: `skills/execute/references/communication-protocol.md`

- [ ] **Step 1: Update start SKILL.md**

Update the Pipeline Flow section to reflect that each stage manages its own team:

```markdown
### Pipeline Flow

Each stage creates and destroys its own team. The workspace is the only handoff:

1. Detect archetype, generate team name (`MMDD-{task-slug}`)
2. Read and follow `../plan/SKILL.md` — creates planning team, produces plan, shuts down team
3. Wait for user approval
4. Read and follow `../execute/SKILL.md` — creates execution team, does work, shuts down team
5. Read and follow `../audit/SKILL.md` — creates audit team, reviews, reports, shuts down team
```

**Keep** TeamCreate/TeamDelete/SendMessage in start's frontmatter `allowed-tools` — start inlines stage logic and needs all tools the stages need. Only update the narrative text in the Pipeline Flow section.

- [ ] **Step 2: Add Pipeline status, Stage, and Archetype fields to workspace-templates.md**

In the `progress.md` template section, add after existing fields:

```markdown
**Stage**: {plan|execute|audit}
**Pipeline status**: {approved|executed|audited}
**Archetype**: {implementation|research|audit|planning|hybrid}
```

Add field docs:
```markdown
- **Stage**: Which pipeline stage last wrote to this workspace (plan, execute, or audit)
- **Pipeline status**: Cross-stage handoff state. Distinct from the `**Status**` field which tracks team lifecycle. Values: `approved` (plan complete, user approved), `executed` (execute complete, work done), `audited` (audit complete, report generated). Absence of this field means "not gated" for backward compatibility.
- **Archetype**: The detected team archetype. Set by the plan stage (or start skill) during workspace creation. Read by execute and audit stages to determine role selection, completion gates, and report variant.
```

- [ ] **Step 3: Add FINDING and ANALYSIS to communication protocol**

In `skills/execute/references/communication-protocol.md`, add a new section `## Plan Stage Messages` before the existing Plan-Mode Messages section:

```markdown
## Plan Stage Messages

### FINDING

Sent by Researchers during plan stage to report codebase discoveries:

\`\`\`
FINDING: {what was found}, relevance={high|medium|low}, files=[{paths}]
\`\`\`

**Lead processing**: Collect findings, use high-relevance findings to inform decomposition.

### ANALYSIS

Sent by Analyst during plan stage to report complexity assessment:

\`\`\`
ANALYSIS: complexity={low|medium|high}, risks=[{risk list}], estimate={scope description}, parallelizable={yes|no|partial}
\`\`\`

**Lead processing**: Use analysis to set task complexity, plan-mode defaults, and team sizing.
```

- [ ] **Step 4: Commit**

```bash
git add skills/start/SKILL.md docs/workspace-templates.md skills/execute/references/communication-protocol.md
git commit -m "feat: update start, workspace templates, and protocol for team-per-stage"
```

---

### Task 6: Update tests, meta docs, and version

**Files:**
- Modify: `tests/structure/test-doc-references.sh`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Update test assertions**

In `tests/structure/test-doc-references.sh`, add:

```bash
# --- Test: Plan stage has team spawn templates ---
assert_true "Plan stage has researcher.md" "[ -f skills/plan/agents/researcher.md ]"
assert_true "Plan stage has analyst.md" "[ -f skills/plan/agents/analyst.md ]"

# --- Test: Audit stage has reviewer spawn template ---
assert_true "Audit stage has reviewer.md" "[ -f skills/audit/agents/reviewer.md ]"

# --- Test: FINDING and ANALYSIS in communication protocol ---
COMM_PROTO="skills/execute/references/communication-protocol.md"
assert_true "FINDING message type defined" "grep -q 'FINDING' $COMM_PROTO"
assert_true "ANALYSIS message type defined" "grep -q 'ANALYSIS' $COMM_PROTO"

# --- Test: Pipeline status field in workspace templates ---
assert_true "Pipeline status field in workspace-templates.md" "grep -q 'Pipeline status' docs/workspace-templates.md"

# --- Test: Plan stage frontmatter has TeamCreate ---
assert_true "Plan stage has TeamCreate" "grep -q 'TeamCreate' skills/plan/SKILL.md"

# --- Test: Audit stage frontmatter has TeamDelete ---
assert_true "Audit stage has TeamDelete" "grep -q 'TeamDelete' skills/audit/SKILL.md"
```

- [ ] **Step 2: Run tests**

```bash
bash tests/run-tests.sh
```

Fix any failures before continuing.

- [ ] **Step 3: Update README.md**

In the How It Works section, update to mention 3 teams:

```markdown
Each stage creates its own team:
- **Plan team** (2-3): Researchers + Analyst + Plan Reviewer
- **Execute team** (2-4): Implementers + Tester + Reviewer + Execute Reviewer
- **Audit team** (2-3): Reviewer + Elegance Reviewer + Audit Reviewer
```

- [ ] **Step 4: Update CLAUDE.md**

Update architecture section to note team-per-stage.

- [ ] **Step 5: Version bump to 3.1.0**

Update version in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` from `3.0.0` to `3.1.0`.

- [ ] **Step 6: Add CHANGELOG entry**

```markdown
## [3.1.0] - 2026-03-23

### Added
- **Team per stage** — each pipeline stage (plan, execute, audit) creates and manages its own team
- Plan stage team: Researcher(s) + Analyst + Plan Reviewer
- Audit stage team: Reviewer + Elegance Reviewer + Audit Reviewer
- New spawn templates: `researcher.md`, `analyst.md`, `reviewer.md` (audit stage)
- `**Pipeline status**` and `**Stage**` fields in `progress.md` for cross-stage handoff
- `FINDING` and `ANALYSIS` message types for plan stage communication
- Review agents (plan-reviewer, execute-reviewer, audit-reviewer, elegance-reviewer) are now team members instead of subagents

### Changed
- Plan stage frontmatter gains `TeamCreate, TeamDelete, SendMessage`
- Execute stage now owns full lifecycle (TeamCreate through TeamDelete)
- Audit stage gains `TeamDelete`, creates its own team
- Workspace creation moved from execute stage to plan stage
```

- [ ] **Step 7: Run tests and commit**

```bash
bash tests/run-tests.sh
git add tests/ README.md CLAUDE.md CHANGELOG.md .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore: bump version to 3.1.0 with team-per-stage"
```
