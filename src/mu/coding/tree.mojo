"""Append-only session trees (Pi-shaped).

Every message may carry `id` / `parentId`. A `leaf` record points at the
active tip. Old files without ids still load as a straight line.
The JSONL is never rewritten.
"""

from std.pathlib import Path
from std.python import PythonObject

from mu.agent.messages import Message
from mu.coding.session import append_session_line, load_session_messages
from mu.jsonx import (
    empty_object,
    json_dumps,
    json_get_str,
    json_loads,
)
from mu.text import is_session_id, split_lines, strip_text


@fieldwise_init
struct TreeEntry(Copyable, ImplicitlyCopyable, Movable):
    var id: String
    var parent_id: String
    var message: Message


@fieldwise_init
struct TreeParse(Copyable, Movable):
    var entries: List[TreeEntry]
    var leaf: String


def parse_tree_entries(path: Path) raises -> TreeParse:
    """Return entries in file order plus the current leaf id."""
    var entries = List[TreeEntry]()
    var leaf = String()
    if not path.exists():
        return TreeParse(entries^, leaf)
    var text = path.read_text()
    var lines = split_lines(text)
    var n = 0
    for line in lines:
        var trimmed = strip_text(line)
        if trimmed.byte_length() == 0:
            continue
        var obj: PythonObject
        try:
            obj = json_loads(trimmed)
        except e:
            _ = e
            continue
        var kind = json_get_str(obj, "type")
        if kind == "leaf":
            var lid = json_get_str(obj, "id")
            if lid.byte_length() > 0:
                leaf = lid
            continue
        if kind != "message":
            continue
        n += 1
        var ident = json_get_str(obj, "id")
        if ident.byte_length() == 0:
            ident = String("m", n)
        var parent = json_get_str(obj, "parentId")
        var tool_calls = json_get_str(obj, "toolCalls", "[]")
        if tool_calls.byte_length() == 0:
            tool_calls = "[]"
        var msg = Message(
            json_get_str(obj, "role"),
            json_get_str(obj, "content"),
            json_get_str(obj, "toolCallId"),
            json_get_str(obj, "toolName"),
            tool_calls,
            json_get_str(obj, "stopReason"),
            json_get_str(obj, "errorMessage"),
        )
        entries.append(TreeEntry(ident, parent, msg))
        leaf = ident
    return TreeParse(entries^, leaf)


def next_entry_id(entries: List[TreeEntry]) -> String:
    return String("m", len(entries) + 1)


def find_entry(entries: List[TreeEntry], ident: String) -> Optional[Int]:
    var i = 0
    for entry in entries:
        if entry.id == ident:
            return Optional(i)
        i += 1
    return None


def branch_messages(entries: List[TreeEntry], leaf: String) raises -> List[Message]:
    """Walk parentId from `leaf` to root and return chronological messages."""
    var out = List[Message]()
    if len(entries) == 0:
        return out^
    var tip = leaf
    if tip.byte_length() == 0:
        tip = entries[len(entries) - 1].id
    var seen = Dict[String, Bool]()
    var stack = List[Message]()
    var guard = 0
    while tip.byte_length() > 0 and guard < 10000:
        guard += 1
        if tip in seen:
            break
        seen[tip] = True
        var idx = find_entry(entries, tip)
        if not idx:
            break
        var entry = entries[idx.value()]
        stack.append(entry.message.copy())
        tip = entry.parent_id
    var i = len(stack) - 1
    while i >= 0:
        out.append(stack[i].copy())
        i -= 1
    return out^


def load_branch_messages(path: Path) raises -> List[Message]:
    """Load the active branch. Falls back to linear load if the file has no tree."""
    if not path.exists():
        return List[Message]()
    var parsed = parse_tree_entries(path)
    var has_parent = False
    for entry in parsed.entries:
        if entry.parent_id.byte_length() > 0:
            has_parent = True
            break
    if not has_parent:
        return load_session_messages(path)
    return branch_messages(parsed.entries, parsed.leaf)


def persist_tree_message(
    path: Path, message: Message, parent_id: String
) raises -> String:
    """Append one message with id/parentId. Returns the new id."""
    var parsed = parse_tree_entries(path)
    var ident = next_entry_id(parsed.entries)
    var obj = empty_object()
    obj["type"] = "message"
    obj["id"] = ident
    obj["parentId"] = parent_id
    obj["role"] = message.role
    obj["content"] = message.content
    obj["toolCallId"] = message.tool_call_id
    obj["toolName"] = message.tool_name
    obj["toolCalls"] = message.tool_calls_json
    obj["stopReason"] = message.stop_reason
    obj["errorMessage"] = message.error_message
    append_session_line(path, obj)
    return ident


def persist_leaf(path: Path, ident: String) raises:
    var obj = empty_object()
    obj["type"] = "leaf"
    obj["id"] = ident
    append_session_line(path, obj)


def current_leaf(path: Path) raises -> String:
    return parse_tree_entries(path).leaf


def format_tree(path: Path) raises -> String:
    """Show user turns on the file, marking the active branch."""
    var parsed = parse_tree_entries(path)
    var leaf = parsed.leaf
    if len(parsed.entries) == 0:
        return "(empty session)"
    var on_branch = Dict[String, Bool]()
    var tip = leaf
    var guard = 0
    while tip.byte_length() > 0 and guard < 10000:
        guard += 1
        if tip in on_branch:
            break
        on_branch[tip] = True
        var idx = find_entry(parsed.entries, tip)
        if not idx:
            break
        tip = parsed.entries[idx.value()].parent_id
    var lines = List[String]()
    for entry in parsed.entries:
        if entry.message.role != "user":
            continue
        var mark = "*" if entry.id in on_branch else " "
        var preview = entry.message.content
        if preview.byte_length() > 60:
            preview = String(preview[byte=0:57]) + "..."
        lines.append(String(mark, " ", entry.id, "  ", preview))
    if len(lines) == 0:
        return String("leaf=", leaf, " (no user turns)")
    var out = String("leaf=") + leaf
    for line in lines:
        out += "\n" + line
    return out


def fork_to(path: Path, ident: String) raises -> List[Message]:
    """Point the active leaf at `ident` and return that branch."""
    var parsed = parse_tree_entries(path)
    var idx = find_entry(parsed.entries, ident)
    if not idx:
        raise Error(String("unknown entry id: ", ident))
    persist_leaf(path, ident)
    return branch_messages(parsed.entries, ident)


def is_entry_id(value: String) -> Bool:
    if value.byte_length() == 0:
        return False
    if not value.startswith("m"):
        return False
    return is_session_id(value)
