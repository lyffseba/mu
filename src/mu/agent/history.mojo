"""Provider-safe repair of malformed tool-call history.

Providers reject an assistant tool call that has no matching tool result.
Resume, crashes, and hand-edited JSONL can leave that behind. Repair is
deterministic and never rewrites the durable log — it only shapes the
context sent to the model.
"""

from mu.agent.messages import Message


comptime INTERRUPTED = "Tool call interrupted by user"


@fieldwise_init
struct HistoryRepair(Copyable, Movable):
    """A provider-safe transcript plus counters."""

    var messages: List[Message]
    var synthesized: Int
    var dropped_orphans: Int
    var dropped_empty_errors: Int

    def changed(self) -> Bool:
        return (
            self.synthesized > 0
            or self.dropped_orphans > 0
            or self.dropped_empty_errors > 0
        )


def provider_context(messages: List[Message]) raises -> HistoryRepair:
    """Return replayable messages: drop empty failures, pair every tool call.

    Matches Tau's `_provider_context` + `repair_tool_history` enough for
    the cases that actually break a next request.
    """
    var filtered = List[Message]()
    var dropped_empty = 0
    for message in messages:
        if (
            message.role == "assistant"
            and message.is_error()
            and message.content.byte_length() == 0
            and not message.has_tool_calls()
        ):
            dropped_empty += 1
            continue
        filtered.append(message.copy())

    var result_ids = List[String]()
    for message in filtered:
        if message.role == "tool" and message.tool_call_id.byte_length() > 0:
            result_ids.append(message.tool_call_id)

    var repaired = List[Message]()
    var used = List[String]()
    var synthesized = 0
    var dropped_orphans = 0

    for message in filtered:
        if message.role == "tool":
            continue
        repaired.append(message.copy())
        if message.role != "assistant" or not message.has_tool_calls():
            continue
        var calls = message.tool_calls()
        for call in calls:
            var existing = _take_result(filtered, used, call.id)
            if existing:
                repaired.append(existing.value())
            else:
                synthesized += 1
                repaired.append(
                    Message.tool_result(call.id, call.name, INTERRUPTED, True)
                )
                used.append(call.id)

    for message in filtered:
        if message.role != "tool":
            continue
        if not _contains(used, message.tool_call_id):
            dropped_orphans += 1

    return HistoryRepair(repaired^, synthesized, dropped_orphans, dropped_empty)


def append_interrupted_results(messages: List[Message]) raises -> List[Message]:
    """Append synthetic tool results for any dangling calls in `messages`."""
    var out = List[Message]()
    for message in messages:
        out.append(message.copy())
    var returned = List[String]()
    for message in messages:
        if message.role == "tool":
            returned.append(message.tool_call_id)
    for message in messages:
        if message.role != "assistant" or not message.has_tool_calls():
            continue
        var calls = message.tool_calls()
        for call in calls:
            if _contains(returned, call.id):
                continue
            returned.append(call.id)
            out.append(
                Message.tool_result(call.id, call.name, INTERRUPTED, True)
            )
    return out^


def _take_result(
    messages: List[Message], mut used: List[String], call_id: String
) -> Optional[Message]:
    for message in messages:
        if message.role != "tool":
            continue
        if message.tool_call_id != call_id:
            continue
        if _contains(used, call_id):
            continue
        used.append(call_id)
        return Optional(message.copy())
    return None


def _contains(ids: List[String], needle: String) -> Bool:
    for item in ids:
        if item == needle:
            return True
    return False
