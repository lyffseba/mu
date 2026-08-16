"""On-disk layout for the living agent.

    ~/.mu/hermes/
      SOUL.md                 persona (one agent)
      USER.md                 user profile
      MEMORY.md               global notes
      sessions/<id>/
        MEMORY.md             session-weighted notes
        AWAKE                 this Mu session is a living agent
"""

from std.os import mkdir
from std.pathlib import Path

from mu.coding.settings import mu_home, mu_home_path
from mu.text import is_session_id


def hermes_home_path() raises -> Path:
    """Path only. Does not create directories."""
    return mu_home_path() / "hermes"


def hermes_home() raises -> Path:
    var root = mu_home() / "hermes"
    if not root.exists():
        mkdir(root)
    return root


def soul_path() raises -> Path:
    return hermes_home() / "SOUL.md"


def user_path() raises -> Path:
    return hermes_home() / "USER.md"


def global_memory_path() raises -> Path:
    return hermes_home() / "MEMORY.md"


def session_hermes_dir_path(session_id: String) raises -> Path:
    """Path only. Does not create directories."""
    if not is_session_id(session_id):
        raise Error(String("Invalid session id for Hermes: ", session_id))
    return hermes_home_path() / "sessions" / session_id


def session_hermes_dir(session_id: String) raises -> Path:
    var root = hermes_home() / "sessions"
    if not root.exists():
        mkdir(root)
    var d = session_hermes_dir_path(session_id)
    if not d.exists():
        mkdir(d)
    return d


def session_memory_path(session_id: String) raises -> Path:
    return session_hermes_dir(session_id) / "MEMORY.md"


def awake_path(session_id: String) raises -> Path:
    return session_hermes_dir_path(session_id) / "AWAKE"


def is_awake(session_id: String) raises -> Bool:
    """True only if this session was already woken. Never creates files."""
    if not is_session_id(session_id):
        return False
    var path = awake_path(session_id)
    return path.exists() and path.is_file()


def mark_awake(session_id: String) raises:
    _ = session_hermes_dir(session_id)
    var path = awake_path(session_id)
    path.write_text("awake\n")
