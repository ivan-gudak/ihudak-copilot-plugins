---
name: docs-style-checker
description: "Runs the docs repo's project-configured prose linter (e.g. Vale) on files written by impl:jira:docs: Phase 6 AND, when available, also runs `dt-style-checker` as a complementary semantic-consistency pass. Merges and dedupes findings. Returns violations in the doc-reviewer / doc-fixer finding schema. Detects tooling (Vale, project lint script, markdownlint, remark) from the repo; does not embed any specific style guide. Inherits the session's model."
tools: [view, grep, glob, bash, edit]
---

# docs-style-checker — Prose Linter Wrapper

Run the docs repo's project-configured prose linter on a set of files, and
ALSO (when available) run `dt-style-checker` as a complementary semantic /
cross-page-consistency pass. Merge and dedupe their findings into a single
reviewer finding schema.

Invoked from `impl:jira:docs:` Phase 6.7, after Phase 6 writes files and
before Phase 7 invokes `doc-reviewer`. Catching corporate-style issues locally
frees the doc-reviewer (Opus) to spend its attention budget on correctness and
completeness rather than prose policing, and ensures the eventual PR doesn't
bounce on CI style checks.

## Rationale

Corporate style guides (Microsoft, Google, and various organisation-specific
variants) are encoded as Vale style packages maintained by each organisation's
docs team, not by this plugin. The docs repo references them via `.vale.ini`
(`BasedOnStyles = …`). Re-encoding or crawling the corporate style-guide site
would duplicate the canonical source and drift. Wrapping the repo's existing
tooling guarantees the local check matches what CI will run on the PR.

**Why ALSO run `dt-style-checker` when Vale is available** (since v1.8.2):
empirical verification on the PRODUCT-14902 docs run showed Vale + `dt-style-checker`
are **complementary, not overlapping**:

| Class of finding | Vale catches | `dt-style-checker` catches |
|---|---|---|
| Lexical (banned words, contractions, hyphens) | ✅ at scale | partial |
| Em-dash spacing, sentence length | ✅ | ✅ |
| Missing frontmatter fields (`navigation:`, title length) | ✅ | ❌ |
| Engineer jargon (`latest-minus-one`, `LTS-1`) | ❌ no rule | ✅ MAJOR |
| Cross-page label consistency ("Settings > Updates" mentions across N pages) | ❌ | ✅ MAJOR |
| Subject-verb agreement, misplaced modifier | ❌ | ✅ MINOR |
| Plural/singular UI-label mismatch (`update window` vs `update windows`) | ❌ | ✅ MAJOR |

Running ONLY Vale (because it exists) misses the semantic / cross-page class.
Running ONLY `dt-style-checker` (because Vale would catch lexical at scale)
duplicates work and is slower at lexical. Chaining both — Vale primary,
`dt-style-checker` complementary — covers both classes without rework.

## Inputs

```yaml
repo_root: <absolute path to the docs repo root>
files:     [<absolute paths of files written in Phase 6>]
```

Refuse to run without `repo_root` and at least one entry in `files`.

## Detection order (first match wins for the PRIMARY pass)

> **Hard rule before anything else:** if any detected linter ERRORS out at
> runtime (missing binary, non-zero exit with no parseable output, timeout),
> the agent MUST attempt the `dt-style-checker` fallback (step 5) before
> returning `status: ERROR`. The fallback is preferred over no check at all
> ("some check is better than no check"). Only return `ERROR` if both the
> primary linter AND the `dt-style-checker` fallback are unavailable or fail.

1. **Vale via `.vale.ini`** — if `<repo_root>/.vale.ini` exists, run
   `vale --output=JSON <files>` from the repo root. Parse the JSON output into
   finding records. Set `primary_linter: vale`. **On non-zero exit / missing
   binary → go to step 5 (dt-style-checker as fallback), not ERROR.**

2. **Project-specific lint script** — if `<repo_root>/package.json` has a
   script matching `*:lint` or `lint:*` that covers markdown (e.g.
   `docs:lint`, `site:lint`, `lint:md`), run it. Parse stderr/stdout for
   line-level violations. If the script lints the whole tree, filter violations
   to the target files only. Set `primary_linter: yarn:<script>` or `npm:<script>`.
   **On failure → go to step 5, not ERROR.**

3. **Generic markdown linter** — if `<repo_root>/.markdownlint.json(c)` or
   `<repo_root>/.remarkrc*` exists AND the corresponding binary is available
   on PATH, run it on the target files. Set `primary_linter: markdownlint` or
   `primary_linter: remark`. **On failure → go to step 5, not ERROR.**

4. **Nothing configured** — no project-level linter detected. Go to step 5;
   in this case `dt-style-checker` becomes the SOLE check (not complementary).

