from std.pathlib import Path
from std.testing import assert_equal, assert_true, TestSuite
from std.tempfile import mkdtemp

from mu.agent.loop import AgentLoop
from mu.agent.messages import ToolCall
from mu.agent.tools import Tool, ToolResult, find_tool
from mu.coding.prompt import apply_plugin_effects, build_system_prompt
from mu.coding.runner import CodingRunner
from mu.coding.skills import Skill
from mu.coding.tools import create_coding_tools
from mu.plugin import CommandResult, NullPlugin, Plugin


struct WakePlugin(Plugin, ImplicitlyCopyable):
    """Test double: /wake adds a memory tool and a prompt block."""

    var awake: Bool

    def __init__(out self, awake: Bool = False):
        self.awake = awake

    def version_suffix(self) -> String:
        return ""

    def extra_help(self) -> String:
        return " /wake"

    def extra_status(self, session_id: String) raises -> String:
        _ = session_id
        if self.awake:
            return "plugin=awake"
        return ""

    def session_mark(self, session_id: String) raises -> String:
        _ = session_id
        if self.awake:
            return "awake"
        return ""

    def extra_tools(self, session_id: String) raises -> List[Tool]:
        _ = session_id
        var tools = List[Tool]()
        if self.awake:
            tools.append(Tool("memory", "notes", "{}", "memory"))
        return tools^

    def extra_prompt(self, session_id: String) raises -> String:
        _ = session_id
        if not self.awake:
            return ""
        return "<plugin_block>frozen</plugin_block>"

    def on_start(
        mut self, session_id: String, persist: Bool, flag_on: Bool
    ) raises -> String:
        _ = session_id
        _ = persist
        if flag_on:
            self.awake = True
        return ""

    def handle_command(
        mut self, text: String, session_id: String, persist: Bool
    ) raises -> CommandResult:
        _ = session_id
        _ = persist
        if text == "/wake":
            self.awake = True
            return CommandResult.done("awake")
        return CommandResult.ignore()

    def execute_tool(
        self, tool: Tool, call: ToolCall, session_id: String
    ) raises -> ToolResult:
        _ = call
        _ = session_id
        if tool.kind == "memory":
            return ToolResult.ok("from-plugin")
        return ToolResult.error(String("Unknown tool kind: ", tool.kind))


def test_null_plugin_is_idle() raises:
    var p = NullPlugin()
    assert_equal(p.version_suffix(), "")
    assert_equal(p.extra_help(), "")
    assert_equal(p.extra_status("s"), "")
    assert_equal(p.session_mark("s"), "")
    assert_equal(len(p.extra_tools("s")), 0)
    assert_equal(p.extra_prompt("s"), "")
    assert_equal(p.on_start("s", True, False), "")
    var err = p.on_start("s", True, True)
    assert_true(err.find("hermes branch") >= 0)
    var cmd = p.handle_command("/hermes", "s", True)
    assert_true(not cmd.handled)
    var tool = Tool("memory", "x", "{}", "memory")
    var got = p.execute_tool(tool, ToolCall("1", "memory", "{}"), "s")
    assert_true(got.is_error)
    _ = CommandResult.ignore()


def test_plugin_block_is_last() raises:
    var root = mkdtemp(prefix="mu-prompt-")
    (Path(root) / "AGENTS.md").write_text("project rule")
    var tools = create_coding_tools()
    var prompt = build_system_prompt(
        String(root), tools, "", "<plugin_block>x</plugin_block>"
    )
    var cwd_at = prompt.find("Current working directory:")
    var project_at = prompt.find("<project_context>")
    var plugin_at = prompt.find("<plugin_block>x</plugin_block>")
    assert_true(cwd_at >= 0)
    assert_true(project_at > cwd_at)
    assert_true(plugin_at > project_at)


def test_apply_plugin_effects_adds_then_freezes() raises:
    var tools = create_coding_tools()
    var loop = AgentLoop("sys", "fake", ".", tools^, 4)
    var plugin = WakePlugin()
    apply_plugin_effects(loop, plugin, "s", ".", "", List[Skill]())
    assert_true(not find_tool(loop.tools, "memory"))
    assert_equal(loop.system, "sys")
    var handled = plugin.handle_command("/wake", "s", True)
    assert_true(handled.handled)
    apply_plugin_effects(loop, plugin, "s", ".", "", List[Skill]())
    assert_true(Bool(find_tool(loop.tools, "memory")))
    assert_true(loop.system.find("<plugin_block>frozen</plugin_block>") >= 0)
    var after_wake = loop.system
    apply_plugin_effects(loop, plugin, "s", ".", "", List[Skill]())
    assert_equal(loop.system, after_wake)


def test_apply_keeps_custom_system() raises:
    var tools = create_coding_tools()
    var loop = AgentLoop("old", "fake", ".", tools^, 4)
    var plugin = WakePlugin(True)
    apply_plugin_effects(loop, plugin, "s", ".", "custom only", List[Skill]())
    assert_true(loop.system.find("custom only") >= 0)
    assert_true(loop.system.find("<plugin_block>frozen</plugin_block>") >= 0)
    assert_true(loop.system.find("You are an expert coding assistant") < 0)


def test_runner_dispatches_unknown_kind_to_plugin() raises:
    var runner = CodingRunner("", "", "", WakePlugin(True))
    var tool = Tool("memory", "notes", "{}", "memory")
    var got = runner.run(tool, ToolCall("1", "memory", "{}"), ".")
    assert_true(not got.is_error)
    assert_equal(got.content, "from-plugin")
    var unknown = runner.run(
        Tool("nope", "x", "{}", "nope"), ToolCall("2", "nope", "{}"), "."
    )
    assert_true(unknown.is_error)
    assert_true(unknown.content.find("Unknown tool kind") >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
