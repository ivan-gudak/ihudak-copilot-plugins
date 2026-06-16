# Source-Code Truth (Shared Policy)

This document is the **single source of truth** for one of the most important
rules in the `dev-workflows` plugin:

> **Implementation > Description.** The source code is what customers will use.
> Jira tickets, PRDs, design specs, and prose descriptions are the *starting
> point*, not the *spec*. They may be outdated, aspirational, simplified, or
> wrong. Every user-visible claim in generated documentation MUST be verified
> against the implementation before it is published.

Every sub-agent that synthesises documentation (`doc-planner`,
`doc-reviewer`, `epic-reviewer`, `code-scanner`) MUST apply this principle.

---

## 1. The principle

Customers do not read your Jira tickets. They read the docs, click the UI,
hit the API. If a Jira ticket says "user picks Latest stable / Previous
stable / specific version" and the code shows four presets (Latest /
Previous / **Older** / specific), the docs MUST reflect what the customer
actually sees, not what the ticket described.

When the description and the code disagree, the **code wins**. Always.

If the description and the code agree, the docs still cite the verified
source — never the description alone — so the docs do not silently drift
when a future ticket revision diverges from what shipped.

## 2. What MUST be verified

For every documentation page, snippet, or release-notes entry produced by
this plugin, verify the following classes of user-visible claim against the
source code:

| Claim type | Where to verify in code |
|---|---|
| **Enum / dropdown options** (e.g. "Latest / Previous / Older stable") | Settings schema JSON (`*.schema.json` under `settings-schemas/`), data source classes (`*DataSource.java`), Java/TypeScript `enum` declarations, OpenAPI schema `enum:` fields |
| **UI labels and button text** (e.g. "Add update window", "Update now to target version") | `displayName:` / `label:` / `title:` constants in schema JSON, `i18n` / `.properties` resource bundles, React/Angular templates, `addItemButton:` metadata in schema files |
| **Menu paths** (e.g. "Settings > Deployment > ActiveGate updates") | UI route definitions, navigation manifests, `schemaGroups:` in schema files, `meta:` blocks |
| **Default values** | Schema `default:` fields, constant declarations (`DEFAULT_*`, `final static …`), `uiDefaultValue:` metadata |
| **Feature flags / maturity gates** | `featureFlag:` metadata in schemas, `@FeatureFlag` annotations, FF config files |
| **API endpoint paths, params, response shapes** | OpenAPI specs in the source repo, REST controller / resource implementations, request/response DTOs |
| **Field nullability / validation rules** | Schema `nullable:`, `minObjects:`, `precondition:` blocks; validator classes; `@Nonnull` annotations |
| **Concurrency / scope rules** ("one AG per group, one per zone") | Algorithm implementations, throttle/lock classes, scope filter expressions |
| **Permission / role gates** | Access-rule classes (`*AccessRule.java`), `@RequiresPermission` annotations, IAM scope declarations |
| **Headline counts** ("3 options", "4 modes", "supports X variants") | Always derived from the enumeration in the source; never copied from the description |

## 3. How to verify (techniques)

Sub-agents performing verification SHOULD use these techniques in order of
specificity:

### 3.1 Settings schema JSON (highest signal)

```bash
find <repo_path> -name "*.schema.json" 2>/dev/null \
  | xargs grep -l "<schema-id-or-keyword>" 2>/dev/null
```

Then read the file. Schema JSON declares the canonical enums, defaults,
validators, and UI labels. If the doc topic touches a Settings 2.0 feature,
this is the most reliable source.

### 3.2 Data source / option provider classes

When schema fields are dynamically populated (e.g. `subType: "datasource"`
in the schema), the runtime options come from a Java/TypeScript class
referenced by the schema's `datasource.identifier`:

```bash
grep -rn "DATA_SOURCE_ID = \"<identifier>\"" <repo_path> --include="*.java"
```

Read the class to find the actual option values and their display names.

### 3.3 Constant declarations

```bash
grep -rn "public static final String <NAME>\|const <NAME> =" <repo_path>
```

### 3.4 OpenAPI specs

