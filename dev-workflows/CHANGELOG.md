# Changelog

All notable changes to the **dev-workflows** plugin are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow semver at the plugin level.

## [2.1.1] — 2026-07-15

### Changed
- **README overhaul, brought up to the Claude Code edition's documentation depth (docs-only).** Added a `## Workflow overview` section (mermaid PM/PA/PE/Dev/QA role-graph of the `idea:` → `create-vi:` → `create-ard:` → `epics:`/`specify:` → `design:` → `implement:` → `document:` → `release-notes:` pipeline, an annotation table, a "Sources of truth & artifact homes" note, and a "Cross-cutting skills" subsection) and an `implement: workflow` phase-flow mermaid diagram, both adapted to this edition's keyword-trigger skill names, strong-tier (Opus/GPT-5.5) model set, and `task()` dispatch — with no cost/statusline nodes, since those are not ported. Expanded the grouped sub-agent name list into a full 30-row `| Agent | Model | Description |` table, correcting the model column to reflect this edition's reality: sub-agents have no `model:` frontmatter pin — the strong tier is passed by the caller at each `task()` call site. Added a `## Reference docs` catalog of the 38 `skills/_shared/*.md` files, an `## Architecture (ARD) consumption` section, a `## Dependencies & companions` section, a trimmed `## Session feedback` section (no session-cost), and expanded `## Hooks` into a table (4 hooks, including the previously-undocumented `test-notify`).
- Root `README.md` — added a `## Prerequisites` section, an environment-variable configuration step (`VAULT_PATH` / `SPECS_PATH` / `REPOS_PATH`, confirmed load-bearing across `skills/_shared/*.md` but previously undocumented at the marketplace level), and a `## Runtime directories` section, mirroring the sibling `ihudak-claude-plugins` marketplace's root README.

### Fixed
- **Root `README.md` Plugins table described the retired `/impl` / `/fix-vuln` taxonomy (docs-only).** The `dev-workflows` row still read "`/impl` for feature implementation, `/fix-vuln` for CVE remediation, `/upgrade` for dependency upgrades" — the pre-1.4.0 command surface, not the current 19-skill lifecycle. Replaced with an accurate summary; also refreshed the stale `skills/impl/`, `fix-vuln/` example paths in the "Repository structure" tree.

## [2.1.0] — 2026-07-14

### Changed
- **`release-notes-writer` — editorial shaping (enhancement).** The writer no
  longer defaults to a flat "2–4 sentence paragraph" for every entry. Process
  step 3 now instructs conditional shaping grounded in shipped dynatrace-docs
  feature-updates: prose stays the default, but when a feature **enumerates
  discrete options** (e.g. a new dropdown with N selectable values) the writer
  uses a short intro sentence + a **bulleted list** (bold each option); it leads
  with the recommended/new default path and **demotes deprecated or manual-only
  options** to a trailing sentence or an optional `> Note:` line rather than
  presenting them as equal peers; and it uses **bold** for UI/field names and
  inline `code` for filenames, identifiers, and flags. The
  `release-notes-writer` handoff schema's `prose` field description was relaxed
  to match (no longer contradicts the agent by mandating a single paragraph).
  Motivation: a real release note enumerating four container-registry options
  read better as a list with the deprecated option footnoted than as a
  comma-chained paragraph.

## [2.0.1] — 2026-07-14

Port of the upstream Claude Code `dev-workflows` **v2.31.0 audit-fix batch** into
the Copilot edition. The Copilot port was based on Claude v2.30.0 (pre-fix) and had
inherited the same latent defects. Each finding was cross-checked against the
Copilot tree and fixed in a GitHub-Copilot-CLI-compatible way. No behavioural
triggers changed.

### Fixed
- **`test-baseliner` dual-schema (BLOCKER)** — the agent now emits a top-level
  `**Status**:` field in both the capture (`## Test Baseline`) and verify
  (`## Test Verify Report`) blocks, so `vuln-fixer` / `upgrade-executor`
  status-branching is no longer dead.