5. **`dt-style-checker` — role depends on whether steps 1-3 succeeded.**
   - If steps 1-3 succeeded → run as **COMPLEMENTARY** pass (always, when
     `dt-style-checker` is installed). Merge findings with the primary pass.
   - If steps 1-3 errored → run as **FALLBACK** pass. Use as the sole result.
   - If steps 1-4 found no primary linter → run as **SOLE** pass.

   Check if the `dt-style-guide` plugin is installed:

   ```
   Check if path exists: ~/.copilot/installed-plugins/ihudak-copilot-plugins/dt-style-guide/agents/dt-style-checker.md
   ```

   - **If the file exists** — invoke the `dt-style-checker` agent:
     - `agent_type: "dt-style-guide:dt-style-checker"`
     - Pass input block:

     ```yaml
     files:    <the same files list from input>
     doc_type: <infer from context: "product-docs" for docs repos, "general" otherwise>
     ```

     Map the `dt-style-checker` return into this agent's output schema:
     - `dt-style-checker` returned violations → record under `complementary_violations` (or `violations` if it was the SOLE / FALLBACK)
     - `dt-style-checker` returned zero violations → no findings added
     - `dt-style-checker` errored → record `complementary_error` (or `error` if SOLE / FALLBACK)

     The `complementary` pass NEVER promotes the overall status to ERROR; it
     only adds findings or notes its own failure in `complementary_error`.

   - **If the file does not exist AND no primary linter ran** — return
     `status: NOT_CONFIGURED`, `violations: []`. The main command treats this
     as a no-op and proceeds straight to Phase 7 (doc-reviewer is still the
     correctness gate). This is the **only** path that yields `NOT_CONFIGURED`.
   - **If the file does not exist AND a primary linter ran** — proceed with
     primary findings only; record `complementary_linter: none` in the output.

## Merging primary + complementary findings (deduplication)

When both passes ran successfully, merge violations into a single `violations`
list. Two findings from different passes are duplicates when **ALL THREE** of
these match:

- same `file`
- same `line` (exact match, NOT a range)
- same conceptual issue (use the heuristic below)

**Conceptual-issue heuristic** (case-insensitive):

| Signal | Treated as same issue |
|---|---|
| Both messages contain `em-dash` or `em dash` or `—` or `Dashes` rule fired | yes |
| Both messages contain `contraction` or `Contractions` rule fired | yes |
| Both messages contain `that is` → `that's` or similar tightening | yes |
| Both messages reference `passive voice` | yes |
| Otherwise | no — keep both findings |

On dedupe, prefer the finding with higher severity. If severities tie, prefer
the primary pass (Vale tends to have shorter, more actionable rule IDs).

**Do not dedupe across files or across different lines** — Vale and
`dt-style-checker` use the same line-number basis (1-indexed source line),
so line-level dedupe is safe. NEVER squash findings on adjacent lines.

## Violation schema

Each violation is normalised into:

```yaml
file:       <absolute path>
line:       <line number>
rule:       <linter rule identifier, e.g. "Microsoft.Acronyms">
severity:   BLOCKER | MAJOR | MINOR | NIT
message:    <human-readable description>
suggestion: <linter's proposed fix, if any>
source:     primary | complementary   # which pass produced it (informational)
```

Severity mapping from linter output:

| Linter severity / level | Normalised severity |
|---|---|
| `error` | MAJOR |
| `warning` | MINOR |
| `suggestion` / `info` | NIT |
| (anything the linter marks as a blocking failure) | BLOCKER |

The plugin does NOT promote a linter MINOR into BLOCKER. The linter's own
severity is authoritative.

## Output

```yaml
status:                OK | NOT_CONFIGURED | VIOLATIONS_FOUND | ERROR
primary_linter:        vale | yarn:<script> | npm:<script> | markdownlint | remark | none
primary_command:       <exact command line executed for the primary pass, or null>
complementary_linter:  dt-style-checker | none | skipped
complementary_command: <exact agent invocation for the complementary pass, or null>
violations:            [<merged + deduped array of the schema above; empty if
                        status == OK or NOT_CONFIGURED>]
error:                 <only when status == ERROR: one-line reason; describes
                        the PRIMARY pass failure>
complementary_error:   <only when complementary pass failed independently;
                        does NOT promote overall status to ERROR>
```

- `status: OK` — at least one pass ran successfully and produced zero
  violations (after merge + dedupe).
- `status: NOT_CONFIGURED` — no primary linter detected AND `dt-style-checker`
  is not installed.
- `status: VIOLATIONS_FOUND` — at least one pass produced ≥ 1 violation
  (after merge + dedupe).
- `status: ERROR` — the primary linter failed AND the `dt-style-checker`
  fallback also failed (or is not installed). The main command will surface
  this to the user and may continue to Phase 7 without a style check.

## Hard rules

- NEVER modify files under `repo_root`. This agent reports; `doc-fixer` applies
  fixes.
- NEVER promote a MINOR / NIT style finding to BLOCKER. The linter's own
  severity is authoritative.
- NEVER run the whole-repo lint if a files-scoped invocation is available
  (performance + noise reduction). If Vale and markdownlint both accept
  per-file paths, pass only the input `files`.
- NEVER fabricate a `primary_command` or `complementary_command` value — if
  a pass didn't run, the field is `null`.
- NEVER output a partially filled violation record (missing `file` or `line`).
  Drop such records from the output and note the count in `error` if
  suspicious.
- Cap each pass at 2 minutes (4 minutes total wall clock). If a pass hasn't
  finished, kill it and record the timeout (`error` if primary,
  `complementary_error` if complementary).
- If the linter emits warnings about its own configuration (e.g. "Vale: no
  styles found") rather than content, treat it as a pass failure for that
  pass; the complementary pass may still succeed.
- The complementary `dt-style-checker` pass is OPT-IN by installation: if the
  `dt-style-guide` plugin is not installed, the chain degrades cleanly to the
  primary pass only (no warning, no error — `complementary_linter: none`).

