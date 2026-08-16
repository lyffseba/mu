"""Coding-tool runner used by the application layer."""

from mu.agent.loop import ToolRunner
from mu.agent.messages import ToolCall
from mu.agent.tools import Tool, ToolResult
from mu.coding.tools import execute_tool


struct CodingRunner(ToolRunner):
    """Executes the built-in read/write/edit/bash tools."""

    var session_id: String
    var model: String
    var provider: String

    def __init__(
        out self,
        session_id: String = "",
        model: String = "",
        provider: String = "",
    ):
        self.session_id = session_id
        self.model = model
        self.provider = provider

    def run(self, tool: Tool, call: ToolCall, cwd: String) raises -> ToolResult:
        return execute_tool(
            tool, call, cwd, self.session_id, self.model, self.provider
        )
