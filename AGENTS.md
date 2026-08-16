# Mu Agent Instructions

Mu is a Mojo 1.0 implementation of Pi/Tau's minimalist coding-agent harness.
Streaming, compaction, and the Python runtime live at the edges. The loop stays portable.

Public branches: `master` (this tree — a normal session) and `hermes` (same tree plus a living Hermes agent). See BRANCHES.md. Never add living-agent code on master.

```text
AgentLoop   = reusable agent brain
CodingRunner = coding-agent environment
CLI / REPL  = one possible frontend
```

Layers:

```text
mu.ai      provider/model layer
mu.agent   portable harness, loop, tools, events, messages
mu.coding  CLI, resources, sessions, coding tools
```

Keep `mu.agent` independent of CLI, rendering, session file locations, and filesystem policy.

## Mojo 1.0 notes

Current language docs: https://mojolang.org/docs/
Current Pi harness docs: https://pi.dev/docs/latest

- Target Mojo 1.0 (`pixi` package `mojo >=1.0.0,<2`).
- There is no language-level `async` yet. The loop is synchronous; HTTP is a blocking request per turn.
- There is no native JSON parser. `mu.jsonx` bridges to Python's `json` via CPython in the pixi env (`python==3.12`).
- Tools are ordinary structs: name, description, JSON schema, kind.
- Prefer explicit traits (`Completer`, `ToolRunner`) over framework magic.
- Tests use `std.testing.TestSuite.discover_tests`.
- Skills follow the [Agent Skills](https://agentskills.io/specification) directory layout (`<name>/SKILL.md`).
- Official Mojo agent skills live at https://github.com/modular/skills and the docs MCP at https://mojo-mcp.modular.com/mcp/.
- Run everything through `pixi` (`pixi run test`, `pixi run mu ...`).

## Development workflow

1. First do it — smallest thing that runs.
2. Then do it right — correctness, tests, boundaries.
3. Then do it better — streaming, TUI, sessions, speed.

Work in small, documented phases. Leave notes in `dev-notes/`.
