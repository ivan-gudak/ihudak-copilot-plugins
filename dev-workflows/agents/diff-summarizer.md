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
repo_path: /repos/<repo-name>
pr_refs:
  - url:         <full Bitbucket/GitHub PR URL — identifier only, never fetched>
    pr_id:       <numeric id as string>
    issue_keys:  [<jira keys from the link title, e.g. ["MGD-1127"]>]
    title_hint:  <link text from markdown>
    status:      MERGED | OPEN | DECLINED | UNKNOWN
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

### Step 2 — Prep step

1. Run `git -C <repo_path> status --porcelain`.
   - If output is non-empty AND `refresh.fetch` or `refresh.pull` is `true` → return `status: DIRTY_TREE`. The orchestrator will escalate.
   - If output is non-empty AND both are `false` → proceed (user opted out of refresh; dirty tree noted in `prep.refresh_note`).

2. If `refresh.fetch`:
   - Run `git -C <repo_path> fetch --all --prune`.
   - On failure (auth error, network issue, RO mount) → return `status: REFRESH_BLOCKED` with the error in `prep.refresh_note`.

3. If `refresh.pull`:
   - Detect default branch: `git -C <repo_path> symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`; fallback to `main`, then `master`.
   - Run `git -C <repo_path> checkout <default>` and `git -C <repo_path> pull --ff-only`.
   - On failure → return `status: REFRESH_BLOCKED` with reason.

Record `prep.fetched`, `prep.pulled`, `prep.refresh_note`.

### Step 3 — Resolve each PR (local git only)

For each entry in `pr_refs`, try strategies in order:

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
