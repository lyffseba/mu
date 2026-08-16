"""OpenAI-compatible `/chat/completions` provider.

Uses the cached `mu_runtime` Python helper so HTTP and SSE don't pay an
import tax every turn. Streaming is the default; a failed stream falls
back to one complete request.
"""

from std.python import Python, PythonObject

from mu.agent.messages import Message, ToolCall, encode_tool_calls
from mu.agent.provider import Completion, ProviderConfig
from mu.agent.sink import EventSink
from mu.agent.tools import Tool
from mu.jsonx import (
    empty_array,
    empty_object,
    json_as_text,
    json_dumps,
    json_get_str,
    json_has,
    json_loads,
    py_is_none,
    py_str,
)
from mu.pyrt import runtime


def complete_openai[
    S: EventSink
](
    config: ProviderConfig,
    system: String,
    messages: List[Message],
    tools: List[Tool],
    mut sink: S,
    stream: Bool = True,
) raises -> Completion:
    """Call an OpenAI-compatible chat-completions endpoint once."""
    if stream:
        try:
            return complete_openai_stream[S](
                config, system, messages, tools, sink
            )
        except e:
            # Some servers don't speak SSE. Fall back once - but only
            # before anything reached the user. If tokens already streamed,
            # a second call would diverge from what was shown and cost
            # extra, so surface a clean error instead of rerunning.
            if should_fallback_after_stream(sink.wrote()):
                _ = e
            else:
                return Completion(
                    Message.error(
                        String(
                            (
                                "stream ended after partial output; not"
                                " re-running: "
                            ),
                            e,
                        )
                    ),
                    "",
                )
    try:
        var payload = build_chat_payload(
            config.model, system, messages, tools, False
        )
        var body = json_dumps(payload)
        var url = join_url(config.base_url, "/chat/completions")
        var raw = http_post_json(
            url, body, config.api_key, config.timeout_seconds
        )
        return parse_chat_completion(raw, config.model)
    except e:
        return Completion(Message.error(String(e)), "")


def complete_openai_stream[
    S: EventSink
](
    config: ProviderConfig,
    system: String,
    messages: List[Message],
    tools: List[Tool],
    mut sink: S,
) raises -> Completion:
    """Stream one `/chat/completions` response as text deltas + a final message.
    """
    var payload = build_chat_payload(
        config.model, system, messages, tools, True
    )
    var body = json_dumps(payload)
    var url = join_url(config.base_url, "/chat/completions")
    var rt = runtime()
    var acc = rt.new_stream_acc()
    var gen = rt.iter_sse(url, body, config.api_key, config.timeout_seconds)
    while True:
        var chunk = rt.gen_next(gen)
        if py_is_none(chunk):
            break
        var delta = py_str(acc.apply(chunk))
        if delta.byte_length() > 0:
            sink.on_text(delta)
    var final = acc.message()
    if json_get_str(final, "error").byte_length() == 0:
        var had = False
        if json_has(final, "had_data"):
            had = Bool(py=final["had_data"])
        if not had:
            raise Error("empty provider stream")
    return completion_from_acc(final)


def completion_from_acc(final: PythonObject) raises -> Completion:
    """Turn a StreamAcc snapshot into a Completion."""
    var err = json_get_str(final, "error")
    if err.byte_length() > 0:
        return Completion(Message.error(err), json_dumps(final))

    var content = json_get_str(final, "content")
    var finish = json_get_str(final, "finish", "stop")
    var tool_calls_json = "[]"
    var raw_calls = final["tool_calls"]
    var n = Int(py=raw_calls.__len__())
    if n > 0:
        var parsed = List[ToolCall]()
        for i in range(n):
            var item = raw_calls[i]
            parsed.append(
                ToolCall(
                    py_str(item["id"]),
                    py_str(item["name"]),
                    json_as_text(item["arguments"]),
                )
            )
        tool_calls_json = encode_tool_calls(parsed)

    var stop_reason = "stop"
    if finish == "tool_calls" or finish == "function_call" or n > 0:
        stop_reason = "toolUse"
    elif finish == "length":
        stop_reason = "length"
    elif finish == "error":
        stop_reason = "error"

    return Completion(
        Message.assistant(content, stop_reason, tool_calls_json),
        json_dumps(final),
    )


def should_fallback_after_stream(emitted: Bool) -> Bool:
    """A failed stream falls back to one request only when nothing streamed."""
    return not emitted


