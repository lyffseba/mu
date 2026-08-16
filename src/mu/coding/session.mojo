"""Append-only JSONL sessions under ~/.mu/sessions/."""

from std.os import mkdir
from std.pathlib import Path
from std.python import PythonObject

from mu.agent.messages import Message
from mu.coding.context import apply_compaction, replay_compaction
from mu.coding.settings import mu_home
from mu.jsonx import (
    empty_object,
    json_dumps,
    json_get_int,
    json_get_str,
    json_loads,
    py_str,
)
from mu.pyrt import runtime
from mu.text import is_session_id, normalize_cwd, split_lines, strip_text


def sessions_dir() raises -> Path:
    var sessions = mu_home() / "sessions"
    if not sessions.exists():
        mkdir(sessions)
    return sessions


def new_session_id() raises -> String:
    """Build a sortable session id: YYYYMMDD-HHMMSS-ffffff."""
    return py_str(runtime().now_stamp())


def session_path(session_id: String) raises -> Path:
    if not is_session_id(session_id):
        raise Error(String("Invalid session id: ", session_id))
    return sessions_dir() / String(session_id, ".jsonl")


def append_session_line(path: Path, obj: PythonObject) raises:
    """Append one JSON object as a line. Uses `'a'` so we don't rewrite the file.
    """
    var line = json_dumps(obj) + "\n"
    var handle = open(path, "a")
    handle.write(line)
    handle.close()


def write_session_header(
    path: Path,
    session_id: String,
    cwd: String,
    model: String,
    provider: String,
    name: String = "",
) raises:
    var header = empty_object()
    header["type"] = "session"
    header["id"] = session_id
    header["cwd"] = normalize_cwd(cwd)
    header["model"] = model
    header["provider"] = provider
    if name.byte_length() > 0:
        header["name"] = name
    append_session_line(path, header)


def load_session_name(path: Path) raises -> String:
    if not path.exists():
        return ""
    var text = path.read_text()
    var lines = split_lines(text)
    for line in lines:
        var trimmed = strip_text(line)
        if trimmed.byte_length() == 0:
            continue
        try:
            var obj = json_loads(trimmed)
            if json_get_str(obj, "type") == "session":
                return json_get_str(obj, "name")
        except e:
            _ = e
    return ""


def persist_compaction(
    path: Path, summary: Message, keep: Int, dropped: Int
) raises:
    """Append a compaction record. The durable log is not rewritten."""
    var obj = empty_object()
    obj["type"] = "compaction"
    obj["keep"] = keep
    obj["dropped"] = dropped
    obj["summary"] = summary.content
    append_session_line(path, obj)


def load_session_cwd(path: Path) raises -> String:
    """Read the cwd recorded in a session header."""
    if not path.exists():
        return ""
    var text = path.read_text()
    var lines = split_lines(text)
    for line in lines:
        var trimmed = strip_text(line)
        if trimmed.byte_length() == 0:
            continue
        try:
            var obj = json_loads(trimmed)
            if json_get_str(obj, "type") == "session":
                return normalize_cwd(json_get_str(obj, "cwd"))
        except e:
            _ = e
    return ""


def latest_session_id() raises -> String:
    """Newest session id, or empty if none exist."""
    var ids = list_session_ids()
    if len(ids) == 0:
        return ""
    return ids[0]


def list_session_ids_for_cwd(cwd: String) raises -> List[String]:
    """Newest-first ids whose header cwd matches `cwd`."""
    var ids = list_session_ids()
    if cwd.byte_length() == 0:
        return ids^
    var matched = List[String]()
    for ident in ids:
        var path = session_path(ident)
        if load_session_cwd(path) == normalize_cwd(cwd):
            matched.append(ident)
    return matched^


def resolve_continue_session(
    remembered: String, cwd: String = ""
) raises -> String:
    """Pick the session to continue, or empty if none exist.

    A remembered `last_session` wins only while its file is still there
    and belongs to `cwd` (when `cwd` is set). A stale, corrupt, or
    other-project pointer degrades to the newest session in this
    directory rather than resuming someone else's work.
    """
    if remembered.byte_length() > 0:
        if is_session_id(remembered) and session_path(remembered).exists():
            if cwd.byte_length() == 0:
                return remembered
            if load_session_cwd(session_path(remembered)) == normalize_cwd(cwd):
                return remembered
    if cwd.byte_length() > 0:
        var ids = list_session_ids_for_cwd(cwd)
        if len(ids) == 0:
            return ""
        return ids[0]
    return latest_session_id()


