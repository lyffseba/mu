# Phase 2 — Do it better

Speed, streaming, and a longer-lived session. The contracts from phase 1
stay; this cut makes the agent feel like a product.

## What changed

### Faster Python edge

- `src/mu_runtime.py` is imported once per process.
- JSON, HTTP, SSE, bash, session stamps, and session previews all go
  through that module. No more `Python.evaluate` on every tool call.

### Streaming

- Completers take an `EventSink` and can emit text as it arrives.
- OpenAI-compatible provider streams SSE by default and falls back to a
  single complete request if the server doesn't speak SSE.
- Print mode and the REPL write tokens live. `--mode json` still waits
  for the full event list. `--no-stream` disables SSE.

### Compaction

- Character-based token estimate (`ceil(bytes / 4)`).
- Auto-compact before a prompt when the estimate crosses
  `--compact-threshold` (default 24000).
- `/compact` and `/status` in the REPL.
- Compaction is an append-only JSONL record. Replay rebuilds the
  in-memory transcript; the durable log is never rewritten.

### CLI

- Piped stdin merges into the prompt (`cat README.md | mu -p`).
- Print mode exits `1` on a failed run and `2` on usage errors.
- Session listing no longer loads every JSONL just to show a preview.

## Intentionally still not here

A real TUI, OAuth, skills, branching, and image attachments. Those are
product features, not harness correctness.
