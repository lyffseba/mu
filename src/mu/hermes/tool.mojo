"""The `memory` tool. Hermes-only."""

from std.python import PythonObject

from mu.agent.messages import ToolCall
from mu.agent.tools import Tool, ToolResult
from mu.hermes.memory import (
    memory_add,
    memory_remove,
    memory_replace,
    memory_search,
    recall_other_sessions,
)
from mu.jsonx import json_get_str, json_loads
from mu.text import strip_text


def memory_schema() -> String:
    return (
        '{"type":"object","properties":{'
        '"action":{"type":"string","enum":["add","replace","remove","search","recall"],'
        '"description":"add/replace/remove an entry; search this agent; recall other sessions"},'
        '"target":{"type":"string","enum":["memory","user","session"],'
        '"description":"memory=global notes, user=profile, session=this Mu session"},'
        '"content":{"type":"string","description":"New entry text (add/replace)"},'
        '"old_text":{"type":"string","description":"Unique substring (replace/remove)"},'
        '"query":{"type":"string","description":"Search text (search/recall)"}'
        '},"required":["action","target"]}'
    )


def create_memory_tool() -> Tool:
    return Tool(
        "memory",
        (
            "Persist curated notes. target=memory (environment/lessons), "
            "user (who they are), or session (this Mu session only). "
            "Stores are bounded. Overflow is an error — consolidate first."
        ),
        memory_schema(),
        "memory",
    )


def execute_memory(call: ToolCall, session_id: String) raises -> ToolResult:
    try:
        var raw = strip_text(call.arguments)
        var args: PythonObject
        if raw.byte_length() == 0:
            return ToolResult.error("arguments required")
        args = json_loads(raw)
        var action = json_get_str(args, "action")
        var target = json_get_str(args, "target", "memory")
        if target != "memory" and target != "user" and target != "session":
            return ToolResult.error("target must be memory, user, or session")
        if action == "add":
            return ToolResult.ok(
                memory_add(target, session_id, json_get_str(args, "content"))
            )
        if action == "replace":
            return ToolResult.ok(
                memory_replace(
                    target,
                    session_id,
                    json_get_str(args, "old_text"),
                    json_get_str(args, "content"),
                )
            )
        if action == "remove":
            return ToolResult.ok(
                memory_remove(target, session_id, json_get_str(args, "old_text"))
            )
        if action == "search":
            var q = json_get_str(args, "query")
            if q.byte_length() == 0:
                q = json_get_str(args, "content")
            var scope = json_get_str(args, "target")
            return ToolResult.ok(memory_search(session_id, q, scope))
        if action == "recall":
            var q2 = json_get_str(args, "query")
            if q2.byte_length() == 0:
                q2 = json_get_str(args, "content")
            return ToolResult.ok(recall_other_sessions(session_id, q2))
        return ToolResult.error("action must be add, replace, remove, search, or recall")
    except e:
        return ToolResult.error(String(e))
