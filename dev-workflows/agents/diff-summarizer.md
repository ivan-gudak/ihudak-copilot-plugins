---
name: diff-summarizer
description: "Sub-agent for use case A (impl:jira:docs:). Given a local git clone path and one or more Bitbucket/GitHub PR identifiers, resolves each PR against local refs using four strategies (PR ref, branch search, merge-commit search, issue-key grep), produces a prose diff summary per PR, and returns an aggregate per-repo summary. All resolution is pure local git — no HTTPS calls, no Bitbucket REST API, no gh CLI. Invoked in parallel by impl:jira: (Phase 5)."
tools: [view, grep, glob, bash]
---

# `diff-summarizer` — PR Diff Summary Sub-Agent

Invoked by the `impl:jira:` orchestrator at Phase 5 (use case A only).
One instance per repository; all repos are launched in parallel in a single orchestrator response.

> **No external API calls.** PR URLs are identifiers only. All resolution uses
> `git` on the locally-cloned repo at `repo_path`. The only network hop is
> the `git fetch` / `git pull` against the configured (SSH) remote during the prep step.

---

## Input

The orchestrator passes this block verbatim:

```yaml
repo_path: <absolute path to the locally-cloned repo — e.g. /workspace/cluster-repo,
            /repos/cluster, ~/projects/cluster. Must contain a .git directory or
            be a bare clone. The orchestrator resolves repo URL slug → local path
            in Phase 4; this agent does NOT search the filesystem.>
repo_url_slug: <the URL slug from the PR URL (e.g. "cluster" for
                bitbucket.../repos/cluster/...). Used only for cross-checking
                that repo_path's `git remote get-url origin` matches the slug —
                if it does not, return status: REPO_MISSING with a clear reason.>
pr_refs:
  - url:                 <full Bitbucket/GitHub PR URL — identifier only, never fetched>
    pr_id:               <numeric id as string>
    issue_keys:          [<jira keys from the link title, e.g. ["MGD-1127"]>]
    title_hint:          <link text from markdown>
    status:              MERGED | OPEN | DECLINED | UNKNOWN
    branch_hint:         <optional — source branch name from the export, used
                          by Strategy 0; omit if not provided>
    target_branch_hint:  <optional — target branch name from the export>
context: |
  <2–4 sentences: what Jira context this repo's PRs relate to>
refresh:
  fetch: true     # default true
  pull:  false    # default false
model_routing:
  classification: SIGNIFICANT | MODERATE
  # ... rest of block from orchestrator
```

---

## Process

### Step 1 — Validate repo

Check that `repo_path` exists and contains a `.git` directory (or is a bare clone).
- If not → return `status: REPO_MISSING` immediately.

If `repo_url_slug` was provided, additionally verify that the resolved repo
matches the expected upstream:

```bash
git -C <repo_path> remote get-url origin 2>/dev/null
```

The last path segment of the URL (with any trailing `.git` stripped) MUST equal
`repo_url_slug`. If it does not, return `status: REPO_MISSING` with reason:
`"repo at <repo_path> has remote slug '<actual>'; expected '<repo_url_slug>'"`.
The orchestrator chose this path; do not silently summarise the wrong repo.

### Step 2 — Prep step

1. Run `git -C <repo_path> status --porcelain`.
   - If output is non-empty AND `refresh.fetch` or `refresh.pull` is `true` → return `status: DIRTY_TREE`. The orchestrator will escalate.
   - If output is non-empty AND both are `false` → proceed (user opted out of refresh; dirty tree noted in `prep.refresh_note`).

2. If `refresh.fetch`:
   - Run `timeout 60 git -C <repo_path> fetch --all --prune`.
   - On non-zero exit (auth error, network issue, RO mount, or timeout) → return
     `status: REFRESH_BLOCKED` with the error in `prep.refresh_note`. If the exit
     code is 124 (GNU `timeout` SIGTERM), report
     `prep.refresh_note: "git fetch timed out after 60s"`.

