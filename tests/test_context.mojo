from std.testing import assert_equal, assert_true, TestSuite

from mu.agent.messages import Message, ToolCall, encode_tool_calls
from mu.coding.context import (
    apply_compaction,
    estimate_context_tokens,
    estimate_text_tokens,
)


def test_token_estimate_is_ceil_div_4() raises:
    assert_equal(estimate_text_tokens(""), 0)
    assert_equal(estimate_text_tokens("abcd"), 1)
    assert_equal(estimate_text_tokens("abcde"), 2)


def test_context_includes_system() raises:
    var messages = List[Message]()
    messages.append(Message.user("hi"))
    var n = estimate_context_tokens("system text", messages)
    assert_true(n > estimate_text_tokens("hi"))


def test_compact_noop_when_short() raises:
    var messages = List[Message]()
    messages.append(Message.user("a"))
    messages.append(Message.assistant("b"))
    var got = apply_compaction(messages, 6)
    assert_equal(got.dropped, 0)
    assert_equal(len(got.messages), 2)


def test_compact_keeps_tail_and_summarizes() raises:
    var messages = List[Message]()
    messages.append(Message.user("one"))
    messages.append(Message.assistant("two"))
    messages.append(Message.user("three"))
    messages.append(Message.assistant("four"))
    messages.append(Message.user("five"))
    messages.append(Message.assistant("six"))
    var got = apply_compaction(messages, 2)
    assert_equal(got.dropped, 4)
    assert_equal(len(got.messages), 3)
    assert_equal(got.messages[0].role, "user")
    assert_true(
        got.messages[0].content.startswith("Previous conversation summary:")
    )
    assert_true(got.summary.content.find("- user: one") >= 0)
    assert_equal(got.messages[1].content, "five")
    assert_equal(got.messages[2].content, "six")


def test_compact_does_not_split_tool_pair() raises:
    var messages = List[Message]()
    var calls = List[ToolCall]()
    calls.append(ToolCall("c1", "bash", "{}"))
    messages.append(Message.assistant("", "toolUse", encode_tool_calls(calls)))
    messages.append(Message.tool_result("c1", "bash", "ok"))
    messages.append(Message.user("later"))
    # keep=2 would otherwise cut on the tool result. Refuse rather than split.
    var got = apply_compaction(messages, 2)
    assert_equal(got.dropped, 0)
    assert_equal(len(got.messages), 3)
    assert_equal(got.messages[1].role, "tool")


def test_compact_keeps_whole_tool_pair() raises:
    var messages = List[Message]()
    messages.append(Message.user("old"))
    var calls = List[ToolCall]()
    calls.append(ToolCall("c1", "read", "{}"))
    messages.append(Message.assistant("", "toolUse", encode_tool_calls(calls)))
    messages.append(Message.tool_result("c1", "read", "ok"))
    messages.append(Message.user("later"))
    var got = apply_compaction(messages, 3)
    assert_equal(got.dropped, 1)
    assert_equal(got.messages[1].role, "assistant")
    assert_equal(got.messages[2].role, "tool")
    assert_equal(got.messages[3].content, "later")


def test_compact_mentions_tool_names() raises:
    var messages = List[Message]()
    var calls = List[ToolCall]()
    calls.append(ToolCall("c1", "bash", "{}"))
    messages.append(Message.assistant("", "toolUse", encode_tool_calls(calls)))
    messages.append(Message.tool_result("c1", "bash", "ok"))
    messages.append(Message.user("later"))
    var got = apply_compaction(messages, 1)
    assert_equal(got.dropped, 2)
    assert_true(got.summary.content.find("bash") >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
