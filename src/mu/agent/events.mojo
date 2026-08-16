"""Provider-neutral events. Frontends render these; the loop never prints."""

from mu.agent.messages import Message


@fieldwise_init
struct Event(Copyable, ImplicitlyCopyable, Movable):
    """One observable step of an agent run.

    `kind` is one of:
      agent_start, agent_end, turn_start, turn_end,
      message, tool_start, tool_end, text, error
    """

    var kind: String
    var text: String
    var tool_name: String
    var tool_call_id: String
    var is_error: Bool

    @staticmethod
    def agent_start() -> Event:
        return Event("agent_start", "", "", "", False)

    @staticmethod
    def agent_end() -> Event:
        return Event("agent_end", "", "", "", False)

    @staticmethod
    def turn_start() -> Event:
        return Event("turn_start", "", "", "", False)

    @staticmethod
    def turn_end() -> Event:
        return Event("turn_end", "", "", "", False)

    @staticmethod
    def message(message: Message) -> Event:
        return Event(
            "message",
            message.visible_text(),
            message.role,
            "",
            message.is_error(),
        )

    @staticmethod
    def text_delta(text: String) -> Event:
        return Event("text", text, "", "", False)

    @staticmethod
    def tool_start(name: String, tool_call_id: String, args: String) -> Event:
        return Event("tool_start", args, name, tool_call_id, False)

    @staticmethod
    def tool_end(
        name: String, tool_call_id: String, result: String, is_error: Bool
    ) -> Event:
        return Event("tool_end", result, name, tool_call_id, is_error)

    @staticmethod
    def error(text: String) -> Event:
        return Event("error", text, "", "", True)
