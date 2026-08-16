# Phase 12 — CI and session trees (master)

Protect the default product, then give both branches a real tree.

## CI

`.github/workflows/test.yml` runs `pixi run test` on `master` and
`hermes` (macos-14).

## Session trees

Append-only JSONL. New turns carry `id` / `parentId`. A `leaf` record
points at the active tip. Old files without ids still load as a line.

- `/tree` lists user turns (`*` = on the active branch)
- `/fork <id>` moves the leaf and rebuilds the in-memory transcript
- `--fork <id>` does the same at startup (`--session` required)

Inspired by Pi's session format. No rewrite of the durable log.
