---
name: fix-vuln
description: >
  Automatically fix security vulnerabilities by updating affected dependencies.
  Triggered by the "vuln:" command followed by space-separated tokens.
  Each token is either JIRA-ID:VULN-ID (e.g. MGD-2423:CVE-2023-46604) or a bare VULN-ID (e.g. CVE-2023-46604) when no Jira ticket exists.
  Handles CVE IDs automatically by looking them up on NVD.
  Skips CWE and OWASP IDs with a warning.
  For each CVE: fetches the affected library, checks if it is used in the repo,
  finds the minimal safe version, runs baseline tests, applies the fix, rebuilds,
  re-runs tests, then commits to a new branch and opens a pull request.
  Use when the user wants to remediate one or more security vulnerabilities in the current repository.
allowed-tools: view, edit, create, bash, glob, grep, ask_user, sql
---

# Fix Vulnerabilities

## Overview

Fix one or more CVE vulnerabilities with the smallest possible dependency change, then open a PR per vulnerability.

> **Model routing is mandatory.** Before Step 1, this skill MUST classify the
> CVE batch per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` and follow the
> routing rules. See "Step 0 — Classify & Route" below.

## Workflow

### Step 0 — Classify & Route (mandatory)

Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`. Classify the CVE batch into
exactly one of: `SIMPLE`, `MODERATE`, `SIGNIFICANT`, `HIGH-RISK`.

Default classification heuristics for `vuln:` — **classify by the size of the
required fix, not by the CVE category alone**. Most CVE remediations are
just a patch/minor dependency bump and do not need Opus. Escalate only when
the fix is structurally non-trivial.

The orchestrator must therefore look up each CVE first (via `vuln-research`)
to know what change is actually required, then classify:

| Required fix (per `vuln-research` output)                                                        | → Class            |
|--------------------------------------------------------------------------------------------------|--------------------|
| Pure **patch** version bump (e.g. `1.4.5 → 1.4.6`), no source-code changes in the repo           | `MODERATE`         |
| Pure **minor** version bump (e.g. `1.4.x → 1.5.0`) within the same major, no source-code changes | `MODERATE`         |
| **Major** version bump required (e.g. `1.x → 2.0`)                                               | `SIGNIFICANT`      |
| Any source-code changes in the repo are required (API renamed, signature changed, deprecation removed, behaviour change to adapt to) | `SIGNIFICANT` |
| Major bump of a security-critical library (Spring Security, jwt-*, oauth/openid, jose, *crypto*, serializer/deserializer, web framework) **or** a major bump combined with required code changes in auth/session/token/permission/payment/audit code | `HIGH-RISK` |
| Batch containing any SIGNIFICANT or HIGH-RISK CVE                                                | classified **per-CVE**, not per-batch |

**Per-CVE classification.** Because `vuln-fixer` runs sequentially per CVE and
each CVE is committed on its own branch with its own PR, classification is
performed and recorded **per CVE**. A patch-only fix that happens to be in
the same `vuln:` invocation as a HIGH-RISK CVE is still MODERATE and does
not pay the Opus-review tax. Only the per-CVE class drives that CVE's
routing.

**When in doubt, escalate one level.**

> Do not pre-classify a CVE as HIGH-RISK just because its category is RCE,
> deserialization, auth bypass, SQL injection, etc. The CVE category drives
> *attention*, but the **classification is driven by the size of the required
> repository change**. A patch bump that fixes an RCE is still MODERATE.

Because classification depends on knowing the required fix, the orchestrator
performs Step 0 in two parts: an initial conservative provisional class
(`MODERATE`) is assigned, `vuln-research` runs, then the class is finalized
from the research output **before** Step 3 (Fix) begins. The finalized
`model_routing` block is what gets passed to `vuln-fixer`.

Build the `model_routing` block (format in `_shared/model-routing.md` §4) and
pass it to **every** sub-agent invocation (`vuln-research`, `vuln-fixer`,
`test-baseliner`).

### Routing consequences

> **Provisional → Finalized.** Because the class depends on what `vuln-research`
> finds, the orchestrator starts with a provisional `MODERATE` to run research,
> then **finalizes** the classification from the research output and applies
> the routing below to Step 3 (Fix) and Step 3.5 (Review).

- **SIMPLE / MODERATE (most CVEs — patch/minor bump, no code changes)** —
  proceed with the existing flow (Steps 1–4 below). No Opus required for
  research, fix, or review. This will be the common path.
