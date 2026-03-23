# Prior Context Loading

## Purpose

Load lessons and error patterns from prior teams to inform better planning. Teams that learn from past execution produce better decompositions, more accurate estimates, and avoid repeating known failure modes.

## Algorithm

1. **Scan `.agent-team/*/lessons.md`** -- find all completed teams' lessons files in the project workspace
2. **Sort by date** (newest first, using MMDD prefix in directory name)
3. **Scan global `~/.claude/agent-team-patterns.json`** -- load the cross-project error pattern library
4. **Relevance filter** -- match prior data against the current task description (see Relevance Filtering below)
5. **Select top 3** most relevant lessons entries
6. **Select matching error patterns** -- filter patterns whose `error_regex` or `context` matches files in the current task scope

## Relevance Filtering

Score each prior lesson/pattern by combining these signals:

| Signal | Weight | How to check |
|--------|--------|-------------|
| **File path overlap** | High | Tasks touching the same files or directories as the current task |
| **Keyword overlap** | Medium | Task description terms matching lesson content (normalize: lowercase, strip stop words) |
| **Archetype match** | Low | Same team type (implementation, research, etc.) gets a small boost |

Scoring is approximate -- read the lesson title and first few lines, compare with the current task description. Do not read entire lesson files during this scan.

## Output

If relevant prior data is found, collect a `## Learned Context` block in memory:

```markdown
## Learned Context

**Prior lessons** (from {N} previous teams):
- [{team-name}]: {lesson summary}
- [{team-name}]: {lesson summary}

**Known error patterns** for files in scope:
- {pattern description}: try {strategy} (success rate: {N/M})

**Estimation adjustments**:
- {adjustment based on prior team data}
```

This block is:
- **Held in memory** during the plan stage for use in decomposition and plan audit
- **Surfaced in the Phase 2 plan presentation** for user visibility (appended as "Learned context" section)
- **Written to `progress.md`** after workspace creation (execute stage handles this write)

## No-Op Conditions

Skip silently (no warning, no empty block) if:
- No `.agent-team/` directory exists
- No `lessons.md` files found in any team workspace
- `~/.claude/agent-team-patterns.json` does not exist
- No prior data passes the relevance filter

## Performance Budget

- Scan at most 10 team directories (newest first)
- Read at most the first 30 lines of each `lessons.md` (title + What Worked + What Failed)
- Read at most 20 patterns from `agent-team-patterns.json`
- Total time budget: this pre-step should add negligible overhead to Phase 1a
