---
name: impl
description: >
  Structured code-implementation workflow. Activated when the user's prompt starts with
  "impl:code:", "implement:", or "impl:code: @<file>". Does NOT activate for bare "impl:"
  prompts (those go to the impl-dispatcher help page), nor for "impl:docs:" prompts
  (handled by the impl-docs skill).
  Enforces ask-don't-guess discipline: clarify all ambiguities first, produce an approved plan,
  then implement immediately. Captures a test baseline before changes, writes tests for all
  new/changed behaviour, and verifies no regressions after.
  After completion, persists learned knowledge and updates instructions.
allowed-tools: view, edit, create, bash, glob, grep, ask_user, sql
---

# `impl:code:` — Structured Code-Implementation Skill

Activated when the user prompt starts with `impl:code:` or `implement:`
(optionally followed by `@<file.md>` to load description from a file).
Bare `impl:` now routes to the dispatcher — use `impl:code:` explicitly.

> **Model routing is mandatory.** Before any planning happens, this skill MUST
> classify the task per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` and follow
> the routing rules. See Phase 0.5 below.

---

## Phase 0 — Load the description

1. If the prompt is `impl: @<file.md>` or `impl:code: @<file.md>` (with an `@` prefix pointing to a markdown file):
   - Read the referenced file's full content using the `view` tool. Resolve the path relative to the current working directory.
   - Confirm the file was loaded: `"Loaded prompt from <filename.md> (N lines)."`
   - If the file cannot be read, stop and report the error to the user immediately.
   - If the file embeds images (e.g. `![…](path)`), note them as "referenced image: <path>" in context.
   - Treat the file's content as the implementation description going forward.
2. Otherwise, treat the text after `impl:` (or `impl:code:` / `implement:`) as the description verbatim.
3. **Docs-only guard**: if the prompt starts with `impl:docs:`, stop immediately and tell the user:
   > This prompt looks like a docs-only change. Use `impl:docs:` instead — it skips branching,
   > code review, and test phases, keeping documentation work lightweight.

---

## Phase 0.5 — Classify & Route (mandatory)

Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` and classify the task into
exactly one of: `SIMPLE`, `MODERATE`, `SIGNIFICANT`, `HIGH-RISK`.

Quick rubric (see the shared doc for the full list):

| If the task involves any of…                                                | → Class            |
|-----------------------------------------------------------------------------|--------------------|
| auth/authz/sessions/tokens, DB schema/migrations, payments/audit/PII, public API contract, broad refactor, concurrency/transactions/caching, > 3–5 non-test files, security-sensitive logic, unclear high-blast-radius requirements | `SIGNIFICANT` or `HIGH-RISK` |
| 1–3 files, well-scoped, none of the above triggers                          | `MODERATE`         |
| trivial typo / comment / formatting / log-message edit                      | `SIMPLE`           |

**When in doubt, escalate one level.**

Record a `model_routing` block (format in `_shared/model-routing.md` §4) and
include it verbatim in the Phase 5 final report under `### Model Routing`.

### Routing consequences for `impl:`

- **SIMPLE / MODERATE** — proceed to Phase 1 normally. No mandatory Opus steps.
- **SIGNIFICANT / HIGH-RISK** —
  - **Phase 2 plan** is produced normally, then **critiqued by an Opus
    sub-agent** (`task` with `agent_type: "dev-workflows:risk-planner"`, `model:
    claude-opus-4.8` or the highest available per `_shared/model-routing.md`
    §2). Address every BLOCKER and document every CONCERN before requesting
    user approval.
  - **Phase 3** implementation proceeds with the current model or Sonnet — no
    Opus required for code edits.
  - **New Phase 3.5 — Opus Code Review (gate before tests):** delegate to a
    `code-review` sub-agent pinned to Opus. The review MUST address every item
    in the §6 checklist of the shared doc. **Do not run tests until the review
    completes** and every BLOCKER is resolved.
  - Any review fixes are applied with the current model or Sonnet, then tests
    are run, then re-run if fixes were applied (Phase 3.6).

---

## Phase 1 — Clarification & Planning

**Rule: Ask, don't guess. This rule is absolute.**

Before producing a plan:

