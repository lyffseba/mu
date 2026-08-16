# Dev notes

Phase-by-phase build journal. Public docs stay in `README.md`.

- [000-mvp.md](000-mvp.md) — first cut: loop, tools, print mode, fake + OpenAI providers
- [001-do-it-right.md](001-do-it-right.md) — correctness: edits, history repair, resume
- [002-do-it-better.md](002-do-it-better.md) — streaming, compaction, cached runtime
- [003-do-it-right-again.md](003-do-it-right-again.md) — compaction pairs, stream fallback, clean JSON stdout
- [004-do-it-better-again.md](004-do-it-better-again.md) — binary, config, --continue, retries
- [005-do-it-right-again.md](005-do-it-right-again.md) — stale --continue fallback, tolerant tool calls, no re-run after partial stream, resume skips a truncated tail
- [006-do-it-better.md](006-do-it-better.md) — skills, cwd-scoped --continue / --sessions
- [007-do-it-right.md](007-do-it-right.md) — skill parse, cwd slash, isolated discovery, Pi/Mojo docs
- [008-do-it-better.md](008-do-it-better.md) — prompt templates, named sessions, --no-session, recursive skills
- [009-hermes.md](009-hermes.md) — living Hermes agent (this branch only)
- [010-hermes-right.md](010-hermes-right.md) — awake probe, separator/target, no ephemeral living agent
