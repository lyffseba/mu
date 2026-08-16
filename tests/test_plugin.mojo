from std.testing import assert_equal, assert_true, TestSuite

from mu.agent.messages import ToolCall
from mu.agent.tools import Tool
from mu.plugin import CommandResult, NullPlugin


def test_null_plugin_is_idle() raises:
    var p = NullPlugin()
    assert_equal(p.version_suffix(), "")
    assert_equal(p.extra_help(), "")
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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
