---
name: impl-jira
description: >
  Jira-driven documentation workflow orchestrator. Activated when the user's prompt starts
  with "impl:jira:", "impl:jira:docs:", or "impl:jira:epics:". Reads Jira work-item exports
  from an Obsidian vault, resolves Bitbucket/GitHub PR URLs as local-git identifiers (no HTTPS
  calls), runs parallel diff-summarizers (use case A — feature docs) or code-scanners
  (use case B — epic writing), synthesises documentation with inline Jira + PR citations,
  gates on doc-reviewer, and runs impl-maintenance. All PR resolution is pure local git
  on analysis-only clones under `$REPOS_PATH` (default `/workspace`).
allowed-tools: view, edit, create, bash, glob, grep, ask_user, sql
---

# `impl:jira:` — Jira-Driven Documentation Workflow

Activated when the user prompt starts with `impl:jira:`, `impl:jira:docs:`, or `impl:jira:epics:`.

> **No external API calls, ever.** PR URLs from Jira exports are identifiers only.
> Do NOT use `gh`, `curl`, Bitbucket REST API, or any HTTPS fetch against Bitbucket.
> All PR resolution is via local `git` on pre-cloned repos under `$REPOS_PATH`
> (default `/workspace`; override via the `REPOS_PATH` environment variable —
> may be a colon-separated list of directories).

> **Model routing is mandatory.** Load
> `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`
> before any planning.

---

## Phase 0 — Load & Dispatch

### Step 0.1 — Subcommand dispatch

Determine which use case applies:

| Prompt prefix              | Use case                          |
|----------------------------|-----------------------------------|
| `impl:jira:docs: <desc>`   | **A** — feature documentation     |
| `impl:jira:epics: <desc>`  | **B** — child epic writing         |
| `impl:jira: <desc>`        | unknown — ask (Step 0.2)          |

If `impl:jira: @<file.md>` — read the file using `view`, treat its content as the description.

### Step 0.2 — Ask if use case is ambiguous

If the prompt was bare `impl:jira:` (no `docs:` or `epics:` suffix):

```
ask_user(
  question: "Which Jira workflow should I run?",
  choices: [
    "impl:jira:docs: — Write feature documentation from existing Jira items + merged PRs",
    "impl:jira:epics: — Write child Epic definitions for a new Value Increment",
    "Other… (describe)"
  ]
)
```

### Step 0.3 — Extract `JIRA_KEY`

Parse `<JIRA_KEY>` from the description (e.g. `PRODUCT-14902`, `MGD-789`).
Pattern: `[A-Z][A-Z0-9]+-\d+`.
If multiple keys found, ask the user which is the root VI key.

### Step 0.4 — Resolve `$VAULT_PATH`

1. Check the `VAULT_PATH` environment variable: `bash -c 'echo "$VAULT_PATH"'`.
2. If set and the directory exists → use it.
3. If set but the directory does not exist, or if unset:

```
ask_user(
  question: "Where is your Obsidian vault? (VAULT_PATH is unset or invalid)",
  choices: [
    "Use /obsidian (Recommended)",
    "Enter the path manually",
    "Cancel",
    "Other… (describe)"
  ]
)
```

4. Validate that `<VAULT_PATH>/jira-products/<JIRA_KEY>/` exists.
   - If it does not:

```
ask_user(
  question: "Jira export directory not found: <VAULT_PATH>/jira-products/<JIRA_KEY>/. How would you like to proceed?",
  choices: [
    "Re-enter the Jira key",
    "Cancel",
    "Other… (describe)"
  ]
)
```

---

## Phase 0.5 — Classify & Route

Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`.

**Classify based on actual scope** — do NOT bind classification to use case alone:

- **SIGNIFICANT** — use case A with multiple repos, many PRs, or large synthesis blast radius. Rubber-duck plan critique required at Phase 2.
- **MODERATE** — use case B (epic writing, single VI, no PR resolution), or use case A with a single repo / few PRs.
- When in doubt, escalate one level.

Record the `model_routing` block (format from `_shared/model-routing.md` §4).

---

## Phase 1 — Clarification

Use `ask_user` with `choices` for each question. The **last choice** in every question MUST be `"Other… (describe)"`.

### Detect cwd context (do this before asking)

Run the branch/write policy detection algorithm (§7 of the spec):

```bash
# Walk up from cwd looking for .obsidian/
dir="$(pwd)"
context=""
while [ "$dir" != "/" ]; do
  [ -d "$dir/.obsidian" ] && { context=obsidian; vault_root="$dir"; break; }
  dir="$(dirname "$dir")"
done

# Check git if not obsidian
if [ -z "$context" ]; then
  git rev-parse --show-toplevel >/dev/null 2>&1 \
    && context=git_repo \
    || context=plain_dir
fi

