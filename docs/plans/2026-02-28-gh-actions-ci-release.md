# GitHub Actions CI/CD Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add two GitHub Actions workflows — CI (test on PR/push) and Release (tag-triggered with auto-changelog).

**Architecture:** Two independent workflow files in `.github/workflows/`. CI runs the existing bash test suite. Release validates version sync against the git tag, runs tests, generates a changelog from conventional commits via bash, and creates a GitHub Release.

**Tech Stack:** GitHub Actions, bash, jq, gh CLI (pre-installed on runners)

**Design doc:** `docs/plans/2026-02-28-gh-actions-ci-release-design.md`

---

### Task 1: Create CI Workflow

**Files:**
- Create: `.github/workflows/ci.yml`

**Step 1: Create the directory structure**

Run: `mkdir -p .github/workflows`

**Step 2: Write the CI workflow file**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install jq
        run: sudo apt-get install -q -y jq

      - name: Ensure scripts are executable
        run: |
          chmod +x scripts/*.sh
          find tests -name '*.sh' -exec chmod +x {} +

      - name: Run tests
        run: bash tests/run-tests.sh

      - name: Check version sync
        run: |
          V_PKG=$(jq -r .version package.json)
          V_PLUGIN=$(jq -r .version .claude-plugin/plugin.json)
          V_MKT=$(jq -r '.plugins[0].version' .claude-plugin/marketplace.json)
          echo "package.json=$V_PKG plugin.json=$V_PLUGIN marketplace.json=$V_MKT"
          if [ "$V_PKG" != "$V_PLUGIN" ] || [ "$V_PKG" != "$V_MKT" ]; then
            echo "::error::Version mismatch across files"
            exit 1
          fi
          echo "All versions in sync: $V_PKG"
```

**Step 3: Verify the workflow is valid YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "Valid YAML"`

Expected: `Valid YAML` (or if pyyaml not installed, visually confirm — the workflow is simple enough)

**Step 4: Run the existing test suite locally to confirm it still passes**

Run: `bash tests/run-tests.sh`

Expected: `All test files passed`

**Step 5: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "feat: add CI workflow for tests and version sync"
```

---

### Task 2: Create Release Workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Step 1: Write the release workflow file**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install jq
        run: sudo apt-get install -q -y jq

      - name: Ensure scripts are executable
        run: |
          chmod +x scripts/*.sh
          find tests -name '*.sh' -exec chmod +x {} +

      - name: Extract tag version
        id: tag
        run: |
          TAG_VERSION="${GITHUB_REF_NAME#v}"
          echo "version=$TAG_VERSION" >> "$GITHUB_OUTPUT"
          echo "Tag version: $TAG_VERSION"

      - name: Check versions match tag
        run: |
          TAG_VERSION="${{ steps.tag.outputs.version }}"
          V_PKG=$(jq -r .version package.json)
          V_PLUGIN=$(jq -r .version .claude-plugin/plugin.json)
          V_MKT=$(jq -r '.plugins[0].version' .claude-plugin/marketplace.json)
          echo "tag=$TAG_VERSION package.json=$V_PKG plugin.json=$V_PLUGIN marketplace.json=$V_MKT"
          MISMATCH=false
          if [ "$V_PKG" != "$TAG_VERSION" ]; then
            echo "::error::package.json ($V_PKG) does not match tag ($TAG_VERSION)"
            MISMATCH=true
          fi
          if [ "$V_PLUGIN" != "$TAG_VERSION" ]; then
            echo "::error::plugin.json ($V_PLUGIN) does not match tag ($TAG_VERSION)"
            MISMATCH=true
          fi
          if [ "$V_MKT" != "$TAG_VERSION" ]; then
            echo "::error::marketplace.json ($V_MKT) does not match tag ($TAG_VERSION)"
            MISMATCH=true
          fi
          if [ "$MISMATCH" = "true" ]; then
            exit 1
          fi
          echo "All versions match tag: $TAG_VERSION"

      - name: Run tests
        run: bash tests/run-tests.sh

  release:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - name: Checkout (full history)
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate changelog
        id: changelog
        run: |
          # Find previous tag
          PREV_TAG=$(git tag --sort=-v:refname | grep '^v' | sed -n '2p')
          if [ -z "$PREV_TAG" ]; then
            # First release — use all commits
            RANGE="HEAD"
          else
            RANGE="${PREV_TAG}..HEAD"
          fi

          echo "Generating changelog for $RANGE"

          CHANGELOG=""

          # Collect commits by type
          FEATS=$(git log "$RANGE" --pretty=format:"%s" --no-merges | grep -E "^feat(\(.+\))?:" | sed 's/^feat\(([^)]*)\)\?: //' | sed 's/^feat: //' || true)
          FIXES=$(git log "$RANGE" --pretty=format:"%s" --no-merges | grep -E "^fix(\(.+\))?:" | sed 's/^fix\(([^)]*)\)\?: //' | sed 's/^fix: //' || true)
          REFACTORS=$(git log "$RANGE" --pretty=format:"%s" --no-merges | grep -E "^refactor(\(.+\))?:" | sed 's/^refactor\(([^)]*)\)\?: //' | sed 's/^refactor: //' || true)
          DOCS=$(git log "$RANGE" --pretty=format:"%s" --no-merges | grep -E "^docs(\(.+\))?:" | sed 's/^docs\(([^)]*)\)\?: //' | sed 's/^docs: //' || true)
          CHORES=$(git log "$RANGE" --pretty=format:"%s" --no-merges | grep -E "^chore(\(.+\))?:" | sed 's/^chore\(([^)]*)\)\?: //' | sed 's/^chore: //' || true)

          if [ -n "$FEATS" ]; then
            CHANGELOG+=$'\n## Features\n\n'
            while IFS= read -r line; do
              CHANGELOG+="- $line"$'\n'
            done <<< "$FEATS"
          fi

          if [ -n "$FIXES" ]; then
            CHANGELOG+=$'\n## Fixes\n\n'
            while IFS= read -r line; do
              CHANGELOG+="- $line"$'\n'
            done <<< "$FIXES"
          fi

          if [ -n "$REFACTORS" ]; then
            CHANGELOG+=$'\n## Refactors\n\n'
            while IFS= read -r line; do
              CHANGELOG+="- $line"$'\n'
            done <<< "$REFACTORS"
          fi

          if [ -n "$DOCS" ]; then
            CHANGELOG+=$'\n## Documentation\n\n'
            while IFS= read -r line; do
              CHANGELOG+="- $line"$'\n'
            done <<< "$DOCS"
          fi

          if [ -n "$CHORES" ]; then
            CHANGELOG+=$'\n## Maintenance\n\n'
            while IFS= read -r line; do
              CHANGELOG+="- $line"$'\n'
            done <<< "$CHORES"
          fi

          if [ -z "$CHANGELOG" ]; then
            CHANGELOG=$'\nNo categorized changes in this release.\n'
          fi

          # Write to file (multi-line output is easier via file)
          echo "$CHANGELOG" > /tmp/changelog.md
          echo "Changelog generated:"
          cat /tmp/changelog.md

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create "$GITHUB_REF_NAME" \
            --title "$GITHUB_REF_NAME" \
            --notes-file /tmp/changelog.md \
            --latest
```

**Step 2: Verify the workflow is valid YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" && echo "Valid YAML"`

Expected: `Valid YAML`

**Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add release workflow with auto-changelog"
```

---

### Task 3: Verify Everything Works Together

**Step 1: Run the full test suite**

Run: `bash tests/run-tests.sh`

Expected: `All test files passed`

**Step 2: Verify workflow files exist and are valid**

Run: `ls -la .github/workflows/`

Expected: `ci.yml` and `release.yml` both present

**Step 3: Dry-run the version sync check locally**

Run:
```bash
V_PKG=$(jq -r .version package.json)
V_PLUGIN=$(jq -r .version .claude-plugin/plugin.json)
V_MKT=$(jq -r '.plugins[0].version' .claude-plugin/marketplace.json)
echo "package.json=$V_PKG plugin.json=$V_PLUGIN marketplace.json=$V_MKT"
[ "$V_PKG" = "$V_PLUGIN" ] && [ "$V_PKG" = "$V_MKT" ] && echo "PASS: All in sync" || echo "FAIL: Mismatch"
```

Expected: `PASS: All in sync` (all should show `1.2.0`)

**Step 4: Dry-run the changelog generation locally**

Run:
```bash
PREV_TAG=$(git tag --sort=-v:refname | grep '^v' | head -1)
if [ -z "$PREV_TAG" ]; then
  echo "No previous tags — first release will include all commits"
  git log --pretty=format:"%s" --no-merges | head -10
else
  echo "Previous tag: $PREV_TAG"
  git log "${PREV_TAG}..HEAD" --pretty=format:"%s" --no-merges | head -10
fi
```

Expected: Lists recent commit messages (confirms the log range works)

**Step 5: Final commit (if any adjustments were made)**

Only if changes were needed. Otherwise, skip.
