from std.os import mkdir
from std.os.env import setenv
from std.pathlib import Path
from std.testing import assert_equal, assert_true, TestSuite
from std.tempfile import mkdtemp

from mu.coding.templates import (
    Template,
    expand_template_body,
    expand_template_command,
    load_templates,
)


def _isolate() raises -> String:
    var home = mkdtemp(prefix="mu-home-")
    var agents = mkdtemp(prefix="mu-agents-")
    _ = setenv("MU_HOME", home, overwrite=True)
    _ = setenv("MU_AGENTS_HOME", agents, overwrite=True)
    return home


def test_expand_placeholders() raises:
    assert_equal(
        expand_template_body("Create $1 with $@", "Button onClick"),
        "Create Button with Button onClick",
    )
    assert_equal(
        expand_template_body("Review the staged changes.", "focus on auth"),
        "Review the staged changes.\n\nfocus on auth",
    )


def test_expand_template_command() raises:
    var templates = List[Template]()
    templates.append(Template("review", "/tmp/review.md", "Look at $1.", "Review"))
    var got = expand_template_command("/review auth", templates)
    assert_true(got)
    assert_equal(got.value(), "Look at auth.")
    var none = expand_template_command("/skill:review", templates)
    assert_true(not none)
    var missing = expand_template_command("/nope", templates)
    assert_true(not missing)


def test_load_templates_project_overrides() raises:
    var home = _isolate()
    var cwd = mkdtemp(prefix="mu-proj-")
    mkdir(Path(home) / "prompts")
    (Path(home) / "prompts" / "review.md").write_text(
        "---\ndescription: User review\n---\nUser body"
    )
    mkdir(Path(cwd) / ".mu")
    mkdir(Path(cwd) / ".mu" / "prompts")
    (Path(cwd) / ".mu" / "prompts" / "review.md").write_text(
        "---\ndescription: Project review\n---\nProject body"
    )
    (Path(cwd) / ".mu" / "prompts" / "skills.md").write_text("reserved")
    var templates = load_templates(cwd)
    assert_equal(len(templates), 1)
    assert_equal(templates[0].name, "review")
    assert_equal(templates[0].description, "Project review")
    assert_true(templates[0].content.find("Project body") >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
