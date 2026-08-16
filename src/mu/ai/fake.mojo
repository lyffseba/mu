"""Deterministic fake provider for tests and offline demos."""

from mu.agent.messages import Message, ToolCall, encode_tool_calls
from mu.agent.provider import Completion
from mu.agent.tools import Tool


@fieldwise_init
struct ScriptedTurn(Copyable, ImplicitlyCopyable, Movable):
    """One canned assistant reply."""

    var content: String
    var tool_name: String
    var tool_arguments: String

    @staticmethod
    def text(content: String) -> ScriptedTurn:
        return ScriptedTurn(content, "", "")

    @staticmethod
    def tool(
        name: String, arguments: String, content: String = ""
    ) -> ScriptedTurn:
        return ScriptedTurn(content, name, arguments)

    def to_completion(self, turn_index: Int) raises -> Completion:
        if self.tool_name.byte_length() == 0:
            return Completion(Message.assistant(self.content), "{}")
        var calls = List[ToolCall]()
        calls.append(
            ToolCall(
                String("call_", turn_index), self.tool_name, self.tool_arguments
            )
        )
        return Completion(
            Message.assistant(
                self.content, "toolUse", encode_tool_calls(calls)
            ),
            "{}",
        )


struct FakeProvider:
    """Replay a script of assistant turns, then stop with a final text reply."""

    var turns: List[ScriptedTurn]
    var cursor: Int

    def __init__(
        out self, var turns: List[ScriptedTurn] = List[ScriptedTurn]()
    ):
        self.turns = turns^
        self.cursor = 0

    def complete(
        mut self,
        model: String,
        system: String,
        messages: List[Message],
        tools: List[Tool],
    ) raises -> Completion:
        _ = model
        _ = system
        _ = messages
        _ = tools
        if self.cursor >= len(self.turns):
            return Completion(Message.assistant("Done."), "{}")
        var turn = self.turns[self.cursor].copy()
        self.cursor += 1
        return turn.to_completion(self.cursor)


def complete_echo(
    model: String,
    system: String,
    messages: List[Message],
    tools: List[Tool],
) raises -> Completion:
    """Reply with the last user text. Useful as a no-network smoke test."""
    _ = model
    _ = system
    _ = tools
    var last = String("")
    for message in messages:
        if message.role == "user":
            last = message.content
    return Completion(Message.assistant(String("echo: ", last)), "{}")
