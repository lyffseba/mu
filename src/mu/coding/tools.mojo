"""Built-in filesystem and shell tools.

Paths resolve against the session working directory. The four tools match
Tau/Pi: `read`, `write`, `edit`, `bash`.
"""

from std.os import mkdir
from std.pathlib import Path
from std.python import Python, PythonObject

from mu.agent.messages import ToolCall
from mu.agent.tools import Tool, ToolResult
from mu.jsonx import (
    empty_object,
    json_dumps,
    json_get_int,
    json_get_str,
    json_has,
    json_loads,
    py_str,
)
from mu.pyrt import runtime
from mu.text import (
    count_occurrences,
    detect_line_ending,
    join_lines,
    normalize_lf,
    ranges_overlap,
    replace_at,
    restore_line_endings,
    split_lines,
    strip_text,
)

comptime MAX_OUTPUT_BYTES = 50 * 1024
comptime MAX_OUTPUT_LINES = 2000


def read_schema() -> String:
    return (
        '{"type":"object","properties":{"path":{"type":"string","description":"Path'
        " to the file to"
        ' read"},"offset":{"type":"integer","description":"1-indexed start line'
        " (0 = start of"
        ' file)"},"limit":{"type":"integer","description":"Maximum number of'
        ' lines to read"}},"required":["path"]}'
    )


def write_schema() -> String:
    return (
        '{"type":"object","properties":{'
        '"path":{"type":"string","description":"Path to the file to write"},'
        '"content":{"type":"string","description":"Complete file contents"}'
        '},"required":["path","content"]}'
    )


def edit_schema() -> String:
    return (
        '{"type":"object","properties":{'
        '"path":{"type":"string","description":"Path to the file to edit"},'
        '"edits":{"type":"array","description":"Exact oldText/newText'
        ' replacements",'
        '"items":{"type":"object","properties":{'
        '"oldText":{"type":"string"},"newText":{"type":"string"}'
        '},"required":["oldText","newText"]}}'
        '},"required":["path","edits"]}'
    )


def bash_schema() -> String:
    return (
        '{"type":"object","properties":{'
        '"command":{"type":"string","description":"Shell command to run"},'
        '"timeout":{"type":"number","description":"Max runtime in seconds"}'
        '},"required":["command"]}'
    )


def create_coding_tools() -> List[Tool]:
    """Create the default coding-tool set."""
    var tools = List[Tool]()
    tools.append(
        Tool(
            "read",
            (
                "Read the contents of a file. For text files, output is"
                " truncated to 2000 lines or 50KB. Use offset/limit for large"
                " files."
            ),
            read_schema(),
            "read",
        )
    )
    tools.append(
        Tool(
            "write",
            (
                "Create or overwrite a complete UTF-8 text file. Creates parent"
                " directories."
            ),
            write_schema(),
            "write",
        )
    )
    tools.append(
        Tool(
            "edit",
            (
                "Apply exact text replacements to one file. Each oldText must"
                " match exactly once and must not overlap another edit. All"
                " edits validate before anything is written."
            ),
            edit_schema(),
            "edit",
        )
    )
    tools.append(
        Tool(
            "bash",
            (
                "Run a shell command in the working directory. Combines stdout"
                " and stderr. Large output is truncated from the tail."
            ),
            bash_schema(),
            "bash",
        )
    )
    return tools^


def execute_tool(
    tool: Tool,
    call: ToolCall,
    cwd: String,
    session_id: String = "",
    model: String = "",
    provider: String = "",
) raises -> ToolResult:
    """Dispatch one tool call to the matching executor."""
    try:
        var args = parse_arguments(call.arguments)
        if tool.kind == "read":
            return tool_read(args, cwd)
        if tool.kind == "write":
            return tool_write(args, cwd)
        if tool.kind == "edit":
            return tool_edit(args, cwd)
        if tool.kind == "bash":
            return tool_bash(args, cwd, session_id, model, provider)
        if tool.kind == "echo":
            return ToolResult.ok(json_get_str(args, "text"))
        return ToolResult.error(String("Unknown tool kind: ", tool.kind))
    except e:
        return ToolResult.error(String(e))


