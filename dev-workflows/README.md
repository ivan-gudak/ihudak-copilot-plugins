# dev-workflows

A GitHub Copilot plugin providing structured development workflow skills for implementing features, remediating vulnerabilities, and upgrading dependencies.

## Installation

```
copilot plugin install dev-workflows@ihudak-copilot-plugins
```

## Skills

### Orchestrator skills (invoke via slash-command)

| Trigger | Skill | Description |
|---------|-------|-------------|
| `/impl` | impl-dispatcher | Help / dispatcher for the impl family. Prints the command matrix and stops — does not run any workflow. Use `/impl:code` for the code-implementation workflow. |
| `/impl:code` | impl | Implement a feature or fix from a spec. Creates a feature branch, captures a test baseline, runs risk-weighted planning (Opus critique for complex tasks), implements, runs Opus code-review (SIGNIFICANT/HIGH-RISK), writes tests for changed behaviour via `test-writer`, verifies no regressions, and runs post-impl maintenance. |
| `/impl:docs` | impl-docs | Implement documentation-only changes (Markdown, READMEs, wikis, Obsidian vault, etc.). Lightweight: no branch by default, no tests, no code-review. Redirects to `/impl:code` if source code changes are detected. |
| `/impl:jira:docs` / `/impl:jira:epics` / `/impl:jira` | impl-jira | Jira-driven documentation workflow. Reads Jira work-item exports from an Obsidian vault, resolves Bitbucket PR URLs as local-git identifiers (no HTTPS/API calls), runs parallel diff-summarizers (use case A — feature docs) or code-scanners (use case B — Epic writing), synthesises output with mandatory inline citations, gates on doc-reviewer, and runs impl-maintenance. |
| `/fix-vuln` | fix-vuln | Remediate one or more CVEs. Researches each CVE via NVD, applies the minimal safe version bump, verifies tests, applies Opus code-review, runs post-batch maintenance. Each CVE gets its own branch and PR. |
| `/upgrade` | upgrade | Upgrade one or more dependencies to a target version. Creates an upgrade branch, captures test baseline, plans compatibility per-component, upgrades and verifies in sequence, applies Opus code-review, runs post-batch maintenance. |
| `/api-guideline-reviewer` | api-guideline-reviewer | Review OpenAPI specification files against Dynatrace REST API and IAM permission naming guidelines. Validates compliance with Dynatrace API standards and IAM scope naming. |
| `/guideline-reviewer` | guideline-reviewer | Review code and UI for compliance with Dynatrace Experience Standards (GUIDElines). Checks component usage, accessibility/WCAG compliance, terminology, and settings implementations. |

> The legacy colon-prefix form (e.g. `impl:code: <description>`) is still accepted for
> backward compatibility, but slash-commands are the preferred trigger.

### Sub-agents (dispatched by orchestrators via the `task` tool)

Each sub-agent lives in `agents/<name>.md` and is dispatched with
`task(agent_type: "dev-workflows:<name>", ...)`. The agent runs in its own
context window and inherits the orchestrator's model unless an explicit
`model:` override is passed.

