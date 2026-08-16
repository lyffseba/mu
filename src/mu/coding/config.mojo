"""CLI flags and provider configuration."""

from std.os.env import getenv
from std.pathlib import Path, cwd
from std.sys import argv

from mu.agent.provider import ProviderConfig
from mu.coding.settings import load_settings
from mu.text import is_blank, is_session_id, normalize_cwd


@fieldwise_init
struct CliArgs(Copyable, ImplicitlyCopyable, Movable):
    """Parsed command-line arguments."""

    var prompt: String
    var print_mode: Bool
    var interactive: Bool
    var help: Bool
    var version: Bool
    var list_sessions: Bool
    var cwd: String
    var model: String
    var provider: String
    var base_url: String
    var api_key: String
    var mode: String
    var fake: Bool
    var max_turns: Int
    var system_prompt: String
    var session: String
    var stream: Bool
    var auto_compact: Bool
    var compact_threshold: Int
    var compact_keep: Int
    var continue_last: Bool
    var no_skills: Bool
    var no_session: Bool
    var session_name: String
    var fork: String
    var error: String

    @staticmethod
    def defaults() raises -> CliArgs:
        var work = String(cwd())
        var settings = load_settings()
        var model = getenv("MU_MODEL", "")
        if is_blank(model):
            if settings.model.byte_length() > 0:
                model = settings.model
            else:
                model = "gpt-4.1-mini"
        var provider = getenv("MU_PROVIDER", "")
        if is_blank(provider):
            if settings.provider.byte_length() > 0:
                provider = settings.provider
            else:
                provider = "openai"
        var base = getenv("MU_BASE_URL", "")
        if is_blank(base):
            if settings.base_url.byte_length() > 0:
                base = settings.base_url
            else:
                base = "https://api.openai.com/v1"
        var threshold = 24000
        if settings.compact_threshold > 0:
            threshold = settings.compact_threshold
        var keep = 6
        if settings.compact_keep > 0:
            keep = settings.compact_keep
        return CliArgs(
            "",
            False,
            False,
            False,
            False,
            False,
            work,
            model,
            provider,
            base,
            getenv("MU_API_KEY", getenv("OPENAI_API_KEY", "")),
            "text",
            False,
            16,
            "",
            "",
            settings.stream,
            True,
            threshold,
            keep,
            False,
            False,
            False,
            "",
            "",
            "",
        )


def take_value(
    mut args: CliArgs,
    raw: Span[StringSpan[ImmStaticOrigin], ImmStaticOrigin],
    mut i: Int,
    flag: String,
) raises -> String:
    i += 1
    if i >= len(raw):
        args.error = String(flag, " requires a value")
        return ""
    return String(raw[i])


