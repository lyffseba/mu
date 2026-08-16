"""A tool is a name, a description, a JSON schema, and an executor."""

from std.python import Python, PythonObject

from mu.jsonx import json_loads


@fieldwise_init
struct ToolResult(Copyable, ImplicitlyCopyable, Movable):
    """Structured result returned by a tool."""

    var content: String
    var is_error: Bool
    var details: String

    @staticmethod
    def ok(content: String, details: String = "{}") -> ToolResult:
        return ToolResult(content, False, details)

    @staticmethod
    def error(content: String, details: String = "{}") -> ToolResult:
        return ToolResult(content, True, details)


@fieldwise_init
struct Tool(Copyable, ImplicitlyCopyable, Movable):
    """A coding tool exposed to the model.

    `kind` selects a built-in executor (`read`, `write`, `edit`, `bash`,
    `echo`). Custom tools can be added later without changing the loop.
    """

    var name: String
    var description: String
    var parameters_json: String
    var kind: String

    def openai_schema(self) raises -> PythonObject:
        """Return the OpenAI function-calling schema for this tool."""
        var schema = Python.dict()
        schema["type"] = "function"
        var function = Python.dict()
        function["name"] = self.name
        function["description"] = self.description
        function["parameters"] = json_loads(self.parameters_json)
        schema["function"] = function
        return schema


def find_tool(tools: List[Tool], name: String) -> Optional[Int]:
    """Return the index of `name` in `tools`, or None."""
    var i = 0
    for tool in tools:
        if tool.name == name:
            return Optional(i)
        i += 1
    return None
