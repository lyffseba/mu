"""Small string helpers used across the agent."""


def count_occurrences(haystack: String, needle: String) -> Int:
    """Count non-overlapping occurrences of `needle` in `haystack`."""
    if needle.byte_length() == 0:
        return 0
    var count = 0
    var start = 0
    while True:
        var idx = haystack.find(needle, start)
        if idx < 0:
            return count
        count += 1
        start = idx + needle.byte_length()


def replace_at(
    haystack: String, start: Int, old_len: Int, new: String
) -> String:
    """Replace the slice `[start, start + old_len)` with `new`."""
    var end = start + old_len
    var before = String(haystack[byte=0:start])
    var after = String(haystack[byte = end : haystack.byte_length()])
    return before + new + after


def replace_first(haystack: String, old: String, new: String) -> String:
    """Replace the first occurrence of `old`, or return the original string."""
    var idx = haystack.find(old)
    if idx < 0:
        return haystack
    return replace_at(haystack, idx, old.byte_length(), new)


def join_lines(lines: List[String]) -> String:
    """Join strings with newlines, matching Python `'\\n'.join`."""
    var out = String()
    var i = 0
    for line in lines:
        if i > 0:
            out += "\n"
        out += line
        i += 1
    return out


def join_strings(parts: List[String], sep: String) -> String:
    """Join strings with `sep`."""
    var out = String()
    var i = 0
    for part in parts:
        if i > 0:
            out += sep
        out += part
        i += 1
    return out


def split_lines(text: String) -> List[String]:
    """Split on `\\n` and return owned strings."""
    var parts = text.split("\n")
    var lines = List[String]()
    for part in parts:
        lines.append(String(part))
    return lines^


def starts_with(text: String, prefix: String) -> Bool:
    return text.startswith(prefix)


def strip_text(text: String) -> String:
    return String(text.strip())


def is_blank(text: String) -> Bool:
    return strip_text(text).byte_length() == 0


def normalize_lf(text: String) -> String:
    """Normalize CRLF / CR to LF for matching."""
    return text.replace("\r\n", "\n").replace("\r", "\n")


def detect_line_ending(text: String) -> String:
    """Return the first line ending in `text`, defaulting to LF."""
    var crlf = text.find("\r\n")
    var lf = text.find("\n")
    if lf < 0:
        return "\n"
    if crlf >= 0 and crlf <= lf:
        return "\r\n"
    return "\n"


def restore_line_endings(text: String, ending: String) -> String:
    """Rewrite LF line endings to `ending`."""
    if ending == "\r\n":
        return text.replace("\n", "\r\n")
    return text


def ranges_overlap(s1: Int, e1: Int, s2: Int, e2: Int) -> Bool:
    """True if `[s1, e1)` and `[s2, e2)` overlap."""
    return s1 < e2 and s2 < e1


def normalize_cwd(path: String) -> String:
    """Strip trailing slashes so `/tmp/foo` and `/tmp/foo/` compare equal."""
    var p = strip_text(path)
    if p.byte_length() == 0:
        return ""
    while p.byte_length() > 1 and p.endswith("/"):
        var cut = String(p[byte=0 : p.byte_length() - 1])
        p = cut
    return p


def first_whitespace(text: String) -> Int:
    """Index of the first space, tab, or newline, or -1."""
    var space = text.find(" ")
    var tab = text.find("\t")
    var nl = text.find("\n")
    var best = -1
    if space >= 0:
        best = space
    if tab >= 0 and (best < 0 or tab < best):
        best = tab
    if nl >= 0 and (best < 0 or nl < best):
        best = nl
    return best


def is_session_id(value: String) -> Bool:
    """Reject empty ids and anything that could escape the sessions directory.
    """
    if value.byte_length() == 0:
        return False
    if value.find("/") >= 0 or value.find("\\") >= 0:
        return False
    if value.find("..") >= 0:
        return False
    return True
