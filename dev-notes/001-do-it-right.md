# Phase 1 — Do it right

Correctness pass over the MVP. No TUI, no streaming — just make the
contracts honest.

## What changed

### Tools

- `edit` now validates *all* replacements against the original text, rejects
  overlaps, applies from the end, refuses no-op edits, and restores the
  file's original line endings.
- `read` treats `offset=0` as start-of-file, keeps the user-limit
  continuation hint, and rejects `offset < 0`.
- `bash` truncates from the tail and reports timeouts as errors.
- Relative paths cannot climb above `--cwd`. `~` still expands.
- Invalid JSON arguments become a tool error instead of crashing the loop.

### Loop / provider

- Dangling tool calls from an interrupted run get a synthetic
  `Tool call interrupted by user` result before the next prompt.
- Empty failed assistant turns are stripped from the next provider request.
- Orphan tool results are not sent to the model.
- HTTP failures become an `error` assistant message instead of aborting
  the process.
- `--fake` is explicit. Missing API keys are an error, not a silent echo.

### Sessions

- JSONL is appended with `'a'`, not rewritten.
- `--session <id>` resumes a transcript.
- `--sessions` lists recent ids.
- Session ids that look like paths are rejected.

## Tests added

- edit overlap / CRLF / offset+limit / path escape / bash exit
- history repair (synthesize, drop empty errors, drop orphans, idempotent)
- session round-trip and append
- provider payload drops empty error turns
- loop repairs dangling tools before the next prompt
