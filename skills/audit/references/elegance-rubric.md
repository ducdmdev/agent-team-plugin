# Elegance Rubric

5-dimension scoring guide for the Elegance Reviewer. Each dimension is scored 1-5. The overall score is the average across all dimensions.

## Dimensions

### 1. Simplicity

Could this be simpler? Are there unnecessary abstractions, over-engineering, or redundant code?

| Score | Description | What to look for |
|-------|-------------|------------------|
| 1 | Severely over-engineered | Multiple unnecessary abstraction layers, patterns used without justification, code that does simple things in complex ways |
| 2 | Notably complex | Some unnecessary abstractions or indirection, could be simplified significantly |
| 3 | Adequate | Reasonable complexity for the task, minor simplification opportunities |
| 4 | Clean | Direct approach, minimal unnecessary abstractions, clear purpose for each component |
| 5 | Elegantly simple | Simplest possible solution that meets requirements, every line earns its place |

**Examples:**
- Score 1: A factory pattern wrapping a factory pattern to create a simple config object
- Score 3: A service class with a couple of methods that could be standalone functions, but the class is not harmful
- Score 5: A utility function that does exactly one thing with no wasted lines

### 2. Consistency

Does the code follow existing codebase patterns, naming conventions, and architectural decisions?

| Score | Description | What to look for |
|-------|-------------|------------------|
| 1 | Contradicts codebase patterns | Different naming style, different error handling approach, different file organization than existing code |
| 2 | Inconsistent in several areas | Mixes conventions, some new patterns alongside existing patterns without justification |
| 3 | Mostly consistent | Follows most conventions, minor deviations |
| 4 | Consistent | Follows all visible conventions, new code looks like it belongs |
| 5 | Exemplary consistency | Could serve as a reference implementation for the project's style |

**Examples:**
- Score 1: Using `snake_case` in a `camelCase` codebase, handling errors with try/catch when the project uses Result types
- Score 3: Correct naming and structure but introduces a new logging pattern where one already exists
- Score 5: Matches import order, error handling style, test structure, naming, and file organization of surrounding code

### 3. Readability

Is the code self-documenting? Are names clear, structure logical, and intent obvious?

| Score | Description | What to look for |
|-------|-------------|------------------|
| 1 | Very difficult to follow | Cryptic variable names, deeply nested logic, no comments where intent is unclear |
| 2 | Requires significant effort to understand | Some unclear names, complex conditionals without explanation |
| 3 | Readable with some effort | Generally clear, occasional unclear sections |
| 4 | Easy to read | Clear naming, logical flow, comments where helpful (not obvious) |
| 5 | Immediately clear | Self-documenting code, intent is obvious from structure alone, comments only for "why" not "what" |

**Examples:**
- Score 1: `const x = a.filter(i => i.p > 0 && i.s !== 3).map(i => ({...i, d: fn(i.p)}))`
- Score 3: Functions with clear names but some intermediate variables that are unclear
- Score 5: `const activeUsers = users.filter(isActive).map(toPublicProfile)` with well-named helper functions

### 4. Testability

Is the code easy to test? Are concerns properly separated? Are dependencies injectable?

| Score | Description | What to look for |
|-------|-------------|------------------|
| 1 | Very difficult to test | Hard-coded dependencies, global state mutation, tightly coupled modules, no clear boundaries |
| 2 | Testable with significant setup | Some coupling issues, requires mocking internal details |
| 3 | Reasonably testable | Most functionality can be tested, minor coupling concerns |
| 4 | Easy to test | Clear interfaces, injectable dependencies, pure functions where appropriate |
| 5 | Test-friendly by design | Excellent separation of concerns, minimal mocking needed, boundary-based testing possible |

**Examples:**
- Score 1: A function that reads from disk, calls an API, mutates a database, and sends an email with no dependency injection
- Score 3: A service class with constructor injection but some internal methods that are hard to test in isolation
- Score 5: Pure functions for business logic, thin integration layers for I/O, clear boundaries between modules

### 5. Minimal Impact

Does the code only touch what is necessary? Is there scope creep or unnecessary refactoring?

| Score | Description | What to look for |
|-------|-------------|------------------|
| 1 | Extensive unnecessary changes | Reformats unrelated files, renames things outside scope, introduces unrelated refactors |
| 2 | Some unnecessary changes | A few files touched that did not need changing, some drive-by refactoring |
| 3 | Mostly focused | Changes are relevant, minor unnecessary touches |
| 4 | Well-scoped | Only necessary files changed, clear relationship between changes and task |
| 5 | Surgically precise | Minimal diff, every change directly serves the task, zero collateral edits |

**Examples:**
- Score 1: A "fix typo in README" task that also reformats 10 source files and renames a utility function
- Score 3: An auth feature that also cleans up a few unrelated imports in touched files
- Score 5: A bug fix that changes exactly the lines needed plus the corresponding test

## Finding Severity Levels

When reporting individual findings, use these severity levels:

### nitpick

Style preference or personal taste. Not a quality issue — the current code is acceptable. Including these shows thoroughness but they should not influence the decision to ship.

**Examples:**
- Preferring `const` over `let` where technically either works
- Suggesting a different variable name that is equally clear
- Preferring single-line ternary over if/else for a simple condition

### improve

Would make the code meaningfully better but is not critical. The code works correctly without this change, but the change would improve maintainability, readability, or robustness.

**Examples:**
- Extracting a repeated pattern into a helper function
- Adding a type annotation that TypeScript can infer but humans cannot easily
- Replacing a magic number with a named constant

### refactor

Should change before merge. The current code works but has a structural issue that will cause problems — maintenance burden, bug risk, or significant readability concern.

**Examples:**
- A function doing 3 unrelated things that should be split
- Missing error handling on an API call that can fail
- A data structure choice that will not scale with expected usage
- Duplicated logic across files that should be shared

## Scoring Protocol

1. Read all files in scope (from `file-locks.json`)
2. Score each dimension 1-5
3. Calculate overall score as the average (round to 1 decimal)
4. List individual findings with file, line range, dimension, suggestion, and severity
5. Report via `ELEGANCE_REVIEW` message format
