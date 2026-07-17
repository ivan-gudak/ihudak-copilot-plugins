# ihudak-copilot-plugins

Ivan Gudak's private GitHub Copilot plugin marketplace.

## Plugins

| Plugin | Description |
|--------|-------------|
| [dev-workflows](dev-workflows/) | Twenty keyword-triggered skills for the PM → PA → PE → Dev workflow — idea refinement, VI / ARD authoring, VI updates, Epic drafting, specification and engineering-design authoring, structured implementation, feature documentation, release notes, vulnerability remediation, dependency upgrades, and API / UI guideline compliance — with strong-tier (Opus 4.8/4.7/4.6 or GPT-5.5) planning, code review, and doc / Epic / design review gates. |
| [dt-style-guide](dt-style-guide/) | Dynatrace corporate style guide enforcement: `/dt-review-pr`, `/dt-review-docs`, `/dt-style-refresh`, and sub-agents used by `dev-workflows` for style checking Epics and feature docs |
| [obsidian-llm-wiki](obsidian-llm-wiki/) | Eleven slash-command skills for compiling Obsidian vault knowledge into a persistent, cross-referenced wiki with task management; supports GitHub Copilot and Claude Code |

## Prerequisites

- **GitHub Copilot CLI** — the plugins install into `copilot` (some `obsidian-llm-wiki` skills also support Claude Code).
- **[`jira-workitem-import`](https://github.com/ivan-gudak/jira-workitem-import)** *(required for Jira-driven skills)* — imports Jira tickets into `$VAULT_PATH/jira-products/<KEY>/` in the exact structure the plugins expect. Every Jira-driven skill (`idea:` from an RFE, `create-vi:`, `update-vi:`, `epics:`, `specify:`, `design:`, `implement:`, `document:`, `release-notes:`, `ready:`) consumes this tree.
- **`gh` + `gh auth login`** *(recommended)* — enables reading GitHub PR diffs (`document:`, `release-notes:`); without it those skills fall back to local-git strategies.
- **`vale`** *(optional)* — a prose linter for docs; `dev-workflows` falls back to a repo lint script, then the `dt-style-guide` plugin, when `vale` is absent.
- **Recommended environment: [`ihudak/ai-containers`](https://github.com/ihudak/ai-containers)** — mounts every repository and your Obsidian vault under one `/workspace` umbrella (repos at `/workspace/<repo>`, vault at `/workspace/obsidian`), so the default `$REPOS_PATH` (`/workspace`) and an exported `VAULT_PATH` just work; it also installs `gh` and mounts the host `gh` auth. Outside a container the commands still work — set `$REPOS_PATH` yourself and manage `gh` login.

> `dev-workflows` has no hard dependency on any of these — every relationship above is convention + runtime-resolve + graceful fallback (see [`dev-workflows/skills/_shared/dependencies.md`](dev-workflows/skills/_shared/dependencies.md)).

## Installation

### 1. Add this marketplace to GitHub Copilot (once)

```bash
copilot plugin marketplace add ihudak/ihudak-copilot-plugins
```

### 2. Install plugins

```bash
copilot plugin install dev-workflows@ihudak-copilot-plugins
copilot plugin install dt-style-guide@ihudak-copilot-plugins
copilot plugin install obsidian-llm-wiki@ihudak-copilot-plugins
```

### 3. Configure environment variables

`dev-workflows` resolves its inputs and outputs through three environment variables. Export them in your shell profile (or rely on the AI-Containers defaults):

```bash
export VAULT_PATH="$HOME/obsidian"     # personal store: Jira imports + idea/project files
export SPECS_PATH="/workspace/specs"   # shared store: specifications, designs, ARDs
export REPOS_PATH="/workspace"         # where your code clones live (default: /workspace)
```

- **`VAULT_PATH`** — your personal store. Holds `jira-products/<KEY>/` (produced by `jira-workitem-import`) and `Projects/<area>/<slug>/` (idea and project files).
- **`SPECS_PATH`** — the shared, team-visible store for a ticket's `specification.md` / `design.md` / ARD under `specifications/<KEY>-<slug>/…`. Required by the specs-authoring skills (`create-vi:`, `create-ard:`, `specify:`, `design:`, `ready:`); advisory for `implement:`; additive for `document:`.
- **`REPOS_PATH`** — where code clones live; a single directory or a colon-separated list. Defaults to `/workspace`. Repos are matched by their `git remote get-url origin` slug, not by directory name.

### 4. Update after new releases

```bash
copilot plugin update --all
```

## Runtime directories

The three environment variables expect these layouts:

```
$VAULT_PATH/                      # personal store (e.g. an Obsidian vault)
  jira-products/<KEY>/            # Jira hierarchy from jira-workitem-import (input; regenerated each import)
  Projects/<area>/<slug>/         # idea.md and project working files

$SPECS_PATH/                      # shared, team-visible store
  specifications/<KEY>-<slug>/    # specification.md, design.md, ARD (+ per-Epic subfolders)

$REPOS_PATH/                      # code clones (default /workspace)
  <repo>/                         # matched by git remote slug, not directory name
```

## Repository structure

```
ihudak-copilot-plugins/
├── dev-workflows/
│   ├── .plugin/plugin.json
│   ├── README.md
│   ├── agents/               ← 30 sub-agents, dispatched via task(agent_type: "dev-workflows:<name>")
│   └── skills/
│       ├── implement/
│       ├── document/
│       ├── vuln/
│       ├── upgrade/
│       ├── _shared/          ← model-routing.md + other cross-skill reference docs
│       └── <15 more lifecycle/utility skills>
├── dt-style-guide/
│   ├── .plugin/plugin.json
│   ├── README.md
│   ├── references/          ← vendored Dynatrace style guide rules
│   └── skills/
│       ├── dt-style-checker/
│       ├── dt-doc-fixer/
│       ├── dt-review-pr/
│       ├── dt-review-docs/
│       ├── dt-style-refresh/
│       └── dt-style-rules/
├── obsidian-llm-wiki/
│   ├── .plugin/plugin.json
│   ├── README.md
│   └── skills/
│       ├── wiki-ingest/
│       ├── wiki-scan/
│       ├── wiki-query/
│       └── <other wiki skills>
└── .github/
    ├── copilot-instructions.md
    └── plugin/marketplace.json
```

## License

MIT — see [LICENSE](LICENSE).
