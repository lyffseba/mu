# Phase 5 — Do it right (again)

Phase 4 made daily use cheaper (binary, config, `--continue`, retries).
That opens up four edge cases that can now silently corrupt a run.
This is the correctness pass that closes them. No new features.

The invariants we protect:

- the durable JSONL log is append-only and never rewrites past;
- a malformed or truncated model turn can *degrade* a run, never crash it;
- resuming a session always lands on a real, readable transcript.

## 5-A Stale `--continue` pointer

`--continue` used the remembered `last_session` verbatim, and only fell
back to the newest JSONL when that pointer was *empty*. If the remembered
file was deleted or the pointer was corrupt, the run hard-failed with
"session not found" even when other valid sessions existed.

`resolve_continue_session(remembered)` now returns:

1. the remembered id **if its file exists** (fast path, unchanged);
2. otherwise the newest existing session;
3. otherwise empty (→ the usual "no previous session" error).

So a stale/corrupt pointer degrades to "most recent session" instead of
"nothing to do". The fast path (`--session <id>` exact resume) is untouched.

## 5-B A truncated tool call degrades, it does not crash

`Message.tool_calls()` parsed `tool_calls_json` with a hard `json_loads`.
A `length` cutoff mid-arguments, or a hand-edited JSONL, produces a
truncated array — and the loop called `tool_calls()` unconditionally, so
one bad turn took the whole process down with a traceback.

`tool_calls()` is now tolerant: an unparseable array yields an empty
list. The loop adds a guard — an assistant that reports tool calls but
parses to none — and stops the run cleanly with a clear error
("malformed or truncated call, likely a length cutoff") instead of
crashing or looping to `max_turns`. Every call site (`compaction`,
`provider_context`, the OpenAI wire format) benefits from the same
tolerance without changing the happy path.

## 5-C No silent re-run after partial stream

Phase 4 made a failed stream fall back to one complete request. That is
right **before anything is shown**. But if the stream already streamed
tokens to the terminal and then failed, the old code launched a *second*
model call and recorded *that* full answer — the screen and the log
diverged, and the user paid for two calls.

`complete_openai` now guards the fallback on `sink.wrote()`. Nothing was
emitted → behave exactly as before (silent fallback). Something was
emitted → fall back to a clean error completion so the transcript never
records a message the user never saw. A tiny `should_fallback_after_stream`
helper keeps the decision testable.

## 5-D Resume tolerates a truncated tail

`load_session_messages` parsed every line with a hard `json_loads`. A
process killed mid-write could leave a partial final line, and the whole
resume then threw. Following the `preview_session` pattern, a line that
won't parse is skipped, not fatal — matching the "never rewrite the log,
repair what you can" spirit of the session module.

## Tests

- `test_session.mojo` — `resolve_continue_session` fast path, stale
  pointer → newest, corrupt pointer → newest, none → empty; load skips a
  truncated final line.
- `test_loop.mojo` — a tool-calling assistant whose `tool_calls_json`
  is malformed/degrades the run with an error instead of crashing or
  looping.
- `test_openai.mojo` — `Message.tool_calls()` tolerates a truncated
  array; `should_fallback_after_stream` is true only with no output.
