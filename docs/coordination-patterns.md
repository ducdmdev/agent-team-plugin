# Coordination Patterns Reference

Patterns for the lead to handle common coordination scenarios during Phase 4.

## Contents

- [Communication Protocol](#communication-protocol) — structured messages, processing rules, and plan approval
- [Batch Updates](#batch-updates) — efficient workspace writes
- [First Contact Verification](#first-contact-verification) — confirming teammates are active
- [Parallel Shutdown](#parallel-shutdown) — shutting down teammates efficiently
- [Pre-Shutdown Commit](#pre-shutdown-commit) — ensuring implementers commit before shutdown
- [Remediation Gate](#remediation-gate) — spawning a fix team for unresolved issues
- [Setup Failures](#setup-failures) — recovery actions for common Phase 3 failures
- [File Conflict Resolution](#file-conflict-resolution) — handling shared-file issues
- [Stuck Dependency Resolution](#stuck-dependency-resolution) — unblocking task chains
- [Result Handoff Between Teammates](#result-handoff-between-teammates) — cross-teammate transfers
- [Teammate Not Responding](#teammate-not-responding) — handling silent teammates
- [Scope Creep Detection](#scope-creep-detection) — keeping teammates on track
- [Synthesis Pattern](#synthesis-pattern) — collecting final results
- [Error Recovery](#error-recovery) — handling teammate errors
- [Issue Triage After Context Recovery](#issue-triage-after-context-recovery) — post-compaction review
- [Resume from Existing Workspace](#resume-from-existing-workspace) — recovering from a previous team session
- [Direct Handoff](#direct-handoff) — authorized peer-to-peer messaging with audit trail
- [Integration Checkpoint Response](#integration-checkpoint-response) — handling convergence point nudges
- [Advanced Patterns](coordination-advanced.md) — re-plan, adversarial review, checkpoint/rollback, deadline escalation, and more

## Communication Protocol

### Structured Messages

See [communication-protocol.md](communication-protocol.md) for the canonical protocol definition (STARTING, COMPLETED, BLOCKED, HANDOFF, QUESTION prefixes and role-specific formats).

### Lead Processing

When receiving structured messages:

| Prefix | Lead Action |
|--------|--------------|
| STARTING | Update `tasks.md` status to `in_progress`, add note |
| COMPLETED | Update `tasks.md` status to `completed`, add file list and notes. Update `task-graph.json`: set node status to `completed`, record `completed_at` and `output_files`. **Self-check**: read `task-graph.json` back to verify valid JSON. Check: does this unblock other tasks? If yes, message the dependent teammate. The `compute-critical-path.sh` hook will output the updated critical path. |
| BLOCKED | Add row to `issues.md` immediately. Acknowledge the teammate. Route to resolution |
| HANDOFF | Extract key details, forward to dependent teammate with actionable context. Log in `progress.md` Handoffs |
| QUESTION | Check if answer is in workspace files. If yes, answer with file reference. If no, investigate |
| PROGRESS | Note milestone in `tasks.md` Notes column. If percent indicates near-completion, no action needed. If stalled, trigger Deadline Escalation |
| CHECKPOINT | If `ready_for` lists task IDs, forward checkpoint details to dependent teammate. Log in `progress.md` Handoffs |
| (hook: integration checkpoint) | Read the nudge from `check-integration-point.sh`. Before unblocking the convergence task, verify interface compatibility between upstream outputs. If compatible, message the convergence task owner to proceed. If unclear, log in `issues.md` as medium severity. Log checkpoint in `progress.md` Decision Log. |

### Shared Workspace as Bulletin Board

The workspace at `.agent-team/{team-name}/` serves as the team's bulletin board:
- **Teammates read** workspace files for self-service context before messaging the lead
- **Lead writes** to workspace files after every significant event
- This reduces "what's happening?" messages and gives teammates situational awareness

When to tell teammates to check the workspace:
- Teammate asks about another teammate's progress -> "Check tasks.md for current status"
- Teammate asks about known issues -> "Check issues.md for known problems"
- Teammate asks about a decision -> "Check progress.md Decision Log"

### Plan Approval Handling

When a teammate spawned with `mode: "plan"` finishes planning, they send a `plan_approval_request` message to the lead. You must respond via SendMessage with `type: "plan_approval_response"`, the teammate as `recipient`, the `request_id` from their request, and `approve: true` or `approve: false`. If rejecting, include `content` with specific feedback so the teammate can revise their plan. The teammate cannot proceed with implementation until the plan is approved.

### Proactive Check-ins

The lead should proactively check in with teammates who haven't sent a message recently:
```
Status check: What's your progress on task #N?
If blocked, use the BLOCKED format so I can log and route it.
```

Don't wait for problems to surface — silent teammates may be stuck.

## Batch Updates

When multiple events arrive in quick succession, collect all pending updates and apply them in a single pass per file. Read once, apply all changes, write once. This prevents redundant I/O and keeps coordination tight.

## First Contact Verification

After spawning teammates, expect a STARTING message from each within their first turn:

1. Track which teammates have sent STARTING
2. If a teammate goes idle without STARTING: message them "Confirm active — send STARTING for your first task"
3. If still no STARTING after their next idle cycle: investigate (check idle notification for error clues)
4. If unrecoverable: shut down, respawn with same prompt and tasks

This prevents "silent spawn failures" where a teammate spawns but gets stuck on a permission prompt or error.

## Parallel Shutdown

During Phase 5, shut down teammates in parallel — not sequentially:

1. Send ALL `shutdown_request` messages in a single turn (parallel SendMessage calls)
2. Collect all approval responses
3. If a teammate rejects: read their reason, resolve, then re-request
4. Only call TeamDelete after ALL teammates have confirmed shutdown

**Why**: Sequential shutdown (send to A, wait, send to B, wait, send to C, wait) triples the wall-clock time. Parallel shutdown sends all requests at once, then waits for the batch.

After shutdown, clean up idle hook counters:
```bash
rm -f /tmp/agent-team-idle-counters/{team-name}--* 2>/dev/null || true
```

## Pre-Shutdown Commit

Before sending shutdown requests, the lead must ensure all implementers have committed their owned files. This preserves git history and makes each teammate's contribution traceable.

1. **Identify implementers** — only teammates with file ownership need to commit. Read-only roles (reviewers, researchers, challengers, testers) are exempt.
2. **Message each implementer** in parallel:
   ```
   Commit your owned files before shutdown.
   - Stage ONLY files in your owned area: git add <your owned files>
   - Commit with a descriptive message following project conventions
   - Send me the commit hash when done
   - If the commit fails, fix the issue and retry.
   ```
3. **Wait for all commit confirmations** — each implementer sends a message with their commit hash.
4. **If a commit fails**: the implementer must fix and retry. Log the failure in `issues.md` as **high** severity. Shutdown cannot proceed until all commits succeed.
5. **Only after all commits confirmed**: proceed to the shutdown sequence.

**Why**: Without this step, teammate work exists only as uncommitted changes on disk. If anything goes wrong during shutdown or cleanup, work is lost. Per-teammate commits also make `git log` useful for tracing who did what.

## Remediation Gate

After generating the final report, the lead reviews `issues.md` for OPEN items. If unresolved issues exist, the lead can spawn a remediation team to fix them — with user approval.

### Protocol

1. **Count OPEN issues** — read `issues.md`, filter for Status = OPEN.
2. **Check remediation cycle** — read `progress.md` for `**Remediation cycle**` value. If already `1`, this IS the remediation team — do not spawn another. Escalate to the user in the report instead.
3. **Present to user** — list OPEN issues with severity and affected tasks. Propose a remediation team (`{team-name}-fix`) with role composition. Ask for approval.
4. **If user approves**:
   - Shut down the original team (parallel shutdown + cleanup)
   - Set `progress.md` `**Remediation cycle**` to `1`
   - Create remediation team: `{original-team-name}-fix`
   - Reuse the same workspace directory — `issues.md` carries forward
   - Create tasks from the OPEN issues (each issue becomes a task)
   - Spawn teammates (typically 1-2 implementers + 1 tester if original was complex)
   - Run Phases 3-5 for remediation scope
5. **If user declines** — include unresolved issues in the user report with the escalation format:
   ```
   Unresolved issues (require manual follow-up):
   - Issue #N (severity): description
   See .agent-team/{team-name}/issues.md for full details.
   ```

### Remediation team conventions

- **Team name**: `{original-team-name}-fix` (e.g., `refactor-auth-fix`)
- **Workspace**: reuses `.agent-team/{original-team-name}/` — no new workspace directory
- **Max 1 cycle**: if the remediation team also has OPEN issues, escalate to user instead of recursing
- **Scope**: only the OPEN issues — tasks derive from the issue list, not a fresh decomposition

**Why**: OPEN issues represent known problems that were logged but never resolved. Leaving them as "FYI" in the report means the user must manually investigate and fix. A remediation team gives the lead a structured way to close the loop while keeping the user in control.

## Setup Failures

Recovery actions for common Phase 3 failures.

| Failure | Recovery |
|---------|----------|
| TeamCreate fails (name collision) | Append a counter: `{name}-2`, `{name}-3`. If `-3` also fails, ask the user for a name |
| TeamCreate fails (feature not enabled) | Tell the user to enable `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and restart |
| Workspace directory already exists | Read `progress.md` — if status is `done`, it's stale: ask user to confirm reuse or clean up. If status is `active`, another session may be using it: ask user |
| Teammate fails to spawn | Check the error. Common causes: tool not available, permission denied. Retry once. If still failing, log to `issues.md`, continue with remaining teammates, reassign orphaned tasks |
| Context compaction during Phase 3 | On recovery, read workspace files. If they exist but tasks/teammates are incomplete, resume from where you left off. If workspace doesn't exist yet, restart Phase 3 |

## Resume from Existing Workspace

When starting a new team session and the `detect-resume.sh` hook reports a resumable workspace:

### Valid Completed Tasks
Tasks whose output files are unchanged since `completed_at`. Skip these entirely — do not re-create or re-assign. Their results carry forward.

### Stale Completed Tasks
Tasks whose output files were modified after `completed_at` (someone edited the files outside the team). These must be re-run:
- Reset status to `pending` in `task-graph.json`
- Create new TaskCreate entries for them
- Assign to appropriate teammates
- Log in `progress.md` Decision Log: "Resumed — task #N marked stale (output modified after completion)"

### Remaining Tasks
Tasks that were never completed. Create and assign normally.

### Archive Protocol
If the user chooses "start fresh" instead of resuming:
- Rename `.agent-team/{team-name}/` to `.agent-team/{team-name}-archived/`
- Proceed with normal Phase 3
- The archived workspace is preserved for reference

## File Conflict Resolution

When two teammates report working on the same file:

1. **Stop both immediately** — message each: "Pause work on [file]. Conflict detected."
2. **Determine ownership** — which teammate's task is more tightly coupled to the file?
3. **Reassign** — the other teammate works around it or waits
4. **Confirm** — message both with the resolution before they resume
5. **Log** — add to `issues.md` as a **high** severity issue

Prevention: during Phase 2, map every file to exactly one owner.

## Stuck Dependency Resolution

When a task is blocked by another task:

1. **Check the blocking task** — is it actually done but not marked complete?
   - If yes: update status yourself via TaskUpdate, then unblock
2. **Check the assigned teammate** — are they stuck?
   - Message them: "Task [ID] is blocking [ID]. What's your status?"
3. **Reassign if needed** — if the teammate is stuck, consider:
   - Giving them hints based on other teammates' findings
   - Reassigning the blocking task to a different teammate
   - Breaking the blocking task into smaller pieces
4. **Log** — if the dependency was unexpected, add to `issues.md`

## Result Handoff Between Teammates

When Teammate A produces output that Teammate B needs:

1. **A sends HANDOFF message** to the lead with key details
2. **Lead extracts the relevant details** — file paths, interfaces, key decisions
3. **Lead messages B** with the condensed context: "A finished [task]. Here's what you need: [details]. You can now proceed with [your task]."
4. **Lead logs** the handoff in `progress.md` Handoffs section

Do NOT have teammates message each other directly for handoffs unless they need a back-and-forth discussion. The lead summarizing and forwarding keeps coordination clean and maintains the workspace audit trail.

### Warm vs Cold Handoff

- **Warm handoff**: Lead forwards full context — what was done, why, key decisions, and specific next steps for the receiving teammate. Use when the handoff requires understanding of reasoning.
  ```
  A finished task #3 (auth token refactor). Key changes:
  - Moved token validation to src/auth/validate.ts
  - New interface: TokenResult { valid: boolean, claims: Claims }
  - Decision: used JWT over opaque tokens (see progress.md Decision Log)
  You can now proceed with task #5 using the new TokenResult interface.
  ```

- **Cold handoff**: Lead forwards minimal context — just file paths and a pointer to workspace. Use when the receiving teammate only needs to know what files to read.
  ```
  A finished task #3. Output files: src/auth/validate.ts, src/auth/types.ts.
  Check workspace tasks.md for full details. Proceed with task #5.
  ```

**Default to warm handoffs** — the extra context costs little and prevents follow-up QUESTION messages. Use cold handoffs only when the downstream task is clearly independent (e.g., reviewer just needs to read files).

## Teammate Not Responding

If a teammate hasn't sent an update after an extended period:

1. **Send a status check**: "What's your current progress on [task]? Use STARTING/COMPLETED/BLOCKED format."
2. **If still no response**: check if they're stuck on a permission prompt or error
3. **If unrecoverable**: shut down the teammate, spawn a replacement, assign remaining tasks
4. **Log** — add to `issues.md` as **medium** severity

## Scope Creep Detection

If a teammate starts working on things outside their assigned tasks:

1. **Message them**: "Your assigned scope is [tasks]. The work on [other thing] isn't in your tasks. Please focus on your assignments."
2. **If the extra work is valuable**: create a new task for it and assign appropriately
3. **If it's not needed**: tell them to stop and return to assigned work

## Synthesis Pattern

When collecting final results from all teammates:

1. **Request structured summaries** from each teammate:
   ```
   Summarize your work:
   - Task IDs completed
   - Files created, modified, or deleted
   - Key decisions you made
   - Open concerns or follow-up items
   ```

2. **Compile into workspace and report**:
   - Update `tasks.md` with final states
   - Update `issues.md` with any last issues
   - Generate `.agent-team/{team-name}/report.md` from [report-format.md](report-format.md)

## Error Recovery

When a teammate encounters an error they can't resolve:

1. **Log to `issues.md`** immediately — don't wait for resolution:
   - Assign a severity (critical/high/medium/low)
   - Record reporter, description, what's impacted, and which task IDs are affected
   - Set Status to OPEN
2. **Acknowledge**: message the teammate — "Received, investigating" or "Routing to [teammate]"
3. **Assess and route**:
   - Can another teammate help? Route the question via message.
   - Is it a missing requirement? Ask the user.
   - Is it an environment issue? Try to help via message.
4. **If unrecoverable**:
   - Mark the task as blocked (update description with error details)
   - Reassign to a different teammate or escalate to the user
   - Do NOT let the teammate spin on the same error repeatedly
5. **On resolution**: update the `issues.md` row — set Status to RESOLVED or MITIGATED, fill the Resolution column

## Issue Triage After Context Recovery

When the lead recovers from context compaction:

1. Read `issues.md` in the workspace
2. Filter for OPEN items — these need immediate attention
3. For each OPEN issue:
   - Is it still relevant? (the teammate may have resolved it without updating)
   - Is it blocking work? Check affected task IDs against TaskList
   - Can it be resolved now with information from other teammates?
4. Address critical/high issues before resuming normal coordination
5. Update `issues.md` rows as issues are resolved

## Direct Handoff

For pre-approved information transfers between specific teammates, bypassing the lead for efficiency.

### When to Use

- Two teammates have a clear dependency (A produces -> B consumes)
- The handoff content is straightforward (file paths, interface definitions)
- The lead has explicitly authorized the direct channel in their spawn prompts

### When NOT to Use

- The handoff requires interpretation or decision-making (route through lead)
- The information needs to be visible to multiple teammates (use lead routing)
- First-time handoffs between teammates who haven't worked together in this session

### Protocol

1. **Lead authorizes** in spawn prompts: "For handoffs to [teammate-name], you may message them directly. Include the lead in a summary."
2. **Sender** messages the recipient directly using SendMessage with `type: "message"` and the recipient's name
3. **Sender also messages the lead** with a brief summary: "HANDOFF #N: Sent [details] directly to [recipient]"
4. **Lead logs** the handoff in `progress.md` Handoffs section (audit trail preserved)

### Key Rule

The audit trail MUST be maintained. Direct handoffs save time but must still be logged via the lead's workspace updates.

## Integration Checkpoint Response

When `check-integration-point.sh` fires an integration nudge after two converging streams complete:

1. **Read the nudge** — identify which convergence point was unblocked and which upstream tasks produced the converging outputs
2. **Quick compatibility check** — read the `output_files` from both upstream tasks in `task-graph.json`. Do they define compatible interfaces? (e.g., if task #1 exports `TokenResult` and task #2 imports `TokenResult`, do the types match?)
3. **If compatible** — message the convergence task owner: "Upstream tasks #X and #Y both completed. Interfaces verified compatible. Proceed with task #Z."
4. **If unclear or incompatible** — message both upstream owners and the convergence owner: "Integration issue at #Z: outputs from #X and #Y may conflict at [interface]. Verify before proceeding." Log in `issues.md` as **medium** severity.
5. **Log** — record the checkpoint in `progress.md` Decision Log: "Integration checkpoint: #Z unblocked by #X + #Y, compatibility [verified|flagged]"

## See Also

- [coordination-advanced.md](coordination-advanced.md) — Re-plan on Block, Adversarial Review, Quality Gate, Checkpoint/Rollback, Deadline Escalation, Circular Dependency Detection, Graceful Degradation, Auto-Block, Anti-Patterns
