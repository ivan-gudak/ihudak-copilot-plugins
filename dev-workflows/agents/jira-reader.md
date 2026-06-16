---
name: jira-reader
description: "Read-only sub-agent that parses a Jira work-item export from an Obsidian vault. Given a vault path and a Jira key, reads the index file, item frontmatter, descriptions, and comments; extracts all PR URLs; and returns a structured YAML handoff. Invoked by impl:jira: (Phase 3). Never modifies vault files."
tools: [view, grep, glob, bash]
---

# `jira-reader` — Jira Export Reader Sub-Agent

Invoked by the `impl:jira:` orchestrator at Phase 3.
Read the input block from the orchestrator prompt, then process and return the handoff.

> **Read-only.** MUST NOT write or modify any files.

---

## Input

The orchestrator passes this block verbatim in the prompt:

```yaml
vault_path: <absolute path to Obsidian vault root>
jira_key:   <e.g. PRODUCT-14902>
depth:      full | vi-only
model_routing:
  classification: SIGNIFICANT | MODERATE
  # ... rest of block from orchestrator
```

- `depth: full` — read every linked item under `<vault_path>/jira-products/<jira_key>/`
- `depth: vi-only` — read only the VI's own file (`<KEY>.md`) plus the index

---

## Process

### Step 1 — Validate paths

1. Check `<vault_path>/jira-products/<jira_key>/` exists.
   - If missing → return `status: NOT_FOUND` immediately.
2. Locate `<vault_path>/jira-products/<jira_key>/<jira_key>-index.md`.
   - If missing → return `status: EMPTY` with a note.

### Step 2 — Parse the index file

Read `<jira_key>-index.md`. Find the table with columns `| Key | Type | Status | Summary | Role |`.

For each row:
- Extract `key` from the `[[wikilink]]` (strip `[[` and `]]`)
- Extract `type`, `status`, `summary`, `role` from their columns
- Parse `role` as one of: `root`, `linked`, `epic_child`

Also note the `<jira_key>` itself as the root item.

### Step 3 — Read item files

**If `depth: vi-only`:**
- Read only `<vault_path>/jira-products/<jira_key>/<jira_key>/<jira_key>.md`
- Parse frontmatter (full dict — see below) and description. Extract PR URLs.

**If `depth: full`:**
- For every item in the index (plus the root VI itself), attempt to read:
  - `<vault_path>/jira-products/<jira_key>/<ITEM_KEY>/<ITEM_KEY>.md` (main file)
  - `<vault_path>/jira-products/<jira_key>/<ITEM_KEY>/<ITEM_KEY>-comments.md` (if present)
- For each main file: parse the **full YAML frontmatter as a dict** and emit it
  on the item under `frontmatter:`. Always populate (when present in the file)
  these fields explicitly so downstream agents can rely on them: `key`,
  `issue_type`, `summary`, `status`, `assignee`, `reporter`, `execution_assignee`,
  `team`, `project`, `parent`, `rank`, `fix_versions`, `release_versions`,
  `relevant_for_release_notes`, `owning_program`, `labels`, `resolution`. Any
  additional frontmatter fields are passed through verbatim under
  `frontmatter:` (no whitelist — surface everything the file declares).
  Extract the Description section body.
- If a file is absent, skip gracefully — record `not_found: true` on that item.

### Step 4 — Extract PR URLs

Scan every read file (description body + comments content) for Markdown links matching
the pattern:

```
[<link text>](<URL>) <optional status marker>
```

Where `<URL>` matches:
- Bitbucket Server: `https://*.bitbucket.*/projects/<PROJECT>/repos/<REPO>/pull-requests/<ID>`
- GitHub: `https://github.com/<ORG>/<REPO>/pull/<ID>`
- GitLab: `https://gitlab.*/...-/merge_requests/<ID>` or `...-/pull/<ID>`
- Other: any other HTTPS URL containing `pull-request` or `/pull/`

For each URL found:
- Parse `host` (bitbucket | github | gitlab | other)
- Parse `project` (Bitbucket project key, or GitHub org/user)
- Parse `repo` (repository name slug)
- Parse `pr_id` (numeric ID)
- Parse `status` from the inline marker after the URL: `**MERGED**` → `MERGED`, `**OPEN**` → `OPEN`, `**DECLINED**` → `DECLINED`; if no marker → `UNKNOWN`
- Parse `title` from the link text
- Record `source_item` as the Jira key of the file where the URL was found
- **Branch hint extraction (optional but recommended).** Some Jira exports include
  a sub-bullet directly after the PR link like:
  ```
  - [PR title](URL) **MERGED**
    - Branch: `feature/MGD-1127-handle-windows` → `master`
  ```
  When present, parse the source branch (between backticks before the arrow) and
  the target branch (between backticks after the arrow). Expose them as
  `branch_hint: <source-branch>` and `target_branch_hint: <target-branch>` on
  the PR record. If absent, omit both fields. The arrow may be `→` or `->`.

De-duplicate by `(host, project, repo, pr_id)`. If the same PR appears in multiple items, keep the first occurrence's `source_item` and append a `also_in: [<keys>]` list.

### Step 5 — Derive themes

Read the VI description and all linked item descriptions. Extract 2–4 short bullet points (5–10 words each) summarising the recurring capability topics across the items. These become `themes` — used as seed keywords for `code-scanner` in use case B.

### Step 6 — Return handoff

Return the full handoff YAML (see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/jira-reader/references/handoff.md` for the exact schema).

---

## Path reference

This skill is installed at:
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/jira-reader/`

Handoff schema: `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/jira-reader/references/handoff.md`