echo "context=$context"
[ -n "$vault_root" ] && echo "vault_root=$vault_root"
[ "$context" = "git_repo" ] && echo "git_root=$(git rev-parse --show-toplevel)"
```

Display to the user:
- Resolved absolute cwd
- Detected context (`obsidian` / `git_repo` / `plain_dir`)
- Whether branching + commit will happen

### Clarification questions

**Q1 — Output path** (show default first):

Use case A default: `<cwd>/<JIRA_KEY>-<slug>.md`
Use case B default: `<cwd>/<JIRA_KEY>/` directory with one file per Epic

```
ask_user(
  question: "Output file path (resolved: <resolved_default_path>). Accept or override?",
  choices: [
    "Use default: <resolved_default_path> (Recommended)",
    "Enter a custom sub-path under cwd",
    "Other… (describe)"
  ]
)
```

If the output file already exists:
```
ask_user(
  question: "Output file <path> already exists. How would you like to proceed?",
  choices: [
    "Overwrite",
    "Write to <path-v2>.md (new file with -v2 suffix)",
    "Cancel",
    "Other… (describe)"
  ]
)
```

**Q2 — PR status filter** (use case A only):

```
ask_user(
  question: "Which PRs should be included in the documentation?",
  choices: [
    "MERGED only (Recommended)",
    "All statuses (MERGED, OPEN, DECLINED)",
    "Specify a list manually",
    "Other… (describe)"
  ]
)
```

**Q3 — Code examination** (use case B only):

```
ask_user(
  question: "Should I scan existing code under $REPOS_PATH (default /workspace) to identify reusable components and gaps?",
  choices: [
    "Yes — scan code (Recommended)",
    "No — write epics from Jira context only",
    "Other… (describe)"
  ]
)
```

If code scan ON:

```
ask_user(
  question: "Which repos under $REPOS_PATH should I scan?",
  choices: [
    "<repo1 derived from sibling epic refs if available> (Recommended)",
    "List repos manually",
    "Other… (describe)"
  ]
)
```

**Q4 — Repo refresh policy**:

Use case A default: `fetch only`. Use case B default: `fetch + pull default branch`.

```
ask_user(
  question: "How should I refresh the local repo clones under $REPOS_PATH?",
  choices: [
    "Fetch only — update remote refs, don't change branches (Recommended for docs)",
    "Fetch + pull default branch — ensure latest code",
    "No refresh — use current local state",
    "Other… (describe)"
  ]
)
```

**Q5 — Branching decision** (only if cwd context is `git_repo`):

```
ask_user(
  question: "Detected context: git repo at <git_root>. Should I create a branch and commit the output?",
  choices: [
    "Yes — create branch docs/<JIRA_KEY>-<slug> and commit (Recommended)",
    "No — write files only, no git ops",
    "Other… (describe)"
  ]
)
```

**Q6 — Release-notes destination + screenshot staging** (use case A only; ask
if any of the following are true on `value_increment.frontmatter`:
`relevant_for_release_notes == "Yes"` OR `release_versions` is a non-empty
string, OR if `screenshots` is non-empty):

The release notes draft is **separate** from the doc page(s). It is NOT
written into the docs repo (`/workspace/dynatrace-docs/` or wherever) — that
path is owned by Jira-driven automation, and writing there manually risks
being overwritten. The default destination is the matching project tracking
folder in the Obsidian vault.

**Auto-discover** the project folder by globbing
`<vault>/Projects/Products/**/<JIRA_KEY>*` and picking the first match. If
multiple, list them and pick the alphabetically-first. The discovered folder
is used for BOTH the release-notes file AND the screenshot staging directory
(if `image_policy: cdn_upload_required` is detected later by `doc-planner`).
Screenshots go into a `Doc screenshots/` subfolder of the project dir.

```
ask_user(
  question: "Where should the release-notes draft + any staged screenshots go? (Default: write release notes to <auto-discovered path>/<JIRA_KEY>-release-notes.md and stage screenshots in <auto-discovered path>/Doc screenshots/ — both persistent, so Jira-paste and CDN-upload work after container restart.)",
  choices: [
    "Use default: <auto-discovered path>/ (Recommended)",
    "Specify a custom absolute directory for both",
    "Output release notes to screen only; stage screenshots in default dir",
    "Skip release notes entirely (screenshots still need a destination)",
    "Other… (describe)"
  ]
)
```

If the default could not be auto-discovered (no matching dir), drop the first
choice and add a note: "no `<JIRA_KEY>*` folder found under
`<vault>/Projects/Products/`".

Record the choices as `release_notes_destination` and `screenshot_staging_dir`:
- `release_notes_destination`: `"file:<absolute path>"` / `"stdout"` / `"skip"`
- `screenshot_staging_dir`: `<absolute path>` (always set — even if release notes
  are skipped, screenshots still need somewhere persistent to land). Default is
  `<auto-discovered path>/Doc screenshots/`. **NEVER `/tmp/`** — container
  restarts wipe it and the work is lost.

---

## Phase 2 — Plan + Approval

Produce a written plan containing:

1. **Use case** (A: feature docs / B: epics)
2. **Jira key** and VI summary
3. **Vault path** and export directory
4. **PRs in scope** (use case A): list of `(url, repo, pr_id, status)`
5. **Repos to process**: for each in-scope repo URL slug, list its resolved
   absolute `repo_path` under `$REPOS_PATH` and whether it was uniquely
   resolved or has multiple candidates (with the auto-preferred one marked).
6. **Output file(s)**: resolved absolute path(s)
7. **Detected context**: `obsidian` / `git_repo` / `plain_dir`; whether branch will be created
8. **Parallelism plan**: N diff-summarizer or code-scanner instances to be launched
9. **Model routing block**

If classification is SIGNIFICANT: run a `risk-planner` sub-agent critique at this point
(use `task` with `agent_type: "dev-workflows:risk-planner"`, `model: claude-opus-4.8` per model-routing.md).
Address every BLOCKER. Document CONCERNs in the plan. Then show the revised plan.

Request approval:

```
ask_user(
  question: "Plan ready. What would you like to do?",
  choices: [
    "Approve & proceed (Recommended)",
    "Revise plan",
    "Cancel",
    "Other… (describe)"
  ]
)
```

---

## Phase 3 — Read Jira Hierarchy

Invoke `jira-reader` sub-agent via `task`:

- `agent_type: "dev-workflows:jira-reader"`
- Prompt: pass the input block:

```yaml
vault_path: <resolved>
jira_key:   <JIRA_KEY>
depth:      full           # use case A
            vi-only        # use case B
model_routing: <block>
```

The agent loads its own handoff schema; see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/jira-reader/references/handoff.md` for reference.

If `jira-reader` returns `status: NOT_FOUND` or `EMPTY` → escalate to user (ask to re-enter key or cancel).

Filter `pull_requests` list by the user's PR status selection from Phase 1.

---

## Phase 4 — Resolve & Validate Repos

The orchestrator translates each unique repo URL slug from the in-scope PR list
(use case A) or user-selected repo list (use case B) into an **absolute local
clone path** before invoking sub-agents. Sub-agents do NOT search the
filesystem — they only operate on `repo_path` arguments the orchestrator gives
them.

### Step 4.1 — Determine the repos search base

```bash
echo "${REPOS_PATH:-/workspace}"
```

The default base is `/workspace`. Override via the `REPOS_PATH` environment
variable when repos live elsewhere. `REPOS_PATH` may be a single directory
or a colon-separated list (e.g. `/workspace:/repos:/home/me/projects`).

### Step 4.2 — Build the URL-slug → local-path map

For each candidate top-level directory under each entry of `REPOS_PATH`:

