# Phase 8 — Do it better

Daily-use leverage from current Pi docs: prompt templates, named
sessions, ephemeral runs, and recursive skill discovery.

## Prompt templates

A template is `name.md`. `/name args` expands it.

```text
~/.mu/prompts/
~/.agents/prompts/
<cwd>/.mu/prompts/
<cwd>/.agents/prompts/
```

Discovery is non-recursive. Reserved names (`skills`, `prompts`, `tools`)
are ignored. `$1` and `$@` / `$ARGUMENTS` substitute; otherwise extra
text is appended.

`/prompts` lists them. Print mode `mu -p /prompts` works too.

## Named + ephemeral sessions

- `--name` / `-n` stores a display name on the session header.
- `--sessions` shows the name when present.
- `--no-session` runs without writing JSONL or updating last-session.

## Recursive skills

`<dir>/**/SKILL.md` is discovered, matching Pi's recursive Agent Skills
scan. Nested directory name is the skill name.

## Intentionally still not here

TUI, branching, OAuth, themes, image attachments.