def join_url(base: String, suffix: String) -> String:
    var url = base
    if url.endswith("/"):
        var trimmed = String(url[byte = 0 : url.byte_length() - 1])
        url = trimmed
    return url + suffix


def build_chat_payload(
    model: String,
    system: String,
    messages: List[Message],
    tools: List[Tool],
    stream: Bool = False,
) raises -> PythonObject:
    """Build a `/chat/completions` request body."""
    var payload = empty_object()
    payload["model"] = model
    payload["stream"] = stream

    var wire = empty_array()
    if system.byte_length() > 0:
        var sys_msg = empty_object()
        sys_msg["role"] = "system"
        sys_msg["content"] = system
        wire.append(sys_msg)

    for message in messages:
        if (
            message.role == "assistant"
            and message.is_error()
            and not message.has_tool_calls()
        ):
            if message.content.byte_length() == 0:
                continue
        wire.append(to_openai_message(message))
    payload["messages"] = wire

    if len(tools) > 0:
        var tool_arr = empty_array()
        for tool in tools:
            tool_arr.append(tool.openai_schema())
        payload["tools"] = tool_arr
        payload["tool_choice"] = "auto"

    return payload


def to_openai_message(message: Message) raises -> PythonObject:
    """Convert one Mu transcript message to OpenAI's chat schema."""
    var obj = empty_object()
    if message.role == "user":
        obj["role"] = "user"
        obj["content"] = message.content
        return obj
    if message.role == "tool":
        obj["role"] = "tool"
        obj["tool_call_id"] = message.tool_call_id
        obj["content"] = message.content
        if message.tool_name.byte_length() > 0:
            obj["name"] = message.tool_name
        return obj

    obj["role"] = "assistant"
    if message.content.byte_length() > 0:
        obj["content"] = message.content
    else:
        obj["content"] = Python.none()
    if message.has_tool_calls():
        var calls = message.tool_calls()
        var arr = empty_array()
        for call in calls:
            var item = empty_object()
            item["id"] = call.id
            item["type"] = "function"
            var function = empty_object()
            function["name"] = call.name
            if call.arguments.byte_length() > 0:
                function["arguments"] = call.arguments
            else:
                function["arguments"] = "{}"
            item["function"] = function
            arr.append(item)
        obj["tool_calls"] = arr
    return obj


def parse_chat_completion(raw: String, model: String) raises -> Completion:
    """Parse a non-streaming chat-completions response into a Message."""
    var data = json_loads(raw)
    if json_has(data, "error"):
        var err = data["error"]
        var msg = json_get_str(err, "message", py_str(err))
        return Completion(Message.error(msg), raw)

    if not json_has(data, "choices"):
        return Completion(Message.error("Provider returned no choices"), raw)

    var choices = data["choices"]
    if Int(py=choices.__len__()) < 1:
        return Completion(Message.error("Provider returned no choices"), raw)

    var choice = choices[0]
    var message = choice["message"]
    var content = ""
    if json_has(message, "content") and not py_is_none(message["content"]):
        content = py_str(message["content"])

    var tool_calls_json = "[]"
    if json_has(message, "tool_calls") and not py_is_none(
        message["tool_calls"]
    ):
        var parsed = List[ToolCall]()
        var raw_calls = message["tool_calls"]
        var n = Int(py=raw_calls.__len__())
        for i in range(n):
            var item = raw_calls[i]
            var function = item["function"]
            var arguments = function["arguments"]
            parsed.append(
                ToolCall(
                    py_str(item["id"]),
                    py_str(function["name"]),
                    json_as_text(arguments),
                )
            )
        tool_calls_json = encode_tool_calls(parsed)

    var finish = json_get_str(choice, "finish_reason", "stop")
    var stop_reason = "stop"
    if finish == "tool_calls" or finish == "function_call":
        stop_reason = "toolUse"
    elif finish == "length":
        stop_reason = "length"
    elif finish == "error":
        stop_reason = "error"

    _ = model
    return Completion(
        Message.assistant(content, stop_reason, tool_calls_json),
        raw,
    )


def http_post_json(
    url: String, body: String, api_key: String, timeout_seconds: Int
) raises -> String:
    """POST JSON using the cached Python runtime."""
    return py_str(runtime().http_post(url, body, api_key, timeout_seconds))
