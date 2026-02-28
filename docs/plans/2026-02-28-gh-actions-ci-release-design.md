# GitHub Actions CI/CD Design

**Date**: 2026-02-28
**Status**: Approved

## Goal

Set up GitHub Actions with two workflows: CI (testing on PR + push) and Release (tag-triggered with auto-generated changelog).

## Decisions

- **Two separate workflows** (`ci.yml` + `release.yml`) for clean separation
- **No npm publish** — plugin installs via git URL
- **Auto-generated changelog** from conventional commits (feat/fix/refactor/docs/chore)
- **Version sync check** in both workflows — fails if package.json, plugin.json, marketplace.json disagree
- **ubuntu-latest** runner — bash scripts are POSIX-compatible
- **No shellcheck** — kept simple for now, can add later

## Workflow 1: CI (`ci.yml`)

**Triggers**: `push` to `main`, `pull_request` to `main`

**Single job** (`test`):
1. Checkout repo
2. Install `jq`
3. Ensure scripts are executable (`chmod +x scripts/*.sh tests/**/*.sh`)
4. Run `tests/run-tests.sh`
5. Version sync check — extract version from all 3 files, fail if any differ

## Workflow 2: Release (`release.yml`)

**Trigger**: `push` tag matching `v*`

**Job 1** (`validate`):
1. Checkout repo
2. Install `jq`
3. Extract version from tag (strip `v` prefix)
4. Verify all 3 files match the tag version
5. Run `tests/run-tests.sh`

**Job 2** (`release`, needs: validate):
1. Checkout with `fetch-depth: 0` (full history for changelog)
2. Generate changelog from conventional commits since previous tag — bash script, no external actions
3. Create GitHub Release via `gh release create` with generated changelog

## Files to Create

```
.github/
├── workflows/
│   ├── ci.yml
│   └── release.yml
```

## Version Sync Check Logic

```bash
V_PKG=$(jq -r .version package.json)
V_PLUGIN=$(jq -r .version .claude-plugin/plugin.json)
V_MKT=$(jq -r '.plugins[0].version' .claude-plugin/marketplace.json)
if [ "$V_PKG" != "$V_PLUGIN" ] || [ "$V_PKG" != "$V_MKT" ]; then
  echo "Version mismatch: package.json=$V_PKG plugin.json=$V_PLUGIN marketplace.json=$V_MKT"
  exit 1
fi
```

## Changelog Generation Logic

Parse `git log` between previous tag and current tag, group by conventional commit prefix:
- `feat:` → Features
- `fix:` → Fixes
- `refactor:` → Refactors
- `docs:` → Documentation
- `chore:` → Maintenance

Skip empty groups. Output as markdown list.
