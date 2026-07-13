---
name: guideline-reviewer
description: >
  Review Dynatrace app code and UI for compliance with Dynatrace Experience Standards (GUIDElines). Checks AppHeader, DataTable, FilterField, Connections, Permissions, Settings, Dashboards, accessibility, and Grail naming.
  Activated when the user prompt starts with "guideline-reviewer:".
allowed-tools: view, bash, glob, grep, task, web_fetch, ask_user
---

Review Dynatrace app code and UI for compliance with Dynatrace Experience Standards (GUIDElines): the argument (text following the `guideline-reviewer:` trigger)

If the argument (text following the `guideline-reviewer:` trigger) is empty, ask the user which files or components to review.

Dispatch the review to the `guideline-reviewer` subagent:

→ task(agent_type: "dev-workflows:guideline-reviewer"):
  > "Review the following app code and UI for compliance with Dynatrace Experience Standards (GUIDElines): the argument (text following the `guideline-reviewer:` trigger)"

Surface the subagent's verdict to the user.
