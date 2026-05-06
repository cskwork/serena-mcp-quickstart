#!/usr/bin/env bash
# serena-mcp-quickstart — one-shot installer
# Usage:   curl -fsSL https://raw.githubusercontent.com/<user>/serena-mcp-quickstart/main/install.sh | bash
#   or:    bash install.sh [--project-dir /path/to/repo] [--global] [--codex] [--codex-only] [--no-permissions]
#
# What it does:
#   1. Verifies prerequisites (uvx).
#   2. Installs the Skill into ~/.claude/skills/serena-mcp-quickstart (skipped with --codex-only).
#   3. Registers the Serena MCP server:
#        - default:        .mcp.json (project) or ~/.claude/mcp.json (--global)  [Claude Code]
#        - --codex:        ALSO registers in ~/.codex/config.toml via `codex mcp add`
#        - --codex-only:   ONLY registers in ~/.codex/config.toml (skips Claude Code paths)
#   4. Generates .serena/project.yml from the bundled template (default 5-language preset).
#   5. Appends a Tooling block to CLAUDE.md / AGENTS.md as appropriate.
#   6. Adds the 32 mcp__serena__* tools to ~/.claude/settings.json permissions.allow
#      so Claude Code never prompts for them. Skipped with --codex-only or --no-permissions.

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/cskwork/serena-mcp-quickstart/main"
SKILL_NAME="serena-mcp-quickstart"
SKILL_DIR="${HOME}/.claude/skills/${SKILL_NAME}"

