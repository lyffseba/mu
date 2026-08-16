"""Bounded, curated memory. Hermes-shaped, session-weighted.

Two global stores plus one per-session store:

    MEMORY.md  — environment, conventions, lessons (2200 chars)
    USER.md    — who you are, how you like to work (1375 chars)
    sessions/<id>/MEMORY.md — notes that belong to this Mu session

Writes that would overflow return an error. The agent consolidates.
The system prompt gets a frozen snapshot at session start (prefix cache).
"""

from std.pathlib import Path

from mu.hermes.paths import (
    global_memory_path,
    hermes_home_path,
    session_memory_path,
    soul_path,
    user_path,
)
from mu.text import join_lines, split_lines, strip_text


comptime MEMORY_LIMIT = 2200
comptime USER_LIMIT = 1375
comptime SEP = "§"


def default_soul() -> String:
    return (
        "You are Hermes Agent, an intelligent AI assistant created by Nous "
        "Research, running inside Mu. You are helpful, knowledgeable, and "
        "direct. You assist with reading, writing, and editing code, running "
        "commands, and remembering what matters about this session and this "
        "user. Communicate clearly. Admit uncertainty. Be targeted.\n"
    )


def ensure_seed_files() raises:
    """Create empty stores and a default SOUL on first wake."""
    var soul = soul_path()
    if not soul.exists():
        soul.write_text(default_soul())
    var user = user_path()
    if not user.exists():
        user.write_text("")
    var mem = global_memory_path()
    if not mem.exists():
        mem.write_text("")


def read_store(path: Path) raises -> String:
    if not path.exists():
        return ""
    return path.read_text()


def split_entries(text: String) -> List[String]:
    var raw = split_lines(text.replace(SEP, "\n" + SEP + "\n"))
    var entries = List[String]()
    var current = String()
    var started = False
    for line in raw:
        var t = strip_text(line)
        if t == SEP:
            if started and strip_text(current).byte_length() > 0:
                entries.append(strip_text(current))
            current = ""
            started = True
            continue
        if t.byte_length() == 0 and not started:
            continue
        if current.byte_length() > 0:
            current += "\n"
        current += line
        started = True
    var last = strip_text(current)
    if last.byte_length() > 0:
        entries.append(last)
    return entries^


def join_entries(entries: List[String]) -> String:
    var parts = List[String]()
    for entry in entries:
        var t = strip_text(entry)
        if t.byte_length() > 0:
            parts.append(t)
    return _join_with_sep(parts)


def _join_with_sep(parts: List[String]) -> String:
    var out = String()
    var i = 0
    for part in parts:
        if i > 0:
            out += "\n" + SEP + "\n"
        out += part
        i += 1
    return out


def require_target(target: String) raises:
    if target != "memory" and target != "user" and target != "session":
        raise Error("target must be memory, user, or session")


def require_entry_text(text: String) raises:
    if text.byte_length() == 0:
        raise Error("content is required")
    if text.find(SEP) >= 0:
        raise Error("content must not contain the entry separator")


def store_limit(target: String) -> Int:
    if target == "user":
        return USER_LIMIT
    return MEMORY_LIMIT


def load_entries(target: String, session_id: String) raises -> List[String]:
    require_target(target)
    var path: Path
    if target == "user":
        path = user_path()
    elif target == "session":
        path = session_memory_path(session_id)
    else:
        path = global_memory_path()
    return split_entries(read_store(path))


def save_entries(target: String, session_id: String, entries: List[String]) raises:
    require_target(target)
    var path: Path
    if target == "user":
        path = user_path()
    elif target == "session":
        path = session_memory_path(session_id)
    else:
        path = global_memory_path()
    path.write_text(join_entries(entries))


def char_count(entries: List[String]) -> Int:
    return join_entries(entries).byte_length()


def find_unique(entries: List[String], needle: String) raises -> Int:
    if needle.byte_length() == 0:
        raise Error("old_text must be non-empty")
    var found = -1
    var i = 0
    for entry in entries:
        if entry.find(needle) >= 0:
            if found >= 0:
                raise Error("old_text matched more than one entry; be more specific")
            found = i
        i += 1
    if found < 0:
        raise Error("old_text not found")
    return found


def memory_add(
    target: String, session_id: String, content: String
) raises -> String:
    var entries = load_entries(target, session_id)
    var text = strip_text(content)
    require_entry_text(text)
    var before = char_count(entries)
    entries.append(text)
    var n = char_count(entries)
    var limit = store_limit(target)
    if n > limit:
        raise Error(
            String(
                "Memory at ",
                before,
                "/",
                limit,
                " chars. Adding this entry (",
                text.byte_length(),
                " chars) would exceed the limit. Consolidate with replace/remove, then retry.",
            )
        )
    save_entries(target, session_id, entries)
    return String("added (", n, "/", limit, " chars)")


