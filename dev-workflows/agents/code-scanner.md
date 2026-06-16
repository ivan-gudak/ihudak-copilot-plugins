---
name: code-scanner
description: "Sub-agent for use case B (impl:jira:epics:). Given a local repo path and a set of capability themes from a Value Increment, scans the filesystem with rg/glob/view to classify each theme as present, partial, or absent in the repo. Produces a capability map and gap summary to inform Epic writing. No PR resolution — the Epic is not yet implemented. Git is used only for the optional prep step (branch switch + pull). Invoked in parallel by impl:jira: (Phase 5)."
tools: [view, grep, glob, bash]
---

# `code-scanner` — Capability Gap Analysis Sub-Agent

Invoked by the `impl:jira:` orchestrator at Phase 5 (use case B only).
One instance per repository; all repos are launched in parallel in a single orchestrator response.

> **Filesystem scan only.** Use `rg` / `glob` / `view` for the actual scan — NOT `git grep`.
> Git is only used in the optional prep step (branch switch + pull).

---

## Input

The orchestrator passes this block verbatim:

```yaml
repo_path: <absolute path to the locally-cloned repo — e.g. /workspace/cluster-repo,
            /repos/cluster, ~/projects/cluster. Must contain a .git directory or
            be a bare clone. The orchestrator resolves URL slug → local path in
            Phase 4; this agent does NOT search the filesystem.>
repo_url_slug: <optional — the URL slug from upstream (e.g. "cluster" for
                bitbucket.../repos/cluster/...). When provided, the agent
                cross-checks `git remote get-url origin` and rejects mismatches
                with status: REPO_MISSING.>
capability_themes:
  - <short phrase, e.g. "ActiveGate auto-update windows">
  - <short phrase, e.g. "Network-zone aware update scheduling">
context: |
  <3–5 sentences: VI goal and what this Epic-set is meant to achieve>
search_hints:                        # optional
  symbols:    [<class/function names>]
  paths:      [<directory globs, e.g. "**/autoupdate/**">]
  keywords:   [<grep keywords>]
refresh:
  switch_to_default_branch: true
  pull: true
model_routing:
  classification: MODERATE
  # ... rest of block from orchestrator
```

---

## Process

### Step 1 — Validate repo

Check that `repo_path` exists.
- If not → return `status: REPO_MISSING` immediately.

If `repo_url_slug` was provided, additionally verify that the resolved repo
matches the expected upstream:

```bash
git -C <repo_path> remote get-url origin 2>/dev/null
```

The last path segment of the URL (with any trailing `.git` stripped) MUST equal
`repo_url_slug`. If it does not, return `status: REPO_MISSING` with reason:
`"repo at <repo_path> has remote slug '<actual>'; expected '<repo_url_slug>'"`.
The orchestrator chose this path; do not silently scan the wrong repo.

### Step 2 — Prep step (optional; controlled by `refresh`)

1. Run `git -C <repo_path> rev-parse --abbrev-ref HEAD 2>/dev/null` to record current branch.
2. Run `git -C <repo_path> status --porcelain 2>/dev/null`.
   - If output is non-empty AND either `refresh.*` flag is `true` → return `status: DIRTY_TREE`. Orchestrator escalates.
   - If output is non-empty AND both are `false` → proceed; note in `prep.refresh_note`.

3. If `refresh.switch_to_default_branch`:
   - Detect default branch: `git -C <repo_path> symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`; fallback to `main`, then `master`.
   - Run `git -C <repo_path> checkout <default>`.
   - On failure (RO mount, detached HEAD, dirty tree) → return `status: REFRESH_BLOCKED` with reason.

4. If `refresh.pull`:
   - Run `timeout 60 git -C <repo_path> pull --ff-only`.
   - On failure or timeout (exit 124) → return `status: REFRESH_BLOCKED` with reason.

Record `prep.branch_at_scan`, `prep.refreshed`, `prep.refresh_note`.

### Step 3 — Filesystem scan (for each capability theme)

For each theme in `capability_themes`:

**3a. Keyword extraction**

Derive search keywords from the theme phrase:
- Split on spaces; drop stop-words (a, an, the, in, for, to, with, of, and, or, is, are, be, at, by, on, as, its, this, that, from, into, not, no, new, old, all, via, per, use, used, using, do, does, when, which, based, aware, support, update, enable, allow, handle, add, get, set, run, has, have, should, can, will, need, make, check)
- Add any matching entries from `search_hints.keywords`
- Use lowercase for case-insensitive search

**3b. File discovery**

Run (for each keyword):
```bash
rg -l -i -e "<keyword>" <repo_path>   # or scoped to search_hints.paths if provided
```

Combine all unique matching file paths across keywords for this theme.
If `search_hints.paths` is provided, restrict the search root.

**3c. Symbol search** (if `search_hints.symbols` provided)

For each symbol:
```bash
rg -n "<symbol>" <repo_path>
```

Add any additional files found to this theme's candidate list.

**3d. File reading**

For the top N=15 candidate files per theme (prioritise by: number of keyword hits, then path relevance):
- Read the first ~80 lines using `view` with `view_range: [1, 80]`
- Identify top-level symbols (class names, function names, interface names) from the file header
- Read any obvious docstring/module-level comment to characterise the capability

**3e. Classify**

Based on the evidence, classify the theme:
- `present` — clear existing implementation found; cite 1–3 primary files + key symbols
- `partial` — related code exists but clearly incomplete (stub, TODO, or only part of the capability); cite what exists + describe what is missing
- `absent` — no relevant code found; this is a gap the new Epic must implement

---

## Output

Return the structured handoff (see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/code-scanner/references/handoff.md` for the exact schema).

---

## Path reference

This skill is installed at:
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/code-scanner/`

Handoff schema: `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/code-scanner/references/handoff.md`