- **Sub-agent `ask_user` misuse** — `vuln-fixer` and `upgrade-executor` no longer
  claim to prompt the user directly (a sub-agent can't in Copilot CLI). On a test
  regression they now return `status: TEST_REGRESSION` + diagnosis; the orchestrator
  asks the user and re-invokes with `phase: regression-resume` + `regression_decision`
  (mirrors the existing verify-resume handshake). Added the missing "Handling Test
  Failures" section to `upgrade:`.
- **`implement:`** — removed stale `general-purpose` + `model: opus` override prose
  that contradicted the actual dispatch; renamed the mis-labelled "Pre-Phase 2" to
  "Phase 1.6" (it sits between 1.5 and 1.7).
- **`document:`** — renumbered Phase 0 steps (were skipping step 2) and fixed all
  cross-references; repointed dead "Increment 2/3" pointers to concrete phases
  (4.5 / 5.7 / 5.9).
- **`epics:`** — swapped the inverted Phase 6.1 (clarifications) / 6.2 (style-check)
  labels and fixed a residual stale cross-reference.
- **`upgrade-planner`** — corrected a false "pinned to Opus" claim (it runs on the
  detection chain).
- **`doc-writer`** — changelog rule now correctly says "no Jira key"; added `bash`
  to `tools:` so it can copy local screenshots.
- **`doc-fixer`** — finding field aligned to the message-based schema (`message`).
- **`create-ard`** — VI-level `jira-reader` fallback is now a formal `task()` block
  with `depth`; annotated in the model-routing comment.
- **`idea`** — carry-forward now includes `source_refs` / `provenance`.
- **`readiness-reviewer` + `workflow-states`** — `CONCERN` vocabulary unified to `MINOR`.
- **`api-guideline-reviewer`** — removed a self-contradictory "never use a subset"
  instruction.
- **`guideline-reviewer`** — gated the dt-app MCP lookup section on MCP availability
  (the agent's `tools:` grant no MCP).
- **Handoff schema drift** — `jira-reader` (`branch_from`/`branch_to`),
  `impl-maintenance` (Command enum extended to 12: `idea:`, `create-vi:`,
  `create-ard:`, `ready:`), `release-notes-writer` (`code_repos` input +
  `jira_phrasing`/`source_phrasing`/`source_location` gap fields), and the
  `code-scanner` / `diff-summarizer` inline `## Output` sections (now match their
  handoff SSOTs — `prep:` block, per-PR fields).
- **Citations** — normalised bare path references to the full
  `~/.copilot/installed-plugins/…` prefix (`pre-lint.md`,
  `release-notes-writer` handoff) and broadened the `jira-reader` `NOT_FOUND`
  description to cover both resolution forms.

### Skipped (not applicable to Copilot)
- Cost / statusline features (intentionally absent from the Copilot edition).
- The "Skill in allowed-tools" finding — Copilot reads `model-routing.md` via `view`,
  not a Skill-tool invocation.



Major re-sync with the upstream Claude Code `dev-workflows` plugin (v2.30.0),
which had evolved into a full product-development lifecycle while this Copilot
edition fell behind. **Breaking**: triggers flattened and renamed.

### Added
- **Product-development lifecycle skills** ported from Claude Code: `idea:`,
  `create-vi:`, `create-ard:`, `specify:`, `design:`, `epics:`, `release-notes:`,
  `ready:`, `docs-profile:`, `feedback:`, `prompt:`, `prompt-brainstorm:`,
  `prompt-grill-me:`.
- **11 new sub-agents**: `idea-reader`, `vi-reviewer`, `ard-reviewer`,
  `spec-reviewer`, `design-reviewer`, `readiness-reviewer`, `doc-writer`,
  `epic-writer`, `release-notes-writer`, plus the extracted `api-guideline-reviewer`
  and `guideline-reviewer` review agents (the reviewer skills are now thin
  dispatchers). Total sub-agents: 30.
- **`dynatrace-docs/` reference bundle** and 10 handoff schemas consolidated under
  `skills/_shared/handoff/`.
- **GPT-5.5 added to the strong model tier** as a peer of Opus 4.8/4.7/4.6
  (GPT models were unavailable in Claude Code, so the upstream used Opus only).

### Changed — BREAKING
- **Triggers flattened and renamed**:
  - `impl:code:` / `impl:` → **`implement:`**
  - `impl:docs:` and `impl:jira:docs:` → **`document:`** (dual-mode)
  - `impl:jira:epics:` → **`epics:`**
  - `fix-vuln:` → **`vuln:`**
- Reviewer skills (`api-guideline-reviewer`, `guideline-reviewer`) split into thin
  dispatcher skills + dedicated review agents holding the logic.
- Target/global instruction-file references updated from `CLAUDE.md` /
  `~/.copilot/CLAUDE.md` to `.github/copilot-instructions.md` /
  `~/.copilot/copilot-instructions.md` throughout.

### Removed
- Legacy skills `impl`, `impl-dispatcher`, `impl-docs`, `impl-jira`, `fix-vuln`
  and 9 orphaned sub-agent handoff directories.
- **Session cost reporting** (`/statusline`, `emit-cost`, cost-emission refs) and
  **statusline integration** — intentionally not ported; GitHub Copilot CLI
  exposes no cost/usage API or statusline extension point.

## [1.8.2] — 2026-06-16

### Changed
- **`docs-style-checker` — Vale + `dt-style-checker` now run as a
  COMPLEMENTARY chain, not a fallback-only relationship.** Empirical
  verification on the PRODUCT-14902 docs run showed the two checkers
  catch different classes of issue:

    | Class of finding | Vale catches | `dt-style-checker` catches |
    |---|---|---|
    | Lexical (banned words, contractions, hyphens) | ✅ at scale | partial |
    | Frontmatter completeness (`navigation:`, title length) | ✅ | ❌ |
    | Engineer jargon (`latest-minus-one`, `LTS-1`) | ❌ no rule | ✅ |
    | Cross-page label consistency | ❌ | ✅ |
    | Subject-verb agreement, misplaced modifier | ❌ | ✅ |
    | Plural/singular UI-label mismatch | ❌ | ✅ |

  Running ONLY the primary linter misses the semantic / cross-page class.
  As of v1.8.2, when Vale (or another primary linter) runs successfully,
  `dt-style-checker` ALSO runs as a complementary semantic pass; both
  finding sets are merged with line-level dedupe. When the primary linter
  fails, `dt-style-checker` continues to serve as the fallback (v1.7.0
  behaviour preserved). When the `dt-style-guide` plugin isn't installed,
  the chain degrades cleanly to the primary pass only.
- **`docs-style-checker` output schema v3.** Old fields (`linter`,
  `command`) are renamed to `primary_linter` / `primary_command` and new
  fields are added: `complementary_linter`, `complementary_command`,
  `complementary_error`. Each violation record now carries a `source:`
  field (`primary` | `complementary`) for traceability. Callers that
  parsed the old schema by string-matching `linter:` need to update.
- **`impl-jira` Phase 6.7 and `impl-docs` Phase 3.4 hard-rule text
  expanded** to describe the chained behaviour. Removed a stale
  duplicate `ERROR` heading block in `impl-jira/SKILL.md` that was
  introduced during the v1.7.0 edit.

### Fixed
- **Bug discovered during PRODUCT-14902 Vale-verification round:** when
  Vale was available, `dt-style-checker` was completely skipped — even
  though it catches semantic / cross-page issues Vale doesn't have rules
  for (the v1.7.0 rationale of "fallback only" was based on the wrong
  assumption that Vale was a superset). The chain now ensures
  high-confidence semantic findings (jargon, UI-label consistency,
  subject-verb agreement) are not silently dropped when Vale exists.

## [1.8.1] — 2026-06-16

### Fixed
- **`doc-planner` — no Jira keys in `changelog:` entries.** New hard rule:
  proposed `frontmatter_updates.changelog.entry` text MUST NOT embed the
  Jira key (e.g. `(PRODUCT-14902)` suffix). The Jira reference is carried
  by the commit message and the file diff, not by the customer-visible
  page changelog. Verified against `dynatrace-docs`: fewer than 5 of
  5500+ pre-existing changelog entries cite an issue key — basically
  zero convention support. Caught during PRODUCT-14902 review where
  v1.8.0 added `(PRODUCT-14902)` to 5 changelog entries.
- **`doc-planner` — cross-product reciprocal touches stay product-scoped.**
  New hard rule: when a "minimal touch" target is on an existing page
  belonging to product X but the change is about a feature shipped by
  product Y, the writer's note must be a one-line cross-link to product
  Y's dedicated page — NOT a copy of product Y's implementation detail
  (throttling rules, enum values, precedence, etc.). Caught during
  PRODUCT-14902 review where v1.8.0 added per-pool ActiveGate
  throttling detail to the OneAgent update page (OneAgent has no
  per-pool throttling; readers don't need that depth on the OA page).

## [1.8.0] — 2026-06-16

### Changed (breaking for callers that depended on auto-corrected docs)
- **`_shared/source-truth.md` principle shift: plugin is the analyst,
  user is the decision-maker.** Replaces the v1.7.0 "Implementation >
  Description (code wins, always)" rule with a discrepancy-escalation
  protocol. When source and description disagree, the plugin presents
  the analysis to the user as a table and asks per-discrepancy whether
  to:
    - document as source suggests (match what shipped)
    - document as Jira claims (with an intentional-discrepancy marker
      + bug-report draft so the user can file a defect against the
      implementation team)
    - skip and report (omit from docs + record in bug-report draft)
  The user's PM/sprint/scope context is the deciding factor — not the
  plugin's keyword grep.
- **`doc-planner` no longer rewrites topic notes to match the source.**
  The planner now records both `jira_phrasing` and `source_phrasing`
  in `verification_warnings[]` and leaves the decision to the
  orchestrator + user (per `_shared/source-truth.md` §7). Pre-v1.8.0
  callers that expected the planner to silently correct claims will see
  the original phrasing preserved until Phase 5.8 resolves it.
- **`verification_warnings` schema v2.** Fields renamed/added:
    - `claim` (preserved)
    - `jira_phrasing` (new, verbatim)
    - `source_phrasing` (new, verbatim — "(not verifiable)" when no
      source evidence)
    - `source_location` (replaces `source_checked`)
    - `technique` (added `menu-builder`, `no-source-evidence`)
    - `finding` (added `AMBIGUOUS`; renamed semantic meaning of
      `NOT_FOUND` to specifically signal implementation-gap)
    - `number` (new, stable index for cross-reference)
    - Removed: `correction`, `recommended_action` (decisions are now
      the orchestrator's responsibility, not the planner's)

### Added
- **`impl-jira` Phase 5.8 — Discrepancy analysis & user decision.**
  New phase that runs after doc-planner (Phase 5.7) when there are
  CONTRADICTED / NOT_FOUND / AMBIGUOUS warnings. Presents an analysis
  table to the user, asks for a batch decision OR per-discrepancy
  decisions, builds a `discrepancy_decisions[]` record, and sets
  `bug_report_destination` if any decisions need a bug-report draft.
- **`impl-jira` Phase 6 — bug-report draft output.** When
  `bug_report_destination` is non-null, the writer emits a Markdown
  file at the auto-discovered vault project folder (same destination
  policy as the release-notes draft):
  `<vault-project-folder>/<JIRA_KEY>-implementation-gaps.md`. Format
  defined in `_shared/source-truth.md` §7.5.
- **`doc-reviewer` — intentional-discrepancy marker awareness.** The
  8th review dimension (Source-code accuracy) now recognises an
  `<!-- intentional-discrepancy: ... -->` HTML comment immediately
  before doc prose that describes a Jira claim the source contradicts.
  When the marker is present, the discrepancy is treated as a known
  recorded gap (NOT BLOCKER). When absent, the BLOCKER rule from
  v1.7.0 still applies.
- **`_shared/source-truth.md` §7 — Discrepancy escalation protocol.**
  Comprehensive new section covering the table format, the batch
  and per-discrepancy prompts, the `discrepancy_decisions[]` record,
  the bug-report draft destination + format, and the
  intentional-discrepancy marker format.

### Migration notes
- Local automation that invoked `doc-planner` and expected the topic
  notes to be auto-corrected to source phrasing will now see the
  original (Jira) phrasing in `topics[].notes`. Look at
  `verification_warnings[]` to find each discrepancy and apply the
  decision externally, OR pipe through the new `impl-jira` Phase 5.8.
- Local automation that parsed the old `verification_warnings`
  schema needs to read `jira_phrasing` + `source_phrasing` instead of
  `correction`, and `source_location` instead of `source_checked`.
- doc-reviewer callers (outside the orchestrator) who don't use the
  intentional-discrepancy marker will see BLOCKERs for any documented
  claim that lacks source evidence — same v1.7.0 behaviour. The
  marker only matters when the documentation is intentionally
  describing a gap.

## [1.7.1] — 2026-06-16

### Fixed
- **`doc-planner` — drop changelog-only frontmatter updates.** New hard
  rule: if a target's `topics:` is empty AND `frontmatter_updates.other:`
  is empty AND the only proposed change is a `frontmatter_updates.changelog`
  entry, drop the target from the checklist entirely. A changelog entry
  without a corresponding content change is meaningless — the changelog
  field is meant to summarise *what changed on this page*, and a "page
  unchanged" entry has no value to readers.
  Especially relevant for auto-generated schema-table pages
  (`{{settings-api-table-standalone}}` body) where the schema JSON's own
  `"version":` field tracks field additions; the doc page just re-renders
  it. Convention is verifiable by sampling siblings: when 90%+ of pages
  in the same directory lack a `changelog:`, the planner must respect
  that convention. Caught during PRODUCT-14902 review where v1.6.0
  added a changelog to `builtin-deployment-activegate-updates.md` whose
  body was unchanged (only 1 of 439 sibling schema pages had a changelog
  precedent).

## [1.7.0] — 2026-06-16

### Added
- **`_shared/source-truth.md`** — new shared policy: **Implementation >
  Description**. The source code is what customers see; Jira tickets,
  design specs, and prose descriptions are the *starting point*, not the
  *spec*. Every user-visible claim in generated documentation MUST be
  verified against the implementation (enums, schema JSON, data-source
  classes, UI label constants, defaults, validators) before publication.
  Born from PRODUCT-14902 where the Jira "User Story" listed 3 target-
  version options but the actual source enumerated 4 (Latest / Previous /
  **Older** / specific).
- **`doc-planner` source-verification step (8.5)** — new mandatory pass.
  Accepts `code_repos: [{slug, path}]` input from the orchestrator and
  verifies every user-visible claim (option lists, labels, defaults,
  counts, mode names) against the actual source using the techniques in
  `_shared/source-truth.md` §3. Emits `verification_warnings[]` for any
  claim that cannot be verified OR is contradicted by the source. The
  planner's topic notes MUST reflect the verified phrasing, not the
  description's.
- **`doc-reviewer` 8th review dimension — Source-code accuracy.** Accepts
  the same `code_repos` input. Spot-checks 3–5 user-visible claims per
  file against source. **A documented option/label/count that does NOT
  appear in source is BLOCKER, not CONCERN** — customer-facing wrongness
  blocks publication.
- **`impl-docs` Phase 3.4 — mandatory style check.** Previously, impl-docs
  had no style-check phase; now it invokes `docs-style-checker` before
  Phase 3.5 (doc-reviewer), with the same fix cycle as impl-jira Phase 6.7.

### Changed (breaking for orchestrators that previously skipped style on tool absence)
- **`docs-style-checker` ERROR → fallback path.** Previously, when the
  primary linter (Vale / project lint / markdownlint) errored at runtime
  (missing binary, non-zero exit), the agent returned `status: ERROR`
  without trying the `dt-style-checker` fallback. Now the agent ALWAYS
  tries the fallback before returning ERROR. `NOT_CONFIGURED` is reached
  ONLY when no primary linter is configured AND the `dt-style-guide`
  plugin is not installed. **Some check is better than no check.**
- **`impl-jira` Phase 6.7 is now MANDATORY.** New hard rule at the top of
  Phase 6.7: the orchestrator MUST dispatch `docs-style-checker` and act
  on its return — never skip on its own judgement of which linters are
  installed. The "Proceed to review without style check" choice was
  removed from the ERROR escalation (replaced with "Proceed to
  doc-reviewer" since doc-reviewer still runs).
- **`impl-jira` Phase 5.7 doc-planner input** — `code_repos:` field added
  (array of `{slug, path}`). Required for source-truth verification. When
  omitted, doc-planner emits a `verification_warnings[]` entry per
  user-visible claim.
- **`impl-jira` Phase 7 doc-reviewer input** — `code_repos:` field added
  for the new 8th review dimension.
- **`risk-planner` hard rules** — explicitly forbid recommending "skip
  the style check" as a valid disposition (closes the loophole that let
  v1.6.0 PRODUCT-14902 ship with no style check). Explicitly forbid
  recommending "trust the Jira description" over source code.

### Fixed
- **Vale-missing → silent skip regression.** Pre-v1.7.0, if the agent
  container lacked the Vale binary (common in ephemeral / sandboxed
  setups), the orchestrator silently skipped Phase 6.7 entirely.
  Customer-visible style violations (engineer jargon, inconsistent UI
  labels, contradicting menu paths, plural/singular label mismatches)
  shipped uncaught. v1.7.0's `docs-style-checker` ERROR-fallback path
  closes this — the `dt-style-checker` LLM-based agent always runs as a
  second-chance check when Vale is unavailable.

### Migration notes
- Local automation that invokes `doc-planner` or `doc-reviewer` directly
  (outside the orchestrator) should add `code_repos: [{slug, path}, ...]`
  to the input block. Omitting it is non-breaking but causes
  `verification_warnings` (planner) or "not verifiable" CONCERN entries
  (reviewer) on every user-visible claim — the agents refuse to silently
  emit unverified content.
- `docs-style-checker` callers who depended on the old "ERROR on missing
  Vale binary" behaviour will now see `VIOLATIONS_FOUND` / `OK` /
  `NOT_CONFIGURED` instead (with a note in the `error:` field explaining
  that the fallback ran). Update conditional logic accordingly.

## [1.6.0] — 2026-06-16

### Added
- **`_shared/branch-naming.md`** — new shared policy: every orchestrator that
  creates a git branch (`impl:`, `impl:docs:`, `impl:jira:`, `fix-vuln:`,
  `upgrade:`) now resolves the branch *prefix* via a 4-step algorithm:
  1. `$GIT_USER_INITIALS` env var
  2. `git config --get user.initials`
  3. Sniff `git branch -a` for the dominant `<2–8-char-prefix>/<rest>` pattern
     (≥ 30 % share AND ≥ 3 occurrences)
  4. Workflow-specific fallback (`feat/`, `docs/`, `fix/`, `chore/`), with a
     mandatory `ask_user` escalation when reached
- **`impl:jira:` Phase 1 Q6** — auto-discovered `<vault>/Projects/Products/**/<JIRA_KEY>*/`
  is now used for BOTH the release-notes destination AND the screenshot
  staging directory. The Q6 prompt was reworded to make this explicit.
- **`doc-planner` `screenshot_staging_dir` input field** — orchestrators now
  pass an explicit persistent directory for screenshot staging. doc-planner
  validates it and emits a gap if missing while `image_policy` is
  `cdn_upload_required`.

### Changed (breaking for orchestrators that depend on hard-coded prefixes)
- **`impl:code:` Phase 2.5** — branch-prefix detection now references
  `_shared/branch-naming.md` instead of the previous "check `git branch -a`,
  default to `feat/`" rule.
- **`impl:docs:` Phase 2.5** — same.
- **`impl:jira:` Phase 5.5** — same. Also rewritten to use explicit
  `git -C <docs_repo_root>` form everywhere (clean-tree check, branch sniff,
  checkout). The previous `git checkout -b docs/...` from cwd silently
  created the branch in whichever git repo cwd happened to be — typically
  the wrong repo when the docs repo is a sibling of cwd.
- **`upgrade:`** — branch-prefix detection now references
  `_shared/branch-naming.md` (was: "default to `chore/`"). Combined prefix
  example shifts from `chore/upgrade-springboot-to-3.3.11` (always) to
  `<resolved-prefix>/upgrade-springboot-to-3.3.11` (e.g.
  `ivgu/upgrade-springboot-to-3.3.11` when `GIT_USER_INITIALS=ivgu`).
- **`fix-vuln:`** — same; fallback prefix `fix/` preserved when detection misses.
- **`impl:jira:` repo_root references** — five spots in `impl-jira/SKILL.md`
  that previously said `<cwd's git root>` (Phase 5.6 doc-location-finder,
  Phase 5.7 doc-planner, Phase 6.7 docs-style-checker, Phase 7 doc-fixer ×2)
  now say `<absolute path to the docs repo root — NOT cwd's git root>`. The
  orchestrator's cwd may be a different repo (marketplace, code repo,
  obsidian vault, etc.); the docs target must be passed explicitly.

### Fixed
- **`doc-planner` screenshot staging path** — previously hard-coded to
  `/tmp/<JIRA_KEY>-screenshots/`; this path is wiped on container restart and
  loses staged screenshots before they can be CDN-uploaded. New default is
  the orchestrator-provided `screenshot_staging_dir` (typically the Obsidian
  vault project folder). The agent now refuses to use `/tmp/` even if the
  orchestrator omits the input — it falls back to a persistent sibling of
  the docs repo and flags a gap.
- **`impl:jira:` Phase 5.5 cwd assumption** — the previous spec issued
  `git checkout -b docs/<slug>` without `-C`, which created the branch in
  the cwd's git repo (often the marketplace repo when the agent is run from
  the plugin source tree). Now explicitly `git -C <docs_repo_root> checkout -b ...`.

### Migration notes
- Users with team-specific branch prefix conventions (e.g. `<initials>/`)
  should set `GIT_USER_INITIALS=<initials>` in their shell rc, or run
  `git config --global user.initials <initials>` once. The plugin's behaviour
  for users who do NOT set either is **unchanged** — the workflow-specific
  fallback (`feat/`, `docs/`, `fix/`, `chore/`) is still used.
- Local automation that invokes `doc-planner` directly (outside the
  orchestrator) should add a `screenshot_staging_dir` field to the input
  block if any `image_policy: cdn_upload_required` page is in scope.
  Otherwise the planner emits a gap (no behaviour break — the gap is for the
  caller to resolve).

## [1.5.0] — 2026-06-15

### Added
- **`impl:jira:docs:` — release-notes draft output.** When the VI's frontmatter
  has `relevant_for_release_notes: "Yes"` or a non-empty `release_versions`
  string, the workflow now generates a release-notes draft alongside the
  feature documentation page. The draft is written to a configurable
  destination (auto-discovered Obsidian project folder by default, custom
  path, stdout, or skip — chosen via Phase 1 Q6) — **never** into the
  dynatrace-docs repo, because that path is owned by Jira-driven automation.
  The draft is rendered in the dynatrace-docs `{{#context}}` /
  `{{#internal-note}}` block format so the user can paste it into Jira and
  the existing automation re-emits it into the docs repo.
- **`doc-planner` — `release_notes_block` output field.** New top-level
  output that captures one entry per declared release version with the
  rendered template, citation source list, and assignee/reporter/PE/status
  populated from `value_increment.frontmatter`. `target_format:
  dynatrace-docs-release-notes-v1` lets consumers detect the schema.
- **`jira-reader` — full frontmatter exposure.** `value_increment` and every
  `linked_items[]` entry now carry a `frontmatter:` sub-object containing
  the file's full raw frontmatter. Always-surfaced fields:
  `assignee`, `reporter`, `execution_assignee`, `team`, `project`,
  `fix_versions`, `release_versions`, `relevant_for_release_notes`,
  `owning_program`, `labels`, `resolution`. Any additional fields the file
  declares are passed through verbatim. Existing schema fields unchanged
  (additive only).
- **`jira-reader` — branch-hint extraction.** Scans the `Pull Requests`
  section of each Jira-export file for sub-bullets like
  `- Branch: \`feature/MGD-1127-...\` → \`master\``. When present, exposes
  `branch_hint` and `target_branch_hint` on the matching
  `pull_requests[]` entry.
- **`diff-summarizer` — Strategy 0 branch-hint resolution.** When
  `branch_hint` is present on a PR ref, attempts
  `git rev-parse refs/heads/<hint>` (and `origin/<hint>`) before falling
  through to existing Strategies 1–4. Records `resolved_via: branch_hint`
  on hits.
- **`impl-docs` — Jira-ticket detection.** When `impl:docs: @<file>` loads
  a file with frontmatter `key: <JIRA_KEY>` plus `[[wikilink]]` references
  and a `## Linked Issues` / `## Pull Requests` heading, the skill offers
  to re-route to `impl:jira:docs:` instead of running the lightweight prose
  workflow.
- **`impl-jira` Phase 9 — image-upload reminder.** Final report now lists
  every screenshot staged outside the docs repo (where
  `image_policy: cdn_upload_required`), so the user knows what needs
  manual CDN upload before merging the docs PR.

### Changed (breaking for orchestrators that hardcode `/repos/`)
- **`impl-jira` repo discovery — `$REPOS_PATH`-based.** The hardcoded
  `/repos/<repo>/` path lookup in Phase 4 is replaced with a configurable
  scan rooted at `$REPOS_PATH` (default `/workspace`; colon-separated list
  supported). For each in-scope PR repo URL slug, the orchestrator scans
  candidate directories under `$REPOS_PATH`, runs
  `git remote get-url origin` (5s timeout per dir), and matches by the
  upstream URL's last path segment. When multiple local clones share an
  upstream (e.g. `cluster` + `cluster-repo`), the auto-preferred order is:
  `<slug>-repo` > `<slug>_repo` > `<slug>_fast` > alphabetically last.
  Sub-agents (`diff-summarizer`, `code-scanner`) now receive an absolute
  `repo_path` plus a `repo_url_slug` and reject mismatches via
  `git remote get-url origin` cross-check.
- **Phase 1 Q3 / Q4 wording.** Code-scan and refresh-policy questions now
  refer to `$REPOS_PATH` instead of `/repos/`.
- **Phase 5 error escalation.** `DIRTY_TREE` / `REFRESH_BLOCKED` prompts
  now report the resolved `repo_path` instead of a synthetic `/repos/...`
  string.
- **`doc-planner` topic-list semantics.** "What's new" remains a valid
  topic on a normal documentation target, but the **standalone release
  notes draft is no longer one of the targets** — it is emitted via the
  top-level `release_notes_block` field instead. New hard rule forbids
  proposing release-notes snippet paths as `target_path`.
- **`doc-location-finder` exclusions.** New hard rule: never propose a
  release-notes / what's-new snippet directory as a target (e.g.
  `_snippets/release-notes/`, `_content/whats-new/<product>/sprint-*`).
  Even high keyword-overlap matches in those paths are skipped, because
  the docs repo's release-notes pages are produced by Jira-driven
  automation and a manual write would be overwritten.

