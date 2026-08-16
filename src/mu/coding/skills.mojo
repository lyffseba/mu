"""Markdown skills, Tau-shaped.

A skill is a directory containing `SKILL.md` (the Agent Skills spec).
Later search roots override earlier ones on the same name:

    ~/.mu/skills/
    ~/.agents/skills/
    <cwd>/.mu/skills/
    <cwd>/.agents/skills/

Bare `.md` files at the root of a skills directory are not skills.
"""

from std.pathlib import Path

from mu.coding.settings import agents_home, mu_home_path
from mu.text import first_whitespace, join_lines, normalize_lf, split_lines, strip_text


@fieldwise_init
struct Skill(Copyable, ImplicitlyCopyable, Movable):
    """One loaded skill."""

    var name: String
    var path: String
    var content: String
    var description: String


@fieldwise_init
struct Frontmatter(Copyable, ImplicitlyCopyable, Movable):
    """Optional YAML-ish header plus the markdown body."""

    var description: String
    var body: String


def strip_quotes(value: String) -> String:
    var t = strip_text(value)
    if t.byte_length() >= 2 and t.startswith("\"") and t.endswith("\""):
        return String(t[byte=1 : t.byte_length() - 1])
    if t.byte_length() >= 2 and t.startswith("'") and t.endswith("'"):
        return String(t[byte=1 : t.byte_length() - 1])
    return t


def derive_description(body: String) -> String:
    """First heading, else the first non-empty line."""
    var lines = split_lines(body)
    for line in lines:
        var t = strip_text(line)
        if t.byte_length() == 0:
            continue
        if t.startswith("#"):
            while t.startswith("#"):
                var rest = String(t[byte=1 : t.byte_length()])
                var next = strip_text(rest)
                t = next
            return t
        return t
    return ""


def parse_skill_markdown(raw: String) -> Frontmatter:
    """Split optional `---\\n...\\n---` frontmatter from the body."""
    var text = normalize_lf(raw)
    if not text.startswith("---"):
        return Frontmatter("", text)
    var rest = String(text[byte=3 : text.byte_length()])
    if rest.startswith("\n"):
        var dropped = String(rest[byte=1 : rest.byte_length()])
        rest = dropped
    var end = rest.find("\n---")
    if end < 0:
        return Frontmatter("", text)
    var meta = String(rest[byte=0:end])
    var body = String(rest[byte = end + 4 : rest.byte_length()])
    if body.startswith("\n"):
        var dropped_body = String(body[byte=1 : body.byte_length()])
        body = dropped_body
    var desc = ""
    var lines = split_lines(meta)
    for line in lines:
        var t = strip_text(line)
        if t.startswith("description:"):
            desc = strip_quotes(String(t[byte=12 : t.byte_length()]))
    return Frontmatter(desc, body)


def is_skill_name(name: String) -> Bool:
    """Directory names that can safely be skill ids."""
    if name.byte_length() == 0:
        return False
    if name.find("/") >= 0 or name.find("\\") >= 0 or name.find("..") >= 0:
        return False
    if name == "." or name == "..":
        return False
    return True


def skill_search_dirs(cwd: String) raises -> List[Path]:
    """Increasing precedence: later roots override earlier names."""
    var dirs = List[Path]()
    dirs.append(mu_home_path() / "skills")
    dirs.append(agents_home() / "skills")
    if cwd.byte_length() > 0:
        var root = Path(cwd)
        dirs.append(root / ".mu" / "skills")
        dirs.append(root / ".agents" / "skills")
    return dirs^


def load_skill_file(name: String, path: Path) raises -> Skill:
    var parsed = parse_skill_markdown(path.read_text())
    var desc = parsed.description
    if desc.byte_length() == 0:
        desc = derive_description(parsed.body)
    return Skill(name, String(path), parsed.body, desc)


def load_skills_from_dir(dir_path: Path, depth: Int = 0) raises -> List[Skill]:
    """Recursively load `<dir>/**/SKILL.md`. Depth is a cycle guard."""
    var skills = List[Skill]()
    if depth > 8:
        return skills^
    if not dir_path.exists() or not dir_path.is_dir():
        return skills^
    var names = dir_path.listdir()
    for name in names:
        var item = String(name)
        if not is_skill_name(item):
            continue
        var child = dir_path / item
        if not child.exists() or not child.is_dir():
            continue
        var skill_md = child / "SKILL.md"
        if skill_md.exists() and skill_md.is_file():
            try:
                skills.append(load_skill_file(item, skill_md))
            except e:
                _ = e
        else:
            var nested = load_skills_from_dir(child, depth + 1)
            for skill in nested:
                skills.append(skill.copy())
    return skills^


