# Phase 15 — Hermes is a plugin

Master added `Plugin` / `NullPlugin`. This branch now only swaps the
type:

```text
master:  var plugin = NullPlugin()
hermes:  var plugin = HermesPlugin()
```

`src/mu/hermes/` owns SOUL, memory, `/hermes`, `/memory`, and the
`memory` tool. `main.mojo` and `coding/tools.mojo` no longer import
them. `--hermes` is still a flag; `on_start` consumes it.

A handled plugin command can add tools. The CLI then rebuilds the
system prompt so a late `/hermes` still injects the frozen snapshot.
`/memory` does not, so the prefix stays frozen.
