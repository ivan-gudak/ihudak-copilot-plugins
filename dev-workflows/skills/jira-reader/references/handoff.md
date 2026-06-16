# jira-reader Handoff Format

## Input

```yaml
vault_path: /absolute/path/to/vault
jira_key:   PRODUCT-14902
depth:      full | vi-only
model_routing:
  classification: SIGNIFICANT | MODERATE
  reason: <from orchestrator>
  current_model: <model name>
  planning_model: <model name>
  review_model: n/a
  implementation_model: <model name>
  opus_available: true | false
  gate_tests_on_review: false
```

## Output

```yaml
status: OK | EMPTY | NOT_FOUND
jira_key: <key>

value_increment:
  key:     <key>
  summary: <text from frontmatter>
  status:  <text from frontmatter>
  goal:    <2–3 sentence extraction from the Description / Goal section>
  frontmatter:                  # full raw frontmatter dict for the VI's main file.
    # Always populated when present in the file. Common fields surfaced explicitly:
    issue_type:                 <e.g. ValueIncrement, Epic, Story>
    assignee:                   <text | null>
    reporter:                   <text | null>
    execution_assignee:         <text | null>
    team:                       <text | null>
    project:                    <text | null>
    fix_versions:               [<version>, ...] | null
    release_versions:           <text — e.g. "Managed (344), SaaS (344)" | null>
    relevant_for_release_notes: "Yes" | "No" | null
    owning_program:             <text | null>
    labels:                     [<label>, ...] | null
    resolution:                 <text | null>
    # ... any additional fields the file declares are passed through verbatim.

linked_items:
  - key:        <key>
    type:       ValueIncrement | Epic | Story | Sub-task | Research | "Request for Assistance"
    status:     <text>
    summary:    <text>
    parent:     <key | null>
    role:       root | linked | epic_child
    team:       <text | null>
    not_found:  false      # true if the item file could not be read
    frontmatter:            # full raw frontmatter dict for this item's main file.
      # Always populated when present (same explicit fields as value_increment.frontmatter
      # above, plus anything else the file declares). Empty dict ({}) when not_found: true.

pull_requests:
  - url:                <full URL>
    host:               bitbucket | github | gitlab | other
    project:            <project key or org from URL>
    repo:               <repo name slug from URL>
    pr_id:              <numeric id as string>
    status:             MERGED | OPEN | DECLINED | UNKNOWN
    title:              <link text from markdown>
    source_item:        <Jira key of the file where the URL was found>
    also_in:            [<other Jira keys that reference this same PR>]  # may be empty list
    branch_hint:        <source branch name if found in the export; omitted otherwise>
    target_branch_hint: <target branch name if found in the export; omitted otherwise>

themes:
  - <short phrase, 5–10 words, summarising a recurring capability topic>
  # 2–4 items

notes: |
  <optional: any parse warnings, skipped items, etc.>
```

## Status codes

| Status     | Meaning                                                                 |
|------------|-------------------------------------------------------------------------|
| `OK`       | Successfully read; `linked_items` and `pull_requests` populated.        |
| `EMPTY`    | Directory found but index file is missing or empty.                     |
| `NOT_FOUND`| `<vault_path>/jira-products/<jira_key>/` does not exist.                |
