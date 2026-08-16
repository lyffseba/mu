# Phase 21 — See living sessions

Master 020 added `extra_status` / `session_mark`. This branch
uses them.

- `/status` appends `hermes=awake` when the session is living.
- `--sessions` tags living ids with `[awake]`.
- `/recall <query>` searches other sessions without a tool call.
  Empty query prints usage. Asleep sessions stay asleep.

Still no FTS5, no Honcho, no gateway. Local files, one process.
