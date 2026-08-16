# Branches

Mu's public GitHub repo has **two branches only**. They stay aligned.

```text
master   — a normal Mu / Pi coding session
hermes   — the same tree, plus a native living Hermes agent
```

## Policy

- **`master` is the default.** It is a coding-agent harness. Sessions are transcripts. Nothing lives between them except the JSONL log.
- **`hermes` is `master` plus one capability.** `/hermes` (and `--hermes`) turns the current Mu session into a living [Hermes Agent](https://hermes-agent.nousresearch.com/docs/): SOUL, curated memory, a user profile, and a learning loop *weighted on that session*.
- **They stay aligned.** Features, fixes, and docs land on `master` first, then merge into `hermes`. Hermes-only files never merge back.
- **Do not add other long-lived public branches.** Experiments stay local.

## Which one should I use?

| You want… | Branch |
| --- | --- |
| A normal coding session, like Pi / Tau | `master` |
| An agent that remembers you and this project | `hermes` |
| `/hermes` to wake a living agent on this session | `hermes` |

```bash
git clone https://github.com/lyffseba/mu.git
cd mu                      # master
git checkout hermes        # living agent
```

## Alignment

```bash
git checkout master
# …work, test, commit…
git checkout hermes
git merge master           # bring every master change across
# hermes-only work stays here
```

Never merge `hermes` into `master`. The living agent is opt-in by branch, not a flag on the default tree.
