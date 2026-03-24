# Landing Page — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single-page landing page for the agent-team-plugin with an interactive terminal demo, hosted on GitHub Pages.

**Architecture:** Single `index.html` with inline CSS and JS. Terminal Dark style (#0f0f23 background, monospace). Interactive terminal animation auto-types the 3-stage pipeline demo. No build tools, no dependencies. Deployed via GitHub Pages from `site/` directory.

**Tech Stack:** HTML, CSS, vanilla JS. No frameworks, no build tools.

**Spec:** `docs/specs/2026-03-24-landing-page-design.md`

---

## Chunk 1: Build the Landing Page

### Task 1: Create site directory and index.html

**Files:**
- Create: `site/index.html`

- [ ] **Step 1: Create site directory**

```bash
mkdir -p site
```

- [ ] **Step 2: Create index.html with all 5 sections**

Create `site/index.html` — a single self-contained HTML file with inline `<style>` and `<script>`. The file should contain all 5 sections from the spec.

**Overall structure:**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Agent Team — Orchestrate parallel AI teammates in Claude Code</title>
  <meta name="description" content="Claude Code plugin that decomposes complex tasks into parallel work streams executed by multiple AI teammates across 3 pipeline stages.">
  <style>/* all CSS inline */</style>
</head>
<body>
  <!-- Section 1: Hero -->
  <!-- Section 2: Terminal Demo -->
  <!-- Section 3: Pipeline Overview -->
  <!-- Section 4: Features Grid -->
  <!-- Section 5: Install + Footer -->
  <script>/* all JS inline */</script>
</body>
</html>
```

**CSS requirements** (inline in `<style>`):

- Base: `body { background: #0f0f23; color: #e2e8f0; font-family: system-ui, -apple-system, sans-serif; margin: 0; }`
- Monospace: `.mono { font-family: 'SF Mono', 'Fira Code', 'JetBrains Mono', monospace; }`
- Container: `max-width: 960px; margin: 0 auto; padding: 0 20px;`
- Section spacing: `padding: 80px 0;`
- Colors: background #0f0f23, card background #1a1a2e, text #e2e8f0, muted #94a3b8, purple #a78bfa, blue #60a5fa, green #4ade80
- Terminal window: dark chrome bar with 3 dots, monospace content, blinking cursor
- Pipeline columns: 3-column grid with colored top borders
- Feature cards: grid layout, code accent text
- Copy button: small button on terminal blocks that copies text to clipboard
- Responsive: `@media (max-width: 768px)` stacks columns
- Reduced motion: `@media (prefers-reduced-motion: reduce)` skips animation

**Section 1: Hero** (HTML):

```html
<header style="text-align: center; padding: 60px 0 20px;">
  <a href="https://github.com/ducdmdev/agent-team-plugin"
     style="position: absolute; top: 20px; right: 20px; color: #94a3b8;">
    <!-- GitHub SVG icon -->
  </a>
  <h1 class="mono" style="font-size: 2.5rem; margin: 0;">Agent Team</h1>
  <p style="color: #94a3b8; font-size: 1.1rem; margin: 12px 0 24px;">
    Orchestrate parallel AI teammates in Claude Code
  </p>
  <div class="terminal-block">
    <code>$ claude plugin marketplace add ducdmdev/agent-team-plugin</code><br>
    <code>$ claude plugin install agent-team</code>
    <button class="copy-btn" onclick="copyInstall()">Copy</button>
  </div>
  <span style="color: #94a3b8; font-size: 0.8rem;">v3.2.0</span>
  <p style="color: #64748b; margin-top: 30px;">Watch the demo ↓</p>
</header>
```

**Section 2: Terminal Demo** (HTML + JS):

The terminal is a `<div>` styled as a macOS terminal window:

```html
<section id="demo">
  <div class="terminal">
    <div class="terminal-chrome">
      <span class="dot red"></span>
      <span class="dot yellow"></span>
      <span class="dot green"></span>
      <span class="terminal-title">claude</span>
      <button class="skip-btn" onclick="skipDemo()">Skip</button>
    </div>
    <div class="terminal-body" id="terminal-output">
      <!-- Lines injected by JS -->
    </div>
  </div>
</section>
```

JS animation logic:
- Define the demo as an array of line objects: `{ text, delay, type, class }`
  - `type: 'input'` — type character by character (50ms/char)
  - `type: 'output'` — appear as a block (100ms delay between lines)
  - `type: 'header'` — stage header with 500ms pause before
  - `class` — optional CSS class for coloring (plan-line, execute-line, audit-line)
- Demo content: directly from README lines 24-104, adapted to the line-object format
- `IntersectionObserver` on `#demo` to auto-start when scrolled into view
- `skipDemo()` function: clears animation timers, renders all lines immediately
- Click on terminal to replay: reset `#terminal-output` innerHTML and re-run animation
- `prefers-reduced-motion`: show all lines immediately, no animation

**Section 3: Pipeline Overview** (HTML):

```html
<section>
  <div class="container">
    <p style="text-align: center; color: #94a3b8; max-width: 700px; margin: 0 auto 40px;">
      Agent Team splits every task into 3 stages — Plan, Execute, Audit — each with its
      own ephemeral team. Auto-detects team type from your task description.
    </p>
    <div class="pipeline-grid">
      <!-- 3 cards with colored top borders -->
      <div class="pipeline-card" style="border-top: 4px solid #a78bfa;">
        <h3 class="mono">Stage 1: Plan</h3>
        <p class="mono" style="color: #a78bfa; font-size: 0.85rem;">
          Researcher + Analyst + Plan Reviewer
        </p>
        <ul>
          <li>Prior context loading</li>
          <li>Plan-mode gate</li>
          <li>7-check plan audit</li>
        </ul>
      </div>
      <!-- Execute card (blue) -->
      <!-- Audit card (green) -->
    </div>
  </div>
</section>
```

**Section 4: Features Grid** (HTML):

7 feature cards in a responsive grid. Each card:

```html
<div class="feature-card">
  <code class="feature-accent">exit 2</code>
  <h3>13 Hooks</h3>
  <p>Block premature completion, enforce file ownership, validate task graphs,
     limit plan revisions, enforce pre-shutdown commits</p>
</div>
```

Cards: 13 Hooks, 13 Roles, Error Recovery, Elegance Review, Lessons Capture, Team Per Stage, 5 Archetypes.

**Section 5: Install + Footer** (HTML):

```html
<section>
  <h2 style="text-align: center;">Get Started</h2>
  <div class="install-grid">
    <div class="terminal-block">
      <code># Install from marketplace</code><br>
      <code>$ claude plugin marketplace add ducdmdev/agent-team-plugin</code><br>
      <code>$ claude plugin install agent-team</code>
      <button class="copy-btn" onclick="copyText(this)">Copy</button>
    </div>
    <div class="terminal-block">
      <code># Enable agent teams feature</code><br>
      <code>$ export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1</code><br><br>
      <code style="color: #64748b;"># Or in settings.json:</code><br>
      <code style="color: #64748b;"># { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }</code>
      <button class="copy-btn" onclick="copyText(this)">Copy</button>
    </div>
  </div>
  <p style="text-align: center; color: #64748b; font-size: 0.85rem;">
    Requires: Claude Code CLI · jq (hooks skip gracefully without it) · git (optional)
  </p>
  <p style="text-align: center;">
    <a href="https://github.com/ducdmdev/agent-team-plugin#readme">Full documentation →</a>
  </p>
</section>

<footer>
  <a href="https://github.com/ducdmdev/agent-team-plugin">GitHub</a> · v3.2.0 · Made for Claude Code developers
</footer>
```

- [ ] **Step 3: Test locally**

```bash
open site/index.html
# Or: python3 -m http.server 8000 --directory site
```

Verify:
- Hero renders with install command and version badge
- Terminal demo auto-starts on scroll, types input, shows all 3 stages
- Skip button works
- Click terminal to replay works
- Pipeline columns render 3 cards with correct colors
- Features grid renders 7 cards
- Install section has copy buttons that work
- Footer has GitHub link
- Responsive: resize to mobile width, verify single-column layout
- Reduced motion: test with system setting or `prefers-reduced-motion` override

- [ ] **Step 4: Commit**

```bash
git add site/
git commit -m "feat: add landing page with interactive terminal demo"
```

---

### Task 2: GitHub Pages setup and deploy

**Files:**
- Modify: `.gitignore` (ensure `site/` is NOT ignored)

- [ ] **Step 1: Verify site/ is not gitignored**

```bash
git check-ignore site/index.html
```

If ignored, update `.gitignore` to exclude the exclusion.

- [ ] **Step 2: Push to main**

```bash
git push origin main
```

- [ ] **Step 3: Enable GitHub Pages**

```bash
gh api repos/ducdmdev/agent-team-plugin/pages -X POST -f source.branch=main -f source.path=/site 2>/dev/null || \
gh api repos/ducdmdev/agent-team-plugin/pages -X PUT -f source.branch=main -f source.path=/site
```

- [ ] **Step 4: Verify deployment**

Wait 1-2 minutes for GitHub Pages to build, then:

```bash
curl -s -o /dev/null -w "%{http_code}" https://ducdmdev.github.io/agent-team-plugin/
```

Expected: `200`

- [ ] **Step 5: Update README with landing page link**

Add to the top of `README.md`, after the badge:

```markdown
🌐 **[Live Demo](https://ducdmdev.github.io/agent-team-plugin/)** — see the pipeline in action
```

- [ ] **Step 6: Commit**

```bash
git add README.md .gitignore
git commit -m "docs: add landing page link to README"
git push origin main
```
