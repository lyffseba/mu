# Living Hermes agent (this branch)

You are on **`hermes`**. This is Mu plus a native living [Hermes Agent](https://hermes-agent.nousresearch.com/docs/) as `HermesPlugin`. Master ships `NullPlugin` and never imports this package.

`master` does **not** have this. If you wanted a disposable coding session, check out `master`.

## What `/hermes` does

```bash
mu --hermes -p "remember that this repo uses pixi"
# or, inside the REPL / as a prompt:
mu /hermes
```

That **wakes** the current Mu session as a living agent:

- A `SOUL.md` persona is seeded (edit `~/.mu/hermes/SOUL.md`).
- Bounded memory stores are injected as a **frozen snapshot** at session start (Hermes prefix-cache pattern).
- The `memory` tool is added so the agent can add / replace / remove entries.
- A learning nudge asks it to persist durable facts and consider writing skills.
- Session-weighted notes live under `~/.mu/hermes/sessions/<id>/MEMORY.md`.
- An `AWAKE` marker means later `--session <id>` or `-c` stays living.
- `/memory` lists stores; `/memory <query>` searches them. The `memory` tool also has `search` and `recall` (other sessions).

The rest of Mu is unchanged: same tools, same JSONL transcript, same loop. Hermes is weighted **on this session**, not a second process.

## Memory (Hermes contract)

| Store | Path | Limit | For |
| --- | --- | --- | --- |
| soul | `~/.mu/hermes/SOUL.md` | unbounded | persona |
| memory | `~/.mu/hermes/MEMORY.md` | 2200 chars | environment, lessons |
| user | `~/.mu/hermes/USER.md` | 1375 chars | who you are |
| session | `~/.mu/hermes/sessions/<id>/MEMORY.md` | 2200 chars | this Mu session |

Overflow is an error. The agent consolidates. Writes persist immediately; the system-prompt snapshot updates on the next wake.

Inspired by Hermes Agent, Honcho-style user modeling, and Mnemosyne-style local memory — kept small and on disk, no extra daemon.

## Two branches

See [BRANCHES.md](BRANCHES.md). Align with `git checkout hermes && git merge master`. Never merge this living-agent code back to `master`.
