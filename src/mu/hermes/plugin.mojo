"""Hermes as a Plugin. This branch's only living-agent wiring."""

from mu.agent.messages import ToolCall
from mu.agent.tools import Tool, ToolResult
from mu.hermes.memory import (
    format_memory_listing,
    frozen_memory_block,
    learning_nudge,
    memory_search,
)
from mu.hermes.paths import is_awake, mark_awake
from mu.hermes.tool import create_memory_tool, execute_memory
from mu.plugin import CommandResult, Plugin
from mu.text import strip_text


struct HermesPlugin(Plugin, ImplicitlyCopyable):
    """SOUL, memory, /hermes, /memory. Weighted on the current session."""

    var _unused: Int

    def __init__(out self):
        self._unused = 0

    def version_suffix(self) -> String:
        return "-hermes"

    def extra_help(self) -> String:
        return " /hermes  /memory"

    def extra_tools(self, session_id: String) raises -> List[Tool]:
        var tools = List[Tool]()
        if is_awake(session_id):
            tools.append(create_memory_tool())
        return tools^

    def extra_prompt(self, session_id: String) raises -> String:
        if not is_awake(session_id):
            return ""
        return frozen_memory_block(session_id) + "\n\n" + learning_nudge()

    def on_start(
        mut self, session_id: String, persist: Bool, flag_on: Bool
    ) raises -> String:
        if flag_on and not persist:
            return "hermes requires a persisted session (drop --no-session)"
        if flag_on or is_awake(session_id):
            mark_awake(session_id)
        return ""

    def handle_command(
        mut self, text: String, session_id: String, persist: Bool
    ) raises -> CommandResult:
        var t = strip_text(text)
        if t == "/memory" or t.startswith("/memory "):
            if not is_awake(session_id):
                return CommandResult.done(
                    "hermes is asleep. /hermes to wake this session."
                )
            var q = String()
            if t.startswith("/memory "):
                q = strip_text(String(t[byte=8 : t.byte_length()]))
            if q.byte_length() == 0:
                return CommandResult.done(format_memory_listing(session_id))
            return CommandResult.done(memory_search(session_id, q, ""))
        if t == "/hermes" or t.startswith("/hermes "):
            if not persist:
                return CommandResult.fail(
                    "hermes requires a persisted session (drop --no-session)"
                )
            var already = is_awake(session_id)
            if not already:
                mark_awake(session_id)
            var printed: String
            if already:
                printed = String("hermes already awake on ", session_id)
            else:
                printed = String(
                    "hermes awake on session ",
                    session_id,
                    "\nThis Mu session is now a living agent. Memory is weighted here.",
                )
            var rest = String()
            if t.startswith("/hermes "):
                rest = strip_text(String(t[byte=8 : t.byte_length()]))
            if rest.byte_length() == 0:
                return CommandResult.done(printed)
            var result = CommandResult.rewrite_prompt(rest)
            result.printed = printed
            return result
        return CommandResult.ignore()

    def execute_tool(
        self, tool: Tool, call: ToolCall, session_id: String
    ) raises -> ToolResult:
        if tool.kind == "memory":
            return execute_memory(call, session_id)
        return ToolResult.error(String("Unknown tool kind: ", tool.kind))
