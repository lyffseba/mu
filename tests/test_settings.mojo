from std.os.env import getenv, setenv
from std.pathlib import Path
from std.testing import assert_equal, assert_true, TestSuite
from std.tempfile import mkdtemp

from mu.coding.session import latest_session_id, persist_message, sessions_dir
from mu.coding.settings import (
    load_settings,
    remember_session,
    save_settings,
    Settings,
)
from mu.agent.messages import Message


def _isolate() raises -> String:
    var dir_path = mkdtemp(prefix="mu-home-")
    _ = setenv("MU_HOME", dir_path, overwrite=True)
    return dir_path


def test_settings_roundtrip() raises:
    _ = _isolate()
    var settings = Settings(
        "m1", "openai", "https://example/v1", "", 12000, 4, False
    )
    save_settings(settings)
    var loaded = load_settings()
    assert_equal(loaded.model, "m1")
    assert_equal(loaded.provider, "openai")
    assert_equal(loaded.base_url, "https://example/v1")
    assert_equal(loaded.compact_threshold, 12000)
    assert_equal(loaded.compact_keep, 4)
    assert_equal(loaded.stream, False)


def test_remember_session_keeps_other_fields() raises:
    _ = _isolate()
    save_settings(Settings("kept", "openrouter", "", "", 0, 0, True))
    remember_session("20260816-120000-000001")
    var loaded = load_settings()
    assert_equal(loaded.model, "kept")
    assert_equal(loaded.provider, "openrouter")
    assert_equal(loaded.last_session, "20260816-120000-000001")


def test_latest_session_id() raises:
    _ = _isolate()
    assert_equal(latest_session_id(), "")
    persist_message(
        sessions_dir() / "20260816-120000-000001.jsonl", Message.user("hi")
    )
    persist_message(
        sessions_dir() / "20260816-130000-000001.jsonl", Message.user("later")
    )
    assert_equal(latest_session_id(), "20260816-130000-000001")
    _ = getenv("MU_HOME", "")
    _ = Path(".")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
