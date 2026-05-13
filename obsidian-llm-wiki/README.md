# obsidian-llm-wiki

LLM Wiki pattern for an active Obsidian vault. Compiles knowledge from meetings,
projects, daily notes, and raw sources into a persistent, cross-referenced wiki at
`wiki/`. Works with GitHub Copilot and Claude Code via unified `/wiki-*` slash commands.

## Installation

```
copilot plugin install obsidian-llm-wiki@ihudak-copilot-plugins
```

## Prerequisites

- Obsidian vault — default `~/obsidian_vault`; set `VAULT_PATH` env var to override
  (WSL users with Windows-side vault: `export VAULT_PATH=/mnt/c/Users/<name>/obsidian_vault`)
- `.raw/` directory in your vault root:
  ```bash
  cd /path/to/your/vault
  mkdir .raw && touch .raw/.gitkeep
  ```

## Usage — Slash Commands

| Command | Description |
|---------|-------------|
| `/wiki-init` | Initialize or re-initialize vault integration for the wiki |
| `/wiki-ingest @filepath` | Ingest one source file into the wiki |
| `/wiki-scan [directory]` | Scan directory for unprocessed files; batch-ingest new/changed |
| `/wiki-query <question>` | Answer from the compiled wiki with citations |
| `/wiki-save` | Save current conversation as a wiki page |
| `/wiki-lint` | Run wiki health check, produce lint report |
| `/wiki-hot` | Manually refresh the hot cache |
| `/wiki-tags-refresh` | Sync wiki tags with `.obsidian/copilot/tag-index.md` |
| `/wiki-task <description>` | Create a single task from natural language |
| `/wiki-tasks-extract [wiki-path]` | Extract tasks from wiki knowledge base |

## Skills

| Skill | Trigger |
|-------|---------|
| wiki-init | `/wiki-init` |
| wiki-ingest | `/wiki-ingest` |
| wiki-scan | `/wiki-scan` |
| wiki-query | `/wiki-query` |
| wiki-save | `/wiki-save` |
| wiki-lint | `/wiki-lint` |
| wiki-hot | `/wiki-hot` |
| wiki-tags-refresh | `/wiki-tags-refresh` |
| wiki-task | `/wiki-task` |
| wiki-tasks-extract | `/wiki-tasks-extract` |
| wiki-schema | Loaded automatically before every wiki operation |

## Boundary Rules

Wiki operations never write to: `Meetings/`, `Daily/`, `Customers/`,
`People/`, `Clippings/`, `Research/`. All wiki output goes to `wiki/`.
Exception: `/wiki-task` and `/wiki-tasks-extract` write to `Projects/` and `Tasks.md`.

## Claude Code (sister plugin)

The same wiki skills are also available as Claude Code slash commands in the
[ihudak-claude-plugins](https://github.com/ihudak/ihudak-claude-plugins/tree/main/plugins/obsidian-llm-wiki)
marketplace (a separate repository). Both agents write to the same `wiki/`
directory — switching between Copilot and Claude mid-session is seamless.

## License

MIT
