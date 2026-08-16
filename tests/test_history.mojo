from std.testing import assert_equal, assert_false, assert_true, TestSuite

from mu.agent.history import (
    INTERRUPTED,
    append_interrupted_results,
    provider_context,
)
from mu.agent.messages import Message, ToolCall, encode_tool_calls


def _tool_assistant(
    id: String, name: String, args: String = "{}"
) raises -> Message:
    var calls = List[ToolCall]()
    calls.append(ToolCall(id, name, args))
    return Message.assistant("", "toolUse", encode_tool_calls(calls))


def test_synthesizes_missing_tool_result() raises:
    var messages = List[Message]()
    messages.append(Message.user("go"))
    messages.append(_tool_assistant("c1", "bash"))
    var repaired = provider_context(messages)
    assert_equal(repaired.synthesized, 1)
    var last = repaired.messages[len(repaired.messages) - 1]
    assert_equal(last.role, "tool")
    assert_equal(last.content, INTERRUPTED)
    assert_true(last.is_error())


def test_drops_empty_error_turns() raises:
    var messages = List[Message]()
    messages.append(Message.user("hi"))
    messages.append(Message.error("boom"))
    messages.append(Message.user("again"))
    var repaired = provider_context(messages)
    assert_equal(repaired.dropped_empty_errors, 1)
    assert_equal(len(repaired.messages), 2)
    assert_equal(repaired.messages[1].role, "user")


def test_drops_orphan_tool_results() raises:
    var messages = List[Message]()
    messages.append(Message.user("hi"))
    messages.append(Message.tool_result("ghost", "bash", "nope"))
    var repaired = provider_context(messages)
    assert_equal(repaired.dropped_orphans, 1)
    assert_equal(len(repaired.messages), 1)


def test_keeps_paired_history() raises:
    var messages = List[Message]()
    messages.append(Message.user("run"))
    messages.append(_tool_assistant("c1", "bash"))
    messages.append(Message.tool_result("c1", "bash", "ok"))
    messages.append(Message.assistant("done"))
    var repaired = provider_context(messages)
    assert_equal(repaired.synthesized, 0)
    assert_equal(repaired.dropped_orphans, 0)
    assert_equal(len(repaired.messages), 4)


def test_append_interrupted_is_idempotent() raises:
    var messages = List[Message]()
    messages.append(_tool_assistant("c1", "read"))
    var once = append_interrupted_results(messages)
    var twice = append_interrupted_results(once)
    assert_equal(len(once), 2)
    assert_equal(len(twice), 2)
    assert_equal(twice[1].content, INTERRUPTED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