### Fixed
- **`diff-summarizer` and `code-scanner` — git fetch/pull timeouts.**
  `git fetch --all --prune` and `git pull --ff-only` are now wrapped in
  `timeout 60`; on timeout, the agent returns `REFRESH_BLOCKED` with the
  reason `"git fetch timed out after 60s"` instead of hanging the workflow.

### Migration notes
- If you have local automation that invokes `diff-summarizer` or
  `code-scanner` directly (outside the orchestrator), update the input
  block: `repo_path` is now an absolute path (any path is acceptable, not
  only `/repos/<name>`), and a new optional `repo_url_slug` enables the
  upstream cross-check.
- If you previously customised the `impl-jira` Phase 4 to point at
  `/repos/`, set `REPOS_PATH=/repos` in your environment to preserve the
  old behaviour.

## [1.4.0] — 2026-06-15

### Breaking changes
- **Sub-agents are now Copilot custom agents, not skills.** The 19 internal
  sub-agents (`risk-planner`, `code-review`, `test-baseliner`, `test-writer`,
  `review-fixer`, `impl-maintenance`, `jira-reader`, `diff-summarizer`,
  `code-scanner`, `doc-reviewer`, `doc-fixer`, `doc-location-finder`,
  `doc-planner`, `docs-style-checker`, `epic-reviewer`, `upgrade-planner`,
  `upgrade-executor`, `vuln-research`, `vuln-fixer`) moved from
  `skills/<name>/SKILL.md` to `agents/<name>.md` with proper Copilot agent
  frontmatter (`name`, `description`, `tools`).
