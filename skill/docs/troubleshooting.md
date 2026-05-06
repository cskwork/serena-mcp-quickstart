# Troubleshooting

## Logs

Serena writes logs to `~/.serena/logs/`. Tail the most recent file when diagnosing startup issues:

```bash
ls -t ~/.serena/logs/ | head -1 | xargs -I {} tail -f ~/.serena/logs/{}
```

For LSP-level issues, set `trace_lsp_communication: true` in `~/.serena/serena_config.yml` and reproduce.

## Common failures

### `uvx: command not found`
The `uv` installer drops binaries in `~/.local/bin` (or `~/.cargo/bin` on older versions). Restart your shell or `source ~/.zshrc`. Then `which uvx` should resolve.

### `KeyError: 'react'` (or `js`, `jsx`, `tsx`, `css`)
Invalid enum value in `.serena/project.yml`. Replace per the alias table in `languages.md`. Restart Claude Code afterward.

### Vue LSP hangs forever
Almost always missing `node_modules`. Run `npm install` (or `pnpm install` / `yarn`) in the project root, then restart MCP.

### Java LSP fails to start
Three common causes:
1. JDK < 17. `java -version` must report 17+.
2. `JAVA_HOME` not set or pointing at a different JDK than `java` on PATH.
3. Eclipse JDT LS download interrupted on first run. Delete `~/.cache/serena/` (or equivalent — check log path) and let Serena re-download.

### Symbol search returns empty for a file
- First call after activation triggers a full index — wait 30–60s.
- Force initial scan: call `mcp__serena__get_symbols_overview` on the file.
- For TypeScript monorepos: missing `additional_workspace_folders:` entry. Add the sibling package paths.

### I changed `languages:` but new entries don't activate
**This is the #1 footgun on Serena 1.2.x.** `activate_project` returns "Created and activated a new project" but actually reuses the LSP pool that was spawned when the MCP process started. Editing `.serena/project.yml` and re-activating is **not enough** — neither is clearing `.serena/cache/`.

Fix: fully restart the MCP host (Claude Code, Desktop, etc.) so a fresh `serena start-mcp-server` process is spawned. Only then does the new language list take effect.

### First Java call times out
Large Gradle / Maven multi-module projects can exceed the default 240s `tool_timeout` while Eclipse JDT LS indexes everything. Check whether `.serena/cache/java/` was created — if it's there, indexing is in progress and the second call will be fast. To raise the budget, edit `~/.serena/serena_config.yml`:

```yaml
tool_timeout: 600
```

### `restart_language_server` doesn't work
This tool is disabled by default in the Claude Code permission allowlist. To enable in-session restarts, add `restart_language_server` to `included_optional_tools:` in `~/.serena/serena_config.yml`. Otherwise, host restart is the standard recovery.

### MCP server starts but no `mcp__serena__*` tools appear in Claude
- The host (Claude Code, Desktop, etc.) needs a restart after editing `.mcp.json` / `~/.claude/mcp.json`.
- Permission allowlist may be blocking the tools — first invocation will prompt; approve once.
- Check `claude mcp list` (Claude Code CLI) to confirm the server is registered.

### "Project not active" errors
Activate explicitly:

```
mcp__serena__activate_project   project="/absolute/path/to/repo"
```

Once activated, Serena remembers the project in `~/.serena/serena_config.yml` under `projects:`.

### Multiple Serena instances clash
Closing Claude Code does not always shut down stale `uvx` processes. Kill them manually:

```bash
pkill -f "serena start-mcp-server" || true
```

Then restart the host.

### Editing tools disabled
Check `.serena/project.yml`:
- `read_only: false` must be set (default).
- `excluded_tools:` must not contain the editing tools you need.

## Resetting

To wipe Serena state and start over:

```bash
rm -rf ~/.serena                      # global state, logs, news cache
rm -rf <project>/.serena              # project memories + cache
pkill -f "serena start-mcp-server" || true
```

Then re-run `install.sh` from the project root.

## Asking for help

When filing an issue at https://github.com/oraios/serena/issues, include:

- OS + version
- `uvx --version`
- Output of `java -version`, `node -version`, `python3 --version` (only for languages you enabled)
- The first ~200 lines of the most recent file in `~/.serena/logs/`
- Your `.serena/project.yml` (sanitize secrets first)