def memory_replace(
    target: String, session_id: String, old_text: String, content: String
) raises -> String:
    var entries = load_entries(target, session_id)
    var idx = find_unique(entries, old_text)
    var text = strip_text(content)
    require_entry_text(text)
    entries[idx] = text
    var n = char_count(entries)
    var limit = store_limit(target)
    if n > limit:
        raise Error(
            String(
                "replace would exceed the ",
                limit,
                " char limit (",
                n,
                "). Shorten the new text or remove another entry first.",
            )
        )
    save_entries(target, session_id, entries)
    return String("replaced (", n, "/", limit, " chars)")


def memory_remove(
    target: String, session_id: String, old_text: String
) raises -> String:
    var entries = load_entries(target, session_id)
    var idx = find_unique(entries, old_text)
    var kept = List[String]()
    var i = 0
    for entry in entries:
        if i != idx:
            kept.append(entry)
        i += 1
    save_entries(target, session_id, kept)
    return String("removed (", char_count(kept), "/", store_limit(target), " chars)")


def render_store(title: String, entries: List[String], limit: Int) -> String:
    var body = join_entries(entries)
    var n = body.byte_length()
    var pct = 0
    if limit > 0:
        pct = (n * 100) // limit
    var lines = List[String]()
    lines.append("══════════════════════════════════════════════")
    lines.append(String(title, " [", pct, "% — ", n, "/", limit, " chars]"))
    lines.append("══════════════════════════════════════════════")
    if n == 0:
        lines.append("(empty)")
    else:
        lines.append(body)
    return join_lines(lines)


def frozen_memory_block(session_id: String) raises -> String:
    """Snapshot injected into the system prompt at session start."""
    ensure_seed_files()
    var soul = strip_text(read_store(soul_path()))
    if soul.byte_length() == 0:
        soul = default_soul()
    var lines = List[String]()
    lines.append("<hermes_soul>")
    lines.append(soul)
    lines.append("</hermes_soul>")
    lines.append("")
    lines.append(
        render_store("MEMORY (your personal notes)", load_entries("memory", session_id), MEMORY_LIMIT)
    )
    lines.append("")
    lines.append(
        render_store("USER PROFILE", load_entries("user", session_id), USER_LIMIT)
    )
    lines.append("")
    lines.append(
        render_store(
            String("SESSION MEMORY [", session_id, "]"),
            load_entries("session", session_id),
            MEMORY_LIMIT,
        )
    )
    lines.append("")
    lines.append(
        "This snapshot is frozen for the rest of the session (prefix cache). "
        "Writes via the memory tool persist immediately and show in tool "
        "results; they appear here on the next wake."
    )
    return join_lines(lines)


def memory_search(
    session_id: String, query: String, target: String = ""
) raises -> String:
    """Case-insensitive substring search. Empty target searches all stores."""
    var q = strip_text(query)
    if q.byte_length() == 0:
        raise Error("query is required")
    var needle = q.lower()
    var targets = List[String]()
    if target.byte_length() == 0:
        targets.append("session")
        targets.append("memory")
        targets.append("user")
    else:
        require_target(target)
        targets.append(target)
    var lines = List[String]()
    for t in targets:
        var entries = load_entries(t, session_id)
        var i = 0
        for entry in entries:
            if entry.lower().find(needle) >= 0:
                lines.append(String("[", t, "] ", entry))
            i += 1
    if len(lines) == 0:
        return "(no matches)"
    return join_lines(lines)


def format_memory_listing(session_id: String) raises -> String:
    """Human listing for /memory."""
    ensure_seed_files()
    var parts = List[String]()
    parts.append(render_store("SESSION", load_entries("session", session_id), MEMORY_LIMIT))
    parts.append("")
    parts.append(render_store("MEMORY", load_entries("memory", session_id), MEMORY_LIMIT))
    parts.append("")
    parts.append(render_store("USER", load_entries("user", session_id), USER_LIMIT))
    return join_lines(parts)


def recall_other_sessions(session_id: String, query: String, limit: Int = 8) raises -> String:
    """Search other living sessions' MEMORY.md. This session is skipped."""
    var q = strip_text(query)
    if q.byte_length() == 0:
        raise Error("query is required")
    var needle = q.lower()
    var root = hermes_home_path() / "sessions"
    if not root.exists() or not root.is_dir():
        return "(no other sessions)"
    var names = root.listdir()
    var lines = List[String]()
    for name in names:
        var ident = String(name)
        if ident == session_id:
            continue
        var path = root / ident / "MEMORY.md"
        if not path.exists() or not path.is_file():
            continue
        var entries = split_entries(read_store(path))
        for entry in entries:
            if entry.lower().find(needle) >= 0:
                lines.append(String("[", ident, "] ", entry))
                if len(lines) >= limit:
                    return join_lines(lines)
    if len(lines) == 0:
        return "(no matches in other sessions)"
    return join_lines(lines)


def learning_nudge() -> String:
    """Closed-loop reminder, Hermes-style. Injected after a living turn."""
    return (
        "After this turn: if you learned a durable fact about the user, the "
        "environment, or this session, persist it with the memory tool "
        "(target=user|memory|session). If a reusable procedure emerged, "
        "consider writing a skill under .mu/skills/<name>/SKILL.md. "
        "Do not save trivia, secrets, or things already in SOUL.md / AGENTS.md."
    )
