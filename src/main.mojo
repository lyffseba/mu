"""`mu` command-line entry point."""

from std.io import input
from std.pathlib import Path
from std.sys.terminate import exit

from mu import VERSION
from mu.agent.loop import AgentLoop, AgentRun, Completer
from mu.agent.messages import Message
from mu.agent.sink import EventSink, NullSink, PrintSink
from mu.ai.completers import EchoCompleter, OpenAICompleter
from mu.coding.config import parse_args, resolve_provider, usage
from mu.coding.context import apply_compaction, estimate_context_tokens
from mu.coding.prompt import build_system_prompt
from mu.coding.render import last_assistant_text, render_json, render_text
from mu.coding.runner import CodingRunner
from mu.coding.session import (
    format_session_list,
    load_session_messages,
    new_session_id,
    persist_compaction,
    persist_message,
    resolve_continue_session,
    session_path,
    write_session_header,
)
from mu.coding.tree import (
    current_leaf,
    fork_to,
    format_tree,
    load_branch_messages,
    persist_leaf,
    persist_tree_message,
)
from mu.coding.settings import load_settings, remember_session
from mu.coding.skills import Skill, expand_skill_command, format_skill_list, load_skills
from mu.coding.templates import (
    Template,
    expand_template_command,
    format_template_list,
    load_templates,
)
from mu.coding.tools import create_coding_tools
from mu.plugin import CommandResult, NullPlugin, Plugin
from mu.jsonx import py_str
from mu.pyrt import runtime
from mu.text import is_blank, strip_text


def eprint(text: String) raises:
    """Write a diagnostic line to stderr so JSON stdout stays clean."""
    runtime().write_err(text + "\n")


def persist_new_messages(path: Path, run: AgentRun, persist: Bool) raises:
    if not persist:
        return
    var leaf = current_leaf(path)
    for message in run.new_messages:
        leaf = persist_tree_message(path, message, leaf)
    if leaf.byte_length() > 0:
        persist_leaf(path, leaf)


def ensure_session(
    path: Path,
    session_id: String,
    cwd: String,
    model: String,
    provider: String,
    mut created: Bool,
    persist: Bool,
    name: String = "",
) raises:
    if created or not persist:
        return
    write_session_header(path, session_id, cwd, model, provider, name)
    created = True


def maybe_compact(
    mut loop: AgentLoop,
    session: Path,
    auto_compact: Bool,
    threshold: Int,
    keep: Int,
    persist: Bool = True,
) raises:
    if not auto_compact:
        return
    var tokens = estimate_context_tokens(loop.system, loop.messages)
    if tokens < threshold:
        return
    var compacted = apply_compaction(loop.messages, keep)
    if compacted.dropped == 0:
        return
    if persist:
        persist_compaction(session, compacted.summary, keep, compacted.dropped)
    var next = List[Message]()
    for message in compacted.messages:
        next.append(message.copy())
    loop.replace_messages(next^)
    eprint(
        String(
            "compacted ",
            compacted.dropped,
            " older message(s); ~",
            estimate_context_tokens(loop.system, loop.messages),
            " tokens remain",
        )
    )


def run_once[
    C: Completer, S: EventSink, P: Plugin
](
    mut loop: AgentLoop,
    mut provider: C,
    runner: CodingRunner[P],
    prompt: String,
    session: Path,
    mode: String,
    mut sink: S,
    live: Bool,
    persist: Bool,
) raises -> Bool:
    var run = loop.prompt_live[C, CodingRunner[P], S](
        provider, runner, prompt, sink
    )
    persist_new_messages(session, run, persist)
    if live:
        # Stream already printed tokens. If the provider fell back to a
        # non-stream response, print the final assistant text once.
        if not sink.wrote():
            var text = last_assistant_text(run)
            if text.byte_length() > 0:
                print(text)
        return run.ok
    if mode == "json":
        print(render_json(run))
    else:
        print(render_text(run))
    return run.ok


def maybe_stdin_prompt(existing: String) raises -> String:
    """Merge piped stdin into the prompt, matching Tau's print-mode contract."""
    var rt = runtime()
    if Bool(py=rt.stdin_is_tty()):
        return existing
    var piped = strip_text(py_str(rt.read_stdin()))
    if piped.byte_length() == 0:
        return existing
    if is_blank(existing):
        return piped
    return existing + "\n\n" + piped


