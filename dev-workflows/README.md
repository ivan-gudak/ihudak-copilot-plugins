# dev-workflows

A GitHub Copilot CLI plugin providing a **full product-development lifecycle** as
structured workflow skills — from raw idea, through requirements and design, to
implementation, documentation, and release. Plus vulnerability remediation,
dependency upgrades, and guideline reviews.

## Installation

```
copilot plugin install dev-workflows@ihudak-copilot-plugins
```

## Triggers

Skills activate on a **flat keyword trigger** — the plugin runs when your prompt
*starts with* the keyword followed by a colon, e.g.:

```
implement: add rate limiting to the /login endpoint
document: PRODUCT-14902
vuln: CVE-2024-1234
```

## Skills

### Product-development lifecycle

The lifecycle skills chain from idea to release. Each writes a reviewable artifact
and offers the next phase.

| Trigger | Skill | Description |
|---------|-------|-------------|
| `idea:` | idea | Capture a raw idea and shape it into a structured problem statement. Pre-VI, keyless. |
| `create-vi:` | create-vi | Draft a Value Increment (VI) from an idea or problem statement. Reviewed by `vi-reviewer`. |
| `create-ard:` | create-ard | Draft an Architecture Decision Record for a VI. Reviewed by `ard-reviewer`; resolves open decisions. |
| `specify:` | specify | Write an engineering specification (Jira-driven). Reviewed by `spec-reviewer`. |
| `design:` | design | Write an engineering design from a specification. Reviewed by `design-reviewer`. |
| `epics:` | epics | Draft child Epic definitions for a VI (Jira-driven). Scans repos via `code-scanner`; reviewed by `epic-reviewer` (Opus). |
| `implement:` | implement | Implement a feature or fix. Classifies complexity → risk-weighted plan (Opus critique for complex tasks) → branch → test baseline → implement → `test-writer` → Opus code-review (SIGNIFICANT/HIGH-RISK) → verify no regressions → post-impl maintenance. |
| `document:` | document | Dual-mode documentation. **Doc-edit mode** for direct Markdown/wiki/vault edits; **Jira mode** reads Jira exports + merged PRs, runs parallel `diff-summarizer`s, plans via `doc-planner`/`doc-location-finder`, writes with mandatory citations, style-checks, and gates on `doc-reviewer`. |
| `release-notes:` | release-notes | Generate release notes for a VI in dynatrace-docs block format. Output to markdown/stdout — **never** written into the docs repo (Jira automation owns that path). |
| `ready:` | ready | Readiness gate: verify a VI/feature is ready to ship. Reviewed by `readiness-reviewer`. |

### Maintenance & review workflows

| Trigger | Skill | Description |
|---------|-------|-------------|
| `vuln:` | vuln | Remediate one or more CVEs. Researches each via NVD (`vuln-research`), applies the minimal safe version bump (`vuln-fixer`), verifies tests, applies Opus code-review, runs post-batch maintenance. One branch + PR per CVE. |
| `upgrade:` | upgrade | Upgrade dependencies to a target version. Branch → test baseline → per-component compatibility plan (`upgrade-planner`) → upgrade + verify in sequence (`upgrade-executor`) → Opus code-review → maintenance. |
| `api-guideline-reviewer:` | api-guideline-reviewer | Review OpenAPI specs against Dynatrace REST API and IAM permission naming guidelines. Thin dispatcher → `api-guideline-reviewer` agent. |
| `guideline-reviewer:` | guideline-reviewer | Review code/UI against Dynatrace Experience Standards (GUIDElines) — component usage, accessibility/WCAG, terminology. Thin dispatcher → `guideline-reviewer` agent. |
| `docs-profile:` | docs-profile | Bootstrap or refresh a machine-readable `.dev-workflows/docs-profile.yml` for a docs repo (consumed by `document:` Jira mode). Writes as a reviewable PR. |

### Utilities

| Trigger | Skill | Description |
|---------|-------|-------------|
| `feedback:` | feedback | Capture structured feedback about a plugin run into the specs repo. |
| `prompt:` | prompt | Improve or refine a prompt. |
| `prompt-brainstorm:` | prompt-brainstorm | Collaboratively brainstorm and expand a prompt/idea. |
| `prompt-grill-me:` | prompt-grill-me | Adversarially interrogate a prompt/plan to surface gaps. |

## Sub-agents

Each sub-agent lives in `agents/<name>.md` and is dispatched with
`task(agent_type: "dev-workflows:<name>", ...)`. Agents run in their own context
window and inherit the orchestrator's model unless an explicit `model:` override
is passed. There are **30** sub-agents:

**Planning & review:** `risk-planner`, `code-review`, `doc-reviewer`,
`epic-reviewer`, `review-fixer`, `doc-fixer`, `docs-style-checker`, `spec-reviewer`,
`design-reviewer`, `vi-reviewer`, `ard-reviewer`, `readiness-reviewer`,
`api-guideline-reviewer`, `guideline-reviewer`.

