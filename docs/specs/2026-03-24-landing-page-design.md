# Agent Team Landing Page — Design Spec

**Date**: 2026-03-24
**Status**: Draft

## Overview

A single-page landing page for the agent-team-plugin, hosted on GitHub Pages. Primary audience: developers already using Claude Code who want to discover and install plugins. Goal: install conversion (hero) + architecture education (scrolling sections).

**Style**: Terminal Dark — dark background (#0f0f23), monospace fonts, terminal-inspired UI, code snippets as visual anchors.

**Tech stack**: Single `index.html` with inline CSS and JS. No build tools, no dependencies, no frameworks. Deployed via GitHub Pages from a `site/` directory.

---

## Section 1: Hero

**Layout**: Centered, minimal, dark background.

**Content**:
- Headline: `Agent Team` — large monospace, white
- Subheadline: `Orchestrate parallel AI teammates in Claude Code` — smaller, muted gray
- Install command in a terminal block with copy button: `$ claude plugin install agent-team`
- Version badge: `v3.2.0` — small, muted
- Scroll cue: "Watch the demo ↓" pointing to terminal section

**Design details**:
- Background: `#0f0f23`
- No navigation bar — single page, just scroll
- Small GitHub icon in top-right corner linking to repo
- Hero is intentionally short — exists to give context before the terminal demo

---

## Section 2: Terminal Demo

**The centerpiece.** A realistic terminal window that auto-types the full 3-stage pipeline.

### Visual
- Dark terminal chrome: title bar with 3 colored dots (red/yellow/green), window title "claude"
- Monospace font (system monospace stack)
- Blinking cursor
- Each stage has a colored left border accent:
  - Plan: purple (#a78bfa)
  - Execute: blue (#60a5fa)
  - Audit: green (#4ade80)

### Animation Sequence (~30 seconds)
1. Type effect: `You > use agent team to refactor the auth module`
2. Pause (500ms), then Stage 1 — Plan output appears line by line:
   - `━━ Stage 1 — Plan ━━`
   - `[Planning team created: 2 Researchers + 1 Plan Reviewer]`
   - Researcher FINDING lines (2-3 lines)
   - `plan-reviewer: PLAN_REVIEW: status=approved`
   - Team plan summary (teammates, task breakdown)
   - `[Planning team shut down]`
   - `Approve?`
3. Type: `You > y`
4. Stage 2 — Execute output:
   - `━━ Stage 2 — Execute ━━`
   - `[Execution team created: 2 Implementers + 1 Reviewer + 1 Execute Reviewer]`
   - PLAN_PROPOSAL → PLAN_APPROVED
   - STARTING → COMPLETED lines
   - BLOCKED with error_type=recoverable + Recovery
   - EXECUTE_REVIEW: status=ready_for_audit
   - `[Execution team shut down]`
5. Stage 3 — Audit output:
   - `━━ Stage 3 — Audit ━━`
   - `[Audit team created: 1 Reviewer + 1 Elegance Reviewer + 1 Audit Reviewer]`
   - Completion gate (8/8 passed)
   - ELEGANCE_REVIEW: overall_score=4.2
   - Lessons captured
   - AUDIT_REVIEW: status=approved
   - Final summary line
   - `[Audit team shut down]`

### Controls
- Auto-starts when scrolled into view (IntersectionObserver)
- "Skip" button in top-right corner of terminal to jump to final state
- Click terminal to replay from start
- Lines appear with ~50ms delay between characters, ~200ms pause between lines
- Stage headers appear with 500ms pause before content

### Content Source
Directly from the README demo walkthrough (lines 24-104 of README.md). Proven accurate against v3.2.0 architecture.

---

## Section 3: Pipeline Overview

**Layout**: 3-column grid below the terminal, centered.

### Columns

| Column | Accent Color | Header | Team |
|--------|-------------|--------|------|
| Plan | Purple (#a78bfa) | Stage 1: Plan | Researcher + Analyst + Plan Reviewer |
| Execute | Blue (#60a5fa) | Stage 2: Execute | Implementers + Tester + Reviewer + Execute Reviewer |
| Audit | Green (#4ade80) | Stage 3: Audit | Reviewer + Elegance Reviewer + Audit Reviewer |

### Content per Column
- Stage name with colored top border
- Team composition (role list)
- 3 key features as bullet points:
  - Plan: Prior context loading, plan-mode gate, 7-check plan audit
  - Execute: Error recovery loop, coordination patterns, file ownership enforcement
  - Audit: 8 completion gates, elegance scoring (1-5), lessons capture + pattern library

### Design
- Dark cards (#1a1a2e background)
- Colored top border (4px, stage color)
- Monospace for role names, sans-serif for descriptions
- Responsive: stacks to single column on mobile

---

## Section 4: Features Grid

**Layout**: 2x3 grid of feature cards.

### Cards

| Card | Accent Text | Description |
|------|------------|-------------|
| 13 Hooks | `exit 2` | Block premature completion, enforce file ownership, validate task graphs, limit plan revisions, enforce pre-shutdown commits |
| 13 Roles | `SendMessage` | Implementers, researchers, reviewers, analysts, elegance reviewer — each with scoped tools and recovery class |
| Error Recovery | `error_type=recoverable` | Classify errors (retry/recoverable/design_flaw), auto-retry with pattern library, bounded recovery cycles |
| Elegance Review | `score=4.2/5` | 5-dimension quality: simplicity, consistency, readability, testability, minimal impact. Advisory, not blocking |
| Lessons Capture | `lessons.md` | Post-execution insights feed future teams. Global error pattern library at ~/.claude/agent-team-patterns.json |
| Team Per Stage | `TeamCreate → TeamDelete` | Each stage owns its lifecycle. Ephemeral teams, persistent workspace. 3 teams per pipeline run |

### Design
- Dark cards (#1a1a2e background)
- Accent text in monospace, colored per feature category
- 2-line description in muted gray
- No icons/emojis — code snippets as visual anchors
- Responsive: 2x3 → 1x6 on mobile

---

## Section 5: Install + Footer

### Install
- Centered section with prominent heading: "Get Started"
- Two terminal blocks side by side (or stacked):
  ```
  # Install from marketplace
  $ claude plugin marketplace add ducdmdev/agent-team-plugin
  $ claude plugin install agent-team
  ```
  ```
  # Enable agent teams feature
  $ export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
  ```
- Each block has a copy button
- Prerequisites listed below: Claude Code CLI (required), `jq` (required for hooks, graceful fallback), `git` (optional)

### Footer
- Single line: GitHub repo link | v3.2.0 | "Made for Claude Code developers"
- Dark background, muted text
- No social links, no newsletter

---

## Technical Implementation

### File Structure
```
site/
├── index.html          # Single file — all CSS and JS inline
└── assets/
    └── demo.gif        # Fallback for no-JS (copy from repo root assets/)
```

### GitHub Pages Deployment
- Source: `site/` directory on main branch
- Settings: GitHub repo → Settings → Pages → Source: Deploy from branch, folder: `/site`
- URL: `https://ducdmdev.github.io/agent-team-plugin/`

### Responsive Breakpoints
- Desktop: ≥1024px — 3-column pipeline, 2x3 features grid
- Tablet: 768-1023px — 2-column features, stacked pipeline
- Mobile: <768px — single column everything, terminal demo still full width

### Performance
- No external dependencies (no CDN, no fonts, no analytics)
- Single HTTP request (inline CSS + JS)
- Terminal animation uses requestAnimationFrame for smooth typing
- IntersectionObserver for scroll-triggered animation start
- Total page weight target: <50KB

### Accessibility
- Semantic HTML (header, main, section, footer)
- Terminal demo has aria-label describing what it shows
- Skip button is keyboard-accessible
- Color contrast meets WCAG AA for text on dark background
- Reduced motion: respect `prefers-reduced-motion` — show final state immediately instead of animation

---

## Content Source

All content derives from existing documentation:
- Demo output: `README.md` lines 24-104
- Hook descriptions: `README.md` Hooks section
- Role list: `docs/teammate-roles.md`
- Pipeline flow: `README.md` How It Works section
- Install commands: `README.md` Installation section
- Feature details: `CHANGELOG.md` v3.0.0-v3.2.0 entries

No new content needs to be written — only reformatted for the landing page layout.
