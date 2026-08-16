# Phase 9 — Living Hermes (hermes branch only)

Fusion of Mu's portable loop with a native slice of
[Hermes Agent](https://hermes-agent.nousresearch.com/docs/).

## What landed

- `/hermes` and `--hermes` wake the current Mu session.
- `SOUL.md`, `MEMORY.md`, `USER.md`, plus `sessions/<id>/MEMORY.md`.
- `memory` tool: add / replace / remove, bounded stores, overflow errors.
- Frozen system-prompt snapshot + learning nudge (closed loop).
- `AWAKE` marker so resume stays living.

## What this is not

Not a port of Hermes' gateway, cron, 70 tools, or Honcho dialectic.
Those stay in Nous Research's agent. This is the living *core* —
persona, curated memory, session weight — running inside Mu.

## Alignment

Land every master change here with `git merge master`.
Never merge this package back to master.