def parse_arguments(raw: String) raises -> PythonObject:
    """Parse tool arguments. Models sometimes send an empty string."""
    var trimmed = strip_text(raw)
    if trimmed.byte_length() == 0:
        return empty_object()
    return json_loads(trimmed)


def resolve_path(cwd: String, raw: String) raises -> Path:
    """Resolve `raw` against `cwd` unless it is already absolute.

    `~` expands. Relative paths never climb above `cwd`.
    """
    var expanded = String(Path(raw).expanduser())
    if expanded.startswith("/"):
        return Path(expanded)
    if expanded.startswith("~/"):
        return Path(expanded).expanduser()
    var cleaned = strip_dot_slash(expanded)
    if has_parent_escape(cleaned):
        raise Error(String("Path escapes working directory: ", raw))
    if cleaned.byte_length() == 0:
        return Path(cwd)
    return Path(cwd) / cleaned


def strip_dot_slash(path: String) -> String:
    var out = path
    while out.startswith("./"):
        var rest = String(out[byte = 2 : out.byte_length()])
        out = rest
    if out == ".":
        return ""
    return out


def has_parent_escape(path: String) -> Bool:
    """True if a relative path would walk above its root."""
    var depth = 0
    var parts = path.split("/")
    for part in parts:
        var piece = String(part)
        if piece.byte_length() == 0 or piece == ".":
            continue
        if piece == "..":
            depth -= 1
            if depth < 0:
                return True
        else:
            depth += 1
    return False


def mkdir_p(path: Path) raises:
    """Create `path` and any missing parents."""
    if path.exists():
        if not path.is_dir():
            raise Error(String("Not a directory: ", path))
        return
    var parent = parent_dir(path)
    if String(parent) != String(path) and not parent.exists():
        mkdir_p(parent)
    if not path.exists():
        mkdir(path)


def parent_dir(path: Path) -> Path:
    var name = path.name()
    var full = String(path)
    if name.byte_length() == 0 or full == name:
        return Path(".")
    var cut = full.byte_length() - name.byte_length()
    if cut > 0 and String(full[byte = cut - 1 : cut]) == "/":
        cut -= 1
    if cut <= 0:
        return Path("/")
    var parent = String(full[byte=0:cut])
    if parent.byte_length() == 0:
        return Path("/")
    return Path(parent)


