---
name: update-vi
description: >
  VI-update workflow (PM phase) — refresh/re-do an existing Value Increment. Resolves the VI Jira-import-first (source of truth) with a 3-day freshness gate, grounds on the VI + comments + any ARD/spec/transcript, updates it via a relentless grill against _shared/vi-format.md, gated by the Opus vi-reviewer, and writes canonical + archived revisions to $SPECS_PATH/specifications/<KEY>-<slug>/. Product-level (no code scan).
  Activated when the user prompt starts with "update-vi:".
allowed-tools: view, edit, create, bash, glob, grep, task, web_fetch, ask_user
---

Update the Value Increment for the Jira item: the argument (text following the `update-vi:` trigger)

`update-vi:` refreshes an **existing** Value Increment (PM phase). It covers routine refreshes (new
information, scope tweaks, wording) and the rare obstacle-driven re-do (a human read an ARD/spec finding,
discussed it in Jira, and decided the VI must change). The VI is **product-level** — what / why /
for-whom, not how. Zero code scan; no repos.

Usage: `update-vi: <KEY> [@transcript-or-notes ...]`.

---

## Phase 0 — Resolve inputs

1. **`KEY` (mandatory).** Parse the first non-flag token; validate `^[A-Z][A-Z0-9_]*-\d+$`. If absent or malformed, stop: `UPDATE_VI_NEEDS_KEY: update-vi: needs the VI's Jira key — 'update-vi: <KEY>'.`
2. **`$SPECS_PATH` (required).** If unset, stop naming `SPECS_PATH` (`choices: ["Set SPECS_PATH (enter the path)", "Cancel"]`).
3. **Feature folder.** `<SPECS_PATH>/specifications/<KEY>-<slug>/` — honor an existing dir matched by key-number (tolerate a stray `-`/`_` and a human-adjusted slug).
4. **Resolve the base VI — Jira-import-first.** Execute `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/vi-source-resolution.md` (`resolve-existing-vi <KEY>`): the re-imported `$VAULT_PATH/jira-products/<KEY>` VI (body + `-comments.md`) is the **authoritative base**; not imported → stop and ask to import; stale (>3 days) → offer re-import.
5. **Secondary grounding (read-only).** Discover in the feature folder: the frozen specs draft (glob `<KEY>_*.md`, `issue_type: ValueIncrement`), any `*_ARD.md`, `specification.md`; plus any `@transcript` / notes path(s) passed in the argument.

`update-vi:` is **cwd-agnostic** and needs **no repos mounted** (product-level; no code scan).

---

## Phase 1 — Configure

Use `choices` arrays; the last choice is always `"Other… (describe)"`.

1. **Confirm** the feature folder; the resolved Jira-import base **with its import date**; and the secondary artifacts discovered (specs draft / ARD / spec / transcript).
   - Show the `docs grounding: ON <root> | OFF (<reason>)` line (off switch: --no-docs).
2. **Scope of the update.** `choices: ["Refresh (incorporate new info / comments / transcript) (Recommended)", "Re-do (substantive re-scope driven by an ARD/spec obstacle)", "Cancel", "Other… (describe)"]`.

---

## Phase 1.5 — Classify + model routing

Load and follow the model-routing policy at
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md`, then record:

```yaml
model_routing:
  classification: MODERATE        # typical; SIGNIFICANT for large/cross-cutting VIs
  reason: <one-line>
  current_model: <the model this orchestrator/grill is running under>
  detection_model: <§2.1 detection chain: claude-sonnet-4.6, fallback claude-sonnet-4.5/gpt-5.4>   # impl-maintenance
  review_model:    <§2 Opus chain>     # vi-reviewer (caller-pinned via `task(model:)`; recorded)
  authoring_model: <= current_model>   # the interactive grill + VI authoring (session model, not a delegated subagent)
  opus_available: <true if a §2 Opus model resolved, else false>
  notes: <any §2/§2.1 fallback or degradation>
