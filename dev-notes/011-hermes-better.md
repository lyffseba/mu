# Phase 11 — Do it better (hermes branch)

Daily-use recall. The living agent can search itself and other
sessions without leaving Mu.

## What landed

- `memory` tool actions `search` and `recall`
  - `search` — this agent's stores (session first, then memory, user)
  - `recall` — other living sessions' MEMORY.md (this id skipped)
- `/memory` lists the three stores
- `/memory <query>` searches them
- Print mode `mu -p /memory` works when the session is awake

Still no Honcho dialectic, no FTS5, no gateway. Local files, session
weight, one process.
