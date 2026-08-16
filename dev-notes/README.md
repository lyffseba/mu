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
- [011-hermes-better.md](011-hermes-better.md) — /memory, search, cross-session recall
- [012-tree-and-ci.md](012-tree-and-ci.md) — GitHub Actions + append-only session trees
- [013-align.md](013-align.md) — merge master; recall skips this session
- [014-plugin.md](014-plugin.md) — Plugin hook; NullPlugin on master
- [015-hermes-plugin.md](015-hermes-plugin.md) — Hermes is HermesPlugin
- [016-plugin-better.md](016-plugin-better.md) — --hermes, create_plugin, glob tests
- [017-hermes-one-file.md](017-hermes-one-file.md) — hermes overwrites coding/active.mojo only
