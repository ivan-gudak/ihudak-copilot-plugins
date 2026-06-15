---
name: impl-dispatcher
description: >
  Help / dispatcher for the impl family of skills. Activated when the user's prompt
  starts with bare "impl:" without a subcommand (no "code:", "docs:", or "jira:" suffix),
  OR when the user seems unsure which impl variant to use. Does NOT run any workflow —
  prints the command matrix and stops. For the code-implementation workflow, use "impl:code:".
allowed-tools: ask_user
---

# `impl:` — Help / Dispatcher

This is a help / dispatcher skill, not an implementation workflow. It never executes
any implementation, does not branch, does not run tests, does not invoke sub-agents,
and does not touch git state.

Print the message below to the user. Do not classify, do not read project files,
do not invoke any sub-agent, do not propose a plan — just print the message and stop.

---

## Message to print

As of plugin version **1.3.0**, `impl:` is a dispatcher — it does not run a workflow.
Pick the variant that matches your task and re-run.

### `impl:*` variants

| Command | When to use | Example |
|---|---|---|
| `impl:code: <description>` | Source code changes — features, refactors, bug fixes in executable code. Classify → optional Opus plan → feature branch → test baseline → implement → write/verify tests → optional Opus review → maintenance → report. | `impl:code: add rate limiting to /api/users` |
| `impl:docs: <description>` | One-shot doc edits — single-file markdown, README tweaks, Obsidian notes, formatting. No branch, no tests, no code review, no commit. Always SIMPLE or MODERATE. | `impl:docs: add a troubleshooting section to README.md` |
| `impl:jira:docs: <VI-KEY>` | Jira-driven **feature documentation** — reads a Value Increment from the vault, resolves PR URLs to local repos, runs parallel PR-diff summaries, writes product docs, gated by Opus `doc-reviewer`. | `impl:jira:docs: MGD-2423` |
| `impl:jira:epics: <VI-KEY>` | Jira-driven **Epic drafting** — reads a Value Increment plus its existing Epics, optionally scans code for reusable capabilities, writes child Epic drafts into the vault, gated by Opus `epic-reviewer`. Never branches or commits. | `impl:jira:epics: MGD-2423` |

### Related skills (same plugin)

| Skill | When to use |
|---|---|
| `fix-vuln: CVE-XXXX-XXXXX[:JIRA-ID]` | Fix security vulnerabilities — NVD research, classify, branch, fix, Opus review (for SIGNIFICANT / HIGH-RISK), baseline compare, PR. |
| `upgrade: component:version` | Upgrade dependencies — compatibility research, Opus plan (for SIGNIFICANT / HIGH-RISK), branch, apply, Opus review, baseline compare. |

### Migration note (pre-1.2.1 users)

Previously, `impl:` was a silent alias for `impl:code:`. That behaviour was removed
to eliminate ambiguity and align with the Claude Code plugin where `/impl` has been a
dispatcher since 1.1.0. **Re-run your command as `impl:code: <description>`** — the
workflow is unchanged, only the trigger moved.

---

Do NOT proceed with any workflow. After printing the message above, stop.
