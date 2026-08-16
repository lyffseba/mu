# Phase 10 — Do it right (hermes branch)

Correctness pass over the living agent. The feature stays; the
contracts get honest.

## What changed

- `is_awake` is a probe. It never creates `~/.mu/hermes` or a session
  directory. Path helpers are split: `*_path` vs mkdir.
- Unknown `target` values error instead of writing into MEMORY.md.
- Entry text cannot contain `§` (the on-disk separator).
- Overflow math uses the store size *before* the write, so the
  separator bytes are not blamed on the new entry alone.
- `--hermes --no-session` is rejected. A living agent needs a
  persisted session to hang memory on.

## Tests

- probe does not mkdir
- separator / bad target rejected
- existing add / replace / overflow / snapshot / tool tests still pass
