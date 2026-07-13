#!/usr/bin/env bash
# PostToolUse: warn-only reminder for dynatrace-docs frontmatter conventions
# (changelog entry on change; managed-docs owners). Delegates to the Python
# logic, passing the PostToolUse payload through on stdin.
# Copilot CLI has no PostToolUse tool matcher, so this fires on every tool use;
# the Python logic self-gates (returns immediately unless the edited file is a
# dynatrace-docs .md content page). Always exits 0 — must never block Copilot.

command -v python3 &>/dev/null || exit 0

ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PLUGIN_ROOT="$ROOT" python3 "$ROOT/hooks/changelog-owners-reminder.py" || true

exit 0
