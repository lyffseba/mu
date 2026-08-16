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
from mu.agent.loop import AgentLoop
from mu.agent.messages import ToolCall
from mu.agent.tools import find_tool
from mu.coding.active import create_plugin
from mu.coding.prompt import apply_plugin_effects, build_system_prompt
from mu.coding.runner import CodingRunner
from mu.coding.skills import Skill
from mu.coding.tools import create_coding_tools
from mu.hermes.paths import hermes_home_path, is_awake, mark_awake
from mu.hermes.plugin import HermesPlugin
from mu.hermes.tool import create_memory_tool, execute_memory


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
    assert_true(rec.find(here) < 0)
    var empty_threw = False
    try:
        _ = recall_other_sessions(here, "")
    except e:
        empty_threw = True
        assert_true(String(e).find("query") >= 0)
    assert_true(empty_threw)


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


def test_plugin_wakes_and_lists() raises:
    _ = _isolate()
    var sid = "20260816-120000-000006"
    var p = HermesPlugin()
    assert_equal(p.version_suffix(), "-hermes")
    assert_equal(p.extra_help().find("/hermes") >= 0, True)
    assert_equal(len(p.extra_tools(sid)), 0)
    assert_equal(p.extra_prompt(sid), "")
    var err = p.on_start(sid, False, True)
    assert_true(err.find("persisted") >= 0)
    assert_equal(p.on_start(sid, True, True), "")
    assert_true(is_awake(sid))
    assert_equal(len(p.extra_tools(sid)), 1)
    assert_true(p.extra_prompt(sid).find("<hermes_soul>") >= 0)
    var listed = p.handle_command("/memory", sid, True)
    assert_true(listed.handled)
    assert_true(listed.consume)
    var wake = p.handle_command("/hermes remember this", sid, True)
    assert_true(wake.handled)
    assert_equal(wake.rewrite, "remember this")
    var idle = HermesPlugin()
    var asleep = idle.handle_command("/memory", "other", True)
    assert_true(asleep.printed.find("asleep") >= 0)


def test_create_plugin_is_hermes() raises:
    var p = create_plugin()
    assert_equal(p.version_suffix(), "-hermes")
    assert_true(p.extra_help().find("/memory") >= 0)


def test_idle_plugin_does_not_mkdir() raises:
    _ = _isolate()
    var sid = "20260816-120000-000007"
    var p = HermesPlugin()
    assert_equal(len(p.extra_tools(sid)), 0)
    assert_equal(p.extra_prompt(sid), "")
    var listed = p.handle_command("/memory", sid, True)
    assert_true(listed.printed.find("asleep") >= 0)
    var ephemeral = p.handle_command("/hermes", sid, False)
    assert_true(ephemeral.error.find("persisted") >= 0)
    assert_true(not is_awake(sid))
    assert_true(not hermes_home_path().exists())


def test_empty_memory_query_lists() raises:
    _ = _isolate()
    var sid = "20260816-120000-000008"
    var p = HermesPlugin()
    assert_equal(p.on_start(sid, True, True), "")
    var listed = p.handle_command("/memory   ", sid, True)
    assert_true(listed.handled)
    assert_true(listed.consume)
    assert_true(listed.printed.find("SESSION") >= 0)
    var blank = p.handle_command("/hermes   ", sid, True)
    assert_true(blank.consume)
    assert_equal(blank.rewrite, "")


def test_late_wake_freezes_snapshot() raises:
    _ = _isolate()
    var sid = "20260816-120000-000009"
    var tools = create_coding_tools()
    var loop = AgentLoop("sys", "fake", ".", tools^, 4)
    var plugin = HermesPlugin()
    apply_plugin_effects(loop, plugin, sid, ".", "", List[Skill]())
    assert_true(not find_tool(loop.tools, "memory"))
    assert_equal(loop.system, "sys")
    var wake = plugin.handle_command("/hermes remember this", sid, True)
    assert_equal(wake.rewrite, "remember this")
    apply_plugin_effects(loop, plugin, sid, ".", "custom only", List[Skill]())
    assert_true(Bool(find_tool(loop.tools, "memory")))
    assert_true(loop.system.find("custom only") >= 0)
    assert_true(loop.system.find("<hermes_soul>") >= 0)
    assert_true(loop.system.find("You are an expert coding assistant") < 0)
    var frozen = loop.system
    apply_plugin_effects(loop, plugin, sid, ".", "custom only", List[Skill]())
    assert_equal(loop.system, frozen)


def test_runner_dispatches_memory() raises:
    _ = _isolate()
    var sid = "20260816-120000-000012"
    var plugin = HermesPlugin()
    assert_equal(plugin.on_start(sid, True, True), "")
    var runner = CodingRunner(sid, "", "", plugin)
    var got = runner.run(
        create_memory_tool(),
        ToolCall(
            "1",
            "memory",
            '{"action":"add","target":"session","content":"bound"}',
        ),
        ".",
    )
    assert_true(not got.is_error)
    assert_true(got.content.find("added") >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
