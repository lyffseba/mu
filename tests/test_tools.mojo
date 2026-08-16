from std.pathlib import Path
from std.testing import assert_equal, assert_false, assert_true, TestSuite
from std.tempfile import mkdtemp

from mu.agent.messages import ToolCall
from mu.coding.tools import create_coding_tools, execute_tool


def _tmp() raises -> String:
    return mkdtemp(prefix="mu-test-")


def test_write_then_read() raises:
    var cwd = _tmp()
    var tools = create_coding_tools()
    var write = tools[1]
    var read = tools[0]
    var result = execute_tool(
        write,
        ToolCall("1", "write", '{"path":"hello.txt","content":"hello mu\\n"}'),
        cwd,
    )
    assert_false(result.is_error)
    var got = execute_tool(
        read, ToolCall("2", "read", '{"path":"hello.txt"}'), cwd
    )
    assert_false(got.is_error)
    assert_equal(got.content, "hello mu\n")


def test_edit_exact_once() raises:
    var cwd = _tmp()
    var tools = create_coding_tools()
    var write = tools[1]
    var edit = tools[2]
    var read = tools[0]
    _ = execute_tool(
        write,
        ToolCall("1", "write", '{"path":"n.txt","content":"alpha beta alpha"}'),
        cwd,
    )
    var fail = execute_tool(
        edit,
        ToolCall(
            "2",
            "edit",
            '{"path":"n.txt","edits":[{"oldText":"alpha","newText":"ALPHA"}]}',
        ),
        cwd,
    )
    assert_true(fail.is_error)

    var ok = execute_tool(
        edit,
        ToolCall(
            "3",
            "edit",
            (
                '{"path":"n.txt","edits":[{"oldText":"alpha beta'
                ' alpha","newText":"ok"}]}'
            ),
        ),
        cwd,
    )
    assert_false(ok.is_error)
    var got = execute_tool(read, ToolCall("4", "read", '{"path":"n.txt"}'), cwd)
    assert_equal(got.content, "ok")


def test_read_missing_file() raises:
    var cwd = _tmp()
    var read = create_coding_tools()[0]
    var got = execute_tool(
        read, ToolCall("1", "read", '{"path":"nope.txt"}'), cwd
    )
    assert_true(got.is_error)


def test_bash_session_env() raises:
    var cwd = _tmp()
    var bash = create_coding_tools()[3]
    var got = execute_tool(
        bash,
        ToolCall("1", "bash", '{"command":"printenv MU_SESSION_ID"}'),
        cwd,
        "sess-1",
        "m",
        "fake",
    )
    assert_false(got.is_error)
    assert_true(got.content.find("sess-1") >= 0)


def test_bash_echo() raises:
    var cwd = _tmp()
    var bash = create_coding_tools()[3]
    var got = execute_tool(
        bash, ToolCall("1", "bash", '{"command":"printf hi"}'), cwd
    )
    assert_false(got.is_error)
    assert_equal(got.content, "hi")


def test_edit_rejects_overlap() raises:
    var cwd = _tmp()
    var tools = create_coding_tools()
    var write = tools[1]
    var edit = tools[2]
    _ = execute_tool(
        write,
        ToolCall("1", "write", '{"path":"o.txt","content":"abcdef"}'),
        cwd,
    )
    var got = execute_tool(
        edit,
        ToolCall(
            "2",
            "edit",
            (
                '{"path":"o.txt","edits":['
                '{"oldText":"abc","newText":"XXX"},'
                '{"oldText":"bcd","newText":"YYY"}]}'
            ),
        ),
        cwd,
    )
    assert_true(got.is_error)
    assert_true(got.content.find("overlap") >= 0)


def test_edit_preserves_crlf() raises:
    var cwd = _tmp()
    var tools = create_coding_tools()
    var write = tools[1]
    var edit = tools[2]
    var read = tools[0]
    _ = execute_tool(
        write,
        ToolCall(
            "1", "write", '{"path":"w.txt","content":"one\\r\\ntwo\\r\\n"}'
        ),
        cwd,
    )
    var got = execute_tool(
        edit,
        ToolCall(
            "2",
            "edit",
            '{"path":"w.txt","edits":[{"oldText":"two","newText":"TWO"}]}',
        ),
        cwd,
    )
    assert_false(got.is_error)
    var raw = Path(cwd).joinpath("w.txt").read_text()
    assert_true(raw.find("\r\n") >= 0)
    var shown = execute_tool(
        read, ToolCall("3", "read", '{"path":"w.txt"}'), cwd
    )
    assert_true(shown.content.find("TWO") >= 0)
    _ = raw


def test_read_offset_limit() raises:
    var cwd = _tmp()
    var tools = create_coding_tools()
    var write = tools[1]
    var read = tools[0]
    _ = execute_tool(
        write,
        ToolCall("1", "write", '{"path":"n.txt","content":"a\\nb\\nc\\nd\\n"}'),
        cwd,
    )
    var got = execute_tool(
        read,
        ToolCall("2", "read", '{"path":"n.txt","offset":2,"limit":2}'),
        cwd,
    )
    assert_false(got.is_error)
    assert_true(got.content.startswith("b\nc"))
    assert_true(got.content.find("more lines") >= 0)


def test_path_escape_rejected() raises:
    var cwd = _tmp()
    var read = create_coding_tools()[0]
    var got = execute_tool(
        read, ToolCall("1", "read", '{"path":"../secret"}'), cwd
    )
    assert_true(got.is_error)
    assert_true(got.content.find("escapes") >= 0)


def test_bash_nonzero_is_error() raises:
    var cwd = _tmp()
    var bash = create_coding_tools()[3]
    var got = execute_tool(
        bash, ToolCall("1", "bash", '{"command":"exit 7"}'), cwd
    )
    assert_true(got.is_error)
    assert_true(got.content.find("exit 7") >= 0)


def test_default_tools_are_four() raises:
    var tools = create_coding_tools()
    assert_equal(len(tools), 4)
    assert_equal(tools[0].name, "read")
    assert_equal(tools[1].name, "write")
    assert_equal(tools[2].name, "edit")
    assert_equal(tools[3].name, "bash")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
