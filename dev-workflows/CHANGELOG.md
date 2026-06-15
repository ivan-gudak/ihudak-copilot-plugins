# Changelog

All notable changes to the **dev-workflows** plugin are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow semver at the plugin level.

## [1.4.0] — 2026-06-15

### Breaking changes
- **Sub-agents are now Copilot custom agents, not skills.** The 19 internal
  sub-agents (`risk-planner`, `code-review`, `test-baseliner`, `test-writer`,
  `review-fixer`, `impl-maintenance`, `jira-reader`, `diff-summarizer`,
  `code-scanner`, `doc-reviewer`, `doc-fixer`, `doc-location-finder`,
  `doc-planner`, `docs-style-checker`, `epic-reviewer`, `upgrade-planner`,
  `upgrade-executor`, `vuln-research`, `vuln-fixer`) moved from
  `skills/<name>/SKILL.md` to `agents/<name>.md` with proper Copilot agent
  frontmatter (`name`, `description`, `tools`).
- **`plugin.json` now declares `"agents": "./agents/"`** in addition to
  `"skills": "./skills/"`.
- **Orchestrator dispatch sites updated**: every `task(agent_type: "<bare-name>")`
  call is now `task(agent_type: "dev-workflows:<name>")`. Bare names matched
  neither a Copilot built-in nor a registered custom agent, so 7 of the 9
  distinct dispatches were silently misrouting before this release.
- **Sub-agent `references/` subdirectories preserved** at their original
  locations (`skills/<sub-agent>/references/handoff.md`) — agents read them
  via absolute paths inside `~/.copilot/installed-plugins/...`.

### Added
- Model fallback chain extended with GPT-5.5 (above Sonnet) and GPT-5.4 / Gemini
  3.1 Pro (below Sonnet) — leveraging Copilot's multi-vendor model access.
  Opus 4.8 added at the top of the Claude chain (forward-compatible — currently
  resolves to whichever Opus version the CLI exposes).

### Fixed
- `impl-dispatcher` SKILL.md version string corrected from `1.2.1` → `1.3.0` →
  current `1.4.0`.

## [1.3.0] — 2026-05-15

### Changed
- **Cross-platform sync with Claude Code plugin (v1.3.0).**
  - Ported `check_guidelines.py` and `checklist-template.md` to
    `guideline-reviewer/references/` (added in Claude Code v1.2.0, missing
    from the Copilot port).
  - Version numbers now track 1:1 between Copilot CLI and Claude Code
    plugin repos. Previous version drift: Copilot 1.2.1 / Claude 1.2.0.

## [1.2.1] — 2026-05-15

### Breaking changes
- **`impl:` is now a dispatcher.** Bare `impl:` no longer runs the code-implementation
  workflow — it prints a help page with the command matrix. Use `impl:code:` explicitly.
  Aligns with Claude Code plugin behaviour since v1.1.0.

### Added
- **`impl-dispatcher` skill.** Help / dispatcher triggered by bare `impl:`. Lists all
  `impl:*` variants and related skills (`fix-vuln:`, `upgrade:`), then stops.

### Changed
- **`impl` skill trigger narrowed.** Now only activates on `impl:code:` and `implement:`.
- **Marketplace descriptions enriched.** `dev-workflows` and `dt-style-guide` descriptions
  in `.github/plugin/marketplace.json` now enumerate all skills, sub-agents, and hooks.

## [1.2.0] — 2026-05-12

Copilot CLI port of the Claude Code dev-workflows plugin (v1.1.0).

### Added
- **Namespaced skill layout.** `skills/impl/`, `skills/impl-docs/`, `skills/impl-jira/`
  become the natural-language prefixes `impl:`, `impl:docs:`, `impl:jira:docs:`,
  `impl:jira:epics:` via Copilot CLI's skill discovery.
- **`impl:code:` full workflow.** Structured code-implementation skill: classify →
  optional Opus planning → feature branch → test baseline → implement → test-writing →
  optional Opus review → maintenance → report.
- **`impl:docs:` full workflow.** One-shot doc-editing skill: classify → plan →
  implement → doc-reviewer gate → maintenance → report.
- **`impl:jira:docs:` and `impl:jira:epics:` workflows.** Jira-driven documentation
  and Epic-writing skills with parallel sub-agent invocation, style checking, and
  Opus review gates.
- **15 sub-agent skills.** test-baseliner, test-writer, risk-planner, code-review,
  review-fixer, impl-maintenance, jira-reader, diff-summarizer, code-scanner,
  doc-location-finder, doc-planner, docs-style-checker, doc-reviewer, doc-fixer,
  epic-reviewer.
- **`fix-vuln:` workflow.** Security vulnerability remediation with NVD lookup,
  minimal-version fix strategy, baseline tests, and per-CVE branches/PRs.
- **`upgrade:` workflow.** Component upgrade with before/after test verification.
- **Hooks.** `preload-context.sh` injects git context on skill activation;
  `post-tool-use.sh` tracks tool usage.
- **Shared references.** `_shared/model-routing.md` defines task classification,
  model routing, and the mandatory Opus code-review checklist.

### Changed (vs Claude Code v1.1.0)
- Skills use SKILL.md with YAML frontmatter (not `commands/*.md` / `agents/*.md`).
- Orchestrator skills declare `allowed-tools:` in frontmatter; sub-agent skills do not.
- Path references use `~/.copilot/installed-plugins/...` instead of `${CLAUDE_PLUGIN_ROOT}`.
- Hooks use `${PLUGIN_ROOT}` instead of `${CLAUDE_PLUGIN_ROOT}`.
