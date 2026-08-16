# Phase 6 — Do it better

Daily-use leverage that isn't a TUI: reusable know-how, and sessions
that stay in the project you started them in.

## Skills

A skill is a directory containing `SKILL.md` (the Agent Skills spec).
Search roots, increasing precedence — later overrides earlier:

```text
~/.mu/skills/
~/.agents/skills/
<cwd>/.mu/skills/
<cwd>/.agents/skills/
```

Bare `.md` files at the root of a skills directory are not skills.

The system prompt lists loaded skills. The model can `read` a SKILL.md
when a task calls for it. The user can also expand one into the prompt:

```text
/skill:review look at auth
```

REPL: `/skills` lists them. Unknown names are an error, not a prompt.

## Cwd-scoped continue

`--continue` and `--sessions` now prefer sessions whose header `cwd`
matches the current working directory. A remembered pointer from another
project is treated as stale and falls back to the newest session *here*.
`--session <id>` still opens an exact id.

## Intentionally still not here

A real TUI, branching, OAuth, image attachments. Prompt templates can
wait — skills cover the reusable-know-how case.
