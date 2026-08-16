"""Persistent user settings under `~/.mu/config.json`.

CLI flags and environment variables still win. This file is the default
for model, provider, base URL, and last-session pointer.
"""

from std.os import mkdir
from std.os.env import getenv
from std.pathlib import Path

from mu.jsonx import (
    empty_object,
    json_dumps,
    json_get_int,
    json_get_str,
    json_has,
    json_loads,
)
from mu.text import is_blank, is_session_id


@fieldwise_init
struct Settings(Copyable, ImplicitlyCopyable, Movable):
    """Values loaded from `~/.mu/config.json`."""

    var model: String
    var provider: String
    var base_url: String
    var last_session: String
    var compact_threshold: Int
    var compact_keep: Int
    var stream: Bool

    @staticmethod
    def empty() -> Settings:
        return Settings("", "", "", "", 0, 0, True)


def mu_home_path() raises -> Path:
    var override = getenv("MU_HOME", "")
    if override.byte_length() > 0:
        return Path(override).expanduser()
    return Path.home() / ".mu"


def mu_home() raises -> Path:
    var root = mu_home_path()
    if not root.exists():
        mkdir(root)
    return root


def agents_home() raises -> Path:
    """User-level `.agents` root. `$MU_AGENTS_HOME` isolates tests."""
    var override = getenv("MU_AGENTS_HOME", "")
    if override.byte_length() > 0:
        return Path(override).expanduser()
    return Path.home() / ".agents"


def config_path() raises -> Path:
    return mu_home_path() / "config.json"


def load_settings() raises -> Settings:
    """Load `~/.mu/config.json` if present. Missing file is empty settings."""
    var path = config_path()
    if not path.exists() or not path.is_file():
        return Settings.empty()
    var raw = path.read_text()
    if is_blank(raw):
        return Settings.empty()
    var obj = json_loads(raw)
    var stream = True
    if json_has(obj, "stream"):
        stream = Bool(py=obj["stream"])
    return Settings(
        json_get_str(obj, "model"),
        json_get_str(obj, "provider"),
        json_get_str(obj, "base_url"),
        json_get_str(obj, "last_session"),
        json_get_int(obj, "compact_threshold", 0),
        json_get_int(obj, "compact_keep", 0),
        stream,
    )


def save_settings(settings: Settings) raises:
    var obj = empty_object()
    if settings.model.byte_length() > 0:
        obj["model"] = settings.model
    if settings.provider.byte_length() > 0:
        obj["provider"] = settings.provider
    if settings.base_url.byte_length() > 0:
        obj["base_url"] = settings.base_url
    if settings.last_session.byte_length() > 0:
        obj["last_session"] = settings.last_session
    if settings.compact_threshold > 0:
        obj["compact_threshold"] = settings.compact_threshold
    if settings.compact_keep > 0:
        obj["compact_keep"] = settings.compact_keep
    obj["stream"] = settings.stream
    _ = mu_home()
    var path = config_path()
    path.write_text(json_dumps(obj) + "\n")


def remember_session(session_id: String) raises:
    """Update only the last-session pointer."""
    if not is_session_id(session_id):
        return
    var settings = load_settings()
    settings.last_session = session_id
    save_settings(settings)
