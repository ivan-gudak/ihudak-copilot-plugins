---
name: api-guideline-reviewer
description: >
  Review OpenAPI specification files against Dynatrace REST API and IAM permission naming guidelines. Checks version consistency, naming conventions, IAM scope format, HTTP status codes, and schema composition.
  Activated when the user prompt starts with "api-guideline-reviewer:".
allowed-tools: view, bash, glob, grep, task, web_fetch, ask_user
---

Review OpenAPI specification files for compliance with Dynatrace REST API and IAM permission naming guidelines: the argument (text following the `api-guideline-reviewer:` trigger)

If the argument (text following the `api-guideline-reviewer:` trigger) is empty, ask the user which OpenAPI spec file(s) to review.

Dispatch the review to the `api-guideline-reviewer` subagent:

→ task(agent_type: "dev-workflows:api-guideline-reviewer"):
  > "Review the following OpenAPI spec file(s) against the guidelines: the argument (text following the `api-guideline-reviewer:` trigger)"

Surface the subagent's verdict to the user.