def load_skills(cwd: String) raises -> List[Skill]:
    """Load skills. Project roots override user roots of the same name."""
    var by_name = Dict[String, Skill]()
    var order = List[String]()
    var dirs = skill_search_dirs(cwd)
    for dir_path in dirs:
        var found = load_skills_from_dir(dir_path)
        for skill in found:
            if skill.name not in by_name:
                order.append(skill.name)
            by_name[skill.name] = skill.copy()
    var skills = List[Skill]()
    for name in order:
        var got = by_name.find(name)
        if got:
            skills.append(got.value().copy())
    # Stable name sort.
    var n = len(skills)
    var a = 0
    while a < n:
        var b = a + 1
        while b < n:
            if skills[b].name < skills[a].name:
                var tmp = skills[a]
                skills[a] = skills[b]
                skills[b] = tmp
            b += 1
        a += 1
    return skills^


def find_skill(skills: List[Skill], name: String) -> Optional[Int]:
    var i = 0
    for skill in skills:
        if skill.name == name:
            return Optional(i)
        i += 1
    return None


def format_skill_invocation(skill: Skill, extra: String = "") -> String:
    """Expand a skill into the user prompt, Tau-shaped."""
    var lines = List[String]()
    lines.append(String('<skill name="', skill.name, '" location="', skill.path, '">'))
    var parent = parent_of_skill(skill.path)
    lines.append(String("References are relative to ", parent, "."))
    lines.append("")
    lines.append(strip_text(skill.content))
    lines.append("</skill>")
    var block = join_lines(lines)
    var more = strip_text(extra)
    if more.byte_length() > 0:
        return block + "\n\n" + more
    return block


def parent_of_skill(path: String) -> String:
    var p = Path(path)
    var name = p.name()
    var full = String(p)
    if name.byte_length() == 0 or full == name:
        return "."
    var cut = full.byte_length() - name.byte_length()
    if cut > 0 and String(full[byte = cut - 1 : cut]) == "/":
        cut -= 1
    if cut <= 0:
        return "/"
    var parent = String(full[byte=0:cut])
    if parent.byte_length() == 0:
        return "/"
    return parent


def expand_skill_command(text: String, skills: List[Skill]) raises -> Optional[String]:
    """Expand `/skill:name …`, or None if this is not a skill command.

    `/skills` is a listing command, not `/skill:` + name `s`.
    A space after the colon is allowed (`/skill: review`). Text after
    the name — including following lines — is extra instruction.
    """
    var trimmed = strip_text(text)
    if trimmed == "/skills" or trimmed.startswith("/skills ") or trimmed.startswith("/skills\t") or trimmed.startswith("/skills\n"):
        return None
    if not trimmed.startswith("/skill:"):
        return None
    var rest = strip_text(String(trimmed[byte=7 : trimmed.byte_length()]))
    if rest.byte_length() == 0:
        raise Error("Skill command must include a skill name")
    var cut = first_whitespace(rest)
    var name: String
    var extra: String
    if cut < 0:
        name = rest
        extra = ""
    else:
        name = String(rest[byte=0:cut])
        extra = strip_text(String(rest[byte = cut + 1 : rest.byte_length()]))
    if name.byte_length() == 0:
        raise Error("Skill command must include a skill name")
    var idx = find_skill(skills, name)
    if not idx:
        raise Error(String("Unknown skill: ", name))
    return Optional(format_skill_invocation(skills[idx.value()], extra))


def build_skill_index(skills: List[Skill]) -> String:
    """Short catalog for the system prompt."""
    if len(skills) == 0:
        return ""
    var lines = List[String]()
    lines.append("<available_skills>")
    for skill in skills:
        var desc = skill.description
        if desc.byte_length() == 0:
            desc = "No description"
        lines.append(String("- ", skill.name, ": ", desc))
    lines.append("</available_skills>")
    lines.append(
        "When a skill is relevant, read its SKILL.md with the read tool. "
        "The user may also invoke /skill:<name> to expand one into the prompt."
    )
    return join_lines(lines)


def format_skill_list(skills: List[Skill]) -> String:
    if len(skills) == 0:
        return "(no skills loaded)"
    var lines = List[String]()
    for skill in skills:
        var desc = skill.description
        if desc.byte_length() == 0:
            desc = "No description"
        lines.append(String("- ", skill.name, "  ", desc, "  (", skill.path, ")"))
    return join_lines(lines)
