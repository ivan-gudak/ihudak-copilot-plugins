---
name: upgrade
description: >
  Upgrade one or more components (libraries, frameworks, languages, build tools, CI/CD actions)
  in the current repository to a target version. Triggered by the "upgrade:" command followed
  by space-separated tokens in the form "component:version", "component:minor", "component:latest",
  "component:lts", or bare "component" (latest compatible assumed). Works on any project regardless of
  language or ecosystem. Upgrades are applied to the current branch with no commits or PRs.
  Runs tests before and after each upgrade; updates test code if required by the new version.
  Use when the user wants to keep dependencies, frameworks, languages, or CI/CD actions current.
allowed-tools: view, edit, create, bash, glob, grep, ask_user, sql
---

# Upgrade Components

## Overview

Upgrade one or more components in the current repository to a requested version, verify the project still builds and tests stay green, and leave all changes uncommitted on the current branch.

> **Model routing is mandatory.** Before Phase 1, this skill MUST classify the
> requested upgrade batch per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` and
> follow the routing rules. See "Phase 0 — Classify & Route" below.

## Phase 0 — Classify & Route (mandatory, runs before Phase 1)

Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` and classify the upgrade
batch into exactly one of: `SIMPLE`, `MODERATE`, `SIGNIFICANT`, `HIGH-RISK`.

Default classification heuristics for `upgrade:`:

| Upgrade type                                                                   | → Class            |
|--------------------------------------------------------------------------------|--------------------|
| Patch-only bumps (e.g. `springboot:minor`, `lib:1.2.3` → `1.2.4`)              | `MODERATE`         |
| `latest`/`lts`/bare-token resolutions that stay within the current major       | `MODERATE`         |
| Any **major** version bump (Spring Boot 2→3, React 17→18, Java 11→21, Gradle 8→9, Node 18→20→22) | `SIGNIFICANT` |
| Major bumps to runtimes/frameworks that touch auth/security/serialization (e.g. Spring Security major, Hibernate major, Jackson major) | `HIGH-RISK` |
| `.github/workflows` action upgrades (no code execution risk)                   | `MODERATE`         |
| Multi-component batches that include any item from the SIGNIFICANT/HIGH-RISK rows above | inherit the highest class |

**When in doubt, escalate one level.**

Build the `model_routing` block (format in `_shared/model-routing.md` §4) and
pass it to **every** sub-agent invocation (`upgrade-planner`,
`upgrade-executor`, `test-baseliner`).

### Routing consequences

- **SIMPLE / MODERATE** — proceed with the existing two-phase flow below
  (Phase 1 planning → Phase 2 execution). No mandatory Opus steps.
- **SIGNIFICANT / HIGH-RISK** —
  - Invoke `upgrade-planner` sub-agents with `model: claude-opus-4.8` (or the
    highest available per `_shared/model-routing.md` §2). Planning is done by
    Opus.
  - Phase 2 execution applies the change with the current model or Sonnet
    (`upgrade-executor`).
  - **NEW Phase 2.5 — Opus Code Review (gate before tests):** after the
    executor has applied changes but **before** `test-baseliner` `verify` runs,
    delegate a `code-review` sub-agent pinned to Opus with the §6 checklist
    from the shared doc. Address every BLOCKER and document every CONCERN.
  - Only after the review passes does the executor (or the orchestrator) run
    the test suite. Any review fixes are applied by the current model or
    Sonnet, then tests are re-run.
  - To gate tests, the orchestrator either (a) invokes the executor with
    `gate_tests_on_review: true` so it stops after the build, or (b) splits
    execution into two calls: apply-only first, review, then a second
    "verify-resume" call.

## Input format

```
upgrade: <token> [<token> ...]
```

Each token is one of:

| Token form | Meaning |
|---|---|
| `component:1.2.3` | Upgrade to exactly this version |
| `component:minor` | Latest patch release within the current major.minor line |
| `component:latest` | Absolute latest stable release |
| `component:lts` | Latest Long-Term Support release |
| `component` (no colon) | **Latest version compatible with everything else in the repo** |

`component` can be a library name, framework name, language runtime, build tool, or a file-system path (e.g. `.github/workflows`).

