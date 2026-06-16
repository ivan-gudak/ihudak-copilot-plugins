---
name: impl-docs
description: >
  Lightweight documentation-implementation workflow. Activated when the user's prompt
  starts with "impl:docs:". Handles documentation-only changes (Markdown files, Obsidian
  vault content, READMEs, wikis, CHANGELOG, etc.) without the code-specific overhead of
  branching, test phases, or code review. Working on the current branch by default —
  branch creation is optional and only created when the user requests it.
  For mixed code + docs changes, redirects the user to impl:code:.
allowed-tools: view, edit, create, bash, glob, grep, ask_user, sql
---

# `impl:docs:` — Documentation Implementation Skill

Activated when the user prompt starts with `impl:docs:`.

> **This skill is for documentation-only changes.** If the description mentions changes
> to source code files (`.js`, `.ts`, `.py`, `.java`, `.go`, `.rs`, `.rb`, etc.),
> stop at Phase 0 and redirect the user to `impl:code:`.

> **Model routing is mandatory.** Before any planning, read
> `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`
> and classify the task per Phase 0.5. Docs-only work is always SIMPLE or MODERATE — no
> Opus steps are required.

---

## Phase 0 — Load the description

1. If the prompt is `impl:docs: @<file.md>` (with an `@` prefix):
   - Read the file using the `view` tool. Confirm: `"Loaded prompt from <filename.md> (N lines)."`
   - If the file cannot be read, stop and report the error immediately.
   - Treat the file's content as the description going forward.
2. Otherwise, treat the text after `impl:docs:` as the description verbatim.

3. **Mixed-changes guard**: scan the description for explicit mentions of non-doc source
   file changes (`.js`, `.ts`, `.py`, `.java`, `.go`, `.rs`, `.rb`, `.php`, `.cs`,
   `.cpp`, `.c`, `.sh`, or similar code extensions). If found, stop immediately:
   > This change appears to include source code modifications. Use `impl:code:` instead —
   > it provides the full test-writing and review workflow required for code changes.

4. **Jira-ticket guard** (only when the description came from `@<file.md>` in step 1):
   detect whether the loaded file is an Obsidian export of a Jira work-item. The
   triggers are **all** of the following:
   - Frontmatter contains a `key:` field whose value matches `^[A-Z][A-Z0-9]+-\d+$`
     (e.g. `PRODUCT-14902`, `MGD-789`).
   - The body contains at least one Obsidian wikilink `[[KEY]]` referencing a Jira
     key (same regex as above) — typical exports include linked-issue lists.
   - At least one of: an `## Linked Issues` heading, a `## Pull Requests` heading,
     or `**Index:**` line referencing `<KEY>-index`.

   When all three triggers fire:
   ```
   ask_user(
     question: "This file looks like a Jira export (key: <KEY>). The Jira-driven docs workflow can aggregate linked tickets, resolve PR diffs across repos, and generate release notes from frontmatter. How would you like to proceed?",
     choices: [
       "Use impl:jira:docs: instead (Recommended) — pass me the Jira key and I'll re-route",
       "Continue with impl:docs: — I want lightweight prose editing only",
       "Cancel",
       "Other… (describe)"
     ]
   )
   ```

   - Choice 1 → STOP this skill. Print: `"Re-run with: impl:jira:docs: <KEY>  (or attach the export: impl:jira:docs: @<path>)"` and exit.
   - Choice 2 → continue with impl:docs:. Note in the Phase 5 report that
     impl:jira:docs: was offered and declined.
   - Choice 3 → exit.

---

## Phase 0.5 — Classify (always SIMPLE / MODERATE for docs)

Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`
and classify. Docs-only work never triggers SIGNIFICANT or HIGH-RISK — classify as
SIMPLE (single-file edits) or MODERATE (multi-file, cross-cutting docs).

Record the `model_routing` block:

```yaml
model_routing:
  classification: SIMPLE | MODERATE
  reason: docs-only change — no code, no Opus routing required
  current_model: <current model>
  planning_model: <current model>
  review_model: n/a — docs-only
  implementation_model: <current model>
  opus_available: false  # not applicable for docs-only
  gate_tests_on_review: false
