#!/usr/bin/env bash
# Fires on every message submission. Matches implement:, document:, epics:,
# release-notes:, vuln:, upgrade: (and /slash variants) and routes per spec §3:
#   • implement:, vuln:, upgrade:       → full (model-routing + git status +
#                                         recent commits + small-repo directory
#                                         listing); implement: also preloads
#                                         Jira context when its argument is a
#                                         JiraID (jira-driven via the shared
#                                         Jira-input front-end)
#   • document:                         → Jira context iff the argument is a
#                                         JiraID (e.g. document: PRODUCT-14902);
#                                         free-text / @file → silent (direct-edit
#                                         mode owns its own git hygiene and never
#                                         invokes the strong tier)
#   • epics:, release-notes:            → $VAULT_PATH + $REPOS_PATH default
#                                         + git branch only if cwd is inside
#                                         a git repo (no model-routing, no full
#                                         status/log, no directory listing). Both
#                                         accept a JiraID or an imported-Jira
#                                         directory via the shared front-end.
#   • docs-profile:                     → not matched (no context injected)
#
# emit_jira_context also surfaces $SPECS_PATH alongside $VAULT_PATH/$REPOS_PATH.
#
# Exits immediately (near-zero overhead) if the message doesn't match.
# Always exits 0 — must never block Copilot.

# Guard: if python3 is not available, skip silently
command -v python3 &>/dev/null || exit 0

# Read prompt from stdin JSON. Copilot CLI's UserPromptSubmit payload uses the
# key "prompt"; try the other known names for robustness across versions.
prompt=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('prompt') or d.get('user_prompt') or d.get('message') or '')
except Exception:
    print('')
" 2>/dev/null) || true

# Require at least one non-whitespace, non-flag argument so a bare `document:` or
# `implement: --help` doesn't inject noise on every misfire. The first capture
# group holds the command token (e.g. "implement", "document", "release-notes").
# Match both keyword form (implement: ...) and slash form (/implement ...).
if [[ "$prompt" =~ ^/?(implement|document|epics|release-notes|vuln|upgrade):?[[:space:]]+[^[:space:]-] ]]; then
    cmd="${BASH_REMATCH[1]}"
else
    exit 0
fi

MODEL_ROUTING="${PLUGIN_ROOT}/skills/_shared/model-routing.md"

# --- helpers -------------------------------------------------------------
emit_model_routing() {
    echo "Model routing: classify task as SIMPLE / MODERATE / SIGNIFICANT / HIGH-RISK before planning."
    echo "  SIGNIFICANT / HIGH-RISK -> plan with risk-planner and code-review on the strong tier"
    echo "  (Opus 4.8/4.7/4.6 or GPT-5.5), BEFORE running tests. Invoke via"
    echo "  task(agent_type: \"dev-workflows:<name>\", model: <strong-tier id>) and have the"
    echo "  sub-agent read the plugin-installed agents/<name>.md."
    if [ -f "$MODEL_ROUTING" ]; then
        echo "  Full rules: $MODEL_ROUTING"
    fi
}

emit_git_full() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
        echo "Status:"
        git status --short 2>/dev/null | head -20
        echo "Recent commits:"
        git log --oneline -5 2>/dev/null
    else
        echo "(not a git repository)"
    fi
}

emit_git_branch_if_repo() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
    fi
}

emit_dir_listing_if_small() {
    local entry_count
    entry_count=$(ls -1 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$entry_count" -le 30 ]]; then
        echo "Directory:"
        ls -1 2>/dev/null | head -20
    fi
}

emit_jira_context() {
    echo "=== Auto-injected project context (Jira workflow) ==="
    if [[ -n "${VAULT_PATH:-}" ]]; then
        echo "VAULT_PATH: $VAULT_PATH"
    else
        echo "VAULT_PATH: (not set — the command will ask in Phase 1)"
    fi
    echo "repos_path: ${REPOS_PATH:-/workspace} (default — the command will confirm or ask)"
    if [[ -n "${SPECS_PATH:-}" ]]; then
        echo "SPECS_PATH: $SPECS_PATH"
    else
        echo "SPECS_PATH: (not set — the command will use \$VAULT_PATH-based specs or ask)"
    fi
    emit_git_branch_if_repo
}

# --- per-command routing (spec §3 table) ---------------------------------
case "$cmd" in
    implement|vuln|upgrade)
        # Full — code / security / upgrade benefit from full git context + model-routing.
        echo "=== Auto-injected project context ==="
        emit_model_routing
        emit_git_full
        emit_dir_listing_if_small
        # implement: <JiraID> is jira-driven — also preload Jira context.
        if [[ "$cmd" == "implement" && "$prompt" =~ ^/?implement:?[[:space:]]+[A-Z][A-Z0-9]+-[0-9]+ ]]; then
            emit_jira_context
        fi
        ;;
    document)
        # Mode-aware: a JiraID argument → Jira context; free-text / @file → silent
        # (direct-edit mode owns its own git hygiene and never invokes the strong tier).
        if [[ "$prompt" =~ ^/?document:?[[:space:]]+[A-Z][A-Z0-9]+-[0-9]+ ]]; then
            emit_jira_context
        fi
        ;;
    epics|release-notes)
        # Jira-driven, vault + repos context.
        emit_jira_context
        ;;
    *)
        # Unreachable given the regex; exit silently if the regex is ever widened.
        exit 0
        ;;
esac

exit 0
