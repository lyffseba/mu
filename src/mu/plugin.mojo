"""Tiny plugin hook. Master ships NullPlugin only.

A plugin can add tools, a system-prompt block, slash commands, and
tool kinds the coding runner does not know. Hermes is one plugin
(on the hermes branch). Master never imports it.

Pi/Hermes both treat this as an extension, not a fork.
"""

from mu.agent.messages import ToolCall
from mu.agent.tools import Tool, ToolResult


@fieldwise_init
struct CommandResult(Copyable, ImplicitlyCopyable, Movable):
    """Outcome of a plugin slash command."""

    var handled: Bool
    var consume: Bool
    var rewrite: String
    var printed: String
    var error: String

    @staticmethod
    def ignore() -> CommandResult:
        return CommandResult(False, False, "", "", "")

    @staticmethod
    def done(printed: String = "") -> CommandResult:
        return CommandResult(True, True, "", printed, "")

    @staticmethod
    def fail(message: String) -> CommandResult:
        return CommandResult(True, True, "", "", message)

    @staticmethod
    def rewrite_prompt(text: String) -> CommandResult:
        return CommandResult(True, False, text, "", "")


trait Plugin(Copyable, Movable, Deinitable):
    """Optional extra behavior. Implementations must be cheap no-ops when idle."""

    def extra_help(self) -> String:
        ...

    def extra_tools(self, session_id: String) raises -> List[Tool]:
        ...

    def extra_prompt(self, session_id: String) raises -> String:
        ...

    def on_start(
        mut self, session_id: String, persist: Bool, flag_on: Bool
    ) raises -> String:
        """Return an error string, or empty on success."""
        ...

    def handle_command(
        mut self, text: String, session_id: String, persist: Bool
    ) raises -> CommandResult:
        ...

    def execute_tool(
        self, tool: Tool, call: ToolCall, session_id: String
    ) raises -> ToolResult:
        ...


struct NullPlugin(Plugin, ImplicitlyCopyable):
    """No extra behavior. This is master."""

    var _unused: Int

    def __init__(out self):
        self._unused = 0

    def extra_help(self) -> String:
        return ""

    def extra_tools(self, session_id: String) raises -> List[Tool]:
        _ = session_id
        return List[Tool]()

    def extra_prompt(self, session_id: String) raises -> String:
        _ = session_id
        return ""

    def on_start(
        mut self, session_id: String, persist: Bool, flag_on: Bool
    ) raises -> String:
        _ = session_id
        _ = persist
        if flag_on:
            return "this build has no living-agent plugin (use the hermes branch)"
        return ""

    def handle_command(
        mut self, text: String, session_id: String, persist: Bool
    ) raises -> CommandResult:
        _ = text
        _ = session_id
        _ = persist
        return CommandResult.ignore()

    def execute_tool(
        self, tool: Tool, call: ToolCall, session_id: String
    ) raises -> ToolResult:
        _ = call
        _ = session_id
        return ToolResult.error(String("Unknown tool kind: ", tool.kind))
