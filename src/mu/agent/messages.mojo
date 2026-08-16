"""Provider-neutral transcript messages.

The stored protocol is intentionally small: a role, visible text, and
optional tool-call metadata encoded as JSON. That keeps the first cut
readable without fighting Mojo 1.0's lack of tagged unions.
"""

from std.python import Python

from mu.jsonx import empty_array, json_dumps, json_loads, py_str


@fieldwise_init
struct ToolCall(Copyable, ImplicitlyCopyable, Movable):
    """One model-requested tool invocation."""

    var id: String
    var name: String
    var arguments: String

    def to_json(self) raises -> String:
        var obj = Python.dict()
        obj["id"] = self.id
        obj["name"] = self.name
        obj["arguments"] = self.arguments
        return json_dumps(obj)


@fieldwise_init
struct Message(Copyable, ImplicitlyCopyable, Movable):
    """A single transcript entry.

    `role` is one of `user`, `assistant`, `tool`.
    `tool_calls_json` is a JSON array of `{id, name, arguments}` objects.
    """

    var role: String
    var content: String
    var tool_call_id: String
    var tool_name: String
    var tool_calls_json: String
    var stop_reason: String
    var error_message: String

    @staticmethod
    def user(content: String) -> Message:
        return Message("user", content, "", "", "[]", "", "")

    @staticmethod
    def assistant(
        content: String,
        stop_reason: String = "stop",
        tool_calls_json: String = "[]",
        error_message: String = "",
    ) -> Message:
        return Message(
            "assistant",
            content,
            "",
            "",
            tool_calls_json,
            stop_reason,
            error_message,
        )

    @staticmethod
    def tool_result(
        tool_call_id: String,
        tool_name: String,
        content: String,
        is_error: Bool = False,
    ) -> Message:
        var stop = String("error") if is_error else String("stop")
        return Message(
            "tool",
            content,
            tool_call_id,
            tool_name,
            "[]",
            stop,
            "",
        )

    @staticmethod
    def error(model_note: String) -> Message:
        return Message(
            "assistant",
            "",
            "",
            "",
            "[]",
            "error",
            model_note,
        )

    def is_error(self) -> Bool:
        return self.stop_reason == "error" or self.stop_reason == "aborted"

    def has_tool_calls(self) -> Bool:
        var raw = self.tool_calls_json
        return raw.byte_length() > 2 and raw != "[]" and raw != "null"

    def tool_calls(self) raises -> List[ToolCall]:
        var raw = self.tool_calls_json
        if raw.byte_length() <= 2 or raw == "[]" or raw == "null":
            return List[ToolCall]()
        var calls = List[ToolCall]()
        try:
            # A length cutoff or a hand-edited JSONL can leave a truncated
            # array. Degrade to "no calls" rather than crash a run.
            var items = json_loads(raw)
            var n = Int(py=items.__len__())
            var i = 0
            while i < n:
                var item = items[i]
                calls.append(
                    ToolCall(
                        py_str(item["id"]),
                        py_str(item["name"]),
                        py_str(item["arguments"]),
                    )
                )
                i += 1
        except e:
            _ = e
        return calls^

    def visible_text(self) -> String:
        if self.role == "assistant" and self.error_message.byte_length() > 0:
            if self.content.byte_length() == 0:
                return self.error_message
        return self.content


def encode_tool_calls(calls: List[ToolCall]) raises -> String:
    """Serialize tool calls to the on-wire JSON array."""
    var arr = empty_array()
    for call in calls:
        var obj = Python.dict()
        obj["id"] = call.id
        obj["name"] = call.name
        obj["arguments"] = call.arguments
        arr.append(obj)
    return json_dumps(arr)


def message_summary(message: Message) -> String:
    """One-line debug summary for logs and tests."""
    var text = message.visible_text()
    if text.byte_length() > 80:
        text = String(text[byte=0:77]) + "..."
    return String(
        "[",
        message.role,
        "] ",
        text,
        " stop=",
        message.stop_reason,
        " tools=",
        message.tool_calls_json,
    )
