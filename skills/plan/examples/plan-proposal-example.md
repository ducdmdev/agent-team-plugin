# Plan Proposal Example

A sample exchange demonstrating the PLAN_PROPOSAL flow between a teammate and the lead. This shows the full cycle: initial proposal, revision request, revised proposal, and approval.

## Context

The team is implementing an auth refactor. Teammate `auth-impl-1` is assigned task #1 (refactor JWT middleware) with plan-mode active.

## Exchange

### 1. Lead assigns plan-mode task

The lead spawned `auth-impl-1` with the plan-mode directive injected in the spawn prompt:

```
PLAN-MODE ACTIVE: Before writing any code, send a PLAN_PROPOSAL message to the lead.
Do NOT write/edit files until you receive PLAN_APPROVED.

Your assigned tasks:
- #1: Refactor JWT middleware to use adapter pattern for multiple auth providers
  Files: src/auth/middleware.ts, src/auth/adapters/
  Blocked by: none
```

### 2. auth-impl-1 sends PLAN_PROPOSAL

After analyzing the codebase, the teammate proposes:

```
PLAN_PROPOSAL #1:
  approach=Replace hardcoded JWT verification in middleware.ts with an AuthAdapter
    interface. Create concrete adapters for JWT (existing) and OAuth2 (new).
    Middleware calls adapter.verify(token) instead of jwt.verify() directly.
    Factory function selects adapter based on config.AUTH_PROVIDER env var.
  alternatives_considered=
    1. Strategy pattern with runtime switching -- rejected because provider is
       determined at startup, not per-request
    2. Middleware chain with separate middleware per provider -- rejected because
       it duplicates request parsing and error handling logic
  files_to_touch=
    - src/auth/middleware.ts (modify: extract interface, delegate to adapter)
    - src/auth/adapters/index.ts (create: AuthAdapter interface + factory)
    - src/auth/adapters/jwt-adapter.ts (create: existing JWT logic extracted)
    - src/auth/adapters/oauth2-adapter.ts (create: new OAuth2 verification)
    - src/auth/types.ts (modify: add AuthProvider type)
  estimated_complexity=medium
  risks=
    - OAuth2 adapter needs the jwks-rsa package (not currently installed)
    - Existing tests in src/auth/__tests__/middleware.test.ts mock jwt.verify()
      directly -- will need updates to mock the adapter instead
```

### 3. Lead sends PLAN_REVISION

The lead reviews and identifies a concern:

```
PLAN_REVISION #1: Good approach with the adapter pattern. Two changes needed:
  1. The OAuth2 adapter dependency (jwks-rsa) should be added as a separate
     sub-task (#1a) that runs first, not embedded in the adapter implementation.
     This keeps the package.json change isolated.
  2. Add src/auth/__tests__/middleware.test.ts to your files_to_touch list --
     the test updates are part of this task, not a separate task.
```

### 4. auth-impl-1 sends revised PLAN_PROPOSAL

```
PLAN_PROPOSAL #1:
  approach=Same adapter pattern approach. Split into two phases:
    Phase A: Install jwks-rsa, update package.json and lock file.
    Phase B: Extract AuthAdapter interface, create JWT and OAuth2 adapters,
    refactor middleware to use factory, update existing tests.
  alternatives_considered=(same as before, no change)
  files_to_touch=
    - package.json (modify: add jwks-rsa dependency)
    - src/auth/middleware.ts (modify: extract interface, delegate to adapter)
    - src/auth/adapters/index.ts (create: AuthAdapter interface + factory)
    - src/auth/adapters/jwt-adapter.ts (create: existing JWT logic extracted)
    - src/auth/adapters/oauth2-adapter.ts (create: new OAuth2 verification)
    - src/auth/types.ts (modify: add AuthProvider type)
    - src/auth/__tests__/middleware.test.ts (modify: mock adapter instead of jwt.verify)
  estimated_complexity=medium
  risks=
    - jwks-rsa version compatibility with current Node version
    - Lock file merge if another teammate also modifies package.json
      (will coordinate via HANDOFF if needed)
```

### 5. Lead sends PLAN_APPROVED

```
PLAN_APPROVED #1
```

The teammate now proceeds with implementation. The lead logs the proposal in `progress.md`:

```markdown
## Plan Proposals
| Teammate | Task | Proposal | Status | Revisions |
|----------|------|----------|--------|-----------|
| auth-impl-1 | #1 | Adapter pattern for multi-provider auth | Approved | 1 |
```