def persist_message(path: Path, message: Message) raises:
    var obj = empty_object()
    obj["type"] = "message"
    obj["role"] = message.role
    obj["content"] = message.content
    obj["toolCallId"] = message.tool_call_id
    obj["toolName"] = message.tool_name
    obj["toolCalls"] = message.tool_calls_json
    obj["stopReason"] = message.stop_reason
    obj["errorMessage"] = message.error_message
    append_session_line(path, obj)


def load_session_id(path: Path) raises -> String:
    if not path.exists():
        return ""
    var text = path.read_text()
    var lines = split_lines(text)
    for line in lines:
        var trimmed = strip_text(line)
        if trimmed.byte_length() == 0:
            continue
        var obj = json_loads(trimmed)
        if json_get_str(obj, "type") == "session":
            return json_get_str(obj, "id")
    return ""


def load_session_messages(path: Path) raises -> List[Message]:
    var messages = List[Message]()
    if not path.exists():
        return messages^
    var text = path.read_text()
    var lines = split_lines(text)
    for line in lines:
        var trimmed = strip_text(line)
        if trimmed.byte_length() == 0:
            continue
        var obj = empty_object()
        var parsed = False
        try:
            # A process killed mid-write can leave a partial final line;
            # skip it, since the durable log is append-only and replays.
            obj = json_loads(trimmed)
            parsed = True
        except e:
            _ = e
        if not parsed:
            continue
        var kind = json_get_str(obj, "type")
        if kind == "compaction":
            var dropped = json_get_int(obj, "dropped", 0)
            var summary = json_get_str(obj, "summary")
            if dropped > 0 or summary.byte_length() > 0:
                messages = replay_compaction(messages, dropped, summary)
            else:
                var keep = json_get_int(obj, "keep", 6)
                var compacted = apply_compaction(messages, keep)
                var next = List[Message]()
                for message in compacted.messages:
                    next.append(message.copy())
                messages = next^
            continue
        if kind != "message":
            continue
        var tool_calls = json_get_str(obj, "toolCalls", "[]")
        if tool_calls.byte_length() == 0:
            tool_calls = "[]"
        messages.append(
            Message(
                json_get_str(obj, "role"),
                json_get_str(obj, "content"),
                json_get_str(obj, "toolCallId"),
                json_get_str(obj, "toolName"),
                tool_calls,
                json_get_str(obj, "stopReason"),
                json_get_str(obj, "errorMessage"),
            )
        )
    return messages^


def list_session_ids() raises -> List[String]:
    """Return session ids newest-first (filename sort, descending)."""
    var dir_path = sessions_dir()
    var names = dir_path.listdir()
    var ids = List[String]()
    for name in names:
        var item = String(name)
        if item.endswith(".jsonl"):
            var ident = String(item[byte = 0 : item.byte_length() - 6])
            if is_session_id(ident):
                ids.append(ident)
    # Insertion-order newest-first: filenames are YYYYMMDD-... so reverse sort.
    var n = len(ids)
    var a = 0
    while a < n:
        var b = a + 1
        while b < n:
            if ids[b] > ids[a]:
                var tmp = ids[a]
                ids[a] = ids[b]
                ids[b] = tmp
            b += 1
        a += 1
    return ids^


def format_session_list(cwd: String = "") raises -> String:
    var ids: List[String]
    if cwd.byte_length() > 0:
        ids = list_session_ids_for_cwd(cwd)
    else:
        ids = list_session_ids()
    if len(ids) == 0:
        return "(no sessions yet)"
    var out = String()
    var shown = 0
    for ident in ids:
        if shown >= 20:
            out += String("… ", len(ids) - shown, " more\n")
            break
        var path = session_path(ident)
        var label = load_session_name(path)
        if label.byte_length() == 0:
            label = py_str(runtime().preview_session(String(path), 60))
        if shown > 0:
            out += "\n"
        if label.byte_length() > 0:
            out += String(ident, "  ", label)
        else:
            out += ident
        shown += 1
    return out
