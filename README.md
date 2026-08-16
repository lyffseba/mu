# Mu

A small, readable terminal coding agent — written in [Mojo 1.0](https://www.modular.com/blog/modular-26-5-mojo-1-0-is-here).

Mu is a Mojo port of the idea behind [Tau](https://github.com/huggingface/tau) and [Pi](https://pi.dev): a coding agent you can run, and a codebase you can read.

## Two branches

This public repo has **exactly two branches**. They stay aligned. Only one difference:

| Branch | What you get |
| --- | --- |
| **`master`** (this) | A normal Mu / Pi session. Stateless between runs except the JSONL transcript. No living agent. |
| **`hermes`** | Same Mu, plus a native living [Hermes](https://hermes-agent.nousresearch.com/docs/) agent. `/hermes` binds *this* session to persistent memory, SOUL, and a learning loop. |

```bash
git clone https://github.com/lyffseba/mu.git
cd mu                 # master — a normal session
git checkout hermes   # living Hermes agent, session-weighted
```

If you want the agent to remember you, learn skills from work, and stay alive across turns — use `hermes`. If you want a disposable coding session — stay on `master`.

See [BRANCHES.md](BRANCHES.md).

```text
mu (CLI)  →  mu.agent (brain)  →  mu.ai (providers)
                ↑
           mu.coding (tools, sessions, prompts)
```

- `mu.ai` talks to model providers.
- `mu.agent` owns the portable brain: messages, tools, events, loop.
- `mu.coding` is the coding app: CLI, filesystem/shell tools, sessions, prompts.

The important boundary is:

```text
AgentLoop = reusable brain
CodingRunner = coding-agent environment
print / REPL = one possible frontend
```

The core does not print. Frontends consume events.

## Status

**Then do it better.** Prompt templates, named sessions, and recursive skills —
still aligned with [Pi](https://pi.dev/docs/latest) and [Mojo](https://mojolang.org/docs/).

What works today:

- Print mode and a small interactive REPL
- Live token streaming (SSE, with a non-stream fallback)
- Built-in tools: `read`, `write`, `edit`, `bash`
- Tau-compatible `edit` (unique, non-overlapping, original line endings)
- OpenAI-compatible `/chat/completions` (no extra Python deps)
- `--fake` echo provider for offline runs (explicit; missing keys error out)
- Append-only JSONL sessions under `~/.mu/sessions/`
- `--session <id>` resume and `--sessions` listing
- Provider-safe tool-history repair on resume
- Local context compaction (`/compact`, auto-compact, `/status`; never splits a tool pair)
- Piped stdin merges into the prompt
- `~/.mu/config.json` for model / provider / last session
- `mu -c` resumes the last session
- A stale or corrupt `--continue` pointer degrades to the newest session
- A truncated tool call (a length cutoff, a hand-edited JSONL) degrades a
   run with a clear error instead of crashing or looping
- A failed stream never re-runs after tokens reached the screen
- Resume skips a truncated final JSONL line instead of failing
- Transient HTTP retries (429 / 5xx)
- `pixi run build` produces `build/mu`
- Project instructions from `AGENTS.md` / `MU.md`
- Skills (`<name>/SKILL.md` under `~/.mu/skills`, `~/.agents/skills`, and the project)
- `/skill:<name>` prompt expansion and `/skills` listing
- `--continue` / `--sessions` scoped to the current working directory
- `--no-skills` disables skill discovery
- Bash tools inherit `AI_AGENT=mu` and `MU_SESSION_ID` / `MU_MODEL` / `MU_PROVIDER`
- Prompt templates (`/name`, `$1` / `$@`, `/prompts`)
- `--name` display names and `--no-session` ephemeral runs
- Session trees (`/tree`, `/fork`, `--fork`) — append-only, Pi-shaped
- GitHub Actions runs `pixi run test` on push
- Recursive skill discovery (`**/SKILL.md`)

What is intentionally not here yet:

- A real TUI
- OAuth login and a provider catalog
- Extensions, themes
- Image attachments

## Install

Requires [pixi](https://pixi.sh) and macOS or Linux.

```bash
git clone <this-repo> mu
cd mu
pixi install
pixi run mu --version
pixi run build          # optional: compiled binary at build/mu
```

## Quickstart

```bash
cd my-project
pixi run --manifest-path /path/to/mu/pixi.toml mu -p "explain what this project does"
```

Or from the `mu` checkout:

```bash
pixi run mu --fake -p "hello"
pixi run mu -p "summarize the architecture"
cat README.md | pixi run mu -p "summarize this"
pixi run mu --sessions
pixi run mu --session <id>
pixi run mu -c
pixi run mu
```

Set a key before talking to a real model:

```bash
export OPENAI_API_KEY=sk-...
# or
export MU_API_KEY=...
export MU_MODEL=gpt-4.1-mini
export MU_BASE_URL=https://api.openai.com/v1
```

Or write `~/.mu/config.json`:

```json
{
  "model": "gpt-4.1-mini",
  "provider": "openai",
  "base_url": "https://api.openai.com/v1"
}
```

OpenRouter and any other OpenAI-compatible endpoint work with `--provider` / `--base-url`.

```bash
pixi run mu --provider openrouter --model anthropic/claude-sonnet-4 \
  -p "what does this repo do?"
```

## Tools

Same four tools as Tau/Pi, resolved against `--cwd`:

| Tool | Purpose |
| --- | --- |
| `read` | Read a text file (`offset` / `limit` supported) |
| `write` | Create or overwrite a file |
| `edit` | Exact `oldText` → `newText` replacements (must match once) |
| `bash` | Run a shell command |

## Tests

```bash
pixi run test
```

## Why "Mu"?

Tau is a Python port of Pi. Mu is the next letter in that joke, and a Mojo-sized name.

First do it, then do it right, then do it better.
