from std.os.env import setenv
from std.testing import assert_equal, assert_true, TestSuite
from std.tempfile import mkdtemp

from mu.hermes.memory import (
    MEMORY_LIMIT,
    char_count,
    frozen_memory_block,
    load_entries,
    memory_add,
    memory_remove,
    memory_replace,
    split_entries,
)
from mu.hermes.paths import is_awake, mark_awake
from mu.hermes.tool import create_memory_tool, execute_memory
from mu.agent.messages import ToolCall


def _isolate() raises -> String:
    var home = mkdtemp(prefix="mu-home-")
    _ = setenv("MU_HOME", home, overwrite=True)
    return home


def test_add_and_split() raises:
    _ = _isolate()
    var sid = "20260816-120000-000001"
    _ = memory_add("session", sid, "This session is about auth.")
    _ = memory_add("session", sid, "User wants short diffs.")
    var entries = load_entries("session", sid)
    assert_equal(len(entries), 2)
    assert_true(entries[0].find("auth") >= 0)


def test_replace_and_remove() raises:
    _ = _isolate()
    var sid = "20260816-120000-000002"
    _ = memory_add("memory", sid, "Project uses tabs.")
    _ = memory_replace("memory", sid, "tabs", "Project uses spaces.")
    var entries = load_entries("memory", sid)
    assert_equal(len(entries), 1)
    assert_true(entries[0].find("spaces") >= 0)
    _ = memory_remove("memory", sid, "spaces")
    assert_equal(len(load_entries("memory", sid)), 0)


def test_overflow_errors() raises:
    _ = _isolate()
    var sid = "20260816-120000-000003"
    var big = String()
    var i = 0
    while i < MEMORY_LIMIT + 10:
        big += "x"
        i += 1
    var threw = False
    try:
        _ = memory_add("memory", sid, big)
    except e:
        threw = True
        assert_true(String(e).find("exceed") >= 0)
    assert_true(threw)
    _ = char_count(List[String]())
    _ = split_entries("")


def test_awake_and_snapshot() raises:
    _ = _isolate()
    var sid = "20260816-120000-000004"
    assert_true(not is_awake(sid))
    mark_awake(sid)
    assert_true(is_awake(sid))
    _ = memory_add("user", sid, "Prefers concise answers.")
    var snap = frozen_memory_block(sid)
    assert_true(snap.find("<hermes_soul>") >= 0)
    assert_true(snap.find("USER PROFILE") >= 0)
    assert_true(snap.find("concise") >= 0)
    assert_true(snap.find(sid) >= 0)


def test_memory_tool() raises:
    _ = _isolate()
    var sid = "20260816-120000-000005"
    var tool = create_memory_tool()
    assert_equal(tool.name, "memory")
    var got = execute_memory(
        ToolCall("1", "memory", '{"action":"add","target":"session","content":"bound"}'),
        sid,
    )
    assert_true(not got.is_error)
    assert_true(got.content.find("added") >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
