# Phase 7 — Do it right

Correctness pass over skills and cwd-scoped sessions. The features stay;
the contracts get honest.

## Skills

- `/skill: name extra` (space after the colon) now parses the name.
  Phase 6 treated the rest as extra and raised "must include a skill
  name".
- `/skills` is a listing command. It is not `/skill:` + name `s`.
- Print mode `mu -p /skills` lists skills and exits.
- Frontmatter accepts CRLF.
- Discovery no longer `mkdir`s `~/.mu` just to look for skills.
- `$MU_AGENTS_HOME` isolates `~/.agents/skills` so tests do not leak
  into the real home directory.

## Sessions

- Header `cwd` is stored and compared without a trailing slash, so
  `/tmp/foo` and `/tmp/foo/` are the same project.
- `--sessions` after a flag error (`--cwd` missing, bad `--session`)
  now reports the error instead of listing.

## Aligned with current docs

From [Pi latest](https://pi.dev/docs/latest):
- Skills use the Agent Skills spec; catalog is progressive disclosure.
- `/skill:name` expands; `/skills` lists.
- `--no-skills` disables discovery.
- Bash tools receive session markers (`AI_AGENT`, `MU_SESSION_ID`, …).
- Sessions stay project-local (`-c` / `--sessions` by cwd).

From [Mojo 1.0 docs](https://mojolang.org/docs/):
- Pixi + `python==3.12` for Python interop.
- `TestSuite.discover_tests` for unit tests.
- Skills follow the Agent Skills standard (`SKILL.md`).
- No language-level async; HTTP stays a blocking request.

## Tests

- `/skill: review …`, `/skills` is not a skill, CRLF frontmatter
- cwd trailing-slash continue
- `normalize_cwd` / `first_whitespace`
- bash sees `MU_SESSION_ID`