1. Analyze the description for:
   - Ambiguous scope or unclear boundaries
   - Missing constraints (performance, security, backwards-compatibility, etc.)
   - Multiple valid implementation approaches
   - Undefined integration points or dependencies
   - Missing acceptance criteria

2. If **any** of the above exist, ask the user using the `ask_user` tool.
   - Use `choices` arrays (interactive list UI) for every question — never plain text questions.
   - The **last choice** in every question MUST be `"Other… (describe)"` to allow free-text.
   - When a clearly superior default exists, make it the first choice and label it `"(Recommended)"`.
   - Group related decisions into a single question where possible (minimize total questions).
   - Repeat until all ambiguities are resolved.
   - Do **not** proceed to Phase 2 until all questions are answered.

3. If **nothing** is ambiguous, skip directly to plan creation.

### Question format rule
```
ask_user(
  question: "Clear, specific question?",
  choices: ["Best option (Recommended)", "Option B", "Option C", "Other… (describe)"]
)
```

---

## Phase 2 — Structured Plan

Produce a written implementation plan containing:

1. **Goal** — one-sentence summary of what will be built.
2. **Approach** — the chosen implementation strategy and why.
3. **Steps** — numbered, concrete implementation steps.
4. **Files to create/modify** — list with brief rationale for each.
5. **Tests** — what tests will be added or run.
6. **Assumptions** — any decisions made without user input (must be minimal).
7. **Out of scope** — explicitly list what is NOT being done.

Then request approval using `ask_user`:

```
ask_user(
  question: "Implementation plan ready. What would you like to do?",
  choices: [
    "Approve & implement now (Recommended)",
    "Revise plan",
    "Cancel"
  ]
)
```

- If **"Approve & implement now"** → proceed to Phase 3 immediately.
- If **"Revise plan"** → ask what to change (use `ask_user`), update the plan, re-show it, re-ask approval.
- If **"Cancel"** → stop and summarize what was planned (no implementation).

---

## Phase 2.5 — Branch Setup

Before writing any file, ensure all work is isolated on a dedicated branch.

1. **Clean-tree check** — Run `git status --porcelain`. If the output is non-empty:
   - Show the user what is dirty (paste the `git status --short` output).
   - Ask:
     ```
     ask_user(
       question: "Uncommitted changes detected. How would you like to proceed?",
       choices: [
         "Stash changes and create branch (Recommended)",
         "Proceed anyway — pre-existing changes will appear in the diff and review outputs",
         "Cancel"
       ]
     )
     ```
   - **Stash**: run `git stash push -m "pre-impl stash"`, then continue.
   - **Proceed**: note in the Phase 5 report that the working tree was dirty at implementation start. Automated review/PR guarantees are void.
   - **Cancel**: stop and summarize what was planned.

2. **Detect branch prefix** — follow the algorithm in
   `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/branch-naming.md`:
   1. `$GIT_USER_INITIALS` env var
   2. `git config --get user.initials`
   3. Sniff `git branch -a` for the dominant `<2-8-char-prefix>/<rest>` pattern
      (≥ 30 % share AND ≥ 3 occurrences)
   4. Workflow fallback for `impl:code:`: `feat/`. If detection falls through to
      this step, run the user-override prompt per §1.5 of `_shared/branch-naming.md`.

3. **Generate slug** — derive from the first 6–8 content words of the implementation description: lowercase, hyphens, max 40 chars, strip punctuation and stop-words (a, an, the, in, for, to, with, of). Example: "Add user authentication to login page" → `add-user-authentication-login-page`.

4. **Check HEAD context** — if HEAD is NOT on the default branch (`main` / `master` / `develop`), check for ahead commits: `git log origin/HEAD..HEAD --oneline 2>/dev/null`. If output is non-empty, ask:
   ```
   ask_user(
     question: "You are on a non-default branch with local commits. Where should the new branch start?",
     choices: [
       "Branch from current position — continue in this work context (Recommended)",
       "Branch from default branch — fresh start",
       "Cancel"
     ]
   )
   ```

