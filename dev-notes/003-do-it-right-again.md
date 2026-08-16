# Phase 3 — Do it right (again)

Correctness pass over streaming and compaction. The new features stay;
the contracts get honest.

## What changed

### Compaction

- A cut never lands on a `tool` result. The assistant that issued those
  calls is kept with them so the next provider request stays well-formed.
- Resume replays the *stored* summary and drop count. It no longer
  re-summarizes on load, so a resumed session matches the original run.
- Older records without `dropped`/`summary` still fall back to a live
  compact.

### Streaming

- An empty SSE body raises and falls back to one complete request.
- A stream that already delivered choices — including an empty
  `finish=stop` — is accepted.
- Non-stream fallback no longer reprints tokens the sink already wrote.
- If a live sink wrote nothing (fallback path), print mode still prints
  the final assistant text once.

### Loop / CLI

- A tool error is a tool result, not a failed run. `ok` is false only
  when the agent itself stops with an error or hits `max_turns`.
- Session ids and auto-compact notices go to stderr so `--mode json`
  stdout stays parseable.
