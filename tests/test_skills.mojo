from std.os import mkdir
from std.pathlib import Path
from std.testing import assert_equal, assert_true, TestSuite
from std.tempfile import mkdtemp

from mu.coding.skills import (
    Skill,
    build_skill_index,
    derive_description,
    expand_skill_command,
    format_skill_invocation,
    load_skills,
    parse_skill_markdown,
)
from mu.coding.settings import mu_home
from std.os.env import setenv


def _isolate() raises -> String:
    var dir_path = mkdtemp(prefix="mu-home-")
    var agents = mkdtemp(prefix="mu-agents-")
    _ = setenv("MU_HOME", dir_path, overwrite=True)
    _ = setenv("MU_AGENTS_HOME", agents, overwrite=True)
    return dir_path


def test_parse_frontmatter_description() raises:
    var parsed = parse_skill_markdown(
        "---\ndescription: Review a diff\n---\n# Security\nLook for holes."
    )
    assert_equal(parsed.description, "Review a diff")
    assert_true(parsed.body.find("Look for holes") >= 0)


def test_parse_frontmatter_crlf() raises:
    var parsed = parse_skill_markdown(
        "---\r\ndescription: Review a diff\r\n---\r\n# Security\r\nLook."
    )
    assert_equal(parsed.description, "Review a diff")
    assert_true(parsed.body.find("Look.") >= 0)


def test_derive_description_from_heading() raises:
    assert_equal(derive_description("# Git Review\nReview diffs."), "Git Review")
    assert_equal(derive_description("Just a line\nmore"), "Just a line")


def test_expand_skill_command() raises:
    var skills = List[Skill]()
    skills.append(
        Skill("review", "/tmp/review/SKILL.md", "Check the diff.", "Review")
    )
    var got = expand_skill_command("/skill:review look at auth", skills)
    assert_true(got)
    var text = got.value()
    assert_true(text.find('<skill name="review"') >= 0)
    assert_true(text.find("Check the diff.") >= 0)
    assert_true(text.find("look at auth") >= 0)
    var spaced = expand_skill_command("/skill: review look at auth", skills)
    assert_true(spaced)
    assert_true(spaced.value().find("look at auth") >= 0)
    var listed = expand_skill_command("/skills", skills)
    assert_true(not listed)
    var none = expand_skill_command("just a prompt", skills)
    assert_true(not none)


def test_unknown_skill_errors() raises:
    var skills = List[Skill]()
    var threw = False
    try:
        _ = expand_skill_command("/skill:missing", skills)
    except e:
        threw = True
        assert_true(String(e).find("Unknown skill") >= 0)
    assert_true(threw)


def test_load_skills_project_overrides_user() raises:
    var home = _isolate()
    var cwd = mkdtemp(prefix="mu-proj-")
    var user_dir = Path(home) / "skills" / "review"
    mkdir(Path(home) / "skills")
    mkdir(user_dir)
    (user_dir / "SKILL.md").write_text("# User Review\nFrom user.")
    mkdir(Path(cwd) / ".mu")
    mkdir(Path(cwd) / ".mu" / "skills")
    mkdir(Path(cwd) / ".mu" / "skills" / "review")
    (Path(cwd) / ".mu" / "skills" / "review" / "SKILL.md").write_text(
        "---\ndescription: Project Review\n---\n# Project\nFrom project."
    )
    mkdir(Path(cwd) / ".mu" / "skills" / "extra")
    (Path(cwd) / ".mu" / "skills" / "extra" / "SKILL.md").write_text(
        "# Extra\nOnly in project."
    )
    # Bare md is not a skill.
    (Path(cwd) / ".mu" / "skills" / "bare.md").write_text("# Bare")

    var skills = load_skills(cwd)
    assert_equal(len(skills), 2)
    assert_equal(skills[0].name, "extra")
    assert_equal(skills[1].name, "review")
    assert_equal(skills[1].description, "Project Review")
    assert_true(skills[1].path.find("/.mu/skills/review/") >= 0)
    var catalog = build_skill_index(skills)
    assert_true(catalog.find("<available_skills>") >= 0)
    assert_true(catalog.find("- extra:") >= 0)
    assert_true(catalog.find("- review: Project Review") >= 0)
    _ = mu_home()


def test_load_nested_skill() raises:
    var home = _isolate()
    mkdir(Path(home) / "skills")
    mkdir(Path(home) / "skills" / "pkg")
    mkdir(Path(home) / "skills" / "pkg" / "nested")
    (Path(home) / "skills" / "pkg" / "nested" / "SKILL.md").write_text(
        "# Nested\nFrom a subdirectory."
    )
    var skills = load_skills("/tmp")
    assert_equal(len(skills), 1)
    assert_equal(skills[0].name, "nested")
    assert_true(skills[0].description.find("Nested") >= 0)
    _ = home


def test_format_invocation_includes_parent() raises:
    var skill = Skill("x", "/tmp/x/SKILL.md", "body", "")
    var text = format_skill_invocation(skill, "")
    assert_true(text.find("References are relative to /tmp/x.") >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