```

The grill + authoring run inline on `current_model` (the §2 Opus chain — interactive judgment, not a delegated subagent). If no Opus resolves, **degrade to best-available + record** in `notes` and the final report — do not hard-block.

---

## Phase 2 — Read the base + grounding

Read the Jira-import VI **body + `-comments.md`** (the authoritative base and the signal for *what to change*), then the secondary artifacts (specs draft, ARD, spec, transcript). Do NOT treat the frozen specs draft as authoritative where it disagrees with the Jira import — the import wins; surface a notable divergence to the user. **No code scan; no repos.**

Then run `resolve-docs-grounding update-vi` per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/docs-grounding.md`. When `docs_grounding: ON`, `dispatch-docs-grounder` with `feature_summary` = the VI goal + the change signal from comments, `jira_key` = `<KEY>`. Carry the digest into the Phase 3 grill with **grill-rank** consumption. When OFF, skip silently.

---

## Phase 3 — Update via grill

**Interview technique (grilling — embedded; no runtime dependency).** Conduct a **relentless** interview per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/grilling-technique.md` — one question at a time, recommend each answer, fact-vs-decision split, walk the design tree in dependency order.

Update the VI live against `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/vi-format.md`, **diffing against the base** rather than authoring from blank: surface what changed and why (drawing on comments / ARD / spec / transcript), resolve open questions, keep the VI product-level. Apply the **self-consistency check** — no `[AC-N]` delivering an Out-of-scope behaviour, no `## Goal` vs `## Scope` contradiction, no conflicting `[US-N]`; record a deliberately-kept tension under `## Assumptions & open questions`. Preserve the frontmatter provenance fields (`sources`, `derived_from`, `seeded_from_vi` if present).

---

## Phase 3.5 — Dynatrace style check

Run the corporate style check on the updated VI **before** the review gate — a **quality enhancement, not a gate**; it never blocks the handoff (mirrors `create-vi:` Phase 3.5).

→ task(agent_type: "dt-style-guide:dt-style-checker", model: <detection_model — §2.1 detection chain>):
  > "Run the style check for this brief:
  >
  > files:    [absolute path to the updated <KEY>_<slug>.md]
  > doc_type: vi
  > emphasis: terminology and customer-facing captions, labels, messages, and text"

Act on the return: `OK` → proceed; `VIOLATIONS_FOUND` → apply the MAJOR fixes inline and re-run `dt-style-checker` once (record remaining MINOR/NIT); `ERROR` → surface and proceed (non-gating). If `dt-style-checker` is unavailable (the `dt-style-guide` plugin is not installed), **skip gracefully** and note `SKIPPED (dt-style-checker unavailable)`.

---

## Phase 3.6 — Structural pre-lint

Before the review gate, run the deterministic checks in
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/pre-lint.md` against the updated file: the **Universal checks** plus the **VI** block. Surface every finding; inline-fix the mechanical ones; leave content gaps for the grill. **Advisory** — never blocks; `vi-reviewer` remains the gate.

---

## Phase 4 — Review gate

Dispatch `vi-reviewer` (Opus, caller-pinned via `task(model:)`; recorded as `review_model`):

→ task(agent_type: "dev-workflows:vi-reviewer", model: <review_model — §2 Opus chain>):
  > "Review the Value Increment:
  >
  > VI path: [absolute path to the updated <KEY>_<slug>.md]
  > Profile: [lean | hybrid | full — infer from the sections present]"

Act on the verdict as `create-vi:` Phase 4 does: on `BLOCK`, fix the BLOCKER findings inline (the orchestrator/grill edits the VI — no delegated writer) and re-review **once**. If still `BLOCK`, escalate per the `Review verdict BLOCK` rule in `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/escalation-rules.md` for each unresolved BLOCKER. Cap: one fix cycle + one re-review.

---

## Phase 5 — Handoff (canonical + archive) + Jira round-trip

1. **Archive the current canonical VI** (if one exists) to `<feature-folder>/revisions/<KEY>_<slug>_<YYYYMMDD>.md` before overwrite (same-day second revision → suffix `-2`, `-3`, …).
2. **Write the refreshed VI** to the **canonical** path `<feature-folder>/<KEY>_<slug>.md`. Record `revision_of: <archived snapshot path>` and `built_from_import: <YYYY-MM-DD>` (the Jira-import date the update was built from) in the frontmatter.
3. **Offer git** (commit-when-asked — never automatic): `choices: ["Branch + commit + push + open PR to main (Recommended)", "Just write the files — I'll handle git", "Cancel"]`. On the first choice, in the specs repo (`$SPECS_PATH`): create branch `vi/<KEY>-<slug>-update`; commit **only** the feature folder (never `git add -A`); push; open a PR targeting `main`. Commit trailer: `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.

