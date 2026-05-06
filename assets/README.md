# Assets

This directory holds visuals referenced by the top-level `README.md`.

## hero.png — generation prompt

The README banner. 1280x320, light background, flat illustration style. Generate with any image model (the Codex CLI's `image` command works well; so does ChatGPT / Imagen / Stable Diffusion).

**Prompt:**

```
A horizontal hero banner, 1280x320 pixels, flat vector illustration style.
Centered: a stylized terminal window showing the text "uvx serena" in monospace.
Surrounding the terminal: small floating language icons — Java cup, Vue.js V,
TypeScript "TS" square, Python snake, HTML "<>" — connected to the terminal
with thin animated lines as if data is flowing in.
Background: subtle off-white with faint grid lines.
Color palette: muted indigo, warm orange accent, charcoal text.
No people, no clutter, generous whitespace, modern indie-OSS aesthetic.
Aspect ratio strictly 4:1.
```

## demo.gif — generation prompt

A 6–8 second screen capture showing:

1. Empty terminal in a project root
2. User pastes the `curl … | bash` install one-liner
3. Spinner runs through 4 steps (prereqs → skill → MCP → project.yml)
4. Final "done." banner
5. Cut to Claude Code session running `mcp__serena__find_symbol` with instant result

Record with `asciinema` + convert with `agg`, or use any screen recorder + `ffmpeg`.

## logo.svg — optional

Simple monogram for the GitHub social preview card. 600x600, single color, transparent background.