```

---

## Phase 1 — Clarification

**Rule: Ask, don't guess.**

Before producing a plan, check for:
- Unclear scope (which files? which sections?)
- Conflicting or missing structural guidance
- Style or formatting constraints not specified

If any exist, use `ask_user`:

```
ask_user(
  question: "Clear, specific question?",
  choices: ["Option A (Recommended)", "Option B", "Other… (describe)"]
)
```

Last choice in every question must be `"Other… (describe)"`.

If nothing is ambiguous, skip directly to Phase 2.

---

## Phase 2 — Plan

Produce a lightweight plan:

1. **Goal** — one sentence.
2. **Files to create/modify** — list with brief rationale.
3. **Out of scope** — what is NOT being changed.
4. **Branch** — note: *"Working on current branch by default. Select 'Create a branch' below to isolate this change."*

Request approval:

```
ask_user(
  question: "Documentation plan ready. What would you like to do?",
  choices: [
    "Approve & implement now (Recommended)",
    "Revise plan",
    "Create a branch / PR for this change",
    "Cancel"
  ]
)
```

- **Approve** → proceed to Phase 3 immediately.
- **Revise** → ask what to change, update plan, re-show, re-ask.
- **Create a branch / PR** → proceed to Phase 2.5, then Phase 3.
- **Cancel** → stop and summarise what was planned.

---

## Phase 2.5 — Branch Setup (optional — only if user requested)

Only run this phase if the user explicitly selected "Create a branch / PR" in Phase 2
or requests it at any later point.

1. **Clean-tree check** — `git status --porcelain`. If dirty, ask:
   ```
   ask_user(
     question: "Uncommitted changes detected. How would you like to proceed?",
     choices: [
       "Stash changes and create branch (Recommended)",
       "Proceed on current branch without stashing",
       "Cancel"
     ]
   )
   ```
2. **Detect branch prefix** — follow the algorithm in
   `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/branch-naming.md`:
   1. `$GIT_USER_INITIALS` env var
   2. `git config --get user.initials`
   3. Sniff `git branch -a` for the dominant `<2-8-char-prefix>/<rest>` pattern
      (≥ 30 % share AND ≥ 3 occurrences)
   4. Workflow fallback for `impl:docs:`: `docs/`. If detection falls through to
      this step, run the user-override prompt per §1.5 of `_shared/branch-naming.md`.
3. **Generate slug** — from the first 6–8 content words of the description: lowercase, hyphens, max 40 chars.
4. **Create and checkout** — `git checkout -b <prefix>/<slug>`. Announce: `"Created branch: <prefix>/<slug>"`.

---

## Phase 3 — Implement

Apply the approved doc changes:

1. Work through each file in the plan in order.
2. Make precise edits — do not restructure sections outside the stated scope.
3. Preserve existing formatting conventions (heading levels, code fences, link style).
4. If a **new ambiguity** emerges mid-edit: pause and use `ask_user` with choices.

---

## Phase 3.4 — Style Check (added v1.7.0 — MANDATORY)

> **Hard rule:** Phase 3.4 MUST run. Some check is better than no check.
> The `docs-style-checker` sub-agent owns linter detection AND the
> `dt-style-checker` fallback when the primary linter errors out. Never
> skip on the basis of "I think Vale isn't installed" — let the sub-agent
> figure it out.

Invoke `docs-style-checker` on the files changed in Phase 3:

```
task(
  agent_type: "dev-workflows:docs-style-checker",
  mode:       "sync",
  description:"Style check",
  prompt:     "repo_root: <absolute path to the repo root>
               files: [<absolute paths of every file changed in Phase 3>]"
)
```

Act on the return:

- **`status: OK`** — proceed to Phase 3.5.
- **`status: NOT_CONFIGURED`** — no repo linter AND no `dt-style-checker`
  available. Record as a known gap in the Phase 5 report. Proceed to
  Phase 3.5 (doc-reviewer is the correctness gate).
- **`status: VIOLATIONS_FOUND`** — invoke `doc-fixer` sub-agent:

  ```
  task(
    agent_type: "dev-workflows:doc-fixer",
    mode:       "sync",
    description:"Apply style fixes",
    prompt:     "Task description: docs update for <repo> — <goal>
                 Reviewer or style-checker output: <paste full docs-style-checker output>
                 Project root: <absolute-repo-root>
                 Severities to fix: BLOCKER, MAJOR, MINOR"
  )
  ```

  Then re-run `docs-style-checker` once. If violations remain after the
  fix cycle, surface to the user (cap: 1 fix cycle + 1 re-check).

- **`status: ERROR`** — only reached when BOTH the primary linter AND the
  `dt-style-checker` fallback failed. Record the error in the Phase 5
  report and proceed to Phase 3.5 (doc-reviewer is the safety net).

---

## Phase 3.5 — Docs Review (via `doc-reviewer` sub-agent)

After all edits and the style-check cycle are complete, invoke the `doc-reviewer` sub-agent for a comprehensive review:

```
task(
  agent_type: "dev-workflows:doc-reviewer",
  mode:       "sync",
  description:"Docs review",
  prompt:     "goal: <one-sentence goal from Phase 2>
               repo: <absolute-repo-root>
               changed_files: [<relative path> — <one-line summary>, ...]
               code_repos: [<optional list of {slug, path} for any source repos referenced by the docs; enables Source-code accuracy review dimension per _shared/source-truth.md>]
               <model_routing block>"
)
```

Evaluate the Doc Review Report:

- `status: OK` → proceed to Phase 4.
- `status: CONCERNS` → record findings in the Phase 5 report; fix any CONCERN that is trivially
  addressable inline; proceed to Phase 4 without re-review.
- `status: BLOCKERS` → invoke `doc-fixer` sub-agent to resolve BLOCKER findings:

  ```
  task(
    agent_type: "dev-workflows:doc-fixer",
    mode:       "sync",
    description:"Fix BLOCKER findings",
    prompt:     "Task description: docs update for <repo> — <goal>
                 Reviewer or style-checker output: <paste full doc-reviewer output>
                 Project root: <absolute-repo-root>
                 Severities to fix: BLOCKER and MAJOR"
  )
  ```

  Then invoke `doc-reviewer` **once more**:
  - Second review `OK` or `CONCERNS` → proceed to Phase 4.
  - Second review still `BLOCKERS` → surface the unresolved BLOCKERs to the user via `ask_user`
    and stop until resolved. Do not loop further.

> **Cap: one fix cycle + one re-review maximum.** Do not loop beyond this.

---

## Phase 4 — Mandatory Maintenance (via `impl-maintenance` sub-agent)

Build a compact handoff and delegate to `impl-maintenance`:

```markdown
## Implementation Summary
repo: <absolute path to repo root, or "none">
change_type: docs
description: >
  <2–4 sentence plain-English summary of what docs were changed and why>