def main() raises:
    var args = parse_args()
    if args.help:
        print(usage())
        return
    if args.version:
        print(String("mu ", VERSION))
        return
    if args.error.byte_length() > 0:
        print("error:", args.error)
        print()
        print(usage())
        exit(2)
    if args.list_sessions:
        print(format_session_list(args.cwd))
        return

    var provider_cfg = resolve_provider(args)
    if not args.fake and is_blank(provider_cfg.api_key):
        print(
            "error: no API key. Set OPENAI_API_KEY or MU_API_KEY, "
            "pass --api-key, or use --fake."
        )
        exit(2)

    var work = args.cwd
    var tools = create_coding_tools()
    var skills = List[Skill]()
    if not args.no_skills:
        skills = load_skills(work)
    var templates = load_templates(work)
    var persist = not args.no_session
    var session_name = args.session_name

    var session_id = args.session
    var resumed = False
    var prior = List[Message]()
    if args.continue_last and session_id.byte_length() == 0:
        session_id = resolve_continue_session(load_settings().last_session, work)
        if session_id.byte_length() == 0:
            print("error: no previous session to continue")
            exit(2)
    if session_id.byte_length() > 0:
        var existing = session_path(session_id)
        if not existing.exists():
            print("error: session not found:", session_id)
            exit(2)
        prior = load_branch_messages(existing)
        resumed = True
    else:
        session_id = new_session_id()

    var session = session_path(session_id)
    var session_created = resumed
    if args.fork.byte_length() > 0:
        if not resumed:
            print("error: --fork requires --session")
            exit(2)
        try:
            prior = fork_to(session, args.fork)
        except e:
            print("error:", String(e))
            exit(2)
    var plugin = NullPlugin()
    var start_err = plugin.on_start(session_id, persist, False)
    if start_err.byte_length() > 0:
        print("error:", start_err)
        exit(2)
    var extra = plugin.extra_tools(session_id)
    for tool in extra:
        tools.append(tool.copy())
    var system = build_system_prompt(
        work, tools, args.system_prompt, plugin.extra_prompt(session_id), skills
    )
    var runner = CodingRunner(session_id, args.model, provider_cfg.name, plugin.copy())

    var loop = AgentLoop(
        system, args.model, work, tools^, args.max_turns, prior^
    )

    var prompt = maybe_stdin_prompt(args.prompt)
    if strip_text(prompt) == "/skills":
        print(format_skill_list(skills))
        return
    if strip_text(prompt) == "/prompts":
        print(format_template_list(templates))
        return
    if not is_blank(prompt):
        var pre = plugin.handle_command(prompt, session_id, persist)
        if pre.handled:
            if pre.error.byte_length() > 0:
                print("error:", pre.error)
                exit(2)
            if pre.printed.byte_length() > 0:
                print(pre.printed)
            if pre.consume:
                if not args.interactive:
                    return
                prompt = ""
            elif pre.rewrite.byte_length() > 0:
                prompt = pre.rewrite
        try:
            var expanded = expand_skill_command(prompt, skills)
            if expanded:
                prompt = expanded.value()
        except e:
            print("error:", String(e))
            exit(2)
        try:
            var expanded_t = expand_template_command(prompt, templates)
            if expanded_t:
                prompt = expanded_t.value()
        except e:
            print("error:", String(e))
            exit(2)
    var print_mode = args.print_mode
    if not args.interactive and not is_blank(prompt):
        print_mode = True

    var live = print_mode and args.mode == "text"

    if args.fake:
        var provider = EchoCompleter()
        var ok = drive(
            loop,
            provider,
            runner,
            session,
            session_id,
            prompt,
            args.mode,
            print_mode,
            args.interactive,
            resumed,
            live,
            args.auto_compact,
            args.compact_threshold,
            args.compact_keep,
            work,
            args.model,
            provider_cfg.name,
            session_created,
            skills,
            templates,
            persist,
            session_name,
        )
        if not ok:
            exit(1)
        return

    var provider = OpenAICompleter(provider_cfg, args.stream)
    var ok = drive(
        loop,
        provider,
        runner,
        session,
        session_id,
        prompt,
        args.mode,
        print_mode,
        args.interactive,
        resumed,
        live,
        args.auto_compact,
        args.compact_threshold,
        args.compact_keep,
        work,
        args.model,
        provider_cfg.name,
        session_created,
        skills,
        templates,
        persist,
        session_name,
    )
    if not ok:
        exit(1)


def drive[
    C: Completer, P: Plugin
](
    mut loop: AgentLoop,
    mut provider: C,
    mut runner: CodingRunner[P],
    mut session: Path,
    mut session_id: String,
    prompt: String,
    mode: String,
    print_mode: Bool,
    interactive: Bool,
    resumed: Bool,
    live: Bool,
    auto_compact: Bool,
    compact_threshold: Int,
    compact_keep: Int,
    cwd: String,
    model: String,
    provider_name: String,
    mut session_created: Bool,
    skills: List[Skill],
    templates: List[Template],
    persist: Bool,
    mut session_name: String,
) raises -> Bool:
    var ok = True
    if not is_blank(prompt):
        maybe_compact(
            loop, session, auto_compact, compact_threshold, compact_keep, persist
        )
        ensure_session(
            session,
            session_id,
            cwd,
            model,
            provider_name,
            session_created,
            persist,
            session_name,
        )
        if live:
            var sink = PrintSink()
            ok = run_once(
                loop, provider, runner, prompt, session, mode, sink, True, persist
            )
            sink.finish()
        else:
            var sink = NullSink()
            ok = run_once(
                loop, provider, runner, prompt, session, mode, sink, False, persist
            )
        if persist:
            remember_session(session_id)
        if not interactive:
            if persist:
                eprint(String("session: ", session_id))
            return ok
    repl(
        loop,
        provider,
        runner,
        session,
        session_id,
        mode,
        resumed,
        live,
        auto_compact,
        compact_threshold,
        compact_keep,
        cwd,
        model,
        provider_name,
        session_created,
        skills,
        templates,
        persist,
        session_name,
    )
    return ok


