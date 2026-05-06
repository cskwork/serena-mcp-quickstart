# Per-language LSP install notes

Serena spawns one language server per entry in `languages:`. Each server has its own toolchain prerequisites. This file lists what to install for each enum value the skill exposes.

> Source of truth for available enum values: [`solidlsp/ls_config.py`](https://github.com/oraios/serena/blob/main/src/solidlsp/ls_config.py).

## Default preset

### `java`
- JDK 17+ on PATH (`java -version` must report 17 or higher).
- macOS: `brew install openjdk@17 && echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc`
- Linux: `sudo apt install openjdk-17-jdk` or distro equivalent.
- The Eclipse JDT LS will be downloaded by Serena on first run (~150 MB). Allow 30–60s on cold start.

### `vue`
- Node 18+ and the project's own `node_modules`. Run `npm install` in the repo root before activating Serena, otherwise the Vue language server will fail to resolve `vue` itself.
- Works for both Vue 2 (with `@vue/language-server`) and Vue 3.

### `typescript` (covers JS / React / TSX)
- Node 18+. No project install required, but a local `tsconfig.json` greatly improves accuracy.
- For monorepos, list sibling packages under `additional_workspace_folders:` in `project.yml` to enable cross-package symbol search.

### `python`
- Python 3.10+ on PATH. Serena will use Pyright by default.
- Alternates: `python_jedi` (Jedi LSP — lighter, fewer features) or `python_ty` (experimental).
- For projects using `venv` / `poetry`, activate the venv before launching the MCP host so the LSP picks up the right interpreter.

### `html`
- Node 18+. Uses `vscode-html-language-server`. No additional setup.

## Opt-in languages

### `scss` (covers CSS, SCSS, Sass)
- Node 18+. Single LSP (`some-sass-language-server`) handles all three syntaxes — there is **no separate `css` enum value**.

### `go`
- Go 1.21+. Serena uses `gopls`, which is auto-installed via `go install golang.org/x/tools/gopls@latest` on first use. Make sure `$GOPATH/bin` is on PATH.

### `rust`
- `rustup` and a stable toolchain. Serena uses `rust-analyzer`, which is bundled with rustup component: `rustup component add rust-analyzer`.

### `csharp` / `csharp_omnisharp`
- .NET SDK 8+. `csharp` uses Microsoft's modern C# LSP; `csharp_omnisharp` is the legacy alternative — pick one, not both.

### `kotlin`
- JDK 17+ (same as Java). Uses `kotlin-language-server`. List `kotlin` separately from `java` — they don't share an enum.

### `cpp`
- LLVM 14+ providing `clangd`. macOS: `brew install llvm`; Linux: `sudo apt install clangd`.
- Use `cpp` for plain C as well — there is no separate `c` enum value.
- For very large C++ projects with slow `request_hover`, raise `symbol_info_budget` in `serena_config.yml`.

### `ruby` / `ruby_solargraph`
- Ruby 3.0+. `ruby` uses Shopify's `ruby-lsp`; `ruby_solargraph` is the alternative.

### `php` / `php_phpactor`
- PHP 8.1+. `php` uses Intelephense (free tier); `php_phpactor` uses Phpactor (FOSS).

### `swift`
- macOS only (realistically). Xcode 15+ provides `sourcekit-lsp` automatically.

### `dart`
- Dart SDK 3+. Set `DART_SDK` env var if not on PATH.

### `terraform`
- HashiCorp `terraform-ls` on PATH: `brew install hashicorp/tap/terraform-ls`.

### `yaml` / `json` / `markdown` / `bash`
- All Node-based, auto-installed by Serena on first use. Useful when you want symbol-level navigation in config-heavy repos.

## Aliases that are NOT valid enum values

If you put any of these in `languages:`, Serena will crash at startup with `KeyError`:

| Alias | Use this instead |
|-------|------------------|
| `js`, `javascript` | `typescript` |
| `react`, `jsx`, `tsx` | `typescript` |
| `css` | `scss` |
| `c` | `cpp` |
| `node`, `nodejs` | `typescript` |
| `vue3` | `vue` |
| `py` | `python` |

When in doubt, check `Language` enum values in [`solidlsp/ls_config.py`](https://github.com/oraios/serena/blob/main/src/solidlsp/ls_config.py).