5. **Create and checkout** — `git checkout -b <prefix>/<slug>`. If that name already exists, append the first 7 chars of HEAD's SHA: `<prefix>/<slug>-<short-sha>`. Announce: `"Created branch: <prefix>/<slug>"`.

---

## Phase 2.6 — Test Baseline Capture

Before touching any source files, record the current test suite state. This baseline is
used in Phase 3.8 to detect regressions introduced during implementation.

1. Invoke the `test-baseliner` sub-agent in `capture` mode:
   ```
   task(
     agent_type: "dev-workflows:test-baseliner",
     mode:       "sync",
     description:"Test baseline capture (pre-impl)",
     prompt:     "## Test Baseline Request\nrepo: <absolute-repo-root>\nmode: capture\n<model_routing block>"
   )
   ```
2. Record the result:
   - `status: OK` — baseline captured. Record `passing_count` and `passing_tests` list for Phase 3.8.
   - `status: NO_TESTS` or `COMMAND_NOT_FOUND` — note this. Do **not** block implementation.
     Record `baseline_status: NO_TESTS` (or `COMMAND_NOT_FOUND`) for use in Phase 3.7
     (the test-writer will surface the no-framework situation to the user).
   - `status: RUN_FAILED` — ask the user:
     ```
     ask_user(
       question: "The test suite failed before any changes were made. How would you like to proceed?",
       choices: [
         "Investigate and fix the failing tests first (Recommended)",
         "Proceed — treat the test suite as unavailable for this impl",
         "Cancel"
       ]
     )
     ```

> Do not run any other commands between Phase 2.6 and Phase 3.
> The baseline must reflect the exact state of the newly-created branch before any edits.

---

## Phase 3 — Implementation

**Implement immediately. Do NOT ask "Should I implement?" or any variation.**

Follow the approved plan step-by-step:

1. Work through each step in order.
2. Make precise, surgical changes — do not modify unrelated code.
3. Use LF line endings. Follow the existing code style.
4. Assume broad permissions; avoid unnecessary stops.
5. If a **new ambiguity or obstacle** emerges mid-implementation:
   - STOP the current step.
   - Use `ask_user` with a choices list (last option: `"Other… (describe)"`).
   - Resume automatically after the answer.
6. After all code changes:
   - **If classification is SIGNIFICANT or HIGH-RISK**, do NOT run tests yet —
     proceed to Phase 3.5 (Opus code review) first.
   - Otherwise (SIMPLE/MODERATE): run any existing linters and builds (not the full test suite).
     Fix any build/lint failures before proceeding to Phase 3.7.
7. Verify the outcome matches the approved plan.

---

## Phase 3.5 — Opus Code Review (SIGNIFICANT / HIGH-RISK only)

Mandatory gate **before** tests are run for SIGNIFICANT / HIGH-RISK tasks.

1. Build the diff/summary of every file changed in Phase 3.
2. Invoke the review sub-agent:
   ```
   task(
     agent_type: "dev-workflows:code-review",          # fall back to "general-purpose" if unavailable
     model:      "claude-opus-4.8",      # or highest available per _shared/model-routing.md §2
     description:"Opus code review (SIGNIFICANT/HIGH-RISK gate)",
     mode:       "sync",
     prompt:     "<plan summary> + <diff/changed files> +
                  Use the §6 checklist from ~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md.
                  For each item return: OK | CONCERN | BLOCKER + comment."
   )
   ```
3. **Resolve every BLOCKER via `review-fixer`.** Invoke the sub-agent:
   ```
   task(
     agent_type: "dev-workflows:review-fixer",
     mode:       "sync",
     description:"Apply review fixes for impl",
     prompt:     "<plan summary> + <full review output> + project root: <absolute path>"
   )
   ```
   Inspect the Fix Report's `Stop condition flag`:
   - `CLEAR` → all BLOCKER findings were applied; proceed to Phase 3.7.
   - `NEEDS HUMAN` → surface the deferred BLOCKERs to the user via `ask_user`
     (one question per unresolved BLOCKER). Do not proceed to tests until the
     user resolves each one. After resolution, run a single re-review cycle
     (re-invoke `code-review`, then `review-fixer` once more). If the re-review
     still BLOCKs, stop and surface to user — do not loop further.
    Document the disposition of every CONCERN from the review output.