- **`plugin.json` now declares `"agents": "./agents/"`** in addition to
  `"skills": "./skills/"`.
- **Orchestrator dispatch sites updated**: every `task(agent_type: "<bare-name>")`
  call is now `task(agent_type: "dev-workflows:<name>")`. Bare names matched
  neither a Copilot built-in nor a registered custom agent, so 7 of the 9
  distinct dispatches were silently misrouting before this release.
- **Sub-agent `references/` subdirectories preserved** at their original
  locations (`skills/<sub-agent>/references/handoff.md`) — agents read them
  via absolute paths inside `~/.copilot/installed-plugins/...`.

### Added
- Model fallback chain extended with GPT-5.5 (above Sonnet) and GPT-5.4 / Gemini
  3.1 Pro (below Sonnet) — leveraging Copilot's multi-vendor model access.
  Opus 4.8 added at the top of the Claude chain (forward-compatible — currently
  resolves to whichever Opus version the CLI exposes).

### Fixed
- `impl-dispatcher` SKILL.md version string corrected from `1.2.1` → `1.3.0` →
  current `1.4.0`.

## [1.3.0] — 2026-05-15

### Changed
- **Cross-platform sync with Claude Code plugin (v1.3.0).**
  - Ported `check_guidelines.py` and `checklist-template.md` to
    `guideline-reviewer/references/` (added in Claude Code v1.2.0, missing
    from the Copilot port).
  - Version numbers now track 1:1 between Copilot CLI and Claude Code
    plugin repos. Previous version drift: Copilot 1.2.1 / Claude 1.2.0.

