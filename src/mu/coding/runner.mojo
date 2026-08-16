"""Coding-tool runner used by the application layer."""

from mu.agent.loop import ToolRunner
from mu.agent.messages import ToolCall
from mu.agent.tools import Tool, ToolResult
from mu.coding.tools import execute_tool
from mu.plugin import Plugin


struct CodingRunner[P: Plugin](ToolRunner):
    """Executes built-in tools, then the plugin for unknown kinds."""

    var session_id: String
    var model: String
    var provider: String
    var plugin: Self.P

    def __init__(
        out self,
        session_id: String,
        model: String,
        provider: String,
        var plugin: Self.P,
    ):
        self.session_id = session_id
        self.model = model
        self.provider = provider
        self.plugin = plugin^

    def run(self, tool: Tool, call: ToolCall, cwd: String) raises -> ToolResult:
        if (
            tool.kind == "read"
            or tool.kind == "write"
            or tool.kind == "edit"
            or tool.kind == "bash"
            or tool.kind == "echo"
        ):
            return execute_tool(
                tool, call, cwd, self.session_id, self.model, self.provider
            )
        return self.plugin.execute_tool(tool, call, self.session_id)
