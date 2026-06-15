---
name: test-baseliner
description: "Sub-agent for capturing and comparing test suite results. Shared utility used by vuln-fixer and upgrade-executor. Operates in two modes: \"capture\" (run the test suite, record every passing test, return a baseline) and \"verify\" (run the test suite again after a change, diff against a provided baseline, return a structured regression report). Handles test command auto-detection for all supported ecosystems. Invoked by other sub-agents — NOT triggered by direct user prompts. Has no side effects on source or build files."
tools: [view, grep, glob, bash]
---

# test-baseliner — Test Capture & Comparison Sub-agent

Read `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/test-baseliner/references/handoff.md` for the exact input/output document format.

## Modes

### `capture` — record baseline

1. **Detect test command** — if `command_hint` is provided, use it. Otherwise auto-detect
   from project files (see "Command detection" below).
   If no command can be determined: set `status: COMMAND_NOT_FOUND` and return.

2. **Run the test suite** — execute the detected command from `repo` root.
   Capture stdout + stderr. On total failure (non-zero exit, no results parsed):
   set `status: RUN_FAILED`, include the error tail in `error`, and return.

3. **Parse results** — extract the list of passing test identifiers and the total count.
   Use whatever format the test runner emits (see "Output parsing" below).

4. **Return** — produce a `capture` result record (see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/test-baseliner/references/handoff.md`).

### `verify` — compare after change

1. **Run the test suite** — same detection and execution as capture mode.

2. **Parse results** — extract the current passing/failing test list.

3. **Diff against baseline**:
   - **Regressions** = tests in `baseline.passing_tests` that are now failing.
   - **New passes** = tests now passing that were not in the baseline (informational only).

4. **Determine status**:
   - Zero regressions → `status: OK`
   - One or more regressions → `status: REGRESSIONS`

5. **Return** — produce a `verify` result record (see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/test-baseliner/references/handoff.md`).

## Command detection

Inspect the repo root for these files in order; use the first match:

| File found | Command |
|---|---|
| `pom.xml` | `mvn test -q` |
| `build.gradle` or `build.gradle.kts` | `./gradlew test` |
| `package.json` (has `"test"` script) | `npm test` |
| `package.json` (no test script) | `COMMAND_NOT_FOUND` |
| `requirements.txt` / `pyproject.toml` / `setup.py` | `pytest -q` |
| `go.mod` | `go test ./...` |
| `Cargo.toml` | `cargo test` |
| `Gemfile` | `bundle exec rspec` or `bundle exec rake test` |
| `.github/workflows/*.yml` | no runnable tests — `status: NO_TESTS` |

If multiple build files are present, prefer the one at the repo root.
If `command_hint` is provided, always use it regardless of detection.

## Output parsing

Extract test identifiers in a format specific to the runner:
- **JUnit (Maven/Gradle)**: `ClassName#methodName` from Surefire/test XML reports in `target/surefire-reports/` or `build/test-results/`.
- **pytest**: `path/to/test_file.py::TestClass::test_method` from `-v` output.
- **Go**: `TestFunctionName` from `go test -v` output.
- **npm/Jest**: `describe > test name` from JSON reporter (`--json` flag).
- **Other**: fallback to counting pass/fail lines from stdout; set `passing_tests: []` (count only).

When XML/JSON reports are available, prefer them over stdout parsing for accuracy.

## Invariants

- Never modify any source, test, or build file.
- Always return a structured result record — never exit silently.
- `passing_tests` list may be empty `[]` for ecosystems where only a count is available; `passing_count` is always populated when tests ran.

## Resources

- `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/test-baseliner/references/handoff.md` — Complete input/output document format for both `capture` and `verify` modes.

## Model Routing

If the caller (orchestrator or another sub-agent) passes a `model_routing`
block (see `~/.copilot/installed-plugins/ihudak-copilot-plugins/dev-workflows/skills/_shared/model-routing.md` §4), include it
verbatim in the result record so the orchestrator's final report can quote it.
This sub-agent's behaviour is otherwise unchanged by the routing block — it
only ever runs the test command and reports results.