def format_size(n: Int) -> String:
    if n < 1024:
        return String(n, "B")
    return String(n // 1024, "KB")


def truncate_head(
    text: String,
    max_lines: Int = MAX_OUTPUT_LINES,
    max_bytes: Int = MAX_OUTPUT_BYTES,
) -> String:
    """Keep the head of `text`, matching Tau's 2000-line / 50KB cap."""
    var lines = split_lines(text)
    var out_lines = List[String]()
    var bytes_used = 0
    var i = 0
    for line in lines:
        var extra = line.byte_length()
        if i > 0:
            extra += 1
        if i >= max_lines or bytes_used + extra > max_bytes:
            var shown = join_lines(out_lines)
            var reason = (
                "lines" if i >= max_lines else format_size(max_bytes) + " limit"
            )
            return (
                shown
                + "\n\n[Showing "
                + String(i)
                + " of "
                + String(len(lines))
                + " lines ("
                + reason
                + "). Use offset="
                + String(i + 1)
                + " to continue.]"
            )
        out_lines.append(line)
        bytes_used += extra
        i += 1
    return join_lines(out_lines)


def truncate_tail(
    text: String,
    max_lines: Int = MAX_OUTPUT_LINES,
    max_bytes: Int = MAX_OUTPUT_BYTES,
) -> String:
    """Keep the tail of `text`. Bash output is more useful from the end."""
    var lines = split_lines(text)
    var total = len(lines)
    var bytes_total = text.byte_length()
    if total <= max_lines and bytes_total <= max_bytes:
        return text

    var out_lines = List[String]()
    var bytes_used = 0
    var i = total - 1
    while i >= 0:
        var line = lines[i]
        var extra = line.byte_length()
        if len(out_lines) > 0:
            extra += 1
        if len(out_lines) >= max_lines or bytes_used + extra > max_bytes:
            break
        out_lines.append(line)
        bytes_used += extra
        i -= 1

    var kept = List[String]()
    var j = len(out_lines) - 1
    while j >= 0:
        kept.append(out_lines[j])
        j -= 1
    var shown = join_lines(kept)
    var dropped = total - len(kept)
    return (
        "[truncated "
        + String(dropped)
        + " earlier line(s); showing tail]\n"
        + shown
    )


def tool_read(args: PythonObject, cwd: String) raises -> ToolResult:
    var raw_path = json_get_str(args, "path")
    if raw_path.byte_length() == 0:
        return ToolResult.error("path is required")
    var path = resolve_path(cwd, raw_path)
    if not path.exists():
        return ToolResult.error(String("File not found: ", path))
    if path.is_dir():
        return ToolResult.error(String("Path is a directory: ", path))

    var raw = path.read_text()
    var text = normalize_lf(raw)
    var lines = split_lines(text)
    var offset = 1
    if json_has(args, "offset"):
        offset = json_get_int(args, "offset", 1)
        if offset < 0:
            return ToolResult.error("offset must be at least 0")
        if offset == 0:
            offset = 1
    var start = offset - 1
    if start >= len(lines):
        return ToolResult.error(
            String(
                "Offset ",
                offset,
                " is beyond end of file (",
                len(lines),
                " lines total)",
            )
        )

    var selected = List[String]()
    var remaining = len(lines) - start
    var user_limit = remaining
    if json_has(args, "limit"):
        var limit = json_get_int(args, "limit", remaining)
        if limit < 1:
            return ToolResult.error("limit must be at least 1")
        user_limit = limit
        if limit < remaining:
            remaining = limit
    for i in range(remaining):
        selected.append(lines[start + i])

    var body = truncate_head(join_lines(selected))
    if start + remaining < len(lines) and body.find("[Showing ") < 0:
        var more = len(lines) - (start + remaining)
        body = (
            body
            + "\n\n["
            + String(more)
            + " more lines in file. Use offset="
            + String(start + remaining + 1)
            + " to continue.]"
        )
    var details = empty_object()
    details["path"] = String(path)
    details["lines"] = len(lines)
    _ = user_limit
    return ToolResult.ok(body, json_dumps(details))


def tool_write(args: PythonObject, cwd: String) raises -> ToolResult:
    var raw_path = json_get_str(args, "path")
    if raw_path.byte_length() == 0:
        return ToolResult.error("path is required")
    if not json_has(args, "content"):
        return ToolResult.error("content is required")
    var content = json_get_str(args, "content")
    var path = resolve_path(cwd, raw_path)
    mkdir_p(parent_dir(path))
    path.write_text(content)
    var details = empty_object()
    details["path"] = String(path)
    details["bytes"] = content.byte_length()
    return ToolResult.ok(String("Wrote ", path), json_dumps(details))


def tool_edit(args: PythonObject, cwd: String) raises -> ToolResult:
    var raw_path = json_get_str(args, "path")
    if raw_path.byte_length() == 0:
        return ToolResult.error("path is required")
    var path = resolve_path(cwd, raw_path)
    if not path.exists():
        return ToolResult.error(String("File not found: ", path))
    if path.is_dir():
        return ToolResult.error(String("Path is a directory: ", path))
    if not json_has(args, "edits"):
        return ToolResult.error("edits is required")

    var original = path.read_text()
    var ending = detect_line_ending(original)
    var text = normalize_lf(original)
    var edits = args["edits"]
    var n = Int(py=edits.__len__())
    if n < 1:
        return ToolResult.error("edits must contain at least one replacement")

    var starts = List[Int]()
    var ends = List[Int]()
    var replacements = List[String]()

    for i in range(n):
        var edit = edits[i]
        var old_text = normalize_lf(json_get_str(edit, "oldText"))
        if old_text.byte_length() == 0:
            return ToolResult.error(
                String(
                    "oldText must be non-empty (edit ", i + 1, " of ", n, ")"
                )
            )
        var matches = count_occurrences(text, old_text)
        if matches == 0:
            return ToolResult.error(
                String("oldText not found (edit ", i + 1, " of ", n, ")")
            )
        if matches > 1:
            return ToolResult.error(
                String(
                    "oldText matched ",
                    matches,
                    " times (edit ",
                    i + 1,
                    " of ",
                    n,
                    "); it must match exactly once",
                )
            )
        var idx = text.find(old_text)
        var end = idx + old_text.byte_length()
        var j = 0
        while j < len(starts):
            if ranges_overlap(idx, end, starts[j], ends[j]):
                return ToolResult.error(
                    String(
                        "edits ",
                        j + 1,
                        " and ",
                        i + 1,
                        (
                            " overlap; all edits must be unique and"
                            " non-overlapping"
                        ),
                    )
                )
            j += 1
        starts.append(idx)
        ends.append(end)
        replacements.append(normalize_lf(json_get_str(edit, "newText")))

    # Apply from the end so earlier offsets stay valid.
    var order = List[Int]()
    for i in range(n):
        order.append(i)
    var a = 0
    while a < n:
        var b = a + 1
        while b < n:
            if starts[order[b]] > starts[order[a]]:
                var tmp = order[a]
                order[a] = order[b]
                order[b] = tmp
            b += 1
        a += 1

    var updated = text
    for k in range(n):
        var i = order[k]
        updated = replace_at(
            updated, starts[i], ends[i] - starts[i], replacements[i]
        )

    if updated == text:
        return ToolResult.error("edits made no change")

    var written = restore_line_endings(updated, ending)
    path.write_text(written)
    var details = empty_object()
    details["path"] = String(path)
    details["edits"] = n
    return ToolResult.ok(
        String("Edited ", path, " (", n, " replacement(s))"),
        json_dumps(details),
    )


def tool_bash(
    args: PythonObject,
    cwd: String,
    session_id: String = "",
    model: String = "",
    provider: String = "",
) raises -> ToolResult:
    var command = json_get_str(args, "command")
    if strip_text(command).byte_length() == 0:
        return ToolResult.error("command is required")

    var timeout = 0
    if json_has(args, "timeout"):
        timeout = json_get_int(args, "timeout", 0)
        if timeout < 0:
            return ToolResult.error("timeout must be >= 0")

    var extra = Python.dict()
    extra["MU_SESSION_ID"] = session_id
    extra["MU_MODEL"] = model
    extra["MU_PROVIDER"] = provider
    extra["MU_CWD"] = cwd
    var result = runtime().run_shell(
        command, cwd, timeout if timeout > 0 else Python.none(), extra
    )
    var output = py_str(result["output"])
    var timed_out = Bool(py=result["timeout"])
    var truncated = truncate_tail(output)
    var details = empty_object()
    details["cwd"] = cwd
    details["timeout"] = timed_out
    if timed_out:
        details["exit_code"] = Python.none()
        return ToolResult.error(
            String("timed out after ", timeout, "s\n", truncated),
            json_dumps(details),
        )
    var code = Int(py=result["code"])
    details["exit_code"] = code
    if code == 0:
        return ToolResult.ok(truncated, json_dumps(details))
    return ToolResult.error(
        String("exit ", code, "\n", truncated), json_dumps(details)
    )
