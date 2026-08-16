from std.testing import assert_equal, assert_false, assert_true, TestSuite

from mu.agent.messages import Message, ToolCall, encode_tool_calls
from mu.agent.tools import Tool
from mu.ai.openai import (
    build_chat_payload,
    completion_from_acc,
    parse_chat_completion,
    should_fallback_after_stream,
    to_openai_message,
)
from mu.pyrt import runtime
from mu.coding.tools import create_coding_tools
from mu.jsonx import json_dumps, json_loads, py_str


def test_parse_text_completion() raises:
    var raw = (
        '{"choices":[{"finish_reason":"stop","message":'
        '{"role":"assistant","content":"hello"}}]}'
    )
    var done = parse_chat_completion(raw, "m")
    assert_equal(done.message.content, "hello")
    assert_equal(done.message.stop_reason, "stop")


def test_parse_tool_call() raises:
    var raw = (
        '{"choices":[{"finish_reason":"tool_calls","message":{'
        '"role":"assistant","content":null,'
        '"tool_calls":[{"id":"c1","type":"function",'
        '"function":{"name":"read","arguments":"{\\"path\\":\\"a\\"}"}}]'
        "}}]}"
    )
    var done = parse_chat_completion(raw, "m")
    assert_equal(done.message.stop_reason, "toolUse")
    var calls = done.message.tool_calls()
    assert_equal(len(calls), 1)
    assert_equal(calls[0].name, "read")
    assert_true(calls[0].arguments.find("path") >= 0)


def test_payload_includes_tools_and_system() raises:
    var tools = create_coding_tools()
    var messages = List[Message]()
    messages.append(Message.user("hi"))
    var payload = build_chat_payload("gpt-test", "be helpful", messages, tools)
    assert_equal(py_str(payload["model"]), "gpt-test")
    var wire = payload["messages"]
    assert_equal(py_str(wire[0]["role"]), "system")
    assert_equal(py_str(wire[0]["content"]), "be helpful")
    assert_equal(Int(py=payload["tools"].__len__()), 4)


def test_parse_error_object() raises:
    var raw = '{"error":{"message":"nope","type":"invalid_request_error"}}'
    var done = parse_chat_completion(raw, "m")
    assert_true(done.message.is_error())
    assert_equal(done.message.error_message, "nope")


def test_empty_error_turn_not_sent() raises:
    var tools = create_coding_tools()
    var messages = List[Message]()
    messages.append(Message.user("hi"))
    messages.append(Message.error("boom"))
    messages.append(Message.user("again"))
    var payload = build_chat_payload("gpt-test", "sys", messages, tools)
    var wire = payload["messages"]
    # system + user + user; the empty error assistant is dropped
    assert_equal(Int(py=wire.__len__()), 3)
    assert_equal(py_str(wire[1]["role"]), "user")
    assert_equal(py_str(wire[2]["content"]), "again")


def test_stream_acc_text_and_tools() raises:
    var acc = runtime().new_stream_acc()
    _ = acc.apply('{"choices":[{"delta":{"content":"Hel"}}]}')
    _ = acc.apply('{"choices":[{"delta":{"content":"lo"}}]}')
    _ = acc.apply(
        '{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"c1",'
        '"function":{"name":"read","arguments":"ab"}}]}}]}'
    )
    _ = acc.apply(
        '{"choices":[{"finish_reason":"tool_calls","delta":{"tool_calls":'
        '[{"index":0,"function":{"arguments":"cd"}}]}}]}'
    )
    var done = completion_from_acc(acc.message())
    assert_equal(done.message.content, "Hello")
    assert_equal(done.message.stop_reason, "toolUse")
    var calls = done.message.tool_calls()
    assert_equal(len(calls), 1)
    assert_equal(calls[0].id, "c1")
    assert_equal(calls[0].name, "read")
    assert_equal(calls[0].arguments, "abcd")


def test_empty_stream_snapshot_is_empty() raises:
    var acc = runtime().new_stream_acc()
    var final = acc.message()
    assert_equal(Bool(py=final["had_data"]), False)
    _ = acc.apply('{"choices":[{"delta":{"content":"x"}}]}')
    final = acc.message()
    assert_equal(Bool(py=final["had_data"]), True)


def test_stream_acc_error() raises:
    var acc = runtime().new_stream_acc()
    _ = acc.apply('{"error":{"message":"nope"}}')
    var done = completion_from_acc(acc.message())
    assert_true(done.message.is_error())
    assert_equal(done.message.error_message, "nope")


def test_tool_calls_tolerates_truncated_array() raises:
    # A length cutoff mid-arguments leaves a JSON array we can't parse.
    var msg = Message.assistant("", "toolUse", '[{"id":"c1","name":"read"')
    assert_true(msg.has_tool_calls())
    var calls = msg.tool_calls()
    assert_equal(len(calls), 0)


def test_no_fallback_once_stream_emitted() raises:
    # A failed stream re-runs only when nothing reached the user yet.
    assert_true(should_fallback_after_stream(False))
    assert_false(should_fallback_after_stream(True))


def test_tool_result_roundtrip() raises:
    var msg = Message.tool_result("c1", "bash", "ok")
    var obj = to_openai_message(msg)
    assert_equal(py_str(obj["role"]), "tool")
    assert_equal(py_str(obj["tool_call_id"]), "c1")
    assert_equal(py_str(obj["content"]), "ok")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
