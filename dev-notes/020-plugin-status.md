# Phase 20 — See the plugin from the CLI

A living session was invisible. `/status` and `--sessions` only
knew about transcripts. That is daily-use friction, not architecture.

```text
Plugin.extra_status(id)   appended to /status
Plugin.session_mark(id)   tag on --sessions  (e.g. [awake])
```

NullPlugin returns empty. Hermes will mark living sessions.
No living-agent code on this branch.