```bash
# Per candidate dir
timeout 5 git -C "<dir>" remote get-url origin 2>/dev/null
```

Strip any trailing `.git` from the URL and take the last path segment — that is
the candidate's URL slug. Build a multimap: `<slug> → [<absolute path>, ...]`.

Skip directories without a `.git` folder. Skip directories whose `git remote`
call fails or times out (5s ceiling).

### Step 4.3 — Resolve each in-scope repo slug

For each unique `<slug>` from `pull_requests[].repo` (use case A) or the
user-selected repo list (use case B):

1. Look up `<slug>` in the multimap from Step 4.2.
2. **Zero matches** — fall through to escalation (Step 4.4).
3. **One match** — use it directly.
4. **Multiple matches** (e.g. both `cluster` and `cluster-repo` exist for the
   same upstream) — apply the preference order:
   - Prefer the path whose basename ends in `-repo` over a bare-slug basename
     (the user's convention is that `<slug>-repo` is a fast/native-volume copy).
   - Then prefer the path whose basename ends in `_repo` or `_fast`.
   - Then choose the alphabetically-last basename (deterministic tie-break).
   Display **all** candidates in the plan and let the user override at Phase 2.

### Step 4.4 — Escalation prompts

If a slug resolved to **zero** local paths:

```
ask_user(
  question: "No local clone of repo '<slug>' was found under <REPOS_PATH>. How would you like to proceed?",
  choices: [
    "Skip this repo and continue without its PRs",
    "I'll clone it now — wait for me",
    "Cancel the run",
    "Specify a different absolute path for this repo",
    "Other… (describe)"
  ]
)
```

If a slug resolved to **multiple** paths and the user asked to choose:

```
ask_user(
  question: "Multiple clones of '<slug>' found:\n<numbered list>\nWhich one should I use?",
  choices: [
    "<auto-preferred path> (Recommended)",
    "<alternative path>",
    "Cancel the run",
    "Other… (describe)"
  ]
)
```

### Step 4.5 — Record the resolution

Record the final list as: `repo_slug → resolved_path → status` and pass each
`resolved_path` (absolute) along with the `repo_slug` to the corresponding
`diff-summarizer` invocation in Phase 5 (`repo_path` and `repo_url_slug`
fields). The sub-agent cross-checks the upstream URL against the slug and
returns `REPO_MISSING` on mismatch.

Note: the actual `git fetch`/`pull`/branch-switch happens **inside** the sub-agents (Phase 5), not here.
Failures surface as `DIRTY_TREE` / `REFRESH_BLOCKED` statuses that this orchestrator escalates.

---

## Phase 5 — Code Analysis (Parallel)

Launch all sub-agent instances in a **single response** (multiple `task()` calls).

### Use case A — diff-summarizer per repo

For each validated repo with at least one in-scope PR, launch one `diff-summarizer` task:

- `agent_type: "dev-workflows:diff-summarizer"`
- Pass the input block:

```yaml
repo_path:     <absolute path resolved in Phase 4 — e.g. /workspace/cluster-repo>
repo_url_slug: <the URL slug — e.g. "cluster">
pr_refs:
  - url:                <url>
    pr_id:              <id>
    issue_keys:         [<keys>]
    title_hint:         <title>
    status:             <status>
    branch_hint:        <optional, from jira-reader.pull_requests[].branch_hint>
    target_branch_hint: <optional, from jira-reader.pull_requests[].target_branch_hint>
context: |
  <2–4 sentences from jira-reader.value_increment.goal + linked_items context>
refresh:
  fetch: <true if "fetch only" or "fetch+pull"; false if "no refresh">
  pull:  <true if "fetch+pull"; false otherwise>
model_routing: <block>
```

### Use case B — code-scanner per repo (if code scan ON)

For each user-selected repo, launch one `code-scanner` task:

- `agent_type: "dev-workflows:code-scanner"`
- Pass input block:

```yaml
repo_path:     <absolute path resolved in Phase 4 — e.g. /workspace/cluster-repo>
repo_url_slug: <the URL slug — e.g. "cluster">
capability_themes: <list from jira-reader.themes>
context: |
  <3–5 sentences from jira-reader.value_increment.goal + Epic context>
search_hints:                    # optional; derive from VI/Epic text if useful
  symbols:  <derived class/function names hinted by VI description, if any>
  paths:    <directory globs hinted by VI text, if any>
  keywords: <extra grep terms beyond capability_themes, if any>
refresh:
  switch_to_default_branch: <true if "fetch+pull default branch"; false if "fetch only" or "no refresh">
  pull: <true if "fetch+pull default branch"; false otherwise>
model_routing: <block>
```

### Handle sub-agent errors

After all sub-agents complete, check each handoff `status`:

- `REPO_MISSING` → impossible (resolved in Phase 4); log and continue
- `DIRTY_TREE`:

```
ask_user(
  question: "The repo at <repo_path> has uncommitted changes and could not be refreshed. How would you like to proceed?",
  choices: [
    "Continue with current local state",
    "Skip this repo",
    "Cancel",
    "Other… (describe)"
  ]
)
```

- `REFRESH_BLOCKED`:

```
ask_user(
  question: "git fetch/pull failed for <repo_path>: <reason>. How would you like to proceed?",
  choices: [
    "Continue with current local state",
    "Skip this repo",
    "Cancel",
    "Other… (describe)"
  ]
)
```

- Use case A, `unresolved_prs` is non-empty for a PR:

```
ask_user(
  question: "PR #<pr_id> (<url>) could not be resolved. Candidates: <candidate SHAs>. How would you like to proceed?",
  choices: [
    "Show candidate commits and let me pick one",
    "Skip this PR",
    "Skip this repo entirely",
    "Cancel",
    "Other… (describe)"
  ]
)
```

---

## Phase 5.5 — Branch Setup (git_repo context only)

Only execute this phase if:
- `context = git_repo` AND
- User confirmed branching at Phase 1 Q5 AND
- This phase has not already been completed

**Clean-tree check:**

```bash
git -C <docs_repo_root> status --porcelain
```

(Use `git -C <repo>` form explicitly — cwd may not be the docs repo, and the
branch must be created in the docs repo, not the orchestrator's cwd.)

If dirty → ask user (same pattern as `impl/SKILL.md` Phase 2.5).

**Detect branch prefix** — follow the algorithm in
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/branch-naming.md`:
1. `$GIT_USER_INITIALS` env var
2. `git -C <docs_repo_root> config --get user.initials`
3. Sniff `git -C <docs_repo_root> --no-pager branch -a` for the dominant
   `<2-8-char-prefix>/<rest>` pattern (≥ 30 % share AND ≥ 3 occurrences)
4. Workflow fallback for `impl:jira:`: `docs/`. If detection falls through
   to this step, run the user-override prompt per §1.5 of `_shared/branch-naming.md`.

**Generate slug:**

Derive from `<JIRA_KEY>` + first 4–6 content words of the VI summary: lowercase, hyphens, max 40 chars, strip stop-words. Example: `PRODUCT-14902-ag-update-windows`.

**Create branch:**

```bash
git -C <docs_repo_root> checkout -b <prefix>/<JIRA_KEY>-<slug>
```

If name exists → append 7-char short SHA: `<prefix>/<JIRA_KEY>-<slug>-<short-sha>`.
Announce: `"Created branch in <docs_repo_root>: <prefix>/<JIRA_KEY>-<slug>"`

---

## Phase 5.6 — Locate Write Targets (use case A only)

Skip this phase for use case B (Epics always write to `<cwd>/<JIRA_KEY>/<slug>.md`).

Invoke `doc-location-finder` sub-agent:

- `agent_type: "dev-workflows:doc-location-finder"`
- Pass input block:

```yaml
repo_root:       <absolute path to the docs repo root — typically the dynatrace-docs
                  clone, e.g. /workspace/dynatrace-docs. Do NOT use cwd's git root
                  here; the orchestrator's cwd may be a different repo entirely
                  (a marketplace repo, a code repo, etc.). Resolve and pass an
                  explicit absolute path.>
feature_summary: <2–4 sentences combining jira-reader themes + value_increment.goal>
diff_highlights:  <key filenames / symbols from the diff-summarizer per_pr summaries>
```

Handle the return:

- **`status: OK`** with a populated `targets` list:
  ```
  ask_user(
    question: "Doc-location-finder proposed these write targets:\n<formatted list>\nHow would you like to proceed?",
    choices: ["Accept all proposed locations (Recommended)", "Adjust individual locations (you'll be prompted per item)", "Cancel"]
  )
  ```
- **`status: LOW_CONFIDENCE`** — display `confidence_notes` alongside targets:
  ```
  ask_user(
    question: "Doc-location-finder proposed targets with low confidence:\n<formatted list + notes>\nHow would you like to proceed?",
    choices: ["Adjust individual locations (Recommended)", "Accept all proposed locations", "Cancel"]
  )
  ```
- **`status: EMPTY`** — skip the accept/adjust flow:
  ```
  ask_user(
    question: "Doc-location-finder could not determine write targets. How would you like to proceed?",
    choices: ["Specify locations manually (you'll be prompted)", "Cancel"]
  )
  ```
  The manual path takes a free-text entry per target (`path` + `kind` + `section`) and validates path existence for `extend-existing` targets.

The confirmed target list is the **authoritative write-target set** for Phase 6 and is passed to `doc-planner` in Phase 5.7.

---

## Phase 5.7 — Plan Documentation (use case A only)

Skip this phase for use case B.

Invoke `doc-planner` sub-agent:

- `agent_type: "dev-workflows:doc-planner"`
- Pass input block:

```yaml
jira_reader_handoff: <paste full YAML from Phase 3>
diff_summaries:       <paste array of diff-summarizer outputs from Phase 5>
write_targets:        <paste confirmed list from Phase 5.6>
screenshots:          <user-provided paths from Phase 1, possibly empty>
screenshot_staging_dir: <from Phase 1 Q6 — typically <vault-project-folder>/Doc screenshots/.
                        NEVER /tmp/ — container restarts wipe it.>
code_repos:           <added v1.7.0 — array of {slug, path} for every code repo
                       used by diff-summarizer in Phase 5. doc-planner uses
                       these to verify every user-visible claim (option
                       names, mode names, UI labels, default values, counts)
                       against the actual source — enums, schema JSON,
                       constants, data-source classes. See
                       ~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/source-truth.md.
                       Format: [{slug: "cluster", path: "/workspace/cluster-repo"}, ...]>
repo_root:            <absolute path to the docs repo root — typically /workspace/dynatrace-docs;
                       do NOT use cwd's git root here, cwd may be a different repo>
```

Handle the `status` and `gaps`:

- **`status: OK`, `gaps: []`** → proceed to the approval prompt.
- **`status: OK` or `PARTIAL` with `gaps` entries** — for each gap, act on its `recommended_action`:
  - `"ask user"` → prompt inline **before** showing the checklist-approval choice. Feed answer back to planner via re-invocation (pass as `gap_resolution` field). If user declines, fall back to `"mark TODO in draft"`.
  - `"mark TODO in draft"` → surface as visible TODO; Phase 6 writer emits `<!-- TODO: … -->`. Does not block approval.
  - `"skip with note in final report"` → list in checklist display; carry forward into Phase 9 `### Skipped items`. Does not block approval.
- **`status: PARTIAL`** alone (without user-asked gaps) is presented alongside the checklist for informed approval.

Present the checklist (with any gaps + dispositions):
```
ask_user(
  question: "Documentation checklist ready:\n<formatted checklist>\nHow would you like to proceed?",
  choices: ["Approve & write (Recommended)", "Adjust (describe)", "Cancel"]
)
```

---

## Phase 5.8 — Discrepancy analysis & user decision (added v1.8.0)

> **Hard rule (per `_shared/source-truth.md` §7):** the plugin is the analyst,
> the user is the decision-maker. When source verification (Phase 5.7
> doc-planner) finds discrepancies between the Jira description and the
> shipped source, the orchestrator MUST surface every discrepancy to the
> user and let the user pick per-discrepancy how to proceed. **Never
> silently pick a winner.**

Skip this phase if doc-planner's `verification_warnings[]` is empty OR
contains only entries with `finding: VERIFIED`.

### Step 5.8.1 — Present the analysis table

Build a Markdown table from doc-planner's `verification_warnings[]` entries
where `finding` is `CONTRADICTED`, `NOT_FOUND`, or `AMBIGUOUS`:

```
| # | Claim | Jira phrasing | Source phrasing | Source location | Verdict |
|---|-------|---------------|-----------------|-----------------|---------|
| 1 | <claim 1> | <jira_phrasing> | <source_phrasing> | <file:line> | CONTRADICTED |
| 2 | <claim 2> | <jira_phrasing> | (not found) | <searched locations> | NOT_FOUND |
```

Display the table to the user as informational context BEFORE the first
ask_user prompt.

### Step 5.8.2 — Ask for the batch decision

```
ask_user(
  question: "<N> discrepancies between the Jira description and the source code were found (see table above). How would you like to handle them?",
  choices: [
    "Decide per discrepancy (Recommended)",
    "Apply 'document as source suggests' to ALL — match what shipped",
    "Apply 'document as Jira claims' to ALL — describe what was promised; orchestrator will draft a bug report for the team",
    "Apply 'skip and report' to ALL — omit these claims; orchestrator will draft a bug report",
    "Cancel"
  ]
)
```

### Step 5.8.3 — Per-discrepancy decisions (if user chose "Decide per discrepancy")

For each row in the table, in order, run:

```
ask_user(
  question: "Discrepancy #<n>: <claim>\n  - Jira: <jira_phrasing>\n  - Source: <source_phrasing>\n  - Source location: <file:line>\n  - Verdict: <finding>\n\nHow would you like to handle this one?",
  choices: [
    "Document as source suggests — match what shipped; users see what's there",
    "Document as Jira claims — describe the promised behaviour; will add a TODO marker in the docs + a bug-report draft entry so you can file a defect against the team",
    "Skip this claim entirely and report it — the docs omit this paragraph; the bug-report draft records the gap",
    "Cancel the whole run"
  ]
)
```

### Step 5.8.4 — Record the decisions

Build a `discrepancy_decisions[]` record (one entry per discrepancy):

```yaml
discrepancy_decisions:
  - number:           <from the table>
    claim:            <copied from verification_warnings>
    jira_phrasing:    <copied>
    source_phrasing:  <copied>
    source_location:  <copied>
    finding:          <CONTRADICTED | NOT_FOUND | AMBIGUOUS>
    decision:         <"document-as-source" | "document-as-jira" | "skip-and-report">
```

Pass this record to Phase 6 (writer).

### Step 5.8.5 — Set the bug-report destination

If ANY entry in `discrepancy_decisions[]` has decision `document-as-jira`
OR `skip-and-report`, set `bug_report_destination` to:

```
<vault-project-folder>/<JIRA_KEY>-implementation-gaps.md
```

— where `<vault-project-folder>` is the same path auto-discovered in
Phase 1 Q6 for the release-notes destination (typically
`<vault>/Projects/Products/**/<JIRA_KEY>*/`). **Same hard rule as for
release notes: NEVER `/tmp/`** — container restarts wipe it. Phase 6
writes the bug-report draft to this path; the file format is defined in
`_shared/source-truth.md` §7.5.

If all decisions are `document-as-source`, `bug_report_destination` is
null and no bug-report draft is emitted.

---

## Phase 6 — Write Documentation / Epics

### Use case A — Feature documentation

Synthesise a feature documentation page using:
- `jira-reader` handoff (VI goal, linked items, PR context)
- `diff-summarizer` handoffs for each repo (per-PR summaries, aggregate summaries)
- `discrepancy_decisions[]` (from Phase 5.8, possibly empty) — applies per-claim

**Citation rule — mandatory:** Every factual claim in the output MUST include:
- The originating Jira key as a wikilink: `[[KEY]]`
- The originating PR URL inline as a Markdown link

Example:
```
The ActiveGate auto-update backend was extended to respect maintenance windows
([[MGD-1127]], [PR #179969](https://bitbucket.lab.dynatrace.org/projects/RX/repos/cluster/pull-requests/179969)):
the scheduler now checks the configured update window before dispatching an update job.
```

**Discrepancy-decision application (added v1.8.0):** For every user-visible
claim that has an entry in `discrepancy_decisions[]`:

- `decision: "document-as-source"` — write the claim using `source_phrasing`
  verbatim. No marker needed.
- `decision: "document-as-jira"` — write the claim using `jira_phrasing`,
  AND insert this intentional-discrepancy marker immediately before the
  affected prose (anywhere from the enclosing paragraph to the enclosing
  section header — pick whichever scope makes the marker readable in the
  diff):

  ```markdown
  <!-- intentional-discrepancy: Jira <VI_KEY> describes
  "<jira_phrasing>" but the source at <source_location> currently has
  "<source_phrasing>". User decision: document Jira phrasing pending
  implementation. See <bug_report_destination> gap #<number>. -->
  ```

  doc-reviewer's Source-code accuracy dimension (Phase 7) recognises this
  marker and treats the discrepancy as intentional (NOT a BLOCKER).

- `decision: "skip-and-report"` — omit the claim from the docs entirely.
  If the claim was the entire content of a topic, omit the topic. If it
  was one sentence in a paragraph, drop the sentence. The bug-report
  draft still records the gap (Step 6.5 below).

Document structure (adapt based on VI content):

```markdown
# <VI Summary>

> **Jira:** [[<VI_KEY>]] | **Status:** <status>

## Overview

<2–3 paragraphs: what this feature does and why it exists. Cite VI description.>

## What Changed

### <Repo Name>

<Aggregate summary from diff-summarizer. Cite per-PR summaries inline.>

#### <PR Title>

<Per-PR summary from diff-summarizer. Cite: [[KEY]], PR URL.>

## Architecture / Design Notes

<Optional: notable patterns, abstractions, or refactors identified from diffs.>

## Related Work

| Jira Item | Type | Status | Summary |
|-----------|------|--------|---------|
| [[KEY]]   | ...  | ...    | ...     |

## References

- Jira: [[<VI_KEY>]]
- PRs: [#<id>](<url>), ...
```

Write to the output path confirmed in Phase 1.
**Never write inside `<VAULT_PATH>/_archive/`.**
**Never write outside cwd unless user provided an explicit absolute path.**

### Use case A — Bug-report draft (separate file, added v1.8.0)

Only generated if `bug_report_destination` (set in Phase 5.8 Step 5.8.5) is
non-null — i.e., the user picked `document-as-jira` OR `skip-and-report` for
at least one discrepancy.

Write a Markdown file at `<bug_report_destination>` (typically
`<vault-project-folder>/<JIRA_KEY>-implementation-gaps.md`):

```markdown
# <JIRA_KEY> — Implementation gaps found during documentation

Generated <YYYY-MM-DD>. File these as defects against the implementation
team (or amend the Jira ticket if the gap is intentional).

> This file was generated by `dev-workflows:impl:jira:docs:` during the
> docs PR for [[<JIRA_KEY>]]. Each gap below corresponds to a place where
> the Jira description and the source code disagreed, AND the user chose
> not to document the source-side phrasing.

<for each entry in discrepancy_decisions[] where decision != "document-as-source":>

## Gap <number>: <claim>

- **Jira phrasing**: <jira_phrasing>
- **Source state**: <source_phrasing>
- **Source location**: <source_location>
- **Verdict**: <finding>
- **User decision in docs**: <decision>
- **Docs status**: <"described as Jira claims, awaiting implementation"
                    if decision == "document-as-jira"
                    | "omitted from docs"
                    if decision == "skip-and-report">
- **Suggested action**: file a Jira defect against the team that owns
  `<source_location>`'s component. Reference [[<VI_KEY>]] and link this
  document.

<endfor>
```

The bug-report draft uses the same hard rules as the release-notes draft:
NEVER `/tmp/`, NEVER inside the docs repo. The user reviews these gaps,
files them as Jira defects against the implementation team, and may hold
the docs PR until they're resolved.

### Use case A — Release-notes draft (separate file)

After writing the feature documentation page(s) above, if
`release_notes_destination` (from Phase 1 Q6) is **not** `"skip"` AND
`doc-planner` returned a non-null `release_notes_block`:

1. Render the `release_notes_block.entries` array using
   `release_notes_block.rendered_template` — one block per release version.
   Concatenate the rendered blocks with a blank line between them.

2. Wrap the rendered output in a thin Markdown header so the user knows it's
   a draft:

   ```markdown
   # <VI summary> — Release-notes draft

   > **Source:** [[<VI_KEY>]]
   > **Generated:** <YYYY-MM-DD>
   > **Paste this into Jira's release-notes field. Jira automation will then emit the
   > `{{#context}}` / `{{#internal-note}}` blocks below into the docs repo.**
   > **Do NOT commit this file into `dynatrace-docs/_snippets/release-notes/...` —
   > the Jira-driven automation owns that path and will overwrite manual edits.**

   ---

   <rendered blocks>
   ```

3. **Apply the destination policy:**
   - `release_notes_destination = "file:<path>"` → write the draft to that
     absolute path. Create parent directories as needed (`mkdir -p`). If the
     file already exists, ask:
     ```
     ask_user(
       question: "Release-notes draft <path> already exists. How would you like to proceed?",
       choices: [
         "Overwrite",
         "Write to <path-v2>.md (new file with -v2 suffix)",
         "Output to screen instead",
         "Skip release-notes draft",
         "Other… (describe)"
       ]
     )
     ```
   - `release_notes_destination = "stdout"` → emit the rendered draft inline
     in the Phase 9 final report under a `### Release-notes draft` section
     instead of writing a file.
   - `release_notes_destination = "skip"` → do nothing here.

4. **Hard rule — NEVER write the release-notes draft into `<docs-repo>`.**
   If the resolved write path is inside any directory whose `.git` upstream
   slug is `dynatrace-docs` (or otherwise matches a docs-repo pattern), abort
   the write, surface the error to the user via `ask_user`, and offer to
   redirect to the auto-discovered vault path.

### Use case B — Child Epic definitions

For each new Epic to write, create one Markdown file at `<cwd>/<JIRA_KEY>/<epic-slug>.md`:

```markdown
# <Epic Title>

## Goal

<1 sentence: what this Epic delivers>

## Business Value

<1–2 sentences: why this matters>

## Scope

### In Scope
- <item>

### Out of Scope
- <item>

## Acceptance Criteria

- [ ] <testable criterion>

## Dependencies

| Item | Type | Notes |
|------|------|-------|
| [[KEY]] | Epic / Repo / Team | <note> |

## Suggested Stories

1. <story title>: <1-sentence description>

## References

- Parent VI: [[<VI_KEY>]]
- Related Epics: [[KEY]], ...
- Code paths (if scanned): `<repo>/<path>` — <note>
```

Citation rule: every Epic must cite the parent VI (`[[VI_KEY]]`). Code references must cite file paths from `code-scanner` handoff.

Create `<cwd>/<JIRA_KEY>/` directory if not present.

---

## Phase 6.7 — Style Check (before reviewer) — MANDATORY

> **Hard rule (added v1.7.0):** Phase 6.7 MUST run. The orchestrator MUST
> NOT skip the style check based on its own knowledge of which linters are
> installed. The `docs-style-checker` sub-agent owns linter detection AND
> the dt-style-checker fallback when the primary linter errors out. The
> orchestrator's job is to dispatch it and act on the return.
>
> "Some check is better than no check." Even when Vale is missing,
> `docs-style-checker` falls back to `dt-style-checker` from the
> `dt-style-guide` plugin (when installed). The orchestrator never skips.

### Use case A — docs-style-checker

Invoke `docs-style-checker` on the files written in Phase 6:

- `agent_type: "dev-workflows:docs-style-checker"`
- Pass input block:

```yaml
repo_root: <absolute path to the docs repo root — NOT cwd's git root; pass explicitly>
files:     <absolute paths of every file written or modified in Phase 6>
```

Act on the return:

- **`status: NOT_CONFIGURED`** — no repo linter AND no `dt-style-checker`
  available. The agent has already exhausted both the primary detection
  (Vale / project lint / markdownlint) AND the `dt-style-checker` fallback.
  Proceed to Phase 7. `doc-reviewer` is the only style/correctness gate.
  Record this as a known gap in the Phase 9 report so the user knows no
  prose linter ran.
- **`status: OK`** — linter ran, zero violations. Proceed to Phase 7.
- **`status: VIOLATIONS_FOUND`** — invoke `doc-fixer` sub-agent:

  - `agent_type: "dev-workflows:doc-fixer"`
  - Pass input block:

  ```
  Task description: doc writing for <JIRA_KEY>
  Reviewer or style-checker output: <paste full docs-style-checker output>
  Project root: <absolute path to the docs repo root — NOT cwd's git root; pass explicitly>
  Severities to fix: BLOCKER and MAJOR
  ```

  After `doc-fixer` completes, re-run `docs-style-checker` once. If violations remain:
  ```
  ask_user(
    question: "Style check still has violations after one fix cycle. How would you like to proceed?",
    choices: ["Proceed to review anyway — reviewer may still PASS", "Show remaining violations and let me fix manually", "Cancel"]
  )
  ```

- **`status: ERROR`** — surface the error reason:
  ```
  ask_user(
- **`status: ERROR`** — only reached when BOTH the primary linter AND the
  `dt-style-checker` fallback failed. Surface the error reason and proceed
  to Phase 7 (doc-reviewer is the safety net):
  ```
  ask_user(
    question: "Style checker encountered an error: <reason>. Both the primary linter and the dt-style-checker fallback failed. doc-reviewer will still run as the correctness gate. How would you like to proceed?",
    choices: [
      "Proceed to doc-reviewer (Recommended) — review is still the correctness gate",
      "Cancel and fix locally"
    ]
  )
  ```
  (The previous "Proceed to review without style check" option was removed
  in v1.7.0 — see hard rule at the top of Phase 6.7. The orchestrator now
  always tries the fallback before declining a style check.)

### Use case B — dt-style-checker for Epics

For Epics (vault content), `docs-style-checker` is skipped (no repo linter for
vault content). Instead, check if the `dt-style-guide` plugin is installed:

```
Check if path exists: ~/.copilot/installed-plugins/ihudak-copilot-plugins/dt-style-guide/agents/dt-style-checker.md
```

**If installed** — invoke `dt-style-checker` directly:

- `agent_type: "dt-style-guide:dt-style-checker"`
- Pass input block:

```yaml
files:    <absolute paths of every Epic file written in Phase 6>
doc_type: epic
```

Act on the return:

- **Zero violations** — proceed to Phase 7.
- **Violations found** — invoke `doc-fixer` sub-agent (same pattern as use case A
  above, passing `dt-style-checker` output as the style-checker report). After
  `doc-fixer` completes, re-run `dt-style-checker` once. If violations remain:
  ```
  ask_user(
    question: "Style check still has violations after one fix cycle. How would you like to proceed?",
    choices: ["Proceed to review anyway — reviewer may still PASS", "Show remaining violations and let me fix manually", "Cancel"]
  )
  ```
  - **Error** — surface the error reason and proceed to Phase 7
    (epic-reviewer is the correctness gate):
    ```
    ask_user(
      question: "dt-style-checker encountered an error: <reason>. epic-reviewer (Opus) will still run as the correctness gate. How would you like to proceed?",
      choices: [
        "Proceed to epic-reviewer (Recommended)",
        "Cancel and fix locally"
      ]
    )
    ```

**If not installed** — proceed directly to Phase 7 (existing behaviour preserved).

---

## Phase 7 — Review Gate

### Use case A — doc-reviewer (feature docs)

Invoke `doc-reviewer` sub-agent:

- `agent_type: "dev-workflows:doc-reviewer"`
- Pass the output file(s) written in Phase 6, the stated goal, the repo path (cwd), and the `model_routing` block
- Additionally pass: the `doc-planner` checklist (Phase 5.7), `diff-summarizer` outputs (Phase 5), the style-check report (Phase 6.7 output, including any `dt-style-checker` fallback notes), and **`code_repos: <array of {slug, path}>` (added v1.7.0)** so the reviewer can verify documented user-visible claims against the actual source code per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/source-truth.md` — the 8th review dimension is "Source-code accuracy"

Act on the verdict:

- **`status: OK`** → proceed to Phase 8.
- **`status: CONCERNS`** → record findings in Phase 9 report; proceed to Phase 8.
- **`status: BLOCKERS`** or **PASS WITH RECOMMENDATIONS** containing MAJOR findings:

  1. Invoke `doc-fixer` sub-agent:
     - `agent_type: "dev-workflows:doc-fixer"`
     - Pass input block:

     ```
     Task description: doc writing for <JIRA_KEY>
     Reviewer or style-checker output: <paste full doc-reviewer output>
     Project root: <absolute path to the docs repo root — NOT cwd's git root; pass explicitly>
     Severities to fix: BLOCKER and MAJOR
     ```

  2. Re-invoke `doc-reviewer` once (one re-review)
  3. If still BLOCKERS after one fix cycle, escalate per-BLOCKER:

  ```
  ask_user(
    question: "Doc review still has BLOCKER: <finding>. How would you like to proceed?",
    choices: [
      "Provide manual fix notes (you'll be prompted)",
      "Defer to a follow-up issue (record in Phase 9 report)",
      "Override and accept the finding",
      "Cancel the whole run"
    ]
  )
  ```
  "Manual fix notes" → take free-text; apply via `doc-fixer` one-shot (no further re-review). "Defer" → record in Phase 9 `### Deferred items`. "Override" → record with rationale.

### Use case B — epic-reviewer (Epics)

Invoke `epic-reviewer` sub-agent (Opus-pinned):

- `agent_type: "dev-workflows:epic-reviewer"`, `model: claude-opus-4.8`
- Pass input block:

```yaml
task_description: <one-paragraph: VI key, VI goal, number of Epics drafted>
written_epic_files: <absolute paths of every Epic file written in Phase 6>
jira_reader_handoff: <paste full YAML from Phase 3>
code_scanner_output:  <paste array of per-repo scanner outputs from Phase 5, or 'N/A — code scan off'>
```

Act on the verdict (same escalation pattern as use case A):

- **BLOCK** — invoke `doc-fixer` with `Severities to fix: BLOCKER and MAJOR`. Re-invoke `epic-reviewer` once. If still BLOCK, escalate per-BLOCKER:
  ```
  ask_user(
    question: "Epic review still has BLOCKER: <finding>. How would you like to proceed?",
    choices: [
      "Provide manual fix notes (you'll be prompted)",
      "Defer to a follow-up issue (record in Phase 9 report)",
      "Override and accept the finding",
      "Cancel the whole run"
    ]
  )
  ```
  For Epics, "Defer" means the finding goes into an Epic-refinement note in the draft itself (appended as a `## Refinement notes` section) in addition to Phase 9 report.
- **PASS WITH RECOMMENDATIONS** — invoke `doc-fixer` for MAJOR findings only. MINOR/NIT findings are deferred to Phase 9 report.
- **PASS** → proceed to Phase 8.

**Cap for both use cases:** 1 fix cycle + 1 re-review maximum.

---

## Phase 8 — Maintenance

Invoke `impl-maintenance` sub-agent:

- `agent_type: "dev-workflows:impl-maintenance"`
- Pass a compact handoff:

```markdown
## Implementation Summary

change_type: docs
skill:       impl:jira:
use_case:    A (feature docs) | B (epics)
jira_key:    <KEY>
vi_summary:  <text>
output_files:
  - <path>
release_notes_destination: <file:<path> | stdout | skip>
release_notes_versions:    <e.g. "Managed (344), SaaS (344)" | "none">
repos_analysed:
  - <repo>: <resolved_path>: <status>
prs_in_scope: <count>
doc_review_status: OK | CONCERNS | BLOCKERS_RESOLVED | BLOCKERS_DEFERRED
model_routing: <block>
```

---

## Phase 9 — Final Report

Output a final report to the user:

```
## impl:jira: Complete

### Jira Hierarchy Summary
- **VI:** [[<KEY>]] — <summary>
- **Linked items:** <count> (<N> Epic, <N> Story, <N> Sub-task, …)

### Repos Analysed
| Repo | Resolved Path | Status | PRs resolved | PRs unresolved |
|------|---------------|--------|-------------|----------------|
| cluster | /workspace/cluster-repo | OK | 3 | 0 |

### PRs in Scope
| PR | Repo | Status | Summary |
|----|------|--------|---------|
| [#179969](<url>) | cluster | MERGED | Handle update windows... |

### Output File(s)
- `<path>` (<N> lines)

### Release-notes draft
- Destination: `<file:<path> | stdout | skip>`
- Versions covered: `<e.g. Managed (344), SaaS (344) | none>`
<if release_notes_destination == "stdout">
- Rendered draft:
  ```
  <full rendered release-notes block — copy-paste into Jira>
  ```
<endif>
<if release_notes_destination == "file:..." and the file was written>
- Wrote: `<path>` (<N> lines)
<endif>

### Doc Review
- Status: <OK | CONCERNS | BLOCKERS_RESOLVED>
- Findings: <count> CONCERNS, <count> BLOCKERS fixed

<if CONCERNS exist, add a sub-list:>
#### Review Concerns
- [<section or heading>]: <finding text>
- …

### Images requiring manual upload
<if doc-planner returned image_policy: cdn_upload_required for any target>
The following screenshots were staged outside the docs repo and need manual
upload to the configured CDN before merging the docs PR. The doc pages
reference these images by their **final CDN URL**, not the staging path —
upload first, then update the URLs in the doc page if they differ from the
planned alt-text.

| Source | Staging path | Alt text | Upload note |
|--------|--------------|----------|-------------|
| `<src>` | `<staging>` | `<alt>` | `<upload_note>` |

<endif if no cdn_upload_required targets, write "None — all images embedded inline.">

### Model Routing
<model_routing block>
```

If branch was created:
```
### Branch
- Created: `docs/<JIRA_KEY>-<slug>`
- Committed: <SHA> — <message>
```

---

## Escalation Reference

| Situation | ask_user choices (last always "Other… (describe)") |
|-----------|---------------------------------------------------|
| `$VAULT_PATH` unset / invalid | "Use /obsidian (Recommended)", "Enter path manually", "Cancel" |
| Jira key dir not found | "Re-enter the Jira key", "Cancel" |
| Repo missing under `$REPOS_PATH` | "Skip this repo", "I'll clone it now — wait", "Cancel the run", "Specify a different absolute path for this repo" |
| Multiple matching clones for the same URL slug | "<auto-preferred path> (Recommended)", "<alternative path>", "Cancel the run" |
| `git fetch` failed | "Continue with current local state", "Skip this repo", "Cancel" |
| `diff-summarizer` returned `unresolved_prs` | "Show candidates and let me pick", "Skip this PR", "Skip this repo", "Cancel" |
| Use case B, no repos derivable | "List repos manually", "Proceed without code scan", "Cancel" |
| `doc-location-finder` LOW_CONFIDENCE | "Adjust individual locations (Recommended)", "Accept all proposed locations", "Cancel" |
| `doc-location-finder` EMPTY | "Specify locations manually (you'll be prompted)", "Cancel" |
| `doc-planner` with gaps | Per-gap prompt based on `recommended_action`; checklist approval with "Approve & write", "Adjust", "Cancel" |
| `docs-style-checker` VIOLATIONS after fix | "Proceed to review anyway", "Show remaining violations and let me fix manually", "Cancel" |
| `docs-style-checker` ERROR | "Proceed to review without style check", "Cancel and fix locally" |
| `dt-style-checker` VIOLATIONS after fix (use case B) | "Proceed to review anyway", "Show remaining violations and let me fix manually", "Cancel" |
| `dt-style-checker` ERROR (use case B) | "Proceed to review without style check", "Cancel and fix locally" |
| `doc-reviewer` or `epic-reviewer` BLOCKERS after one fix cycle | Per-BLOCKER: "Provide manual fix notes", "Defer", "Override", "Cancel the whole run" |
| Output file already exists | "Overwrite", "Write to <path-v2>.md", "Cancel" |
| Release-notes draft file already exists | "Overwrite", "Write to <path-v2>.md", "Output to screen instead", "Skip release-notes draft" |
| Release-notes auto-discover failed | drop the default; user picks "Specify a custom absolute path", "Output to screen only", "Skip release notes entirely" |
