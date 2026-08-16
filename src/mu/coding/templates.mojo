"""Prompt templates, Pi-shaped.

A template is a Markdown file. The filename without `.md` is the slash
command. Discovery is non-recursive. Later roots override earlier names:

    ~/.mu/prompts/
    ~/.agents/prompts/
    <cwd>/.mu/prompts/
    <cwd>/.agents/prompts/

Reserved names (`skills`, `prompts`, `tools`) are ignored.
"""

from std.pathlib import Path

from mu.coding.settings import agents_home, mu_home_path
from mu.coding.skills import Frontmatter, parse_skill_markdown
from mu.text import first_whitespace, join_lines, split_lines, strip_text


@fieldwise_init
struct Template(Copyable, ImplicitlyCopyable, Movable):
    """One loaded prompt template."""

    var name: String
    var path: String
    var content: String
    var description: String


def is_reserved_template(name: String) -> Bool:
    return name == "skills" or name == "prompts" or name == "tools"


def is_template_name(name: String) -> Bool:
    if name.byte_length() == 0:
        return False
    if name.find("/") >= 0 or name.find("\\") >= 0 or name.find("..") >= 0:
        return False
    if name == "." or name == "..":
        return False
    return True


def template_search_dirs(cwd: String) raises -> List[Path]:
    var dirs = List[Path]()
    dirs.append(mu_home_path() / "prompts")
    dirs.append(agents_home() / "prompts")
    if cwd.byte_length() > 0:
        var root = Path(cwd)
        dirs.append(root / ".mu" / "prompts")
        dirs.append(root / ".agents" / "prompts")
    return dirs^


def load_templates_from_dir(dir_path: Path) raises -> List[Template]:
    var templates = List[Template]()
    if not dir_path.exists() or not dir_path.is_dir():
        return templates^
    var names = dir_path.listdir()
    for name in names:
        var item = String(name)
        if not item.endswith(".md"):
            continue
        var stem = String(item[byte=0 : item.byte_length() - 3])
        if not is_template_name(stem) or is_reserved_template(stem):
            continue
        var path = dir_path / item
        if not path.exists() or not path.is_file():
            continue
        try:
            var parsed = parse_skill_markdown(path.read_text())
            var desc = parsed.description
            if desc.byte_length() == 0:
                var lines = split_lines(parsed.body)
                for line in lines:
                    var t = strip_text(line)
                    if t.byte_length() > 0:
                        if t.startswith("#"):
                            while t.startswith("#"):
                                var rest = String(t[byte=1 : t.byte_length()])
                                var next = strip_text(rest)
                                t = next
                        desc = t
                        break
            templates.append(Template(stem, String(path), parsed.body, desc))
        except e:
            _ = e
    return templates^


def load_templates(cwd: String) raises -> List[Template]:
    var by_name = Dict[String, Template]()
    var order = List[String]()
    var dirs = template_search_dirs(cwd)
    for dir_path in dirs:
        var found = load_templates_from_dir(dir_path)
        for item in found:
            if item.name not in by_name:
                order.append(item.name)
            by_name[item.name] = item.copy()
    var templates = List[Template]()
    for name in order:
        var got = by_name.find(name)
        if got:
            templates.append(got.value().copy())
    var n = len(templates)
    var a = 0
    while a < n:
        var b = a + 1
        while b < n:
            if templates[b].name < templates[a].name:
                var tmp = templates[a]
                templates[a] = templates[b]
                templates[b] = tmp
            b += 1
        a += 1
    return templates^


def find_template(templates: List[Template], name: String) -> Optional[Int]:
    var i = 0
    for item in templates:
        if item.name == name:
            return Optional(i)
        i += 1
    return None


def expand_template_body(body: String, args: String) -> String:
    """Substitute `$1` and `$@`. Unset `$1` becomes empty."""
    var out = body
    if out.find("$@") >= 0:
        out = out.replace("$@", args)
    if out.find("$ARGUMENTS") >= 0:
        out = out.replace("$ARGUMENTS", args)
    var used_placeholder = False
    if body.find("$1") >= 0:
        used_placeholder = True
        var first = args
        var cut = first_whitespace(args)
        if cut >= 0:
            first = String(args[byte=0:cut])
        out = out.replace("$1", first)
    if body.find("$@") >= 0 or body.find("$ARGUMENTS") >= 0:
        used_placeholder = True
    if args.byte_length() > 0 and not used_placeholder:
        return strip_text(out) + "\n\n" + args
    return out


def expand_template_command(
    text: String, templates: List[Template]
) raises -> Optional[String]:
    """Expand `/name …` if `name` is a loaded template."""
    var trimmed = strip_text(text)
    if not trimmed.startswith("/"):
        return None
    if trimmed.startswith("/skill:"):
        return None
    var rest = String(trimmed[byte=1 : trimmed.byte_length()])
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
        return None
    var idx = find_template(templates, name)
    if not idx:
        return None
    var item = templates[idx.value()]
    return Optional(expand_template_body(item.content, extra))


def format_template_list(templates: List[Template]) -> String:
    if len(templates) == 0:
        return "(no prompt templates loaded)"
    var lines = List[String]()
    for item in templates:
        var desc = item.description
        if desc.byte_length() == 0:
            desc = "No description"
        lines.append(String("/", item.name, "  ", desc))
    return join_lines(lines)
