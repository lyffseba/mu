# Phase 14 — Plugin hook (master)

Hermes should be a plugin, not a fork. Master now has the hook.
NullPlugin is the default. No living-agent code on this branch.

```text
Plugin
  extra_help / extra_tools / extra_prompt
  on_start(session, persist, flag)
  handle_command(text) -> CommandResult
  execute_tool(kind the runner does not know)
```

`CodingRunner` is parameterized over `P: Plugin`. Unknown tool kinds
go to the plugin. Unknown `/` commands do too.

Next: fold the hermes branch onto `HermesPlugin` and stop merging
living-agent wiring by hand.