PROJECT_DIR="$(pwd)"
SCOPE="project"      # project | global   (Claude Code MCP scope)
WITH_CODEX="no"      # no | yes | only
WITH_PERMS="yes"     # yes | no  (auto-add Serena tools to settings.json allowlist)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)    PROJECT_DIR="$2"; shift 2 ;;
    --global)         SCOPE="global"; shift ;;
    --codex)          WITH_CODEX="yes"; shift ;;
    --codex-only)     WITH_CODEX="only"; shift ;;
    --no-permissions) WITH_PERMS="no"; shift ;;
    -h|--help)
      sed -n '2,17p' "$0"
      exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  warn: %s\033[0m\n' "$*"; }
fail() { printf '\033[31m  error: %s\033[0m\n' "$*" >&2; exit 1; }

bold "[1/6] checking prerequisites"
if ! command -v uvx >/dev/null 2>&1; then
  warn "uvx not found — installing uv (https://astral.sh/uv)"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # shellcheck disable=SC1090
  [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env" || true
  export PATH="${HOME}/.local/bin:${PATH}"
  command -v uvx >/dev/null 2>&1 || fail "uvx still not on PATH; restart your shell and re-run"
fi
info "uvx: $(command -v uvx)"

bold "[2/6] installing skill into ${SKILL_DIR}"
if [[ "${WITH_CODEX}" == "only" ]]; then
  info "skipped (--codex-only — Claude Code skill not installed)"
else
  mkdir -p "${SKILL_DIR}/templates" "${SKILL_DIR}/docs"
  # When the script is invoked via `curl | bash`, $0 is "bash" so we pull files from REPO_RAW.
  # When run from a checked-out clone, copy from the local tree.
  if [[ -d "$(dirname "$0")/skill" ]]; then
    cp -R "$(dirname "$0")/skill/." "${SKILL_DIR}/"
    info "copied from local clone"
  else
    for f in SKILL.md templates/project.yml templates/mcp-server.json docs/languages.md docs/troubleshooting.md; do
      mkdir -p "${SKILL_DIR}/$(dirname "$f")"
      curl -fsSL "${REPO_RAW}/skill/${f}" -o "${SKILL_DIR}/${f}"
    done
    info "fetched skill files from ${REPO_RAW}"
  fi
fi

bold "[3/6] registering Serena MCP server"

# --- Claude Code path (skipped when --codex-only) -----------------------------
if [[ "${WITH_CODEX}" != "only" ]]; then
  if [[ "${SCOPE}" == "global" ]]; then
    MCP_FILE="${HOME}/.claude/mcp.json"
  else
    MCP_FILE="${PROJECT_DIR}/.mcp.json"
  fi
  mkdir -p "$(dirname "${MCP_FILE}")"

  # MCP snippet is embedded so --codex-only can also use it without the skill copy step
  SNIPPET_FILE="$(mktemp)"
  cat > "${SNIPPET_FILE}" <<'JSON'
{
  "mcpServers": {
    "serena": {
      "command": "uvx",
      "args": ["--from", "git+https://github.com/oraios/serena", "serena", "start-mcp-server"]
    }
  }
}
JSON

  if command -v jq >/dev/null 2>&1; then
    if [[ -f "${MCP_FILE}" ]]; then
      jq -s '.[0] * .[1]' "${MCP_FILE}" "${SNIPPET_FILE}" > "${MCP_FILE}.tmp" && mv "${MCP_FILE}.tmp" "${MCP_FILE}"
    else
      cp "${SNIPPET_FILE}" "${MCP_FILE}"
    fi
  else
    python3 - "${MCP_FILE}" "${SNIPPET_FILE}" <<'PY'
import json, os, sys
target, snippet = sys.argv[1], sys.argv[2]
base = json.load(open(target)) if os.path.exists(target) else {}
add  = json.load(open(snippet))
base.setdefault("mcpServers", {}).update(add.get("mcpServers", {}))
json.dump(base, open(target, "w"), indent=2)
PY
  fi
  rm -f "${SNIPPET_FILE}"
  info "Claude Code: merged into ${MCP_FILE} (scope: ${SCOPE})"
fi

# --- Codex CLI path (--codex or --codex-only) ---------------------------------
if [[ "${WITH_CODEX}" != "no" ]]; then
  if ! command -v codex >/dev/null 2>&1; then
    warn "codex CLI not on PATH — skipping Codex registration"
  elif codex mcp get serena >/dev/null 2>&1; then
    info "Codex: serena already registered (use 'codex mcp remove serena' to re-add)"
  else
    cp ~/.codex/config.toml "${HOME}/.codex/config.toml.bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    codex mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server >/dev/null
    info "Codex: registered in ~/.codex/config.toml"
  fi
fi

bold "[4/6] generating .serena/project.yml"
SERENA_DIR="${PROJECT_DIR}/.serena"
mkdir -p "${SERENA_DIR}"
if [[ -f "${SERENA_DIR}/project.yml" ]]; then
  warn "${SERENA_DIR}/project.yml already exists — leaving it untouched"
else
  PROJECT_NAME="$(basename "${PROJECT_DIR}")"
  sed "s/__PROJECT_NAME__/${PROJECT_NAME}/g" \
      "${SKILL_DIR}/templates/project.yml" > "${SERENA_DIR}/project.yml"
  info "wrote ${SERENA_DIR}/project.yml (project_name=${PROJECT_NAME})"
fi

bold "[5/6] appending Tooling section to agent context file(s)"
TOOLING_BLOCK=$(cat <<'EOF'

<!-- BEGIN serena-mcp-quickstart -->
## Tooling

- When `mcp__serena__*` tools are loaded, prefer them for code search and symbol-level edits over `Grep`/`Read`/`Edit`. Fall back silently if absent.
<!-- END serena-mcp-quickstart -->
EOF
)

append_tooling() {
  local file="$1"
  if [[ -f "${file}" ]] && grep -q "BEGIN serena-mcp-quickstart" "${file}"; then
    info "skip ${file} (already has Tooling block)"
    return
  fi
  printf '%s\n' "${TOOLING_BLOCK}" >> "${file}"
  info "appended Tooling block to ${file}"
}

CLAUDE_MD="${PROJECT_DIR}/CLAUDE.md"
AGENTS_MD="${PROJECT_DIR}/AGENTS.md"

if [[ -f "${CLAUDE_MD}" || -f "${AGENTS_MD}" ]]; then
  [[ -f "${CLAUDE_MD}" ]] && append_tooling "${CLAUDE_MD}"
  [[ -f "${AGENTS_MD}" ]] && append_tooling "${AGENTS_MD}"
else
  # Neither exists — pick the convention matching the active CLI.
  if [[ "${WITH_CODEX}" == "only" ]]; then
    printf '# %s\n%s\n' "$(basename "${PROJECT_DIR}")" "${TOOLING_BLOCK}" > "${AGENTS_MD}"
    info "created ${AGENTS_MD} with Tooling block (Codex default)"
  else
    printf '# %s\n%s\n' "$(basename "${PROJECT_DIR}")" "${TOOLING_BLOCK}" > "${CLAUDE_MD}"
    info "created ${CLAUDE_MD} with Tooling block (Claude Code default)"
  fi
fi

# When Codex registration is requested, also append to the user's global Codex AGENTS.md
# so future Codex sessions everywhere benefit (per-project blocks above already cover the
# active project; this covers global agent context).
if [[ "${WITH_CODEX}" != "no" ]] && [[ -e "${HOME}/.codex/AGENTS.md" ]]; then
  GLOBAL_AGENTS="$(readlink "${HOME}/.codex/AGENTS.md" 2>/dev/null || echo "${HOME}/.codex/AGENTS.md")"
  [[ -f "${GLOBAL_AGENTS}" ]] && append_tooling "${GLOBAL_AGENTS}"
fi

bold "[6/6] granting Serena tool permissions in Claude Code settings"
SETTINGS_FILE="${HOME}/.claude/settings.json"
if [[ "${WITH_CODEX}" == "only" ]]; then
  info "skipped (--codex-only — Claude Code settings not modified)"
elif [[ "${WITH_PERMS}" == "no" ]]; then
  info "skipped (--no-permissions)"
else
  mkdir -p "$(dirname "${SETTINGS_FILE}")"
  python3 - "${SETTINGS_FILE}" <<'PY'
import json, os, sys
target = sys.argv[1]
serena_tools = [
    "find_symbol", "find_referencing_symbols", "get_symbols_overview",
    "search_for_pattern", "list_dir", "find_file", "read_file",
    "replace_symbol_body", "insert_after_symbol", "insert_before_symbol",
    "create_text_file", "delete_lines", "replace_lines", "insert_at_line",
    "write_memory", "read_memory", "list_memories", "delete_memory",
    "check_onboarding_performed", "onboarding",
    "get_current_config", "think_about_collected_information",
    "think_about_task_adherence", "think_about_whether_you_are_done",
    "summarize_changes", "prepare_for_new_conversation",
    "restart_language_server", "execute_shell_command",
    "activate_project", "remove_project", "switch_modes", "get_active_project",
]
entries = [f"mcp__serena__{t}" for t in serena_tools]

settings = json.load(open(target)) if os.path.exists(target) else {}
perms = settings.setdefault("permissions", {})
allow = perms.setdefault("allow", [])
existing = set(allow)
added = [e for e in entries if e not in existing]
allow.extend(added)

if added:
    json.dump(settings, open(target, "w"), indent=2)
    print(f"added {len(added)} mcp__serena__* entries to {target}")
else:
    print(f"all {len(entries)} mcp__serena__* entries already present — skipping")
PY
  info "permissions allowlist updated"
fi

bold ""
bold "done."
echo ""
echo "Next steps:"
case "${WITH_CODEX}" in
  only)
    echo "  1. Restart Codex CLI so it spawns the new MCP server."
    echo "  2. In Codex, run:    mcp__serena__activate_project  project=\"${PROJECT_DIR}\"" ;;
  yes)
    echo "  1. Restart Claude Code AND Codex CLI so each picks up the new MCP server."
    echo "  2. In either CLI:    mcp__serena__check_onboarding_performed"
    echo "                       (if it errors)  mcp__serena__activate_project  project=\"${PROJECT_DIR}\"" ;;
  *)
    echo "  1. Restart Claude Code so it picks up the new MCP server."
    echo "  2. In Claude, run:    mcp__serena__check_onboarding_performed"
    echo "                        (if it errors)  mcp__serena__activate_project  project=\"${PROJECT_DIR}\"" ;;
esac
echo "  3. Tweak .serena/project.yml — uncomment opt-in languages as needed."
echo ""
if [[ "${WITH_CODEX}" != "only" ]]; then
  echo "Skill installed at: ${SKILL_DIR}"
  [[ -n "${MCP_FILE:-}" ]] && echo "Claude MCP config:  ${MCP_FILE}"
fi
if [[ "${WITH_CODEX}" != "no" ]]; then
  echo "Codex MCP config:   ${HOME}/.codex/config.toml"
fi
exit 0
