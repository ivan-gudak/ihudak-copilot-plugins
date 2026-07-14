# Changelog

All notable changes to the **obsidian-llm-wiki** plugin are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow semver at the plugin level.

## [0.3.3]

### Fixed
- **wiki-tags-refresh grep flag ordering**: flags were placed after the pattern/path
  operands, which GNU grep tolerates but strict/BSD grep (default on macOS) doesn't
  reliably. Flags now precede operands. Found via cross-repo review with the sibling
  `ihudak-claude-plugins` port of this same feature.
- **wiki-tags-refresh stale-tag check used an unanchored substring match**: `grep
  "#tagname"` falsely matched longer tags like `#tagname-extended` or `#tagname/nested`.
  Now extracts exact tag tokens and matches with `grep -xF`.
- **wiki-tags-refresh stale-tag check always counted a tag as "used"**: the vault-wide
  recheck never excluded `tag-index.md` itself, and every documented tag's own entry in
  that file matched the search, making the "confirm zero vault-wide use" check
  meaningless for every tag. Now excludes only `tag-index.md` (not all of `.obsidian/`,
  so genuine uses elsewhere in `.obsidian/` still protect a tag from removal).

## [0.3.2]

### Changed
- **wiki-tags-refresh** now scans the whole vault by default (excludes `.obsidian/`)
  instead of just `wiki/`; accepts an optional `[directory]` argument to scope the scan.
- `VAULT_PATH` and `AGENTS.md`/README documentation: `VAULT` is now also accepted as an
  alias for `VAULT_PATH` (fallback pattern `${VAULT_PATH:-${VAULT:-${HOME}/obsidian_vault}}`),
  honored consistently across `wiki-init`, `wiki-tags-refresh`, and the SessionStart/Stop hooks.

### Fixed
- **wiki-tags-refresh inline-tag collection returned nothing**: the pipeline piped
  `grep -oh` output (which always starts with `#`) through `grep -v "^#"`, discarding
  every match. Removed the dead filter.
- **wiki-tags-refresh frontmatter scan broke on filenames with spaces**: `find | xargs awk`
  word-split paths; switched to `find -print0 | xargs -0 awk`.

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
