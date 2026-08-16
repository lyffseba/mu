from std.pathlib import Path
from std.testing import assert_equal, assert_true, TestSuite
from std.tempfile import mkdtemp

from mu.agent.messages import Message
from mu.coding.session import persist_message, write_session_header
from mu.coding.tree import (
    branch_messages,
    current_leaf,
    fork_to,
    format_tree,
    load_branch_messages,
    persist_leaf,
    persist_tree_message,
)


def test_linear_file_still_loads() raises:
    var dir_path = mkdtemp(prefix="mu-tree-")
    var path = Path(dir_path) / "s.jsonl"
    write_session_header(path, "s", "/tmp", "m", "fake")
    persist_message(path, Message.user("one"))
    persist_message(path, Message.assistant("two"))
    var loaded = load_branch_messages(path)
    assert_equal(len(loaded), 2)
    assert_equal(loaded[0].content, "one")


def test_fork_keeps_side_branch() raises:
    var dir_path = mkdtemp(prefix="mu-tree-")
    var path = Path(dir_path) / "s.jsonl"
    write_session_header(path, "s", "/tmp", "m", "fake")
    var a = persist_tree_message(path, Message.user("start"), "")
    var b = persist_tree_message(path, Message.assistant("ok"), a)
    persist_leaf(path, b)
    var c = persist_tree_message(path, Message.user("path A"), b)
    persist_leaf(path, c)
    var d = persist_tree_message(path, Message.user("path B"), b)
    persist_leaf(path, d)
    var active = load_branch_messages(path)
    assert_equal(len(active), 3)
    assert_equal(active[2].content, "path B")
    var forked = fork_to(path, c)
    assert_equal(len(forked), 3)
    assert_equal(forked[2].content, "path A")
    assert_equal(current_leaf(path), c)
    var shown = format_tree(path)
    assert_true(shown.find("path A") >= 0)
    assert_true(shown.find("path B") >= 0)
    _ = branch_messages


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
