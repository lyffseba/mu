"""Approximate context size and local compaction.

Token counts are character-based on purpose: a stable application-layer
estimate, not a provider tokenizer. Compaction never rewrites the
durable JSONL — it only rebuilds the in-memory transcript.
"""

from mu.agent.messages import Message
from mu.text import join_lines


comptime CHARS_PER_TOKEN = 4
comptime DEFAULT_KEEP = 6


@fieldwise_init
struct CompactResult(Copyable, Movable):
    """Result of a local compaction pass."""

    var messages: List[Message]
    var summary: Message
    var dropped: Int


def estimate_text_tokens(text: String) -> Int:
    """Rough token count: ceil(bytes / 4)."""
    var n = text.byte_length()
    if n == 0:
        return 0
    return (n + CHARS_PER_TOKEN - 1) // CHARS_PER_TOKEN


def estimate_message_tokens(message: Message) -> Int:
    var n = estimate_text_tokens(message.content)
    n += estimate_text_tokens(message.tool_calls_json)
    n += estimate_text_tokens(message.tool_name)
    n += 4
    return n


def estimate_context_tokens(system: String, messages: List[Message]) -> Int:
    """Estimate tokens for the next provider request."""
    var n = estimate_text_tokens(system)
    for message in messages:
        n += estimate_message_tokens(message)
    return n


def compaction_cut(messages: List[Message], keep: Int) raises -> Int:
    """How many leading messages can be dropped without splitting a tool pair.

    A cut never lands on a `tool` result. Walking backward includes the
    assistant that issued those calls so the kept tail stays well-formed.
    """
    var total = len(messages)
    if total == 0:
        return 0
    var retain = keep
    if retain < 1:
        retain = 1
    if retain > total:
        return 0
    var cut = total - retain
    if cut < 1:
        return 0
    while cut > 0 and messages[cut].role == "tool":
        cut -= 1
    return cut


def apply_compaction(
    messages: List[Message], keep: Int = DEFAULT_KEEP
) raises -> CompactResult:
    """Replace older turns with one summary. Keep the last `keep` messages."""
    var drop = compaction_cut(messages, keep)
    if drop < 1:
        var kept_all = List[Message]()
        for message in messages:
            kept_all.append(message.copy())
        return CompactResult(kept_all^, Message.user(""), 0)

    var lines = List[String]()
    lines.append("Previous conversation summary:")
    var i = 0
    while i < drop:
        var message = messages[i]
        var role = message.role
        var note = message.visible_text()
        if note.byte_length() > 160:
            var clipped = String(note[byte=0:157]) + "..."
            note = clipped
        if message.role == "assistant" and message.has_tool_calls():
            var names = String()
            var calls = message.tool_calls()
            var first = True
            for call in calls:
                if not first:
                    names += ", "
                names += call.name
                first = False
            if note.byte_length() == 0:
                note = String("called ", names)
            else:
                note = String(note, " [tools: ", names, "]")
        if note.byte_length() == 0:
            note = "(empty)"
        lines.append(String("- ", role, ": ", note))
        i += 1

    var summary = Message.user(join_lines(lines))
    var out = List[Message]()
    out.append(summary.copy())
    var j = drop
    var total = len(messages)
    while j < total:
        out.append(messages[j].copy())
        j += 1
    return CompactResult(out^, summary, drop)


def replay_compaction(
    messages: List[Message], dropped: Int, summary: String
) -> List[Message]:
    """Apply a persisted compaction record to a reconstructed transcript.

    Uses the stored summary and drop count. Does not re-summarize, so
    resume matches what the original run persisted.
    """
    var out = List[Message]()
    if summary.byte_length() > 0:
        out.append(Message.user(summary))
    var start = dropped
    if start < 0:
        start = 0
    if start > len(messages):
        start = len(messages)
    var i = start
    while i < len(messages):
        out.append(messages[i].copy())
        i += 1
    return out^