4. Only after every BLOCKER is resolved, proceed to Phase 3.7.

---

## Phase 3.7 — Write / Update Tests

Mandatory for all code changes. Skip **only** if the user explicitly chose
"Proceed without tests" via the `ask_user` prompt within Phase 3.7 step 3 below.

1. Collect the list of changed source files and their one-line change summaries from Phase 3.
2. Invoke the `test-writer` sub-agent:
   ```
   task(
     agent_type: "dev-workflows:test-writer",
     mode:       "sync",
     description:"Write tests for changed behaviour",
     prompt:     "<task description>
                  changed_files: [<relative path> — <one-line summary>, ...]
                  repo: <absolute-repo-root>
                  baseline_status: <OK | NO_TESTS | COMMAND_NOT_FOUND — from Phase 2.6>
                  command_hint: <test command from Phase 2.6 result, if status was OK>
                  <model_routing block>"
   )
   ```
3. Inspect the Test Report:
   - `status: OK` — tests written; proceed to Phase 3.8.
   - `status: NO_TESTS` or `COMMAND_NOT_FOUND` — surface to user (do NOT silently skip):
     ```
     ask_user(
       question: "No test framework was detected in this project. Writing tests is required for code changes. How would you like to proceed?",
       choices: [
         "Set up a test framework first — I will handle it, then re-invoke impl:code: (Recommended)",
         "Proceed without tests for this change — document the reason in the report",
         "Cancel"
       ]
     )
     ```
     - **Set up first** → stop; summarise what was implemented so far so the user can resume.
     - **Proceed without tests** → record the reason; Phase 3.8 skips test-suite comparison
       but still runs the build/lint.
     - **Cancel** → stop.
   - `status: DEFERRED_TO_HUMAN` → surface the deferred findings via `ask_user` and resolve
     before proceeding to Phase 3.8.

---

## Phase 3.8 — Verify (Tests + Regression Check)

Run the full test suite and compare against the Phase 2.6 baseline.

> **Skip** if the user explicitly chose "Proceed without tests" in Phase 3.7.
> In that case:
> 1. Run linters and builds (same commands as Phase 3 step 6). Fix any failures.
> 2. Record `tests: skipped — no framework` in the Phase 5 report.
> 3. Proceed to Phase 4.

1. Invoke `test-baseliner` in `verify` mode, passing the Phase 2.6 baseline:
   ```
   task(
     agent_type: "dev-workflows:test-baseliner",
     mode:       "sync",
     description:"Test verification (post-impl)",
     prompt:     "## Test Baseline Request
                  repo: <absolute-repo-root>
                  mode: verify
                  baseline:
                    passing_count: <N from Phase 2.6>
                    passing_tests: [<list from Phase 2.6>]
                  <model_routing block>"
   )
   ```
2. Evaluate the result:
   - `status: OK` **and** all new tests from Phase 3.7 pass → proceed to Phase 4.
   - `status: REGRESSIONS` (baseline tests now failing):
     - Fix the regressions using the current model. Do not add complexity beyond
       restoring the baseline.
     - For `SIGNIFICANT` / `HIGH-RISK`: if production code was changed during regression
       fixing, run a **single** re-review cycle (re-invoke Phase 3.5 once, then
       `review-fixer` once). Do not loop again.
     - Re-run Phase 3.8 once after fixes. If regressions persist, surface to the user
       and stop.
   - New tests from Phase 3.7 fail (test code issue, not a prod bug):
     - Fix the test code and re-run Phase 3.8 once.
     - If tests still fail after one fix attempt, surface to the user.
   - `status: RUN_FAILED` → surface to the user and ask how to proceed.

> **Cap: one remediation cycle + one re-review cycle maximum.**
> Do not loop beyond this — surface to user if the suite is still red.

---

## Phase 4 — Mandatory Maintenance (via `impl-maintenance` sub-agent)

After successful implementation, build a compact handoff document and delegate ALL maintenance tasks to the `impl-maintenance` sub-agent. Do **not** perform knowledge base, instructions, or documentation updates inline.