files_changed:
  - path: <relative path>
    summary: <one-line description of the change>
kb_context: >
  <Non-obvious decisions or patterns worth remembering. Leave blank if nothing notable.>
```

> For `change_type: docs`, `impl-maintenance` will skip Task C (secondary documentation
> update — the work IS the docs) and evaluate Tasks A and B only if warranted.

Include the sub-agent's Maintenance Report under `### Knowledge base` and
`### Instructions` in the Phase 5 report.

---

## Phase 5 — Final Report

```
## Documentation Implementation Report

### What was implemented
[High-level summary]

### Branch
[Branch name, or "none — implemented on current branch"]

### Files changed
- path/to/file.md — [what changed]

### Consistency review findings
- [issues found and fixed, or "none"]

### Knowledge Base
- [entry added/updated] OR "no update required"

### Instructions
- [change summary] OR "no update required"

### Model Routing
- Classification: SIMPLE | MODERATE
- Reason: docs-only change
- Planning model: <current model>
- Notes: no Opus routing required for docs-only work
```

---

## Invariants

- NEVER run `test-baseliner` for docs-only work — no baseline capture, no regression compare.
- NEVER invoke the `code-review` sub-agent for docs-only work.
- NEVER create a branch unless the user explicitly requests it.
- ALWAYS redirect to `impl:code:` if source code file changes are described.
- ALWAYS use `ask_user` with `choices` for any decision point; last choice is always `"Other… (describe)"`.
- ALWAYS produce the Phase 5 report as the final output.
- ALWAYS skip Phase 4 Task C (docs update) for `change_type: docs` — the work is already docs.
- NEVER skip Phase 4 entirely — KB and instructions evaluation is still mandatory.
