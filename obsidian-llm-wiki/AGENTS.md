# obsidian-llm-wiki — GitHub Copilot Instructions

LLM Wiki pattern for an active Obsidian vault. Compiles knowledge from meetings,
projects, daily notes, and raw sources into a persistent, cross-referenced wiki at
`wiki/`. Supports both Claude Code (slash commands) and GitHub Copilot
(natural language prefixes). Wiki sessions from both agents accumulate into the same
wiki — switching between them mid-project is seamless.

---

## Vault Path

Default vault: `~/obsidian_vault` (Linux/Mac). WSL users with vault on Windows side must set
`VAULT_PATH=/mnt/c/Users/<name>/obsidian_vault`. Override with the `VAULT_PATH` env var.

All file paths in skill instructions are relative to the vault root unless they start
with `skills/` (which are relative to this plugin's installation directory).

---

## Hot Cache — Automatic via Hooks

`wiki/hot.md` is managed automatically by plugin hooks:
- **SessionStart / PostCompact** — hot.md is read silently and injected as context
- **Stop** — the agent is prompted to update hot.md before ending the session

No manual steps needed. Both Copilot and Claude Code handle this identically via hooks.
To force a hot cache refresh mid-session, run `wiki-hot:`.

---

## Wiki Schema

Before any wiki operation, read `skills/wiki-schema/SKILL.md` for the full vault
conventions: three-layer source model, page types, frontmatter schemas, tag rules,
cross-linking rules, and file formats.

---

## Natural Language Prefixes

All commands are invoked as natural language prefixes. Use the exact prefix to trigger
the correct workflow.

| Prefix | Skill | Description |
|--------|-------|-------------|
| `wiki-ingest: @filepath` | wiki-ingest | Ingest one source file into the wiki |
| `wiki-scan: [directory]` | wiki-scan | Scan directory for unprocessed files, batch-ingest new/changed |
| `wiki-query: <question>` | wiki-query | Answer from the compiled wiki with citations |
| `wiki-save:` | wiki-save | Save current conversation as a wiki page |
| `wiki-lint:` | wiki-lint | Run wiki health check, produce lint report |
| `wiki-hot:` | wiki-hot | Manually refresh the hot cache |
| `wiki-tags-refresh:` | wiki-tags-refresh | Sync wiki tags with vault's tag-index.md |
| `wiki-init:` | wiki-init | Initialize or re-initialize vault integration (first run or after plugin update) |

When the user types any of these prefixes, read the corresponding skill file fully
before executing. Skill files are at `skills/<skill-name>/SKILL.md` relative to the
plugin installation directory.

---

## Command Equivalence

Every natural language prefix has an identical Claude Code slash command. Both produce
the same output and operate on the same wiki files. There is no behavioural difference between the two agents.

| Copilot prefix | Claude Code slash command |
|----------------|--------------------------|
| `wiki-ingest:` | `/wiki-ingest` |
| `wiki-scan:` | `/wiki-scan` |
| `wiki-query:` | `/wiki-query` |
| `wiki-save:` | `/wiki-save` |
| `wiki-lint:` | `/wiki-lint` |
| `wiki-hot:` | `/wiki-hot` |
| `wiki-tags-refresh:` | `/wiki-tags-refresh` |
| `wiki-init:` | `/wiki-init` |

---

## Boundary Rules

Wiki operations MUST NEVER write to or delete files from:
`Meetings/`, `Daily/`, `Projects/`, `Customers/`, `People/`, `Clippings/`, `Research/`

The wiki layer reads these directories. It never modifies them.

The only directory wiki may clean up is `.raw/` — by moving processed files to
`.raw/_processed/YYYY-MM/` after successful ingest.

The existing task system (`task:` / `/task`, `tags-refresh`) is completely separate.
Wiki operations do not create tasks, do not touch `Tasks.md`, and do not modify project
files in `Projects/Products/`.

---

## Tags

Only use tags from `.obsidian/copilot/tag-index.md`. Never invent new tags. If a
concept needs a tag that does not exist, flag it with `tag-needed: <proposed>` in the
log entry and let the user approve it via `wiki-tags-refresh:`.