**Build the handoff** (use the format in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/impl-maintenance/references/handoff.md`):

```markdown
## Implementation Summary
repo: <absolute path to repo root, or "none" if not a git repo>
change_type: <feature | bugfix | security | refactor | test-only>
description: >
  <2–4 sentence plain-English summary of what was built/changed>
files_changed:
  - path: <relative path>
    summary: <one-line description of the change>
kb_context: >
  <Non-obvious decisions, gotchas, or patterns worth remembering.
   Leave blank if nothing notable.>
```

Invoke the `impl-maintenance` sub-agent with this handoff document.

Include the sub-agent's Maintenance Report verbatim in the Phase 5 Final Report under the `### Knowledge base`, `### Instructions`, and `### Documentation` sections.

---

## Phase 5 — Final Report

Conclude with a structured report (no questions):

```
## Implementation Report

### What was implemented
[High-level summary]

### Branch
[branch name created in Phase 2.5, e.g. feat/add-user-authentication]

### Files changed
- path/to/file.ext — [what changed]

### Commands / tests run
- [command] → [result]

### Tests written (Phase 3.7)
- framework: [detected framework | none]
- files_created: [list, or "none"]
- files_modified: [list, or "none"]
- status: [OK | NO_TESTS | COMMAND_NOT_FOUND | skipped — user chose to proceed without tests]

### Knowledge Base
- [file updated/created] — [summary of entry] OR "no update required"

### Instructions
- [summary of change] OR "no update required"

### Documentation
- [file updated] — [summary of change] OR "no update required (bugfix / internal / non-visible change)" OR "no doc files found — no update made"

### Model Routing
- Classification: <SIMPLE | MODERATE | SIGNIFICANT | HIGH-RISK>
- Reason: <one-line trigger>
- Planning model: <model>
- Implementation model: <model>
- Review model: <model | "n/a — SIMPLE/MODERATE">
- Opus checklist verdicts (SIGNIFICANT/HIGH-RISK only):
  - Correctness / Security / Architecture / Edge cases / Migration / Dependencies / Tests / Rollback
- Notes: <degradation, fallbacks, deferred items>

### Assumptions & limitations
- [list any]
```

---

## Invariants (always enforced)

- NEVER make assumptions that could have been asked — ask instead.
- NEVER end Phase 3 with a question like "Should I implement?" — if approved, implement.
- NEVER rewrite files wholesale when only an append/edit is needed.
- NEVER skip Phase 4 — knowledge persistence is mandatory after every successful impl.
- NEVER skip Phase 4c — always evaluate whether documentation needs updating and act accordingly.
- NEVER invent new knowledge files if an existing structure already fits.
- ALWAYS use `ask_user` with `choices` for any decision point; last choice is always `"Other… (describe)"`.
- ALWAYS produce the Phase 5 report as the final output.
- ALWAYS use safe defaults only when they are truly unambiguous; otherwise ask.
- ALWAYS keep every decision explicit and deterministic.
- ALWAYS perform Phase 0.5 classification before Phase 1; never skip it.
- ALWAYS run the Opus code-review gate (Phase 3.5) BEFORE tests for SIGNIFICANT / HIGH-RISK tasks; never run tests first.
- NEVER use Opus for routine implementation steps — Opus is reserved for planning critique and the post-impl review.
- ALWAYS create a feature branch (Phase 2.5) before writing any file — never implement directly on the default branch.
- ALWAYS check for a clean working tree before branching; stash or get explicit user consent if dirty.
- ALWAYS use `review-fixer` sub-agent (not inline fixes) to resolve BLOCKER findings after Opus review.
- NEVER run a second review-fixer cycle if the re-review still BLOCKs — surface to user instead.
- ALWAYS capture a test baseline (Phase 2.6) on the new branch before writing any code.
- ALWAYS invoke `test-writer` (Phase 3.7) for code changes — never skip test-writing silently.
- NEVER skip test-writing if no framework is detected — surface `NO_TESTS` / `COMMAND_NOT_FOUND` to the user explicitly.
- ALWAYS verify the full test suite against the baseline (Phase 3.8) before proceeding to Phase 4.
- NEVER activate for `impl:docs:` prompts — redirect to the `impl-docs` skill immediately.