| Agent | Role |
|-------|------|
| risk-planner | Risk-weighted planner for SIGNIFICANT/HIGH-RISK tasks. Returns a structured plan with explicit risks section. Pinned to Opus by the orchestrator. |
| code-review | Post-implementation Opus review (SIGNIFICANT/HIGH-RISK gate). Returns per-item verdicts against the 8-dimension checklist in `_shared/model-routing.md`. |
| test-baseliner | Captures test baseline before a change; compares after; returns regression report. Used by `/impl:code`, `upgrade-executor`, and `vuln-fixer`. |
| test-writer | Writes or updates tests for newly added or changed code behaviour. Used by `/impl:code` (Phase 3.7). |
| review-fixer | Receives Opus code-review output; applies BLOCKER and MAJOR locally-actionable findings in one cycle. |
| impl-maintenance | Post-implementation maintenance: updates knowledge base, copilot-instructions, and project docs. |
| upgrade-planner | Plans a single component upgrade: resolves target version, checks compatibility. |
| upgrade-executor | Executes a single planned upgrade: applies change, builds, verifies tests, auto-fixes test breakage. |
| vuln-research | Read-only CVE research: NVD lookup, library detection, minimum safe version resolution. |
| vuln-fixer | Applies a CVE fix: captures baseline, bumps version, rebuilds, verifies tests, commits, opens PR. |
| jira-reader | Read-only: parses `$VAULT_PATH/jira-products/<KEY>/` Jira exports. Used by `/impl:jira` (Phase 3). |
| diff-summarizer | Use case A: resolves each PR against local git refs and produces prose diff summaries. Used by `/impl:jira:docs` (Phase 5, parallel). |
| code-scanner | Use case B: scans the filesystem to classify each capability theme as present/partial/absent. Used by `/impl:jira:epics` (Phase 5, parallel). |
| doc-reviewer | Comprehensive review of changed documentation: links, headings, wikilinks, style, completeness. Used by `/impl:docs` (Phase 3.5) and `/impl:jira` (Phase 7). |
| doc-fixer | Applies targeted fixes for BLOCKER and MAJOR findings from doc-reviewer, epic-reviewer, docs-style-checker, or dt-style-checker. |
| doc-location-finder | Use case A: identifies write-target file paths in the docs repo before writing begins. Used by `/impl:jira:docs` (Phase 5.6). |
| doc-planner | Use case A: synthesises Jira + diffs into a documentation checklist. Used by `/impl:jira:docs` (Phase 5.7). |
| docs-style-checker | Wraps the docs repo's project-configured prose linter (Vale, markdownlint, remark). Falls back to `dt-style-guide:dt-style-checker` when no repo linter is configured. |
| epic-reviewer | Reviews Epic drafts for goal clarity, acceptance-criteria testability, scope boundaries, and non-duplication. Pinned to Opus. Used by `/impl:jira:epics` (Phase 7). |

### Shared reference

`skills/_shared/model-routing.md` is the single source of truth for complexity classification, model routing policy (default → Opus thresholds), and the 8-dimension Opus review checklist. All orchestrators read it at runtime. Sub-agents receive the routing block in their prompt and reference the file via absolute path.

Sub-agent handoff schemas live in `skills/<name>/references/handoff.md` (the `skills/<name>/` directories are kept for those reference files even though the SKILL.md was promoted to `agents/<name>.md`).

## Model routing

| Complexity | Model |
|------------|-------|
| SIMPLE | Default session model |
| MODERATE | Default session model (with structured planning) |
| SIGNIFICANT / HIGH-RISK | `claude-opus-4.8` (forced via `model:` override) |

## Feature highlights

- **Branch-per-change**: `/impl:code` and `/upgrade` create a feature branch before touching code; `/fix-vuln` creates one per CVE. `/impl:docs` works on the current branch by default. `/impl:jira` branches when run from a git repo (opt-in at plan approval); never branches in an Obsidian vault.
- **Jira-driven docs**: `/impl:jira:docs` and `/impl:jira:epics` read Obsidian vault Jira exports, resolve PR URLs as pure local-git identifiers (no Bitbucket REST API), run parallel diff-summarizers or code-scanners per repo, and produce documentation with mandatory inline Jira + PR citations.
- **Style checking**: `/impl:jira:docs` runs the repo's own linter via `docs-style-checker`; if unconfigured, falls back to `dt-style-checker` (from the optional `dt-style-guide` plugin). `/impl:jira:epics` uses `dt-style-checker` directly for vault content. Both gracefully degrade if `dt-style-guide` is not installed.
- **Test-writing gate**: `/impl:code` writes tests for all new/changed behaviour via `test-writer` (Phase 3.7) and verifies no regressions against a pre-impl baseline (Phase 3.8). No test framework? The workflow asks — it never silently skips.
- **Opus code-review gate**: every code workflow runs an Opus review before committing for SIGNIFICANT/HIGH-RISK tasks; `review-fixer` sub-agent auto-applies fixable findings
- **Post-batch maintenance**: after all workflows, `impl-maintenance` updates the project knowledge base, `copilot-instructions.md`, and docs
- **Stateless sub-agents**: all sub-agents receive full context in their prompt — no hidden state between calls

## License

[MIT](LICENSE)
