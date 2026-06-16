# Changelog

## 0.3.1

### Changed
- **`dt-review-pr` SKILL.md examples** — the `--repo <path>` example was
  updated from `/repos/dynatrace-docs` to `/workspace/dynatrace-docs` to match
  the convention used by `dev-workflows` v1.5.0+ (default `$REPOS_PATH` is
  `/workspace`). The skill itself accepts any absolute path; only the
  documented example changed. No behaviour change.

## 0.3.0 (Copilot)

### Breaking changes
- **`dt-style-checker` and `dt-doc-fixer` moved from skills to Copilot custom agents.**
  They now live at `agents/dt-style-checker.md` and `agents/dt-doc-fixer.md`. Orchestrator
  skills (`dt-review-pr`, `dt-review-docs`) dispatch them via
  `task(agent_type: "dt-style-guide:<name>", ...)` instead of the previous
  `agent_type: "general-purpose"` + "include the full SKILL.md content" pattern.
  Bare names were never registered as Copilot agents, so the prior dispatch was
  silently misrouting.
- **`plugin.json` now declares `"agents": "./agents/"`** in addition to `"skills": "./skills/"`.
- Cross-plugin: `dev-workflows` orchestrators now dispatch
  `dt-style-guide:dt-style-checker` (e.g. as a docs-style-checker fallback) using the same
  pattern.

## 0.2.0 (Copilot)

Port from Claude Code plugin to GitHub Copilot CLI plugin format.

- Ported `dt-style-checker` agent → sub-agent skill
- Ported `dt-doc-fixer` agent → sub-agent skill
- Ported `/dt-review-pr` command → orchestrator skill
- Ported `/dt-review-docs` command → orchestrator skill with `--fix` support
- Ported `/dt-style-refresh` command → orchestrator skill
- Ported `dt-style-rules` writing-aid skill
- Ported 8 vendored reference docs
- Integrated with `dev-workflows` plugin:
  - `docs-style-checker` falls back to `dt-style-checker` when `NOT_CONFIGURED`
  - `impl:jira:epics:` Phase 6.7 uses `dt-style-checker` as primary style checker
  - `impl:jira:docs:` Phase 6.7 uses `dt-style-checker` as fallback after `NOT_CONFIGURED`
- Tool mapping: Read→view, Bash→bash, Glob→glob, Grep→grep, Edit→edit, WebFetch→web_fetch
- Path convention: `~/.copilot/installed-plugins/ihudak-copilot-plugins/dt-style-guide/`

### Based on Claude Code v0.2.0

- Added `/dt-review-pr` command — reviews doc changes from a pull request
- Added `/dt-review-docs` command — reviews files/directories with optional `--fix`
- Added `dt-doc-fixer` agent — applies safe mechanical fixes for style violations
- Added `checker_source` field to `dt-style-checker` output for cross-plugin disambiguation
- Documented integration with `dev-workflows` (`docs-style-checker` fallback + Epic primary)

### Based on Claude Code v0.1.0

- Initial release
- `dt-style-checker` agent — LLM-based Dynatrace style guide checker
- `dt-style-rules` skill — writing aid for agents producing Dynatrace content
- `/dt-style-refresh` command — updates vendored references from styleguide.dynatrace.com
- 8 vendored reference docs (terminology, word-list, voice-and-tone, grammar, formatting, ui-interactions, accessibility, top-10-tips)
