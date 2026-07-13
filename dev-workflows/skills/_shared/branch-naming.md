# Branch Naming (Shared Policy)

This document is the **single source of truth** for how every orchestrator that
creates a git branch (`implement:`, `document:`, `epics:`, `vuln:`,
`upgrade:`, and their sub-agents) selects the branch **prefix**. Each
orchestrator still decides its own *slug* — typically based on the task
description, Jira key, or component name.

## 1. Prefix detection algorithm

Apply these checks in order. **Stop at the first one that yields a non-empty value.**

### 1.1 Environment variable

```bash
echo "$GIT_USER_INITIALS"
```

If set and non-empty, use it as the prefix verbatim (no trailing `/`).
Example: `GIT_USER_INITIALS=ivgu` → prefix `ivgu`.

This is the recommended way for users to lock in their team's initials-prefix
convention across all workflows and all repositories.

### 1.2 Git config

```bash
git -C <repo_path> config --get user.initials
```

Same semantics as 1.1. Users may set this once per repository (or globally with
`git config --global user.initials <initials>`) so they don't need to remember
the env var.

### 1.3 Inferred from existing branches

```bash
git -C <repo_path> --no-pager branch -a --format='%(refname:short)' 2>/dev/null \
  | head -200
```

Scan branch names for the pattern `<prefix>/<rest>` where `<prefix>` is **2–8
lowercase alphanumeric characters** (matches typical team conventions like
`ivgu/`, `ahuet/`, `jdoe/`, `mz23/`, plus `feat/`, `docs/`, `fix/`, `chore/`,
`feature/`, `bugfix/`, `hotfix/`, `release/`, `story/`).

Tally each candidate prefix's frequency. If a single prefix accounts for **≥ 30 %**
of recent branches AND the pattern has ≥ 3 occurrences in the sample, use it.

When multiple short prefixes (≤ 5 chars) tie at the top of the tally, prefer
the **alphabetically first** one for determinism. When the tally is split between
a short prefix and a generic one (e.g. `feat/` and `ivgu/`), prefer the **short
non-generic** one if it has ≥ 3 occurrences — that's the team convention; the
generic prefixes are likely older or external contributions.

### 1.4 Workflow-specific fallback

Each orchestrator declares its own fallback prefix when 1.1–1.3 all yield nothing:

| Workflow | Fallback prefix |
|---|---|
| `implement:` (skill: `implement`) | `feat/` |
| `document:` doc-edit mode (skill: `document`) | `docs/` |
| `document:` / `epics:` Jira mode | `docs/` |
| `vuln:` (skill: `vuln`) | `fix/` |
| `upgrade:` (skill: `upgrade`) | `chore/` |

### 1.5 User override (mandatory escalation when 1.4 is hit)

If detection falls through to 1.4, **the orchestrator MUST surface the choice to
the user before creating the branch**:

```
ask_user(
  question: "I couldn't infer your branch prefix from $GIT_USER_INITIALS, git config user.initials, or existing branches. The default for this workflow is `<fallback>`. What prefix should I use?",
  choices: [
    "Use `<fallback>` (default for this workflow)",
    "Use my initials — I'll enter them next",
    "Cancel"
  ]
)
```

If the user picks "Use my initials", follow up with:

```
ask_user(
  question: "Enter your initials (lowercase, 2–8 alphanumeric characters; will be used as `<initials>/<slug>`):",
  choices: []   # freeform input
)
```

After the user provides initials, recommend they also set the env var or git config
for future runs:

> Tip: Set `GIT_USER_INITIALS=<initials>` in your shell rc, or run
> `git config --global user.initials <initials>`, to skip this prompt next time.

## 2. Slug format (unchanged by this doc)

Each orchestrator owns its own slug derivation:

- `implement:` — first 6–8 content words of description → kebab-case
- `document:` — first 6–8 content words of description → kebab-case
- `document:` / `epics:` Jira mode — `<JIRA_KEY>-<first 4–6 content words of VI summary>`
- `vuln:` — `<JIRA-ID>-<CVE-ID>` or `<NOJIRA-CVE-ID>` or `<CVE-ID>`
- `upgrade:` — `upgrade-<component>-to-<version>` or `upgrade-<first>-and-<N>-more`

If `<prefix>/<slug>` already exists, append the first 7 chars of HEAD's SHA:
`<prefix>/<slug>-<short-sha>`.

## 3. Implementation handoff snippet

Orchestrators should embed this resolution step in their branch-setup phase:

```bash
# Resolve branch prefix per _shared/branch-naming.md
prefix="${GIT_USER_INITIALS:-}"
if [ -z "$prefix" ]; then
  prefix="$(git -C "<repo>" config --get user.initials 2>/dev/null || true)"
fi
if [ -z "$prefix" ]; then
  prefix="$(git -C "<repo>" --no-pager branch -a --format='%(refname:short)' 2>/dev/null \
    | head -200 \
    | awk -F/ 'NF>=2 && length($1)>=2 && length($1)<=8 && $1 ~ /^[a-z0-9]+$/ {print $1}' \
    | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')"
fi
[ -z "$prefix" ] && prefix="<workflow-fallback>"   # then ask_user per §1.5 if user is interactive
```

## 4. Hard rules

- NEVER hard-code `docs/`, `feat/`, `chore/`, or any other prefix as the only
  option. Always run §1.1–§1.3 first.
- NEVER append a trailing `/` to the env var or git config value — the algorithm
  inserts it.
- NEVER use uppercase characters in the prefix — git branch names are typically
  lowercase by team convention.
- NEVER use special characters (e.g. `_`, spaces). Stick to `[a-z0-9-]`.
- If the user provides initials via the §1.5 escalation, suggest they save them
  to env var or git config — do NOT silently persist them.
