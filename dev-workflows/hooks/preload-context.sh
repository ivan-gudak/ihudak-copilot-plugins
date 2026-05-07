#!/usr/bin/env bash
# Fires on every message submission. Injects git context for impl:, vuln:, upgrade: commands.
# Exits immediately (near-zero overhead) if the message doesn't match.
# Always exits 0 — must never block Copilot.

# Guard: if python3 is not available, skip silently
command -v python3 &>/dev/null || exit 0

# Read prompt from stdin JSON.
prompt=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('prompt') or d.get('user_prompt') or d.get('message') or '')
except Exception:
    print('')
" 2>/dev/null) || true

# Match Copilot prefixes: impl:, impl:code:, impl:docs:, impl:jira:, vuln:, upgrade:
if ! echo "$prompt" | grep -qE '^(impl:|impl:code:|impl:docs:|impl:jira:|vuln:|upgrade:)[[:space:]]+[^[:space:]-]'; then
    exit 0
fi

MODEL_ROUTING="${PLUGIN_ROOT}/skills/_shared/model-routing.md"

echo "=== Auto-injected project context ==="
echo "Model routing: classify task as SIMPLE / MODERATE / SIGNIFICANT / HIGH-RISK before planning."
echo "  SIGNIFICANT / HIGH-RISK -> use task tool with agent_type: general-purpose, model: claude-opus-4.7"
echo "  for planning (rubber-duck) and code-review, BEFORE running tests."
if [ -f "$MODEL_ROUTING" ]; then
    echo "  Full rules: $MODEL_ROUTING"
fi
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
    echo "Status:"
    git status --short 2>/dev/null | head -20
    echo "Recent commits:"
    git log --oneline -5 2>/dev/null
else
    echo "(not a git repository)"
fi
# Only inject a short directory listing for small repos (<= 30 entries)
entry_count=$(ls -1 2>/dev/null | wc -l | tr -d ' ')
if [[ "$entry_count" -le 30 ]]; then
    echo "Directory:"
    ls -1 2>/dev/null | head -20
fi

exit 0