- **SIGNIFICANT / HIGH-RISK (major bump or code changes required)** —
  - When the finalized class is **HIGH-RISK**, the orchestrator MUST re-run
    `vuln-research` on Opus (highest available per `_shared/model-routing.md`
    §2) for a confirming pass over the upgrade path and breaking-change
    surface. The provisional research output may be reused as a starting
    point but must be re-validated on Opus.
  - When the finalized class is **SIGNIFICANT** (major bump or code changes
    required, but not in a security-critical library), the orchestrator
    SHOULD re-run `vuln-research` on Opus when a major bump is involved or
    when the breaking-change surface is non-trivial; otherwise the original
    research output may be carried forward.
  - Either way, the final `model_routing.notes` MUST record whether research
    was re-run on Opus and why / why not.
  - Step 3 fix application proceeds with the current model or Sonnet.
  - **NEW Step 3.5 — Opus Code Review (gate before tests):** after
    `vuln-fixer` has applied the change(s) and the build succeeds but
    **before** the `test-baseliner verify` runs, delegate a `code-review`
    sub-agent pinned to Opus with the §6 checklist. Address every BLOCKER and
    document every CONCERN.
  - Only after the review passes does `vuln-fixer` (or the orchestrator) run
    the test suite. Any review fixes are applied by the current model or
    Sonnet, then tests are re-run.
  - To gate tests, the orchestrator passes `gate_tests_on_review: true` to
    `vuln-fixer` so it stops after the build, performs the review, then
    instructs `vuln-fixer` to proceed with verify and PR.

### Step 1 — Prepare (orchestrator)

1. **Parse** all input tokens — extract Jira ID (optional) and CVE ID from each.
   - `JIRA-ID:VULN-ID` (e.g. `MGD-2423:CVE-2023-46604`) → with Jira
   - bare `VULN-ID` (e.g. `CVE-2023-46604`) → no Jira ticket
   - A token is "bare VULN-ID" when it has no colon **or** the part before the colon does not match `[A-Z]+-\d+`.
2. **Determine no-Jira placeholder** (once): scan `git log --oneline -50` and `git branch -a` for `NOJIRA`/`NO-JIRA` patterns. Use the project's convention or omit entirely.
3. **Filter** non-CVE IDs (CWE-*, OWASP `\d{4}:A\d`): warn the user and remove from the batch.
4. **Snapshot repo inventory**: note primary language/ecosystem to include in the research handoff.

### Step 2 — Research (parallel, via `vuln-research` sub-agent)

For each valid CVE, build a research handoff (see `vuln-research/references/handoff.md`) and invoke the `vuln-research` sub-agent. All CVEs can be researched in parallel — use `/fleet` when multiple CVEs are present.

Collect all research reports. For each result:
- `READY` → proceed to Step 3.
- `NOT_IN_REPO` → notify user: "CVE-XXXX not applicable — library not found in this repo."
- `LOOKUP_FAILED` → warn user; offer to retry or skip.
- `SKIP_NON_CVE` → already warned in Step 1; nothing further.

### Step 3 — Fix (sequential, via `vuln-fixer` sub-agent)

For each CVE with research `status: READY`, invoke the `vuln-fixer` sub-agent **sequentially** (one at a time, to avoid conflicting edits to the same build files). Pass the research report + repo path + no-Jira placeholder + the **per-CVE** `model_routing` block finalized in Step 0 (each CVE carries its own classification — do not collapse them).

For **SIGNIFICANT / HIGH-RISK** CVEs:

1. **Capture the baseline yourself before invoking the fixer.** Call
   `test-baseliner` in `capture` mode and keep the full result (the
   `passing_count` AND the `passing_tests` list). The orchestrator must own
   this baseline — it is needed again on the verify-resume call after the
   Opus review, and a sub-agent invocation is stateless.
2. Pass the captured baseline to `vuln-fixer` as
   `baseline_tests: provided` + `baseline_passing` + `baseline.passing_tests`,
   plus `gate_tests_on_review: true`. The fixer will skip its own baseline
   step, apply the fix, build, and stop with `status: AWAITING_REVIEW`.
3. Run Step 3.5 (Opus code review).
4. Re-invoke `vuln-fixer` with `phase: verify-resume` AND the same
   `baseline.passing_tests` list (so `test-baseliner verify` can detect
   regressions exactly), plus the original research report re-supplied
   verbatim — the sub-agent retains nothing across the AWAITING_REVIEW
   boundary and needs the report to render the commit message and PR body.
   The fixer will resume at Verify, then commit + PR.

For **SIMPLE / MODERATE** CVEs the orchestrator may continue to delegate
baselining to the fixer (`baseline_tests: run-fresh`) since there is no
gating boundary.

See `vuln-fixer/references/handoff.md` for the handoff format.

### Step 3.5 — Opus Code Review (SIGNIFICANT / HIGH-RISK only — gate before tests)

1. Build the diff/summary of every file changed by the fixer for this CVE.
2. Invoke a `code-review` sub-agent pinned to Opus:
   ```
   task(
     agent_type: "dev-workflows:code-review",       # fall back to "general-purpose" if unavailable
     model:      "claude-opus-4.8",   # or highest available per _shared/model-routing.md §2
     description:"Opus review of CVE fix",
     mode:       "sync",
     prompt:     "<CVE summary> + <diff> +
                  Use the §6 checklist from ~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md.
                  For each item return: OK | CONCERN | BLOCKER + comment."
   )
   ```