def parse_args() raises -> CliArgs:
    """Parse `mu` flags. Unknown flags become part of the prompt after `--`."""
    var args = CliArgs.defaults()
    var raw = argv()
    var i = 1
    var prompt_parts = List[String]()
    var rest_is_prompt = False

    while i < len(raw):
        var arg = String(raw[i])
        if rest_is_prompt:
            prompt_parts.append(arg)
            i += 1
            continue
        if arg == "--":
            rest_is_prompt = True
            i += 1
            continue
        if arg == "-h" or arg == "--help":
            args.help = True
            i += 1
            continue
        if arg == "--version":
            args.version = True
            i += 1
            continue
        if arg == "--sessions":
            args.list_sessions = True
            i += 1
            continue
        if arg == "-c" or arg == "--continue":
            args.continue_last = True
            i += 1
            continue
        if arg == "--no-skills":
            args.no_skills = True
            i += 1
            continue
        if arg == "--no-session":
            args.no_session = True
            i += 1
            continue
        if arg == "-n" or arg == "--name":
            args.session_name = take_value(args, raw, i, "--name")
            i += 1
            continue
        if arg == "--fork":
            args.fork = take_value(args, raw, i, "--fork")
            i += 1
            continue
        if arg == "-p" or arg == "--print":
            args.print_mode = True
            i += 1
            continue
        if arg == "-i" or arg == "--interactive":
            args.interactive = True
            i += 1
            continue
        if arg == "--fake":
            args.fake = True
            i += 1
            continue
        if arg == "-m" or arg == "--model":
            args.model = take_value(args, raw, i, "--model")
            i += 1
            continue
        if arg == "--provider":
            args.provider = take_value(args, raw, i, "--provider")
            i += 1
            continue
        if arg == "--base-url":
            args.base_url = take_value(args, raw, i, "--base-url")
            i += 1
            continue
        if arg == "--api-key":
            args.api_key = take_value(args, raw, i, "--api-key")
            i += 1
            continue
        if arg == "--cwd":
            args.cwd = take_value(args, raw, i, "--cwd")
            i += 1
            continue
        if arg == "--mode":
            args.mode = take_value(args, raw, i, "--mode")
            args.print_mode = True
            i += 1
            continue
        if arg == "--max-turns":
            var value = take_value(args, raw, i, "--max-turns")
            if args.error.byte_length() == 0:
                try:
                    args.max_turns = atol(value)
                except e:
                    _ = e
                    args.error = String("invalid --max-turns: ", value)
            i += 1
            continue
        if arg == "--system-prompt":
            args.system_prompt = take_value(args, raw, i, "--system-prompt")
            i += 1
            continue
        if arg == "--session":
            args.session = take_value(args, raw, i, "--session")
            i += 1
            continue
        if arg == "--no-stream":
            args.stream = False
            i += 1
            continue
        if arg == "--no-auto-compact":
            args.auto_compact = False
            i += 1
            continue
        if arg == "--compact-threshold":
            var value = take_value(args, raw, i, "--compact-threshold")
            if args.error.byte_length() == 0:
                try:
                    args.compact_threshold = atol(value)
                except e:
                    _ = e
                    args.error = String("invalid --compact-threshold: ", value)
            i += 1
            continue
        if arg == "--compact-keep":
            var value = take_value(args, raw, i, "--compact-keep")
            if args.error.byte_length() == 0:
                try:
                    args.compact_keep = atol(value)
                except e:
                    _ = e
                    args.error = String("invalid --compact-keep: ", value)
            i += 1
            continue
        if arg.startswith("-"):
            args.error = String("Unknown flag: ", arg)
            return args
        prompt_parts.append(arg)
        i += 1

    if args.error.byte_length() > 0:
        return args

    if len(prompt_parts) > 0:
        var prompt = String()
        var first = True
        for part in prompt_parts:
            if not first:
                prompt += " "
            prompt += part
            first = False
        args.prompt = prompt

    if args.mode != "text" and args.mode != "json":
        args.error = String(
            "Unknown --mode: ", args.mode, " (use text or json)"
        )

    if args.session.byte_length() > 0 and not is_session_id(args.session):
        args.error = String("Invalid --session id: ", args.session)

    if args.cwd.byte_length() > 0:
        var work = Path(args.cwd).expanduser()
        if not work.exists():
            args.error = String("--cwd does not exist: ", args.cwd)
        elif not work.is_dir():
            args.error = String("--cwd is not a directory: ", args.cwd)
        else:
            args.cwd = normalize_cwd(String(work))

    if args.system_prompt.byte_length() > 0:
        var maybe = Path(args.system_prompt)
        if maybe.exists() and maybe.is_file():
            args.system_prompt = maybe.read_text()

    return args


def resolve_provider(args: CliArgs) -> ProviderConfig:
    """Build a provider config from CLI args and environment."""
    var name = args.provider
    var base = args.base_url
    if name == "openrouter":
        if base == "https://api.openai.com/v1":
            base = "https://openrouter.ai/api/v1"
        var key = args.api_key
        if key.byte_length() == 0:
            key = getenv("OPENROUTER_API_KEY", "")
        return ProviderConfig(name, base, key, args.model, 120)
    return ProviderConfig(name, base, args.api_key, args.model, 120)


def usage() -> String:
    return (
        'mu — a small Mojo coding-agent harness\n\nUsage:\n  mu -p "explain'
        ' this repo"\n  mu --fake -p "hello"\n  mu --session <id>\n  mu -c\n '
        " mu --sessions\n  mu\n\nOptions:\n  -p, --print            One-shot"
        " print mode\n  -i, --interactive      REPL even if a prompt is given\n"
        "  -m, --model NAME       Model id (default: $MU_MODEL or"
        " gpt-4.1-mini)\n      --provider NAME    openai | openrouter |"
        " compatible\n      --base-url URL     OpenAI-compatible base URL\n    "
        "  --api-key KEY      API key (or $MU_API_KEY / $OPENAI_API_KEY)\n     "
        " --cwd PATH         Working directory for tools\n      --mode"
        " text|json   Print-mode output format\n      --max-turns N      Stop"
        " after N model turns (default 16)\n      --system-prompt T  Replace"
        " the default system prompt (or a file path)\n      --session ID      "
        " Resume an existing JSONL session\n  -c, --continue         Resume the"
        " last session\n      --sessions         List recent sessions\n      --no-session       Do not persist this run\n  -n, --name NAME       Display name for a new session\n      --fork ID          Continue from a session tree entry\n      --no-skills        Disable skill discovery\n     "
        " --no-stream        Disable token streaming\n      --no-auto-compact "
        " Never compact long sessions\n      --compact-threshold N  Approximate"
        " tokens before auto-compact (default 24000)\n      --compact-keep N  "
        " Messages to keep after compact (default 6)\n      --fake            "
        " Use the built-in echo provider (no network)\n      --version         "
        " Print version\n  -h, --help             Show this help\n"
    )