## [1.2.1] — 2026-05-15

### Breaking changes
- **`impl:` is now a dispatcher.** Bare `impl:` no longer runs the code-implementation
  workflow — it prints a help page with the command matrix. Use `impl:code:` explicitly.
  Aligns with Claude Code plugin behaviour since v1.1.0.

### Added
- **`impl-dispatcher` skill.** Help / dispatcher triggered by bare `impl:`. Lists all
  `impl:*` variants and related skills (`fix-vuln:`, `upgrade:`), then stops.

### Changed
- **`impl` skill trigger narrowed.** Now only activates on `impl:code:` and `implement:`.
- **Marketplace descriptions enriched.** `dev-workflows` and `dt-style-guide` descriptions
  in `.github/plugin/marketplace.json` now enumerate all skills, sub-agents, and hooks.

## [1.2.0] — 2026-05-12

Copilot CLI port of the Claude Code dev-workflows plugin (v1.1.0).

### Added
- **Namespaced skill layout.** `skills/impl/`, `skills/impl-docs/`, `skills/impl-jira/`
  become the natural-language prefixes `impl:`, `impl:docs:`, `impl:jira:docs:`,
  `impl:jira:epics:` via Copilot CLI's skill discovery.
- **`impl:code:` full workflow.** Structured code-implementation skill: classify →
  optional Opus planning → feature branch → test baseline → implement → test-writing →
  optional Opus review → maintenance → report.