3. If `refresh.pull`:
   - Detect default branch: `git -C <repo_path> symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`; fallback to `main`, then `master`.
   - Run `git -C <repo_path> checkout <default>` and
     `timeout 60 git -C <repo_path> pull --ff-only`.
   - On failure or timeout → return `status: REFRESH_BLOCKED` with reason.

Record `prep.fetched`, `prep.pulled`, `prep.refresh_note`.

### Step 3 — Resolve each PR (local git only)

For each entry in `pr_refs`, try strategies in order:

**Strategy 0 — Branch-hint fast path (when provided)**

If `branch_hint` is present:

```bash
git -C <repo_path> rev-parse "refs/heads/<branch_hint>" 2>/dev/null \
  || git -C <repo_path> rev-parse "refs/remotes/origin/<branch_hint>" 2>/dev/null
```

If exactly one of these resolves to a SHA:
- `head = <resolved sha>`
- If `target_branch_hint` is present and resolves, use it as the merge base via
  `git merge-base <target_branch_hint> <head>`. Otherwise fall back to the
  default branch.
- Record `resolved_via: branch_hint`

If neither ref resolves, fall through to Strategy 1.

**Strategy 1 — Bitbucket Server pull-request refs**

```bash
git -C <repo_path> rev-parse refs/pull-requests/<pr_id>/from 2>/dev/null
```

If the ref exists:
- `head = refs/pull-requests/<pr_id>/from`
- `base = git merge-base <default-branch> <head>`
- Record `resolved_via: pr_ref`

**Strategy 2 — Branch search by issue key**

For each key in `issue_keys`:
```bash
git -C <repo_path> branch -a --list "*<KEY>*" 2>/dev/null
```

If exactly one branch matches → use as `head`, `base = git merge-base <default-branch> <head>`.
If multiple branches match → skip (ambiguous); try next key.
Record `resolved_via: branch_search`.

**Strategy 3 — Merge-commit search by PR ID or title keyword**

```bash
git -C <repo_path> log --all --oneline --grep="pull[- ]request[- ]<pr_id>" -n 5 2>/dev/null
git -C <repo_path> log --all --oneline --grep="<title_keyword>" -n 5 2>/dev/null
```

(Use first 2–3 distinctive words from `title_hint` as `title_keyword`.)

For each candidate commit, check if it is a merge commit (has `^2`):
```bash
git -C <repo_path> rev-parse <sha>^2 2>/dev/null
```

If yes: `head = <sha>^2`, `base = <sha>^1`.
Record `resolved_via: merge_commit`.

**Strategy 4 — Last resort: commits referencing the issue key**

```bash
git -C <repo_path> log --all --oneline --grep="<issue_key>" -n 10 2>/dev/null
```

Do NOT auto-pick. Record all candidate SHAs under `unresolved_prs[].candidates`.
Record `resolved_via: unresolved` with `reason: "Strategy 4 — candidates listed; needs manual selection"`.

### Step 4 — Diff each resolved PR

For each PR with `resolved_via != unresolved`:

```bash
git -C <repo_path> log --oneline <base>..<head>
git -C <repo_path> diff --stat <base>..<head>
```

Cap: 200 files. If the diff stat exceeds 200 files, record only the file list and stats; skip the body for the long tail; note `diff_truncated: true`.

Read the actual diff body for each file changed (up to the cap). Use `git diff <base>..<head> -- <file>` per file if needed.

Count `files_changed`, `insertions`, `deletions` from `git diff --stat`.

### Step 5 — Write per-PR prose summary

For each resolved PR, write a prose summary (3–8 sentences) covering:
- What changed (subsystems, patterns, refactors)
- Which modules/packages are affected
- Any notable patterns (e.g. new abstractions, removed legacy code, test coverage changes)
- Any obvious risks or regressions

### Step 6 — Aggregate repo summary

Write 1–2 paragraphs summarising this repo's contribution to the feature:
- Common themes across PRs
- Overall direction of the changes

---

## Output

Return the structured handoff (see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/diff-summarizer/references/handoff.md` for the exact schema).

---

## Path reference

This skill is installed at:
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/diff-summarizer/`

Handoff schema: `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/diff-summarizer/references/handoff.md`