## Workflow

The workflow has two phases: **Compatibility planning** (no files are changed) followed by **Execution** (changes are applied one component at a time).

### Phase 1 — Compatibility planning (parallel, via `upgrade-planner` sub-agent)

1. **Inventory** — Detect all components and their current versions from build files, runtime version files, and CI YAML. See `references/ecosystems.md`. Produce a `repo_inventory` map (component → version).

2. **Spawn `upgrade-planner` sub-agents in parallel** — one per requested component.
   For each, build a plan request handoff (see `upgrade-planner/references/handoff.md`) including the full `repo_inventory`, the `other_upgrades` list, and the `model_routing` block from Phase 0. Use `/fleet` for parallel execution.
   For SIGNIFICANT/HIGH-RISK batches, invoke each planner with `model: claude-opus-4.8` (or highest available per `_shared/model-routing.md` §2).

3. **Collect results**:
   - `READY` plans → proceed to Phase 2.
   - `NOT_FOUND` → warn the user, mark the component as skipped.
   - `CONFLICT` → surface the conflict and `alternatives` to the user via `ask_user` with ranked choices. Honor the user's choice (lower version / upgrade blocker / skip). Update the plan record accordingly.

4. **Confirm plan** — If any version was auto-adjusted or companion upgrades were added, print the full resolved plan and ask the user to confirm before proceeding.

### Conflict resolution options

When a `CONFLICT` is returned, the `upgrade-planner` sub-agent provides ranked alternatives. Always present them to the user as-is — least-invasive first:

> **Option A** — Lower to the highest compatible version (e.g. "Use Gradle 8.13, compatible with Java 11")
> **Option B** — Upgrade the blocking dependency too (e.g. "Upgrade Java to 17 first, then Gradle 9 works")
> **Option C** — Skip this component entirely

### Phase 2 — Execution (sequential, via `upgrade-executor` sub-agent)

#### Phase 2 pre-steps (run once before any component is executed)

1. **Create upgrade branch**
   - Run `git status --porcelain`. If non-empty:
     - Show the user what is dirty.
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
     - **Stash**: `git stash push -m "pre-upgrade stash"`, then continue. **Cancel**: stop.
   - Generate the branch name. The prefix is selected per
     `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/branch-naming.md`
     (env var → git config → branch sniff → fallback). The workflow fallback
     for `upgrade:` is `chore/`. The slug portion is:
     - Single component: `upgrade-<component>-to-<version>` (e.g. `upgrade-springboot-to-3.3.11`)
     - Multiple components: `upgrade-<first>-and-<N>-more` (e.g. `upgrade-springboot-and-2-more`)
     Combined: `<prefix>/<slug>` (e.g. `ivgu/upgrade-springboot-to-3.3.11` if
     `GIT_USER_INITIALS=ivgu`, or `chore/upgrade-springboot-to-3.3.11` on fallback).
   - Check HEAD context: if HEAD is NOT on the default branch and has ahead commits (`git log origin/HEAD..HEAD --oneline 2>/dev/null` is non-empty), ask:
     ```
     ask_user(
       question: "You are on a non-default branch with local commits. Where should the upgrade branch start?",
       choices: [
         "Branch from current position (Recommended)",
         "Branch from default branch",
         "Cancel"
       ]
     )
     ```
   - Run `git checkout -b <branch-name>`. If it already exists, append the first 7 chars of HEAD SHA: `<branch-name>-<short-sha>`. Announce the branch name.

