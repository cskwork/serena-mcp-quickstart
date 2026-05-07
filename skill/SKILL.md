---
name: serena-mcp-quickstart
description: Use when the user asks to install, set up, configure, or onboard Serena MCP / Serena code analysis / semantic LSP search for a project, or mentions phrases like "add serena", "setup serena", "enable serena mcp", "serena onboarding", "configure serena for this repo".
---

# Serena MCP Quickstart

Zero-friction installer for [Serena](https://github.com/oraios/serena) — semantic, LSP-powered code search/edit MCP server.

Default project preset enables LSPs for **Java, Vue, TypeScript (covers JS/React/TSX), Python, HTML**.

> **Why these five?** Every entry in `languages:` must match a Serena enum exactly. `js`, `javascript`, `react`, `jsx`, `tsx`, `css` are NOT valid enum values — they are absorbed by other entries (see mapping table below). Listing them verbatim crashes `start-mcp-server` with `KeyError`.

## When to Run

Trigger this skill when:
- A new repo needs Serena MCP wired up
- An existing repo's `.serena/project.yml` is missing or out of date
- The user types `/serena-setup` or pastes the README's setup prompt

## Prerequisites Check (do this first)

Run these in parallel and stop on any failure:

```bash
command -v uvx     # uv toolchain — required to launch Serena
command -v node    # Node 18+ — required by typescript / vue / html LSPs
command -v java    # JDK 17+ — required only if Java is in the language list
command -v python3 # Python 3.10+ — required only if Python is in the language list
```

Missing tool → recover with:
- macOS: `brew install uv node openjdk@17 python@3.11`
- Linux: `curl -LsSf https://astral.sh/uv/install.sh | sh` + distro package manager
- Windows: refer the user to the official installers; do not attempt silent install

## Workflow

### Step 1 — Detect project languages

Inspect the repo (don't trust assumptions). Prefer `fd` when available, fall back to `find` (which is always present):

```bash
# fd variant (faster, but not installed by default on macOS / many Linux distros)
fd -e java -e kt -e vue -e ts -e tsx -e jsx -e js -e py -e html -e mjs -e scss -e css \
   --max-depth 10 -E node_modules -E build -E dist -E .gradle -E target . \
  | awk -F. '{print $NF}' | sort | uniq -c | sort -rn

# find fallback (POSIX, always works) — also recommended for monorepos where
# top-level depth=6 misses Java packages buried under `service/src/main/java/...`
find . \( -path '*/node_modules' -o -path '*/.git' -o -path '*/build' \
       -o -path '*/dist' -o -path '*/.gradle' -o -path '*/target' \
       -o -path '*/.venv' \) -prune -o -type f \
       \( -name '*.java' -o -name '*.kt' -o -name '*.vue' -o -name '*.ts' \
       -o -name '*.tsx' -o -name '*.jsx' -o -name '*.js' -o -name '*.mjs' \
       -o -name '*.py' -o -name '*.html' -o -name '*.scss' -o -name '*.css' \) \
       -print 2>/dev/null \
  | awk -F. '{print $NF}' | sort | uniq -c | sort -rn
```

Pick the `find` variant for unfamiliar / multi-service monorepos — `fd --max-depth 6` will miss Java sources that live ~8 directories deep (e.g. `aidt-service-foo/src/main/java/com/org/...`).

Map extensions to Serena enum values. **Only enum values from the table below are legal** — anything else makes `start-mcp-server` crash on startup.

#### Default 5-language preset

| File extension | Serena `languages:` entry | Notes |
|----------------|---------------------------|-------|
| `.java` | `java` | JDK 17+ on PATH |
| `.kt` | `kotlin` | Add separately; not covered by `java` |
| `.vue` | `vue` | Requires `npm install` first |
| `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs` | `typescript` | **One entry covers JS, TS, React, TSX** |
| `.py` | `python` | Or `python_jedi` / `python_ty` for alternates |
| `.html`, `.htm` | `html` | |

#### Opt-in extensions (add only if the repo actually contains them)

| File extension | Serena `languages:` entry | Notes |
|----------------|---------------------------|-------|
| `.css`, `.scss`, `.sass` | `scss` | **One LSP handles all three** — there is no `css` enum |
| `.go` | `go` | Requires Go 1.21+ |
| `.rs` | `rust` | Requires `rustup` toolchain |
| `.cs` | `csharp` (or `csharp_omnisharp`) | dotnet SDK 8+ |
| `.cpp`, `.c`, `.h`, `.hpp` | `cpp` | For plain C, also use `cpp` |
| `.rb` | `ruby` (or `ruby_solargraph`) | |
| `.php` | `php` (or `php_phpactor`) | |
| `.swift` | `swift` | macOS preferred |
| `.dart` | `dart` | |
| `.ex`, `.exs` | `elixir` | |
| `.hs` | `haskell` | |
| `.lua` | `lua` | |
| `.scala` | `scala` | |
| `.clj`, `.cljs` | `clojure` | |
| `.tf` | `terraform` | |
| `.yml`, `.yaml` | `yaml` | |
| `.json` | `json` | |
| `.md` | `markdown` | |
| `.sh`, `.bash` | `bash` | |

#### Aliases that are NOT valid enum values

`js`, `javascript`, `react`, `jsx`, `tsx` → use `typescript` instead.
`css` → use `scss` instead.
`c` → use `cpp` instead.
`angular` → only if the project is Angular-CLI-managed and `npm install` has run; otherwise prefer `typescript`.

For the canonical, current enum list, see https://github.com/oraios/serena/blob/main/src/solidlsp/ls_config.py

### Step 2 — Register the MCP server

Always go through `claude mcp add` (or `codex mcp add`). Do **not** hand-write JSON — Claude Code 2.x reads user-scope MCP from `~/.claude.json` (the bare file), not `~/.claude/mcp.json` (the directory), and the CLI knows the right target.

| Host | Scope | Command |
|------|-------|---------|
| Claude Code | single project | `cd <project> && claude mcp add serena --scope project -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server` (writes `<project>/.mcp.json`) |
| Claude Code | all projects | `claude mcp add serena --scope user -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server` (writes `~/.claude.json`) |
| Claude Code | marketplace plugin | nothing — already registered as plugin |
| Codex CLI | global (only mode supported) | `codex mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server` |
| Gemini CLI | per its own config | refer to Gemini CLI docs |

The MCP server definition the CLI installs is equivalent to the JSON snippet below — kept here for reference, not for hand-editing:

```json
{
  "mcpServers": {
    "serena": {
      "command": "uvx",
      "args": ["--from", "git+https://github.com/oraios/serena", "serena", "start-mcp-server"]
    }
  }
}
```

> **WARNING:** A common stale instruction (and the previous version of this skill) tells you to write `~/.claude/mcp.json`. That file is silently ignored by Claude Code 2.x — `claude mcp list` will not show servers placed there, and the `mcp__serena__*` tools never load. If you find yourself debugging a "MCP installed but tools never load" issue, run `claude mcp get serena` and verify the registration actually landed in `~/.claude.json` (no inner `claude/` directory).

For Codex CLI, prefer the `codex mcp add` command over hand-editing `~/.codex/config.toml` — it does schema-safe TOML editing and won't disturb existing entries. Codex has no project-scoped MCP equivalent; registration is always global, and per-project activation is done at runtime via `mcp__serena__activate_project`.

### Step 3 — Generate `.serena/project.yml`

Use `templates/project.yml` from this skill as the base. Replace only:
- `project_name:` → repo's directory name
- `languages:` → array from Step 1

Do NOT modify other keys unless the user requests it. Defaults are tuned for first-run safety:
- `read_only: false` — editing tools enabled
- `ignore_all_files_in_gitignore: true` — skips `node_modules`, `target/`, etc.
- `encoding: utf-8`

### Step 4 — Append Tooling guidance to the agent context file

Add this block to the project's `CLAUDE.md` (Claude Code) or `AGENTS.md` (Codex / Gemini CLI). Detect which exists and append to all that do; if neither exists, create `CLAUDE.md`. **Skip if a `BEGIN serena-mcp-quickstart` marker is already present** (idempotent).

```markdown
<!-- BEGIN serena-mcp-quickstart -->
## Tooling

- When `mcp__serena__*` tools are loaded, prefer them for code search and symbol-level edits over `Grep`/`Read`/`Edit`. Fall back silently if absent.
<!-- END serena-mcp-quickstart -->
```

This is what teaches future agents in this project to actually use Serena instead of falling back to grep — without it, Serena MCP loads but rarely fires.

### Step 5 — Verify

Restart the MCP host:
- Claude Code — run `/mcp` then reconnect, or restart the CLI. Confirm with `claude mcp list` — `serena` should show `✓ Connected`. If it does not appear at all, your registration landed in the wrong file (see the WARNING in Step 2).
- Codex CLI — exit and restart `codex` so it spawns a fresh `serena start-mcp-server` process

In Claude Code 2.x, MCP tools are exposed as **deferred tools**: their schemas are not loaded into the prompt until you fetch them. Before calling a Serena tool for the first time in a session, run:

```
ToolSearch  query = "select:mcp__serena__activate_project,mcp__serena__check_onboarding_performed"
```

Then, on the very first install, **call `activate_project` before `check_onboarding_performed`** — otherwise `check_onboarding_performed` returns "No active project" because Serena has never been told about this repo:

```
mcp__serena__activate_project           project = "<absolute path to repo root>"
mcp__serena__check_onboarding_performed
```

After the first activation, Serena remembers the project; future sessions can call `check_onboarding_performed` directly.

> **Heads-up:** the first time Serena activates a project, it rewrites `.serena/project.yml` to its canonical schema (full comments, every documented key). This is normal — your `project_name`, `languages`, and `ignored_paths` are preserved. Don't be surprised if a `git status` after first verification shows changes to `project.yml`.

## Common Failure Modes

| Symptom | Root cause | Fix |
|---------|------------|-----|
| `uvx: command not found` | uv not installed | `curl -LsSf https://astral.sh/uv/install.sh \| sh` then re-source shell |
| LSP hangs on first call | language server downloading on cold start | wait 30–60s; check `~/.serena/logs/` |
| `Language 'react' not recognized` | invalid enum in `project.yml` | replace with `typescript` |
| Vue LSP fails | missing `node_modules` | run `npm install` in the repo root first |
| Java LSP fails to start | wrong JDK | `java -version` must show 17+; set `JAVA_HOME` |
| Symbol search empty | LSP still indexing | run `mcp__serena__get_symbols_overview` to force initial scan |
| Edited `languages:` but new entries don't activate | Serena 1.2.x reuses the LSP pool spawned at MCP start; `activate_project` does not reload it | fully restart the MCP host (Claude Code etc.) — clearing `.serena/cache/` alone won't help |
| First Java call times out (~240s) | JDT LS indexing a large multi-module project | wait, check `.serena/cache/java/` exists, then retry; raise `tool_timeout` in `~/.serena/serena_config.yml` if needed |

## What This Skill Does NOT Do

- It does not auto-update Serena. Re-run `uvx` to pull latest from `git+...`.
- It does not run `serena onboarding` (Serena's own ingest). Suggest that step to the user once MCP is reachable.

> **Note:** The bundled `install.sh` (run from CLI) **does** auto-grant the 32 `mcp__serena__*` tools in `~/.claude/settings.json` so Claude Code never prompts. If a user is invoking this skill via prompt-only flow (no shell access), explicitly tell them the first call to each Serena tool will trigger a one-time permission prompt — which they can pre-empt by running `install.sh` once.

## References

- Serena upstream: https://github.com/oraios/serena
- Language enum source of truth: https://github.com/oraios/serena/blob/main/src/solidlsp/ls_config.py
- Project config docs: https://oraios.github.io/serena/02-usage/050_configuration.html
- See `docs/languages.md` for per-language LSP install notes
- See `docs/troubleshooting.md` for extended diagnostics
