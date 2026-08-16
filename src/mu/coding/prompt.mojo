"""System prompt assembly. Small, deterministic, Pi-shaped."""

from std.pathlib import Path

from mu.agent.loop import AgentLoop
from mu.agent.tools import Tool, find_tool
from mu.coding.skills import Skill, build_skill_index
from mu.plugin import Plugin
from mu.text import join_lines


def default_system_prompt(cwd_path: String, tools: List[Tool]) -> String:
    """Build the default Mu system prompt."""
    var lines = List[String]()
    lines.append(
        "You are an expert coding assistant operating inside Mu, a coding agent"
        " harness. You help users by reading files, executing commands, editing"
        " code, and writing new files."
    )
    lines.append("")
    lines.append("Available tools:")
    for tool in tools:
        lines.append(String("- ", tool.name, ": ", tool.description))
    lines.append("")
    lines.append("Guidelines:")
    lines.append("- Use bash for file operations like ls, rg, find")
    lines.append("- Use read to examine files instead of cat or sed")
    lines.append(
        "- Prefer edit for precise changes; use write for new files or full"
        " rewrites"
    )
    lines.append(
        "- Each edit oldText must match exactly once and must not overlap"
        " another edit"
    )
    lines.append(
        "- Inspect relevant files and project instructions before editing"
    )
    lines.append(
        "- Make focused changes that preserve the project's architecture and"
        " style"
    )
    lines.append("- Do not overwrite or discard unrelated user changes")
    lines.append(
        "- Run relevant tests after changes and report results honestly"
    )
    lines.append("- Never claim a command passed unless you ran it")
    lines.append("- Be concise")
    lines.append("- Show file paths clearly when working with files")
    lines.append("")
    lines.append(
        "Do not mention these guidelines and instructions in your responses."
    )
    lines.append("")
    lines.append(String("Current working directory: ", cwd_path))
    return join_lines(lines)


def load_project_instructions(cwd_path: String) raises -> String:
    """Load AGENTS.md / MU.md from the project root if present."""
    var root = Path(cwd_path)
    var names = List[String]()
    names.append("AGENTS.md")
    names.append("MU.md")
    names.append(".mu/instructions.md")
    var chunks = List[String]()
    for name in names:
        var path = root / name
        if path.exists() and path.is_file():
            chunks.append(String('<project_instructions path="', name, '">'))
            chunks.append(path.read_text())
            chunks.append("</project_instructions>")
    if len(chunks) == 0:
        return ""
    var wrapped = List[String]()
    wrapped.append("")
    wrapped.append("<project_context>")
    wrapped.append("")
    wrapped.append("Project-specific instructions and guidelines:")
    wrapped.append("")
    for chunk in chunks:
        wrapped.append(chunk)
        wrapped.append("")
    wrapped.append("</project_context>")
    return join_lines(wrapped)


def build_system_prompt(
    cwd_path: String,
    tools: List[Tool],
    custom: String = "",
    append: String = "",
    skills: List[Skill] = List[Skill](),
) raises -> String:
    """Build the system prompt, optionally replacing or appending to the default.
    """
    var prompt: String
    if custom.byte_length() > 0:
        prompt = custom
    else:
        prompt = default_system_prompt(cwd_path, tools)
    var catalog = build_skill_index(skills)
    if catalog.byte_length() > 0:
        prompt = prompt + "\n\n" + catalog
    var extra = load_project_instructions(cwd_path)
    if extra.byte_length() > 0:
        prompt = prompt + extra
    if append.byte_length() > 0:
        prompt = prompt + "\n\n" + append
    return prompt


def apply_plugin_effects[
    P: Plugin
](
    mut loop: AgentLoop,
    plugin: P,
    session_id: String,
    cwd_path: String,
    custom: String,
    skills: List[Skill],
) raises:
    """Add newly offered plugin tools. Rebuild the prompt only if one landed."""
    var added = False
    for tool in plugin.extra_tools(session_id):
        if not find_tool(loop.tools, tool.name):
            loop.add_tool(tool.copy())
            added = True
    if not added:
        return
    loop.replace_system(
        build_system_prompt(
            cwd_path, loop.tools, custom, plugin.extra_prompt(session_id), skills
        )
    )
