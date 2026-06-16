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

- **Source-code is the truth, but discrepancies escalate to YOU** (`_shared/source-truth.md`, v1.8.0+): every sub-agent that writes or reviews user-visible docs (`doc-planner`, `doc-reviewer`, `code-scanner`, `epic-reviewer`) verifies enum/option lists, UI labels, defaults, counts, and mode names against the actual source code. When source and Jira description **agree**, the docs cite the verified source. When they **disagree**, the plugin presents an analysis table and asks you per-discrepancy: document as source / document as Jira (with an intentional-discrepancy marker + bug-report draft) / skip and report. The plugin is the analyst; you are the decision-maker. Bug-report drafts land alongside the release-notes draft in your Obsidian vault project folder so you can file defects against the implementation team.
- **Mandatory style checking with fallback** (v1.7.0+): every docs workflow (`/impl:docs`, `/impl:jira:docs`, `/impl:jira:epics`) runs a style-check phase that cannot be skipped. If Vale (or the repo's configured linter) is unavailable, `docs-style-checker` falls back to `dt-style-checker` from the `dt-style-guide` plugin. Some check is always better than no check.
- **Branch-per-change** with shared **branch-prefix detection** (`_shared/branch-naming.md`): every branch-creating workflow resolves the prefix via `$GIT_USER_INITIALS` → `git config user.initials` → `git branch -a` sniff → workflow fallback. Teams with `<initials>/`-prefix conventions set the env var or git config once and every workflow follows it automatically.
- **Branch-per-change**: `/impl:code` and `/upgrade` create a feature branch before touching code; `/fix-vuln` creates one per CVE. `/impl:docs` works on the current branch by default. `/impl:jira` branches when run from a git repo (opt-in at plan approval); never branches in an Obsidian vault.
- **Jira-driven docs**: `/impl:jira:docs` and `/impl:jira:epics` read Obsidian vault Jira exports, resolve PR URLs as pure local-git identifiers (no Bitbucket REST API), run parallel diff-summarizers or code-scanners per repo, and produce documentation with mandatory inline Jira + PR citations.
- **Repo discovery via `$REPOS_PATH`**: `/impl:jira:*` resolves repo URL slugs (e.g. `cluster` from `bitbucket.../repos/cluster/...`) to local clone paths by scanning `$REPOS_PATH` (default `/workspace`; colon-separated list supported) and matching `git remote get-url origin`. When multiple local clones share an upstream (e.g. `cluster` + `cluster-repo`), the auto-preferred order is `<slug>-repo` > `<slug>_repo` > `<slug>_fast` > alphabetically last. The user can override at plan approval.
- **Release-notes draft (use case A)**: `/impl:jira:docs` detects when a VI is release-notes-worthy (`relevant_for_release_notes: Yes` or non-empty `release_versions` in the VI frontmatter) and produces a separate release-notes draft — rendered in the dynatrace-docs `{{#context}}` / `{{#internal-note}}` block format — at a configurable destination. Default destination is the Obsidian project tracking folder under `<vault>/Projects/Products/**/<JIRA_KEY>*`; the same folder is also used for **persistent screenshot staging** (under a `Doc screenshots/` subfolder) when `image_policy: cdn_upload_required` is detected. Alternatives are custom path, stdout, or skip. The draft is **never** written into the docs repo, because that path is owned by Jira-driven automation; the user pastes the draft into Jira and existing automation re-emits it into the docs repo. **Never uses `/tmp/`** for any staged artifact — container restarts would wipe staged screenshots before they can be CDN-uploaded.
- **Style checking**: `/impl:jira:docs` runs the repo's own linter via `docs-style-checker`; if unconfigured, falls back to `dt-style-checker` (from the optional `dt-style-guide` plugin). `/impl:jira:epics` uses `dt-style-checker` directly for vault content. Both gracefully degrade if `dt-style-guide` is not installed.
- **Test-writing gate**: `/impl:code` writes tests for all new/changed behaviour via `test-writer` (Phase 3.7) and verifies no regressions against a pre-impl baseline (Phase 3.8). No test framework? The workflow asks — it never silently skips.
- **Opus code-review gate**: every code workflow runs an Opus review before committing for SIGNIFICANT/HIGH-RISK tasks; `review-fixer` sub-agent auto-applies fixable findings
- **Post-batch maintenance**: after all workflows, `impl-maintenance` updates the project knowledge base, `copilot-instructions.md`, and docs
- **Stateless sub-agents**: all sub-agents receive full context in their prompt — no hidden state between calls
- **Jira-ticket detection in `/impl:docs`**: when called as `/impl:docs @<file>` and the file is a Jira-export markdown (frontmatter `key:` + `[[wikilink]]`s + `## Linked Issues` heading), the skill offers to re-route to `/impl:jira:docs` for proper multi-ticket aggregation and PR analysis.

## License

[MIT](LICENSE)