2. **Baseline** — Invoke `test-baseliner` sub-agent in `capture` mode (see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/test-baseliner/references/handoff.md`). Pass the returned result to all `upgrade-executor` invocations. If `status: RUN_FAILED` or `COMMAND_NOT_FOUND`, warn the user and ask whether to proceed without a test safety net.

#### Per-component loop (for each component, in order)

3. **Execute sequentially** — For each component with a `READY` plan (in the order requested), invoke the `upgrade-executor` sub-agent. Pass the upgrade plan + baseline results + the `model_routing` block. See `upgrade-executor/references/handoff.md` for the handoff format.
   - For **SIGNIFICANT / HIGH-RISK** batches: pass `gate_tests_on_review: true` so the executor stops after applying changes and the build step. The orchestrator then performs Phase 2.5 (Opus code review) before instructing the executor to proceed with `test-baseliner verify`.

4. **Phase 2.5 — Opus Code Review** *(SIGNIFICANT / HIGH-RISK only — gate before tests)*
   - Build the diff/summary of every file changed by the executor.
   - Invoke a `code-review` sub-agent pinned to Opus (`task` with
     `agent_type: "dev-workflows:code-review"`, `model: "claude-opus-4.8"` or highest
     available, `mode: "sync"`). Embed the §6 checklist from
     `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` in the prompt and require
     `OK | CONCERN | BLOCKER` per item.
   - **Invoke `review-fixer`** to apply BLOCKER+MAJOR findings:
     ```
     task(
       agent_type: "dev-workflows:review-fixer",
       mode:       "sync",
       description:"Apply review fixes for upgrade",
       prompt:     "<upgrade summary> + <full review output> + project root: <absolute path>"
     )
     ```
     Inspect the Fix Report's `Stop condition flag`:
     - `CLEAR` → proceed to step 5 (verify tests).
     - `NEEDS HUMAN` → surface deferred BLOCKERs to the user via `ask_user`. Do not
       proceed to tests until resolved. Run one re-review cycle; if still BLOCK, stop.
   - Document the disposition of every CONCERN.
   - Only then proceed to step 5.

5. **Verify tests** — Re-invoke `upgrade-executor` with `phase: verify-resume`
   AND the same `baseline` block (including `baseline.passing_tests`) captured
   in step 2, plus the original upgrade plan re-supplied verbatim — the
   sub-agent retains nothing across the AWAITING_REVIEW boundary and needs
   the plan for any test-regression auto-fixes. The executor will skip
   apply/build and resume at the Verify step. Apply regression fixes per the
   existing rules below; re-run tests if needed.

6. **Collect results** — Accumulate the summary rows returned by each executor sub-agent and print the final table (see "Output" below).

## Version resolution

### bare token (no specifier) — "latest compatible"

1. Fetch all stable versions from the registry.
2. Filter to versions compatible with every other component in the repo (both those being upgraded and those staying at their current version). See `references/compatibility.md`.
3. Select the highest version that passes all compatibility constraints.
4. If no version passes, report the conflict and follow "Conflict resolution options".

### `minor` (stay on current major.minor, get latest patch)

1. Read the current version from the build file.
2. Extract `MAJOR.MINOR`.
3. Query the package registry for all versions matching `MAJOR.MINOR.*`.
4. Select the highest stable (non-pre-release) patch version.

### `latest`

Fetch the highest stable release from the registry, then run a compatibility check (Phase 1, step 3) against the rest of the repo. If it is incompatible, treat it the same as a conflict: offer alternatives rather than blindly applying an incompatible version.

### `lts`

Consult the official LTS source for the technology. Use `web_fetch` on:

| Technology | LTS source URL |
|---|---|
| Java (JDK) | `https://api.adoptium.net/v3/info/available_releases` — field `most_recent_lts` |
| Node.js | `https://nodejs.org/dist/index.json` — latest entry with `lts != false` |
| Python | `https://endoflife.date/api/python.json` — latest entry where `eol` is in the future and it is an active LTS line |
| Ruby | `https://endoflife.date/api/ruby.json` |
| Go | `https://endoflife.date/api/go.json` |
| .NET | `https://endoflife.date/api/dotnet.json` |
| Any other | `https://endoflife.date/api/<product>.json` (substitute the product slug) |

If the lookup fails, ask the user for the target LTS version.

### `exact version` (e.g. `1.2.3`)

Use the version as-is. Verify it exists in the registry, then run a compatibility check against the rest of the repo before applying. If incompatible, report the conflict and present alternatives — **never silently downgrade or ignore an explicit version request**; always surface the incompatibility to the user.

## Handling test failures

If previously-green tests fail after an upgrade:

1. **Inspect** the failures — determine whether they are caused by a breaking API change in the upgraded component (e.g. a renamed class, changed method signature, removed annotation).
2. **Auto-fix test code** if the fix is straightforward (rename import, update assertion syntax, adjust configuration). Explain every test change in the summary.
3. If the failures cannot be auto-fixed, present them clearly and ask the user:
   > "These tests were passing before the upgrade. Would you like me to:
   > (1) Keep the upgrade and leave the failing tests for you to fix,
   > (2) Revert this upgrade and skip it,
   > (3) Investigate further before deciding?"
4. Honor the user's choice. If they choose (1), note the failing tests prominently in the final summary.

## Handling build failures

If the build fails after applying the upgrade:

1. Read the full error output.
2. Attempt an automatic fix (wrong API, missing plugin version, incompatible config).
3. If unfixable, revert the change for this component, warn the user, and continue with the next component.

## Special case: `.github/workflows` (GitHub Actions)

When the component is a directory path matching `**/.github/workflows` or similar CI/CD config paths:

1. Scan every `.yml`/`.yaml` file in the directory for `uses: owner/action@ref` declarations.
2. For each action, fetch the latest release tag from the GitHub API:
   ```
   GET https://api.github.com/repos/<owner>/<action>/releases/latest
   ```
   Use `gh api repos/<owner>/<action>/releases/latest --jq .tag_name` if `gh` CLI is available.
3. Replace the `@ref` with the latest tag (e.g. `actions/checkout@v3` becomes `actions/checkout@v4`).
4. Also update any pinned SHA references to match the new tag's HEAD commit.
5. Validate the updated YAML is syntactically correct.
6. There is no test suite to run for CI/CD files — instead, report a summary of every action upgraded and flag any action where the major version changed (potential breaking change).

## Output

After processing all components, print a summary table:

```
## Upgrade Summary

| Component       | Before  | After   | Status  | Notes                        |
|-----------------|---------|---------|---------|------------------------------|
| springboot      | 3.1.4   | 3.3.11  | OK      | Also upgraded hibernate 6.4  |
| java            | 17      | 21      | OK      | Updated 2 test files         |
| redis           | -       | -       | SKIPPED | Not found in project         |
| gradle          | 8.4     | 8.13    | OK      |                              |

Tests: 142 passed, 0 regressions (baseline: 142 passing)

### Model Routing
- Classification: <class>
- Reason: <trigger>
- Planning model: <model>
- Implementation model: <model>
- Review model: <model | "n/a — SIMPLE/MODERATE">
- Opus checklist verdicts (SIGNIFICANT/HIGH-RISK only): Correctness / Security / Architecture / Edge cases / Migration / Dependencies / Tests / Rollback
```

All changes are left **uncommitted** on the upgrade branch.

## Post-batch Maintenance

After printing the summary table, build a compact session handoff and invoke
`impl-maintenance`:

```markdown
## Implementation Summary
repo: <absolute path to repo root>
change_type: refactor
description: >
  Upgraded <component list> from <versions> to <versions>.
  <1–2 sentences on what changed and any notable compatibility work done.>
files_changed:
  - path: <relative path>
    summary: <what changed>
kb_context: >
  <Non-obvious compatibility gotchas, workarounds used, or ecosystem-specific
   findings from this upgrade. Leave blank if nothing notable.>
```

```
task(
  agent_type: "dev-workflows:impl-maintenance",
  mode:       "sync",
  description:"Post-upgrade maintenance",
  prompt:     "<handoff document above>"
)
```

Include the Maintenance Report in the final output under `### Knowledge Base`,
`### Instructions`, and `### Documentation`.

## Resources

- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` - Mandatory classification rubric, model fallback chain, and the Opus code-review checklist.
- `references/ecosystems.md` - Detection patterns, update commands, and registry query patterns for every supported ecosystem.
- `references/lts-sources.md` - LTS lookup reference for common runtimes and frameworks.
- `references/compatibility.md` - Known compatibility constraints between common components (Java, Gradle, Maven, Spring Boot, Node, etc.) and how to look up compatibility dynamically.
- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/upgrade-planner/references/handoff.md` - Input/output format for the `upgrade-planner` sub-agent.
- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/upgrade-executor/references/handoff.md` - Input/output format for the `upgrade-executor` sub-agent.
- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/test-baseliner/references/handoff.md` - Input/output format for the `test-baseliner` sub-agent.