```bash
find <repo_path> -name "openapi*.yaml" -o -name "openapi*.json" 2>/dev/null
```

For REST endpoint documentation, the OpenAPI spec is authoritative for
paths, params, request/response shapes, and enum values.

### 3.5 UI source

For button labels, menu items, and React/Angular templates:

```bash
grep -rn "<exact-string-the-doc-uses>" <repo_path>/ui --include="*.ts" --include="*.tsx" --include="*.html"
```

### 3.6 Tests as a fallback

If neither schema nor code yields the answer, test files often encode the
shipped behaviour:

```bash
grep -rn "<feature-name>" <repo_path> --include="*Test.java" --include="*.spec.ts"
```

## 4. Sub-agent responsibilities

### 4.1 `diff-summarizer` (use case A)

When summarising a PR diff, surface enum changes, new schema files, new
constants, and renamed labels in the per-PR summary. These are
high-signal evidence for downstream verification.

### 4.2 `doc-planner` (use case A)

The orchestrator passes `code_repos:` as an input — a list of
`{slug, path}` records pointing to the local clones used by the
diff-summarizer. doc-planner MUST:

1. Extract every user-visible claim from the proposed checklist (option
   names, button labels, default values, counts, menu paths, mode names).
2. For each claim, run the appropriate technique from §3 against the
   `code_repos` to verify the claim.
3. If a claim cannot be verified, OR the source contradicts the claim,
   emit a `verification_warnings` entry with: the claim, the
   technique used, the source location checked, and the discrepancy.
4. Adjust the checklist topic notes to match what the source actually
   says — do not pass the unverified claim through to the writer.

### 4.3 `doc-reviewer` (use case A)

The orchestrator also passes `code_repos:` to the reviewer. The reviewer
runs the **Source-code accuracy** dimension (added in v1.7.0): spot-check
3–5 user-visible claims per file against the source using §3 techniques.
Any documented option/label/value that does NOT appear in the source is a
**BLOCKER** (severity rule: customer-facing wrongness blocks publication).

### 4.4 `code-scanner` + `epic-reviewer` (use case B)

For Epic-writing, the principle applies in reverse: the planner uses
existing code presence/absence to scope Epics that don't yet exist. The
scanner already operates on code; reinforce that any Epic claim about
existing behaviour must trace back to a code reference, not a Jira
description.

## 5. Hard rules

- NEVER copy a Jira description's option list, count, label, or default
  value into the docs without checking the source.
- NEVER trust a Jira ticket's "User Story" section as the spec — it is
  the customer-narrative phrasing, often simplified.
- NEVER trust a Jira ticket's date — descriptions are often months old
  and may pre-date the actual implementation.
- When source and description disagree, **the source wins**. Document
  what was shipped. If the description's intent matters, raise a
  follow-up ticket; don't ship the description.
- When source verification is impossible (no code repos provided, source
  not yet implemented, generated code), surface that as a
  `verification_warning` with action `"ask user"` — never silently emit
  unverified user-visible claims.
- Reviewer severity rule: a customer-visible option / label / count
  that does not appear in the source is **BLOCKER**, not CONCERN.
  Customers will use the wrong information and file support tickets.

## 6. Example (real, from PRODUCT-14902)

Jira "User Story" said:

> A specific stable version available on the cluster (e.g., `1.327`).
> [implied 3 presets: Latest / Previous / specific]

Source — `cluster-repo/shared/core.platform.autoupdate/src/main/java/com/dynatrace/core/platform/autoupdate/activegate/settings/datasource/PrivateActiveGateAutoUpdateDataSource.java` lines 35–38:

```java
public static final String LATEST_VALUE = "latest";
public static final String PREVIOUS_VALUE = "previous";
public static final String OLDER_VALUE = "older";

private static final int ENTRY_LIMIT = 3; // only latest, previous and older can be selected
```

The source shipped **4 options** (Latest / Previous / **Older** / specific
main version). The Jira "User Story" missed "Older". A v1.6.0 docs-PR
shipped with the 3-option Jira phrasing — caught only in a manual review
round, not by the plugin. v1.7.0 adds the verification step to prevent
the next instance.
