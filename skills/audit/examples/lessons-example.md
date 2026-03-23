# Lessons Learned — 0315-refactor-auth

## What Worked
- **Early interface agreement**: Defining the `TokenResult` type in a shared types file before both implementers started prevented integration friction at the convergence point. Both streams consumed the same interface without rework.
- **Reviewer as blocker detector**: The dedicated reviewer caught a missing null check in the session middleware before it reached integration testing, saving an estimated 15-minute debug cycle.
- **Task granularity**: Splitting "refactor auth middleware" into 3 sub-tasks (token validation, session management, error handling) allowed true parallelism — all 3 proceeded independently for the first 80% of execution.

## What Failed
- **Underestimated test migration scope**: The auth test suite had implicit dependencies on the old middleware structure. Moving to the new token-based flow required rewriting 12 test fixtures, not the 3 originally estimated. **Root cause**: Plan did not audit test fixtures for structural coupling — only counted test files, not fixture dependencies.
- **Stale dependency in package.json**: The `jsonwebtoken` library was pinned to v8 which lacked `algorithm: "ES256"` support needed for the new signing strategy. Discovery happened mid-implementation, triggering a recovery cycle. **Root cause**: Phase 1 dependency scan checked for the package but not its version capabilities.

## Estimation Accuracy
| Task | Estimated | Actual | Delta |
|------|-----------|--------|-------|
| Token validation refactor | 10 min | 12 min | +2 min |
| Session management migration | 15 min | 28 min | +13 min |
| Auth error handling consolidation | 8 min | 7 min | -1 min |
| Test suite migration | 10 min | 25 min | +15 min |

**Summary**: Systematic underestimation for tasks involving test migration (+13-15 min each). Core implementation tasks were estimated accurately (+/- 2 min).

## Integration Friction Points
- **Token type export path**: The token validation stream exported `TokenResult` from `src/auth/types.ts` but the session management stream initially imported from `src/auth/validate.ts` (the old path). Caught at convergence point check — required a 2-minute fix but blocked the downstream integration task for 5 minutes while the lead coordinated.
- **Error code enum collision**: Both streams added error codes to `src/auth/errors.ts`. The file-locks prevented direct conflicts, but the error code numbering overlapped (both started at 100). Resolved by assigning non-overlapping ranges during the handoff.

## Recommendations for Future Teams
- **Audit test fixtures during Phase 1**: When refactoring modules with existing tests, scan test fixtures for structural dependencies, not just test file count. Add a plan audit check: "Do test fixtures depend on internal structure of the module being refactored?"
- **Pin dependency version checks to capability**: During Phase 1 dependency scan, verify not just that a package exists but that its pinned version supports the features the plan requires. Add a checklist item: "For each library the plan depends on, confirm the pinned version supports the required API."
- **Pre-assign non-overlapping enum ranges**: When multiple teammates will extend the same enum or constant set (even through separate files), assign non-overlapping ranges at spawn time to prevent collision at integration.