3. **Invoke `review-fixer`** to apply BLOCKER+MAJOR findings:
   ```
   task(
     agent_type: "dev-workflows:review-fixer",
     mode:       "sync",
     description:"Apply review fixes for CVE fix",
     prompt:     "<CVE summary> + <full review output> + project root: <absolute path>"
   )
   ```
   Inspect the Fix Report's `Stop condition flag`:
   - `CLEAR` → proceed to step 4 (document CONCERNs, then instruct fixer to continue).
   - `NEEDS HUMAN` → surface deferred BLOCKERs to the user via `ask_user`. Do not
     proceed to tests until resolved. Run one re-review cycle; if still BLOCK, stop.
4. Document the disposition of every CONCERN.
5. Instruct `vuln-fixer` to proceed with `test-baseliner verify`, then commit + PR.

### Step 4 — Summarise

After all CVEs are processed, print a result table:

```
| CVE              | Library               | Change          | Result  | PR  |
|------------------|-----------------------|-----------------|---------|-----|
| CVE-2023-46604   | activemq-broker       | 5.15.5→5.15.16  | OK      | #42 |
| CVE-2024-99999   | (not in repo)         | —               | SKIP    | —   |
```

Append a `### Model Routing` section per `_shared/model-routing.md` §7 with the
classification, reason, models used at each step, and (for SIGNIFICANT/HIGH-RISK)
the per-item Opus checklist verdicts.

### Post-batch Maintenance

After printing the result table, build a compact session handoff and invoke
`impl-maintenance`:

```markdown
## Implementation Summary
repo: <absolute path to repo root>
change_type: security
description: >
  Fixed <CVE list> by upgrading <library list>. <1–2 sentences on scope,
  any code changes required, or notable compatibility work.>
files_changed:
  - path: <relative path>
    summary: <what changed>
kb_context: >
  <Non-obvious findings: ecosystem-specific gotchas, API changes required,
   test regressions and how they were fixed. Leave blank if nothing notable.>
```

```
task(
  agent_type: "dev-workflows:impl-maintenance",
  mode:       "sync",
  description:"Post-CVE-fix maintenance",
  prompt:     "<handoff document above>"
)
```

Include the Maintenance Report in the final output under `### Knowledge Base`,
`### Instructions`, and `### Documentation`.

## Handling Test Failures After Fix

If the fix causes previously-green tests to fail and a quick investigation does not reveal an obvious fix (e.g., the new version changed an API):

- Present the failing tests clearly.
- Ask the user: "These tests were passing before. Would you like me to (1) apply the fix anyway and flag the failures in the PR description, (2) revert the fix, or (3) investigate further?"
- Honor the user's choice.

## Git Workflow

### Branch naming

Inspect recent git history (`git log --oneline -50`) and existing branches (`git branch -a`) to match the project's naming convention. The branch **prefix** is selected per
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/branch-naming.md`
(env var `GIT_USER_INITIALS` → `git config user.initials` → branch sniff →
workflow fallback). The workflow fallback for `fix-vuln:` is `fix/`.

**When a Jira ID is present**, the slug default is:
```
<JIRA-ID>-<CVE-ID>
```
Combined with prefix: `<prefix>/<JIRA-ID>-<CVE-ID>`.
Example: `fix/MGD-2423-CVE-2023-46604` (fallback) or `ivgu/MGD-2423-CVE-2023-46604` (with `GIT_USER_INITIALS=ivgu`).

**When no Jira ID is provided**, use the placeholder determined in step 1 (Parse):
```
<NOJIRA-CVE-XXXX-XXXXX>   (if the project uses NOJIRA)
<CVE-XXXX-XXXXX>           (if the project omits issue keys)
```
Combined with prefix: `<prefix>/<slug>`.

### Commit message

Use the project's existing style (check recent commits). Default template:

**With Jira ID:**
```
fix(deps): upgrade <library> to <version> to remediate <CVE-ID>

Resolves <JIRA-ID>
Fixes <CVE-ID> - <one-line CVE description>

Vulnerable range: <range>
Safe version: <version>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

**Without Jira ID** (omit the `Resolves` line entirely, or substitute the placeholder if the project uses one):
```
fix(deps): upgrade <library> to <version> to remediate <CVE-ID>

Fixes <CVE-ID> - <one-line CVE description>

Vulnerable range: <range>
Safe version: <version>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

### PR

- **Base branch**: `main` (fall back to `master` if `main` does not exist).
- **Title**: `fix(deps): <library> upgrade to remediate <CVE-ID>` (append ` [<JIRA-ID>]` only when a Jira ID is present)
- **Body**: Include CVE summary, vulnerable range, the version change made, and test result summary (pass count before vs. after).

## Resources

- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` - Mandatory classification rubric, model fallback chain, and Opus code-review checklist.
- `references/nvd-api.md` - NVD REST API usage, response structure, and how to extract affected packages and version ranges.
- `references/build-systems.md` - Per-ecosystem patterns for detecting libraries and updating version pins (Gradle, Maven, npm, pip, Go modules, etc.).
- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/vuln-research/references/handoff.md` - Input/output format for the `vuln-research` sub-agent.
- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/vuln-fixer/references/handoff.md` - Input/output format for the `vuln-fixer` sub-agent.
- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/test-baseliner/references/handoff.md` - Input/output format for the `test-baseliner` sub-agent.
