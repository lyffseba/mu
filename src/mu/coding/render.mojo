"""Print-mode event rendering. The loop never prints; this does."""

from mu.agent.events import Event
from mu.agent.loop import AgentRun
from mu.jsonx import empty_array, empty_object, json_dumps
from mu.text import join_lines, split_lines


def render_text(run: AgentRun) -> String:
    """Human-readable print-mode output."""
    var lines = List[String]()
    for event in run.events:
        if event.kind == "text":
            lines.append(event.text)
            lines.append("")
        elif event.kind == "tool_start":
            lines.append(String("→ ", event.tool_name, "(", event.text, ")"))
        elif event.kind == "tool_end":
            var mark = "✗" if event.is_error else "✓"
            var preview = event.text
            var preview_lines = split_lines(preview)
            if len(preview_lines) > 8:
                var clipped = List[String]()
                for i in range(8):
                    clipped.append(preview_lines[i])
                preview = join_lines(clipped) + "\n…"
            lines.append(String(mark, " ", event.tool_name))
            if preview.byte_length() > 0:
                lines.append(preview)
            lines.append("")
        elif event.kind == "error":
            lines.append(String("error: ", event.text))
            lines.append("")
    return join_lines(lines)


def render_json(run: AgentRun) raises -> String:
    """Machine-readable event dump."""
    var arr = empty_array()
    for event in run.events:
        var obj = empty_object()
        obj["kind"] = event.kind
        obj["text"] = event.text
        obj["tool"] = event.tool_name
        obj["id"] = event.tool_call_id
        obj["error"] = event.is_error
        arr.append(obj)
    return json_dumps(arr)


def last_assistant_text(run: AgentRun) -> String:
    """Return the last non-empty assistant text from the run."""
    var last = String("")
    for message in run.new_messages:
        if message.role == "assistant" and message.content.byte_length() > 0:
            last = message.content
    return last
