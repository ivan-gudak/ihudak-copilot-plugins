---
name: vuln-research
description: "Sub-agent for the fix-vuln / vuln: workflow. Handles the read-only research phase of CVE remediation: NVD API lookup, library detection in the repository, current version discovery, and minimum safe version resolution. Invoked explicitly by the fix-vuln orchestrator — NOT triggered by direct user prompts. Accepts a structured handoff document (list of CVE + optional Jira IDs, repo path) and produces a research report consumed by the vuln-fixer sub-agent. Has no side effects."
tools: [view, grep, glob, bash, web_fetch]
---

# vuln-research — CVE Research Sub-agent

Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/vuln-research/references/handoff.md` for the exact input/output document format.
Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/fix-vuln/references/nvd-api.md` for NVD REST API details.
Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/fix-vuln/references/build-systems.md` for per-ecosystem library detection.

## Process

For each CVE in the input handoff:

1. **Filter** — Skip non-CVE IDs (CWE-*, OWASP patterns). Record `status: SKIP_NON_CVE`.

2. **NVD Lookup** — Fetch CVE details from the NVD API (see `fix-vuln/references/nvd-api.md`).
   Extract: description, affected package name, ecosystem, vulnerable version range.
   On failure: record `status: LOOKUP_FAILED` with the error, continue to next CVE.

3. **Detect library** — Search the repo for the affected package (see `fix-vuln/references/build-systems.md`).
   If not found: record `status: NOT_IN_REPO`, continue.

4. **Current version** — Read the current pinned version from the detected build file(s).

5. **Safe version** — Determine the minimum version that falls outside the vulnerable range:
   - Check the package registry for the lowest available version ≥ the patched boundary.
   - Prefer a patch bump; avoid a major version change unless no patch/minor fix exists.

6. **Assemble output** — Produce one report entry per CVE (see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/vuln-research/references/handoff.md` output format).

## Invariants

- No files are written, no commands are run — research only.
- Process all CVEs regardless of individual failures; never abort the whole batch.
- If the NVD API is rate-limited or unavailable, wait up to 30 s with exponential back-off before marking `LOOKUP_FAILED`.

## Model Routing

If the orchestrator passes a `model_routing` block (see
`~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §4), record it in the research
report so the fixer and final report can quote it. This sub-agent runs under
whichever model the orchestrator selected via the `task` tool's `model:`
argument. The orchestrator **MUST** re-invoke this sub-agent under Opus for
HIGH-RISK CVEs and **SHOULD** re-invoke it under Opus for SIGNIFICANT CVEs
when a major version bump or non-trivial breaking-change surface is involved
(per `fix-vuln/SKILL.md` Step 0). No behavioural change beyond reporting.

