# Coordination Patterns Reference

Patterns for the lead to handle common coordination scenarios.

## Contents

- [Communication Protocol](#communication-protocol) — structured messages and processing rules
- [Batch Updates](#batch-updates) — efficient workspace writes
- [First Contact Verification](#first-contact-verification) — confirming teammates are active
- [Parallel Shutdown](#parallel-shutdown) — shutting down teammates efficiently
- [File Conflict Resolution](#file-conflict-resolution) — handling shared-file issues
- [Stuck Dependency Resolution](#stuck-dependency-resolution) — unblocking task chains
- [Result Handoff Between Teammates](#result-handoff-between-teammates) — cross-teammate transfers
- [Teammate Not Responding](#teammate-not-responding) — handling silent teammates
- [Scope Creep Detection](#scope-creep-detection) — keeping teammates on track
- [Synthesis Pattern](#synthesis-pattern) — collecting final results
- [Error Recovery](#error-recovery) — handling teammate errors
- [Issue Triage After Context Recovery](#issue-triage-after-context-recovery) — post-compaction review

## Communication Protocol

### Structured Messages

All teammates use structured message prefixes when communicating with the lead:

```
STARTING #N: {what I plan to do, which files I'll touch}
COMPLETED #N: {what I did, files changed, any concerns}
BLOCKED #N: severity={critical|high|medium|low}, {what's blocking}, impact={what can't proceed}
HANDOFF #N: {what I produced that another teammate needs, key details}
QUESTION: {what I need to know, what I already checked}
```

### Lead Processing

When receiving structured messages:

| Prefix | Lead Action |
|--------|--------------|
| STARTING | Update `tasks.md` status to `in_progress`, add note |
| COMPLETED | Update `tasks.md` status to `completed`, add file list and notes. Check: does this unblock other tasks? If yes, message the dependent teammate |
| BLOCKED | Add row to `issues.md` immediately. Acknowledge the teammate. Route to resolution |
| HANDOFF | Extract key details, forward to dependent teammate with actionable context. Log in `progress.md` Handoffs |
| QUESTION | Check if answer is in workspace files. If yes, answer with file reference. If no, investigate |

### Shared Workspace as Bulletin Board

The workspace at `.agent-team/{team-name}/` serves as the team's bulletin board:
- **Teammates read** workspace files for self-service context before messaging the lead
- **Lead writes** to workspace files after every significant event
- This reduces "what's happening?" messages and gives teammates situational awareness

When to tell teammates to check the workspace:
- Teammate asks about another teammate's progress -> "Check tasks.md for current status"
- Teammate asks about known issues -> "Check issues.md for known problems"
- Teammate asks about a decision -> "Check progress.md Decision Log"

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
rm -f /tmp/agent-team-idle-counters/{team-name}_* 2>/dev/null || true
```

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