**Writers:** `doc-writer`, `epic-writer`, `release-notes-writer`, `doc-planner`,
`doc-location-finder`, `idea-reader`.

**Testing:** `test-baseliner`, `test-writer`.

**Jira / repo analysis:** `jira-reader`, `diff-summarizer`, `code-scanner`.

**Vuln & upgrade:** `vuln-research`, `vuln-fixer`, `upgrade-planner`,
`upgrade-executor`.

**Maintenance:** `impl-maintenance`.

## Model routing

`skills/_shared/model-routing.md` is the single source of truth for complexity
classification, the model fallback chain, and the 8-dimension Opus code-review
checklist. All orchestrators load it at runtime; sub-agents receive the routing
block in their prompt.

| Complexity | Model |
|------------|-------|
| SIMPLE | Default session model |
| MODERATE | Default session model (with structured planning) |
| SIGNIFICANT / HIGH-RISK | Strong tier — `claude-opus-4.8` / `4.7` / `4.6` or `gpt-5.5`, pinned via `model:` override |

The strong tier treats Opus 4.8/4.7/4.6 and GPT-5.5 as peers (fallback chain:
Opus 4.8 → 4.7 → 4.6 → Haiku 4.5 → GPT-5.5 → Sonnet 4.6 → Sonnet 4.5 → GPT-5.4 →
Gemini 3.1 Pro).

## Feature highlights

- **Full lifecycle**: `idea:` → `create-vi:` → `create-ard:` → `specify:` →
  `design:` → `epics:` → `implement:` → `document:` → `release-notes:` → `ready:`,
  each with a dedicated Opus/GPT-5.5 reviewer sub-agent.
- **Source-code is the truth, discrepancies escalate to YOU**
  (`_shared/source-truth.md`): every sub-agent that writes or reviews user-visible
  docs verifies enums, labels, defaults, and counts against the actual source.
  When source and Jira disagree, the plugin presents an analysis table and asks
  you per-discrepancy — it never silently picks a winner.
- **Mandatory style checking with fallback**: docs workflows run a style-check
  phase that cannot be skipped. If the repo's linter (Vale, markdownlint, remark)
  is unavailable, `docs-style-checker` falls back to `dt-style-checker` from the
  `dt-style-guide` plugin. Some check is always better than no check.
- **Branch-per-change** with shared **branch-prefix detection**
  (`_shared/branch-naming.md`): resolves the prefix via `$GIT_USER_INITIALS` →
  `git config user.initials` → existing-branch sniff → workflow fallback. Teams
  with `<initials>/`-prefix conventions set the env var once and every workflow
  follows it.
- **Jira-driven docs & epics**: `document:` (Jira mode) and `epics:` read Obsidian
  vault Jira exports, resolve PR URLs as **pure local-git identifiers** (no
  Bitbucket REST API, no HTTPS fetch), run parallel `diff-summarizer`s or
  `code-scanner`s per repo, and produce output with mandatory inline Jira + PR
  citations.
- **Repo discovery via `$REPOS_PATH`**: Jira workflows resolve repo URL slugs to
  local clone paths by scanning `$REPOS_PATH` (default `/workspace`; colon-separated
  list supported) and matching `git remote get-url origin`. When multiple clones
  share an upstream, the fast copy (`<slug>-repo`) is auto-preferred.
- **Release-notes draft**: `release-notes:` renders dynatrace-docs block format
  and writes to markdown or stdout — **never** into the docs repo (Jira automation
  owns that path); you paste the draft into Jira and automation re-emits it.
  Staged artifacts are **never** written to `/tmp/` (container restarts wipe it).
- **Test-writing gate**: `implement:` writes tests for all new/changed behaviour
  via `test-writer` and verifies no regressions against a pre-impl baseline. No
  test framework? The workflow asks — it never silently skips.
- **Opus/GPT-5.5 code-review gate**: code workflows run a strong-tier review before
  committing for SIGNIFICANT/HIGH-RISK tasks; `review-fixer` auto-applies fixable
  findings.
- **Post-batch maintenance**: `impl-maintenance` updates the knowledge base,
  `copilot-instructions.md`, and project docs after each workflow.
- **Stateless sub-agents**: every sub-agent receives full context in its prompt —
  no hidden state between calls.

## Not ported from the Claude Code edition

Two features from the upstream Claude Code plugin are intentionally omitted because
they depend on capabilities GitHub Copilot CLI does not expose:

- **Session cost reporting** (`/statusline`, `emit-cost`) — no cost/usage API.
- **Statusline integration** — no statusline extension point.

## Hooks

- **notify-done** — desktop notification when a workflow completes.
- **preload-context** — injects project context on lifecycle triggers.
- **changelog-owners-reminder** — dynatrace-docs frontmatter reminder.

## License

[MIT](LICENSE)
