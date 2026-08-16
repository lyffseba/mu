from std.os.env import setenv
from std.pathlib import Path
from std.testing import assert_equal, assert_true, TestSuite
from std.tempfile import mkdtemp

from mu.agent.messages import Message
from mu.coding.session import (
    load_session_messages,
    persist_compaction,
    persist_message,
    resolve_continue_session,
    sessions_dir,
    write_session_header,
)
from mu.text import is_session_id


def test_session_id_rejects_paths() raises:
    assert_true(is_session_id("20260813-120000-000001"))
    assert_true(not is_session_id(""))
    assert_true(not is_session_id("../etc/passwd"))
    assert_true(not is_session_id("a/b"))
    assert_true(not is_session_id("a\\b"))


def test_roundtrip_messages() raises:
    var dir_path = mkdtemp(prefix="mu-sess-")
    var path = Path(dir_path) / "s.jsonl"
    write_session_header(path, "s", "/tmp", "m", "fake")
    persist_message(path, Message.user("hello"))
    persist_message(path, Message.assistant("hi"))
    persist_message(path, Message.user("again"))
    var loaded = load_session_messages(path)
    assert_equal(len(loaded), 3)
    assert_equal(loaded[0].role, "user")
    assert_equal(loaded[0].content, "hello")
    assert_equal(loaded[1].role, "assistant")
    assert_equal(loaded[2].content, "again")


def test_compaction_entry_replays() raises:
    var dir_path = mkdtemp(prefix="mu-sess-")
    var path = Path(dir_path) / "s.jsonl"
    persist_message(path, Message.user("one"))
    persist_message(path, Message.assistant("two"))
    persist_message(path, Message.user("three"))
    persist_message(path, Message.assistant("four"))
    persist_compaction(path, Message.user("STORED SUMMARY"), 2, 2)
    var loaded = load_session_messages(path)
    assert_equal(len(loaded), 3)
    assert_equal(loaded[0].content, "STORED SUMMARY")
    assert_equal(loaded[1].content, "three")
    assert_equal(loaded[2].content, "four")


def test_append_does_not_rewrite() raises:
    var dir_path = mkdtemp(prefix="mu-sess-")
    var path = Path(dir_path) / "s.jsonl"
    persist_message(path, Message.user("one"))
    persist_message(path, Message.user("two"))
    var loaded = load_session_messages(path)
    assert_equal(len(loaded), 2)
    assert_equal(loaded[0].content, "one")
    assert_equal(loaded[1].content, "two")


def _isolate() raises -> String:
    var dir_path = mkdtemp(prefix="mu-home-")
    _ = setenv("MU_HOME", dir_path, overwrite=True)
    return dir_path


def test_continue_prefers_remembered_when_present() raises:
    _ = _isolate()
    var dir_path = sessions_dir()
    write_session_header(
        dir_path / "20260816-110000-000001.jsonl",
        "20260816-110000-000001",
        "/tmp",
        "m",
        "fake",
    )
    write_session_header(
        dir_path / "20260816-120000-000002.jsonl",
        "20260816-120000-000002",
        "/tmp",
        "m",
        "fake",
    )
    assert_equal(
        resolve_continue_session("20260816-120000-000002"),
        "20260816-120000-000002",
    )
    assert_equal(
        resolve_continue_session("20260816-110000-000001"),
        "20260816-110000-000001",
    )


def test_continue_falls_back_to_newest_when_stale() raises:
    _ = _isolate()
    var dir_path = sessions_dir()
    write_session_header(
        dir_path / "20260816-110000-000001.jsonl",
        "20260816-110000-000001",
        "/tmp",
        "m",
        "fake",
    )
    write_session_header(
        dir_path / "20260816-120000-000002.jsonl",
        "20260816-120000-000002",
        "/tmp",
        "m",
        "fake",
    )
    # Remembered id is well-formed but its file is gone.
    assert_equal(
        resolve_continue_session("20260816-130000-999999"),
        "20260816-120000-000002",
    )


def test_continue_corrupt_or_empty_pointer_falls_back() raises:
    _ = _isolate()
    var dir_path = sessions_dir()
    write_session_header(
        dir_path / "20260816-120000-000002.jsonl",
        "20260816-120000-000002",
        "/tmp",
        "m",
        "fake",
    )
    # A corrupt pointer must not sink the resume; degrade to newest.
    assert_equal(
        resolve_continue_session("../etc/passwd"),
        "20260816-120000-000002",
    )
    assert_equal(resolve_continue_session(""), "20260816-120000-000002")


def test_continue_ignores_other_cwd() raises:
    _ = _isolate()
    var dir_path = sessions_dir()
    write_session_header(
        dir_path / "20260816-110000-000001.jsonl",
        "20260816-110000-000001",
        "/tmp/other",
        "m",
        "fake",
    )
    write_session_header(
        dir_path / "20260816-120000-000002.jsonl",
        "20260816-120000-000002",
        "/tmp/here",
        "m",
        "fake",
    )
    assert_equal(
        resolve_continue_session("20260816-110000-000001", "/tmp/here"),
        "20260816-120000-000002",
    )
    assert_equal(resolve_continue_session("", "/tmp/here"), "20260816-120000-000002")
    assert_equal(resolve_continue_session("", "/tmp/here/"), "20260816-120000-000002")
    assert_equal(resolve_continue_session("", "/tmp/nowhere"), "")


def test_continue_none_when_no_sessions() raises:
    _ = _isolate()
    assert_equal(resolve_continue_session(""), "")


def test_load_skips_truncated_tail() raises:
    var dir_path = mkdtemp(prefix="mu-sess-")
    var path = Path(dir_path) / "s.jsonl"
    write_session_header(path, "s", "/tmp", "m", "fake")
    persist_message(path, Message.user("one"))
    # A process killed mid-write leaves a partial final line.
    var full = path.read_text() + '{"type":"message","role"'
    path.write_text(full)
    var loaded = load_session_messages(path)
    assert_equal(len(loaded), 1)
    assert_equal(loaded[0].content, "one")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
