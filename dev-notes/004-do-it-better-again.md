# Phase 4 — Do it better (again)

Daily-use speed. The contracts stay; startup and recovery get cheaper.

## What changed

### Compiled binary

- `pixi run build` writes `build/mu` plus `build/mu_runtime.py`.
- `mu_runtime` search now covers the executable's directory, `MU_HOME`,
  and `~/.mu`, so a built binary does not need the source tree on `cwd`.

### Persistent settings

- `~/.mu/config.json` (or `$MU_HOME/config.json`) stores model,
  provider, base URL, last session, and compact defaults.
- CLI flags and environment variables still win.

### Continue

- `mu -c` / `mu --continue` resumes the last remembered session,
  falling back to the newest JSONL if the pointer is missing.

### No empty leftovers

- A new session file is written only when the first message is
  persisted. `--help`, `--version`, and a missing API key no longer
  leave an empty JSONL behind.

### Retries

- HTTP and SSE retry 429 / 5xx / network failures with backoff
  (3 attempts). Non-retryable 4xx still fail immediately.

### REPL

- `/clear` starts a new session without leaving the process.