def repl[
    C: Completer, P: Plugin
](
    mut loop: AgentLoop,
    mut provider: C,
    mut runner: CodingRunner[P],
    mut session: Path,
    mut session_id: String,
    mode: String,
    resumed: Bool,
    live: Bool,
    auto_compact: Bool,
    compact_threshold: Int,
    compact_keep: Int,
    cwd: String,
    model: String,
    provider_name: String,
    mut session_created: Bool,
    skills: List[Skill],
    templates: List[Template],
    persist: Bool,
    mut session_name: String,
) raises:
    var status = "resumed" if resumed else "session"
    print(
        String(
            "mu ",
            VERSION,
            "  cwd=",
            loop.cwd,
            "  model=",
            loop.model,
            "  ",
            status,
            "=",
            session_id,
        )
    )
    print("Type a request and press Enter. /exit to quit. /help for commands.")
    print()
    while True:
        var line = input("μ ")
        var text = strip_text(line)
        if text.byte_length() == 0:
            continue
        if text == "/exit" or text == "/quit" or text == "/q":
            print(String("To resume: mu --session ", session_id))
            return
        if text == "/help":
            print(
                "Commands: /exit  /help  /tools  /session  /status  /compact "
                " /clear  /skills  /prompts  /skill:<name>  /name  /tree  /fork",
                runner.plugin.extra_help(),
            )
            continue
        if text == "/session":
            print(session_id)
            continue
        var plug = runner.plugin.handle_command(text, session_id, persist)
        if plug.handled:
            if plug.error.byte_length() > 0:
                print("error:", plug.error)
                continue
            if plug.printed.byte_length() > 0:
                print(plug.printed)
            if plug.consume:
                continue
            if plug.rewrite.byte_length() > 0:
                text = plug.rewrite
        if text == "/tree":
            if persist:
                print(format_tree(session))
            else:
                print("(ephemeral session)")
            continue
        if text.startswith("/fork "):
            var ident = strip_text(String(text[byte=6 : text.byte_length()]))
            if not persist:
                print("error: /fork needs a persisted session")
                continue
            try:
                var branched = fork_to(session, ident)
                var n = len(branched)
                loop.replace_messages(branched^)
                print(String("forked to ", ident, " (", n, " messages)"))
            except e:
                print("error:", String(e))
            continue
        if text == "/prompts":
            print(format_template_list(templates))
            continue
        if text.startswith("/name "):
            var named = strip_text(String(text[byte=6 : text.byte_length()]))
            session_name = named
            print(String("name: ", session_name))
            continue
        if text == "/status":
            print(
                String(
                    "messages=",
                    len(loop.messages),
                    "  ~tokens=",
                    estimate_context_tokens(loop.system, loop.messages),
                    "  threshold=",
                    compact_threshold,
                )
            )
            continue
        if text == "/compact" or text.startswith("/compact "):
            var compacted = apply_compaction(loop.messages, compact_keep)
            if compacted.dropped == 0:
                print("nothing to compact")
                continue
            ensure_session(
                session,
                session_id,
                cwd,
                model,
                provider_name,
                session_created,
                persist,
                session_name,
            )
            if persist:
                persist_compaction(
                    session, compacted.summary, compact_keep, compacted.dropped
                )
            var next = List[Message]()
            for message in compacted.messages:
                next.append(message.copy())
            loop.replace_messages(next^)
            print(
                String(
                    "compacted ",
                    compacted.dropped,
                    " older message(s); ~",
                    estimate_context_tokens(loop.system, loop.messages),
                    " tokens remain",
                )
            )
            continue
        if text == "/clear":
            loop.replace_messages(List[Message]())
            session_id = new_session_id()
            session = session_path(session_id)
            session_created = False
            print(String("new session ", session_id))
            continue
        if text == "/tools":
            for tool in loop.tools:
                print(String("- ", tool.name, ": ", tool.description))
            continue
        if text == "/skills":
            print(format_skill_list(skills))
            continue
        try:
            var expanded = expand_skill_command(text, skills)
            if expanded:
                text = expanded.value()
        except e:
            print("error:", String(e))
            continue
        try:
            var expanded_t = expand_template_command(text, templates)
            if expanded_t:
                text = expanded_t.value()
        except e:
            print("error:", String(e))
            continue
        maybe_compact(
            loop, session, auto_compact, compact_threshold, compact_keep, persist
        )
        ensure_session(
            session,
            session_id,
            cwd,
            model,
            provider_name,
            session_created,
            persist,
            session_name,
        )
        if live or mode == "text":
            var sink = PrintSink()
            _ = run_once(
                loop, provider, runner, text, session, mode, sink, True, persist
            )
            sink.finish()
        else:
            var sink = NullSink()
            _ = run_once(
                loop, provider, runner, text, session, mode, sink, False, persist
            )
        if persist:
            remember_session(session_id)
        print()
