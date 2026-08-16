# Phase 17 — One-file swap

Master now owns `--hermes`, `add_tool`, late prompt refresh, and
`version_suffix`. This branch overwrites one file:

```text
src/mu/coding/active.mojo
  master: NullPlugin
  hermes: HermesPlugin
```

`VERSION` stays `0.6.0`. `--version` prints `0.6.0-hermes` via the
plugin. `pixi.toml` is identical. Shared CLI/loop/config no longer
fork.
