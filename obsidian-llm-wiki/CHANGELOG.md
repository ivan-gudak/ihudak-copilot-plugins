# Changelog

All notable changes to the **obsidian-llm-wiki** plugin are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow semver at the plugin level.

## [0.3.1]

### Fixed
- **Stop hook infinite loop**: Copilot CLI never sets `stop_hook_active=true` after a
  block-triggered AI run, causing the Stop hook to re-block indefinitely. Added a
  `find -mmin -3` recency guard on `hot.md` — if the file was updated in the last
  3 minutes, exit 0 and allow the session to stop.
- **Hooks fire in every project**: Both SessionStart and Stop hooks now check that
  `$PWD` resolves to `$VAULT_PATH` before doing anything. Outside the vault they exit
  immediately, so the plugin is silent in all other projects.

## [0.3.0]

### Added
- **wiki-task** skill — create individual tasks from natural language with
  effort estimation, tagging, and Jira linking in Obsidian Tasks format.
- **wiki-tasks-extract** skill — batch-extract tasks from wiki content
  after ingest.

## [0.2.0]

### Changed
- Ported from Claude Code plugin to GitHub Copilot CLI plugin format.
- Skills use SKILL.md with YAML frontmatter.
- Orchestrator skills declare `allowed-tools:` in frontmatter.
- Path references use `~/.copilot/installed-plugins/...`.

## [0.1.0]

### Added
- Initial release with nine skills: wiki-init, wiki-ingest, wiki-scan,
  wiki-query, wiki-save, wiki-lint, wiki-hot, wiki-tags-refresh, wiki-schema.
- Hooks: `SessionStart` and `Stop` via `hooks.json`.
- AGENTS.md for Claude Code compatibility.