### Jira round-trip (document to the user — they will otherwise miss it)

1. **Paste** the updated VI body (below the frontmatter) back into the Jira workitem `<KEY>`.
2. **Re-import** the VI to `$VAULT_PATH/jira-products/<KEY>` (via `https://github.com/ivan-gudak/jira-workitem-import`) so the downstream pipeline and the next `update-vi:` see the current text.

Without these steps the update silently diverges from Jira again.

---

## Phase 6 — Next steps

Offer these — guidance only, never auto-invoke — per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/next-phase-offer.md`:

```
choices: ["Re-draft the release note — release-notes: <KEY> (PM)", "Re-run architecture — create-ard: <KEY> (PA, if one exists)", "Re-run the spec — specify: <KEY> (PE, if one exists)", "Stop here", "Other… (describe)"]
```

### Context hygiene

Write/overwrite the resume pointer at `<VI-dir>/dev-workflows/resume.md` (per `session-hygiene.md` §1). Then: continuing as PM → run **`/compact`**; handing to PA/PE → run **`/clear`**. Guidance only — nothing is auto-run. See `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md`.

---

## Phase 7 — Session maintenance & feedback

Terminal phase — runs after Phase 6, NEVER interrupts an earlier phase.

**Capture-at-block invariant.** If an EARLIER phase **halts on a plugin / skill / command / reference gap** (a capability the run needed but the plugin lacked), `emit-block` (per `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md`) at that halt **before** escalating. NEVER `emit-block` for an environment / user halt (missing key, unset `$SPECS_PATH`, not-imported, cancellation) or a work-quality review BLOCK.

**Session-hygiene invariant.** End Phase 6 with a `### Context hygiene` block per
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/session-hygiene.md` — prepare-first (write `resume.md`),
then a span suggestion (PM continue → `/compact`; PA/PE handoff → `/clear`). Guidance only, never auto-run.

1. **Invoke `impl-maintenance`** (agent_type: "dev-workflows:impl-maintenance", model: `<detection_model — §2.1 detection chain>`) with a compact handoff: command `update-vi:`; what was updated (which sections changed + why); key events (import/freshness friction, BLOCK reviews, unresolved clarifications — or 'none'); workarounds; the `vi-reviewer` verdict; test result N/A; project root = the feature folder.
2. **Persist plugin feedback (automatic).** Cite `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/feedback-emission.md` and call its `emit-auto` entry point (§6) with the Lessons Learned report, `command: update-vi:`, the run's `jira_key`, `source`, and `plugin_version` (read from `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/.plugin/plugin.json`). Surface the persisted path (or "no plugin-facing signal — nothing persisted").

ADDITIVE — this phase NEVER fails the run, NEVER commits (git is offered only in Phase 5), and NEVER writes into a code/docs repo or the current working directory; no user name is ever written.

---

## Final report

Report: the canonical VI path + the archived snapshot path; which sections changed; the Jira-import date the update was built from; open-question count; the `vi-reviewer` verdict; the Dynatrace style-check outcome (`OK` | `N fixed, M remaining` | `SKIPPED`); the PR URL (if opened); the Jira round-trip reminder; resolved model routing (+ any Opus degradation); the feedback path; and the next-step recommendations.
