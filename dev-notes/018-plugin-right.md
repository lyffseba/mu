# Phase 18 — Plugin hook, done right

The one-file swap was the right shape. The contracts were not.

## What was wrong

- Plugin append sat *before* skills and AGENTS.md. A frozen snapshot
  in the middle of a changing prefix is not frozen.
- REPL `/hermes` rebuilt the system prompt with `custom=""`, so a
  `--system-prompt` vanished on late wake.
- `handle_command` ran on a *copy* of the plugin. The runner kept
  the original. Fine for NullPlugin / HermesPlugin (state is on
  disk). Wrong the moment a plugin has in-memory state.
- No test proved runner dispatch, late tool add, or block order.

## Fixes

- `build_system_prompt` appends the plugin block last.
- `apply_plugin_effects` lives next to it in `coding/prompt.mojo`.
- `drive` / `repl` thread `custom_system` through late refresh.
- The runner owns the plugin. Commands mutate that instance.
- Tests: idle NullPlugin, last-block order, add-then-freeze,
  custom system kept, unknown kind goes to the plugin.
