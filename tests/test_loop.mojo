from std.testing import assert_equal, assert_false, assert_true, TestSuite

from mu.agent.loop import AgentLoop, Completer
from mu.agent.messages import Message, ToolCall, encode_tool_calls
from mu.agent.provider import Completion
from mu.agent.sink import EventSink, NullSink
from mu.agent.tools import Tool
from mu.ai.completers import EchoCompleter, ScriptCompleter
from mu.ai.fake import ScriptedTurn
from mu.coding.runner import CodingRunner
from mu.coding.tools import create_coding_tools
from mu.plugin import NullPlugin


struct MalformedToolCompleter(Completer):
    """Reply with a tool call whose JSON we cannot parse (a length cutoff)."""

    var _unused: Bool

    def __init__(out self):
        self._unused = True

    def complete[
        S: EventSink
    ](
        mut self,
        model: String,
        system: String,
        messages: List[Message],
        tools: List[Tool],
        mut sink: S,
    ) raises -> Completion:
        _ = model
        _ = system
        _ = messages
        _ = tools
        _ = sink
        return Completion(
            Message.assistant("", "toolUse", '[{"id":"c1","name":"read"'), "{}"
        )


def test_echo_completer_stops() raises:
    var tools = create_coding_tools()
    var loop = AgentLoop("sys", "fake", ".", tools^, 4)
    var provider = EchoCompleter()
    var runner = CodingRunner("", "", "", NullPlugin())
    var run = loop.prompt(provider, runner, "hello")
    assert_true(run.ok)
    var last = run.new_messages[len(run.new_messages) - 1]
    assert_equal(last.role, "assistant")
    assert_equal(last.content, "echo: hello")


def test_scripted_tool_then_text() raises:
    var tools = create_coding_tools()
    var loop = AgentLoop("sys", "fake", ".", tools^, 4)
    var turns = List[ScriptedTurn]()
    turns.append(ScriptedTurn.tool("bash", '{"command":"printf mu"}'))
    turns.append(ScriptedTurn.text("the command printed mu"))
    var provider = ScriptCompleter(turns^)
    var runner = CodingRunner("", "", "", NullPlugin())
    var run = loop.prompt(provider, runner, "run printf")
    assert_true(run.ok)

    var saw_tool = False
    var saw_result = False
    for message in run.new_messages:
        if message.role == "assistant" and message.has_tool_calls():
            saw_tool = True
        if message.role == "tool":
            saw_result = True
            assert_equal(message.content, "mu")
    assert_true(saw_tool)
    assert_true(saw_result)

    var last = run.new_messages[len(run.new_messages) - 1]
    assert_equal(last.content, "the command printed mu")


def test_unknown_tool_is_error_result() raises:
    var tools = create_coding_tools()
    var loop = AgentLoop("sys", "fake", ".", tools^, 4)
    var turns = List[ScriptedTurn]()
    turns.append(ScriptedTurn.tool("nope", "{}"))
    turns.append(ScriptedTurn.text("handled"))
    var provider = ScriptCompleter(turns^)
    var runner = CodingRunner("", "", "", NullPlugin())
    var run = loop.prompt(provider, runner, "call missing")
    assert_true(run.ok)
    var found = False
    for message in run.new_messages:
        if message.role == "tool":
            found = True
            assert_true(message.is_error())
            assert_true(message.content.find("not found") >= 0)
    assert_true(found)


def test_repairs_dangling_tool_before_prompt() raises:
    var tools = create_coding_tools()
    var prior = List[Message]()
    var calls = List[ToolCall]()
    calls.append(ToolCall("c1", "nope", "{}"))
    prior.append(Message.assistant("", "toolUse", encode_tool_calls(calls)))
    var loop = AgentLoop("sys", "fake", ".", tools^, 4, prior^)
    var provider = EchoCompleter()
    var runner = CodingRunner("", "", "", NullPlugin())
    var run = loop.prompt(provider, runner, "continue")
    assert_true(run.ok)
    var saw_repair = False
    for message in run.new_messages:
        if message.role == "tool" and message.tool_call_id == "c1":
            saw_repair = True
            assert_true(message.is_error())
    assert_true(saw_repair)


def test_malformed_tool_call_degrades_without_crashing() raises:
    # A tool-calling assistant whose JSON we cannot parse must stop the run
    # cleanly with an error, not crash or loop to max_turns.
    var tools = create_coding_tools()
    var loop = AgentLoop("sys", "fake", ".", tools^, 4)
    var provider = MalformedToolCompleter()
    var runner = CodingRunner("", "", "", NullPlugin())
    var run = loop.prompt(provider, runner, "go")
    assert_false(run.ok)
    var last = run.new_messages[len(run.new_messages) - 1]
    assert_true(last.is_error())
    assert_true(last.error_message.find("truncated") >= 0)


def test_max_turns_stops() raises:
    var tools = create_coding_tools()
    var loop = AgentLoop("sys", "fake", ".", tools^, 1)
    var turns = List[ScriptedTurn]()
    turns.append(ScriptedTurn.tool("bash", '{"command":"printf a"}'))
    turns.append(ScriptedTurn.tool("bash", '{"command":"printf b"}'))
    var provider = ScriptCompleter(turns^)
    var runner = CodingRunner("", "", "", NullPlugin())
    var run = loop.prompt(provider, runner, "loop")
    assert_false(run.ok)
    var last = run.new_messages[len(run.new_messages) - 1]
    assert_true(last.is_error())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
