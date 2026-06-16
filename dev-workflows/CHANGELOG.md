# Changelog

All notable changes to the **dev-workflows** plugin are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow semver at the plugin level.

## [1.5.0] — 2026-06-15

### Added
- **`impl:jira:docs:` — release-notes draft output.** When the VI's frontmatter
  has `relevant_for_release_notes: "Yes"` or a non-empty `release_versions`
  string, the workflow now generates a release-notes draft alongside the
  feature documentation page. The draft is written to a configurable
  destination (auto-discovered Obsidian project folder by default, custom
  path, stdout, or skip — chosen via Phase 1 Q6) — **never** into the
  dynatrace-docs repo, because that path is owned by Jira-driven automation.
  The draft is rendered in the dynatrace-docs `{{#context}}` /
  `{{#internal-note}}` block format so the user can paste it into Jira and
  the existing automation re-emits it into the docs repo.
- **`doc-planner` — `release_notes_block` output field.** New top-level
  output that captures one entry per declared release version with the
  rendered template, citation source list, and assignee/reporter/PE/status
  populated from `value_increment.frontmatter`. `target_format:
  dynatrace-docs-release-notes-v1` lets consumers detect the schema.
- **`jira-reader` — full frontmatter exposure.** `value_increment` and every
  `linked_items[]` entry now carry a `frontmatter:` sub-object containing
  the file's full raw frontmatter. Always-surfaced fields:
  `assignee`, `reporter`, `execution_assignee`, `team`, `project`,
  `fix_versions`, `release_versions`, `relevant_for_release_notes`,
  `owning_program`, `labels`, `resolution`. Any additional fields the file
  declares are passed through verbatim. Existing schema fields unchanged
  (additive only).
- **`jira-reader` — branch-hint extraction.** Scans the `Pull Requests`
  section of each Jira-export file for sub-bullets like
  `- Branch: \`feature/MGD-1127-...\` → \`master\``. When present, exposes
  `branch_hint` and `target_branch_hint` on the matching
  `pull_requests[]` entry.
- **`diff-summarizer` — Strategy 0 branch-hint resolution.** When
  `branch_hint` is present on a PR ref, attempts
  `git rev-parse refs/heads/<hint>` (and `origin/<hint>`) before falling
  through to existing Strategies 1–4. Records `resolved_via: branch_hint`
  on hits.
- **`impl-docs` — Jira-ticket detection.** When `impl:docs: @<file>` loads
  a file with frontmatter `key: <JIRA_KEY>` plus `[[wikilink]]` references
  and a `## Linked Issues` / `## Pull Requests` heading, the skill offers
  to re-route to `impl:jira:docs:` instead of running the lightweight prose
  workflow.
- **`impl-jira` Phase 9 — image-upload reminder.** Final report now lists
  every screenshot staged outside the docs repo (where
  `image_policy: cdn_upload_required`), so the user knows what needs
  manual CDN upload before merging the docs PR.

### Changed (breaking for orchestrators that hardcode `/repos/`)
- **`impl-jira` repo discovery — `$REPOS_PATH`-based.** The hardcoded
  `/repos/<repo>/` path lookup in Phase 4 is replaced with a configurable
  scan rooted at `$REPOS_PATH` (default `/workspace`; colon-separated list
  supported). For each in-scope PR repo URL slug, the orchestrator scans
  candidate directories under `$REPOS_PATH`, runs
  `git remote get-url origin` (5s timeout per dir), and matches by the
  upstream URL's last path segment. When multiple local clones share an
  upstream (e.g. `cluster` + `cluster-repo`), the auto-preferred order is:
  `<slug>-repo` > `<slug>_repo` > `<slug>_fast` > alphabetically last.
  Sub-agents (`diff-summarizer`, `code-scanner`) now receive an absolute
  `repo_path` plus a `repo_url_slug` and reject mismatches via
  `git remote get-url origin` cross-check.
- **Phase 1 Q3 / Q4 wording.** Code-scan and refresh-policy questions now
  refer to `$REPOS_PATH` instead of `/repos/`.
- **Phase 5 error escalation.** `DIRTY_TREE` / `REFRESH_BLOCKED` prompts
  now report the resolved `repo_path` instead of a synthetic `/repos/...`
  string.
- **`doc-planner` topic-list semantics.** "What's new" remains a valid
  topic on a normal documentation target, but the **standalone release
  notes draft is no longer one of the targets** — it is emitted via the
  top-level `release_notes_block` field instead. New hard rule forbids
  proposing release-notes snippet paths as `target_path`.
- **`doc-location-finder` exclusions.** New hard rule: never propose a
  release-notes / what's-new snippet directory as a target (e.g.
  `_snippets/release-notes/`, `_content/whats-new/<product>/sprint-*`).
  Even high keyword-overlap matches in those paths are skipped, because
  the docs repo's release-notes pages are produced by Jira-driven
  automation and a manual write would be overwritten.

### Fixed
- **`diff-summarizer` and `code-scanner` — git fetch/pull timeouts.**
  `git fetch --all --prune` and `git pull --ff-only` are now wrapped in
  `timeout 60`; on timeout, the agent returns `REFRESH_BLOCKED` with the
  reason `"git fetch timed out after 60s"` instead of hanging the workflow.

### Migration notes
- If you have local automation that invokes `diff-summarizer` or
  `code-scanner` directly (outside the orchestrator), update the input
  block: `repo_path` is now an absolute path (any path is acceptable, not
  only `/repos/<name>`), and a new optional `repo_url_slug` enables the
  upstream cross-check.
- If you previously customised the `impl-jira` Phase 4 to point at
  `/repos/`, set `REPOS_PATH=/repos` in your environment to preserve the
  old behaviour.

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
