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
    memory_search,
    recall_other_sessions,
    split_entries,
)
from mu.hermes.paths import hermes_home_path, is_awake, mark_awake
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


def test_is_awake_does_not_mkdir() raises:
    _ = _isolate()
    var sid = "20260816-120000-000099"
    assert_true(not is_awake(sid))
    var root = hermes_home_path()
    assert_true(not root.exists())


def test_reject_separator_and_bad_target() raises:
    _ = _isolate()
    var sid = "20260816-120000-000098"
    var threw_sep = False
    try:
        _ = memory_add("session", sid, "bad § entry")
    except e:
        threw_sep = True
        assert_true(String(e).find("separator") >= 0)
    assert_true(threw_sep)
    var threw_target = False
    try:
        _ = memory_add("nope", sid, "x")
    except e:
        threw_target = True
        assert_true(String(e).find("target") >= 0)
    assert_true(threw_target)


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


def test_search_and_recall() raises:
    _ = _isolate()
    var here = "20260816-120000-000010"
    var other = "20260816-120000-000011"
    _ = memory_add("session", here, "This session is about auth.")
    _ = memory_add("memory", here, "Machine has pixi.")
    _ = memory_add("session", other, "Other session migrated postgres.")
    var hit = memory_search(here, "auth", "")
    assert_true(hit.find("auth") >= 0)
    assert_true(hit.find("[session]") >= 0)
    var miss = memory_search(here, "zzzz", "")
    assert_true(miss.find("no matches") >= 0)
    var rec = recall_other_sessions(here, "postgres")
    assert_true(rec.find(other) >= 0)
    assert_true(rec.find("postgres") >= 0)
    var rec_miss = recall_other_sessions(here, "auth")
    assert_true(rec_miss.find("no matches") >= 0)


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
    var searched = execute_memory(
        ToolCall("2", "memory", '{"action":"search","query":"bound"}'),
        sid,
    )
    assert_true(not searched.is_error)
    assert_true(searched.content.find("bound") >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
