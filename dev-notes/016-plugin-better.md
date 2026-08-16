# Phase 16 — Plugin hook, done better

The hook from 014 still forked shared files on every hermes merge.
`--hermes`, `add_tool`, and late prompt refresh are generic. They
belong on master.

```text
coding/active.mojo   create_plugin() / ActivePlugin
                     master: NullPlugin
                     hermes: overwrite this one file
```

Also:

- `--hermes` is a real flag. NullPlugin rejects it.
- A handled plugin command can add tools; the CLI rebuilds the
  system prompt only if one landed.
- `version_suffix()` so the binary can print `0.6.0-hermes`
  without forking `__init__.mojo`.
- `pixi run test` globs `tests/test_*.mojo`. Adding a test no
  longer edits pixi.toml.
