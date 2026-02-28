# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-02-27

### Added
- **Re-plan on Block** coordination pattern — structured re-planning when critical blockers invalidate the original plan
- **Adversarial Review Rounds** coordination pattern — multi-round cross-review for high-stakes changes
- **Quality Gate** coordination pattern — final validation pass before Phase 5 synthesis
- **Auto-Block on Repeated Failures** coordination pattern — auto-escalation after 3 blocked attempts on the same task
- Custom role definitions template (`docs/custom-roles.md`) — project-specific roles alongside built-in ones
- `description` field in `hooks/hooks.json` for better UX in `/hooks` menu

## [1.2.0] - 2026-02-26

### Added
- Remediation Gate in Phase 5 — spawn fix team for unresolved issues (max 1 cycle)
- Tester role with spawn template
- Pre-shutdown commit protocol for implementers
- Complexity assessment and dedicated reviewer/tester gate for complex plans
- Remediation cycle tracking in `progress.md`

## [1.1.0] - 2026-02-24

### Added
- TeammateIdle hook with loop protection (3 strikes)
- Batch updates coordination pattern
- First contact verification pattern
- Parallel shutdown pattern

## [1.0.0] - 2026-02-23

### Added
- Initial release: 5-phase team orchestrator
- TaskCompleted hook with workspace and git change verification
- 5 teammate roles: Implementer, Reviewer, Researcher, Challenger, Leader
- Persistent workspace with progress.md, tasks.md, issues.md
- Structured communication protocol (STARTING/COMPLETED/BLOCKED/HANDOFF/QUESTION)
- Coordination patterns library
- Final report generation
