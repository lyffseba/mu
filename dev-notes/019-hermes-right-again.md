# Phase 19 — Hermes plugin, done right

Master 018 made the hook honest. This branch has to honor it.

## Contracts

- `create_plugin()` is `HermesPlugin`. Shared CLI stays identical.
- Asleep `extra_tools` / `extra_prompt` / failed `/hermes` never
  create `~/.mu/hermes`.
- `/memory` with no query lists. Empty leftover text after the
  command is not a search (search requires a non-empty query).
- `/hermes` with no extra text consumes. Extra text rewrites.
  `--no-session` still fails and does not write `AWAKE`.
- Late `/hermes` goes through `apply_plugin_effects`: memory tool
  lands once, snapshot is last, `--system-prompt` is kept, a
  second apply does not rebuild.
- `CodingRunner` dispatches `memory` to the plugin.

The living-agent files stay under `src/mu/hermes/`. The swap is
still one file.