- **`impl:docs:` full workflow.** One-shot doc-editing skill: classify → plan →
  implement → doc-reviewer gate → maintenance → report.
- **`impl:jira:docs:` and `impl:jira:epics:` workflows.** Jira-driven documentation
  and Epic-writing skills with parallel sub-agent invocation, style checking, and
  Opus review gates.
- **15 sub-agent skills.** test-baseliner, test-writer, risk-planner, code-review,
  review-fixer, impl-maintenance, jira-reader, diff-summarizer, code-scanner,
  doc-location-finder, doc-planner, docs-style-checker, doc-reviewer, doc-fixer,
  epic-reviewer.
- **`fix-vuln:` workflow.** Security vulnerability remediation with NVD lookup,
  minimal-version fix strategy, baseline tests, and per-CVE branches/PRs.
- **`upgrade:` workflow.** Component upgrade with before/after test verification.
- **Hooks.** `preload-context.sh` injects git context on skill activation;
  `post-tool-use.sh` tracks tool usage.
- **Shared references.** `_shared/model-routing.md` defines task classification,
  model routing, and the mandatory Opus code-review checklist.

### Changed (vs Claude Code v1.1.0)
- Skills use SKILL.md with YAML frontmatter (not `commands/*.md` / `agents/*.md`).
- Orchestrator skills declare `allowed-tools:` in frontmatter; sub-agent skills do not.
- Path references use `~/.copilot/installed-plugins/...` instead of `${CLAUDE_PLUGIN_ROOT}`.
- Hooks use `${PLUGIN_ROOT}` instead of `${CLAUDE_PLUGIN_ROOT}`.
