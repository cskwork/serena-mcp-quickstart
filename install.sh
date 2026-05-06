#!/usr/bin/env bash
# serena-mcp-quickstart — one-shot installer
# Usage:   curl -fsSL https://raw.githubusercontent.com/<user>/serena-mcp-quickstart/main/install.sh | bash
#   or:    bash install.sh [--project-dir /path/to/repo] [--global]
#
# What it does:
#   1. Verifies prerequisites (uvx).
#   2. Installs the Skill into ~/.claude/skills/serena-mcp-quickstart.
#   3. Registers the Serena MCP server in .mcp.json (project) or ~/.claude/mcp.json (--global).
#   4. Generates .serena/project.yml from the bundled template (default 5-language preset).
#   5. Prints next steps.

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/cskwork/serena-mcp-quickstart/main"
SKILL_NAME="serena-mcp-quickstart"
SKILL_DIR="${HOME}/.claude/skills/${SKILL_NAME}"

PROJECT_DIR="$(pwd)"
SCOPE="project"   # project | global

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --global)      SCOPE="global"; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  warn: %s\033[0m\n' "$*"; }
fail() { printf '\033[31m  error: %s\033[0m\n' "$*" >&2; exit 1; }

bold "[1/5] checking prerequisites"
if ! command -v uvx >/dev/null 2>&1; then
  warn "uvx not found — installing uv (https://astral.sh/uv)"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # shellcheck disable=SC1090
  [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env" || true
  export PATH="${HOME}/.local/bin:${PATH}"
  command -v uvx >/dev/null 2>&1 || fail "uvx still not on PATH; restart your shell and re-run"
fi
info "uvx: $(command -v uvx)"

bold "[2/5] installing skill into ${SKILL_DIR}"
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

bold "[3/5] registering Serena MCP server (scope: ${SCOPE})"
if [[ "${SCOPE}" == "global" ]]; then
  MCP_FILE="${HOME}/.claude/mcp.json"
else
  MCP_FILE="${PROJECT_DIR}/.mcp.json"
fi
mkdir -p "$(dirname "${MCP_FILE}")"

merge_mcp() {
  local target="$1"
  local snippet="${SKILL_DIR}/templates/mcp-server.json"
  if command -v jq >/dev/null 2>&1; then
    if [[ -f "${target}" ]]; then
      jq -s '.[0] * .[1]' "${target}" "${snippet}" > "${target}.tmp" && mv "${target}.tmp" "${target}"
    else
      cp "${snippet}" "${target}"
    fi
  else
    python3 - "$target" "$snippet" <<'PY'
import json, os, sys
target, snippet = sys.argv[1], sys.argv[2]
base = json.load(open(target)) if os.path.exists(target) else {}
add  = json.load(open(snippet))
base.setdefault("mcpServers", {}).update(add.get("mcpServers", {}))
json.dump(base, open(target, "w"), indent=2)
PY
  fi
}
merge_mcp "${MCP_FILE}"
info "merged into ${MCP_FILE}"

bold "[4/5] generating .serena/project.yml"
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

bold "[5/5] appending Tooling section to agent context file(s)"
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
  # Neither exists — create CLAUDE.md (Claude Code is the primary host for this skill).
  printf '# %s\n%s\n' "$(basename "${PROJECT_DIR}")" "${TOOLING_BLOCK}" > "${CLAUDE_MD}"
  info "created ${CLAUDE_MD} with Tooling block (Claude Code default)"
fi

cat <<EOF

$(bold "done.")

Next steps:
  1. Restart Claude Code so it picks up the new MCP server.
  2. In Claude, run:    mcp__serena__check_onboarding_performed
     If it errors:       mcp__serena__activate_project  project="${PROJECT_DIR}"
  3. Tweak .serena/project.yml — uncomment opt-in languages as needed.

Skill installed at: ${SKILL_DIR}
MCP config:        ${MCP_FILE}
EOF
