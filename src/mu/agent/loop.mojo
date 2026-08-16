"""The small engine that turns messages + tools + a provider into a run.

For each turn the loop:

1. asks the provider for one assistant message
2. emits that message
3. executes any requested tools
4. appends the tool results
5. repeats until the assistant stops calling tools

The loop does not import CLI, rendering, or filesystem code. A frontend
supplies a `Completer`, a `ToolRunner`, and optionally an `EventSink`.
"""

from mu.agent.events import Event
from mu.agent.history import append_interrupted_results, provider_context
from mu.agent.messages import Message, ToolCall
from mu.agent.provider import Completion
from mu.agent.sink import EventSink, NullSink
from mu.agent.tools import Tool, ToolResult, find_tool


trait Completer:
    """Anything that can produce one assistant message.

    Implementations that can stream should call `sink.on_text` as tokens
    arrive. Non-streaming completers may emit the full text once, or not
    at all — the loop records the final message either way.
    """

    def complete[
        S: EventSink
    ](
        mut self,
        model: String,
        system: String,
        messages: List[Message],
        tools: List[Tool],
        mut sink: S,
    ) raises -> Completion:
        ...


trait ToolRunner:
    """Anything that can execute a named tool call."""

    def run(self, tool: Tool, call: ToolCall, cwd: String) raises -> ToolResult:
        ...


@fieldwise_init
struct AgentRun(Copyable, Movable):
    """Everything a frontend needs after one prompt."""

    var events: List[Event]
    var messages: List[Message]
    var new_messages: List[Message]
    var ok: Bool


struct AgentLoop:
    """Stateful reusable agent brain. UI-free on purpose."""

    var system: String
    var model: String
    var cwd: String
    var max_turns: Int
    var messages: List[Message]
    var tools: List[Tool]

    def __init__(
        out self,
        system: String,
        model: String,
        cwd: String,
        var tools: List[Tool],
        max_turns: Int = 16,
        var messages: List[Message] = List[Message](),
    ):
        self.system = system
        self.model = model
        self.cwd = cwd
        self.max_turns = max_turns
        self.messages = messages^
        self.tools = tools^

    def replace_messages(mut self, var messages: List[Message]):
        self.messages = messages^

    def replace_system(mut self, system: String):
        self.system = system

    def add_tool(mut self, tool: Tool):
        if not find_tool(self.tools, tool.name):
            self.tools.append(tool)

    def prompt[
        C: Completer, R: ToolRunner
    ](mut self, mut provider: C, runner: R, content: String) raises -> AgentRun:
        """Run one user prompt to completion with no live sink."""
        var sink = NullSink()
        return self.prompt_live[C, R, NullSink](provider, runner, content, sink)

    def prompt_live[
        C: Completer, R: ToolRunner, S: EventSink
    ](
        mut self,
        mut provider: C,
        runner: R,
        content: String,
        mut sink: S,
    ) raises -> AgentRun:
        """Run one user prompt, forwarding live events to `sink`."""
        return self.run[C, R, S](provider, runner, Message.user(content), sink)

    def run[
        C: Completer, R: ToolRunner, S: EventSink
    ](
        mut self,
        mut provider: C,
        runner: R,
        prompt: Message,
        mut sink: S,
    ) raises -> AgentRun:
        """Run until the model stops calling tools or `max_turns` is hit."""
        var events = List[Event]()
        var new_messages = List[Message]()

        events.append(Event.agent_start())
        events.append(Event.turn_start())

        # Repair dangling tool calls from a previous interrupted run so the
        # next provider request is well-formed. Synthetic results are visible
        # to the frontend and persist with the rest of the turn.
        var repaired = append_interrupted_results(self.messages)
        if len(repaired) > len(self.messages):
            for i in range(len(self.messages), len(repaired)):
                var extra = repaired[i].copy()
                self.messages.append(extra.copy())
                new_messages.append(extra.copy())
                events.append(Event.message(extra))

        self.messages.append(prompt.copy())
        new_messages.append(prompt.copy())
        events.append(Event.message(prompt))

        var turn = 1

        while True:
            if self.max_turns < 1 or turn > self.max_turns:
                var reason = String(
                    "Agent stopped after max_turns=", self.max_turns
                )
                if self.max_turns < 1:
                    reason = "max_turns must be at least 1"
                var stopped = Message.error(reason)
                self.messages.append(stopped.copy())
                new_messages.append(stopped.copy())
                events.append(Event.error(stopped.error_message))
                events.append(Event.message(stopped))
                events.append(Event.turn_end())
                events.append(Event.agent_end())
                sink.on_error(stopped.error_message)
                return AgentRun(
                    events^, self.messages.copy(), new_messages^, False
                )

            var context = provider_context(self.messages)
            var completion = provider.complete[S](
                self.model,
                self.system,
                context.messages.copy(),
                self.tools.copy(),
                sink,
            )
            var assistant = completion.message.copy()
            self.messages.append(assistant.copy())
            new_messages.append(assistant.copy())
            events.append(Event.message(assistant))

            if assistant.content.byte_length() > 0:
                events.append(Event.text_delta(assistant.content))

            if assistant.is_error():
                events.append(Event.error(assistant.error_message))
                events.append(Event.turn_end())
                events.append(Event.agent_end())
                sink.on_error(assistant.error_message)
                return AgentRun(
                    events^, self.messages.copy(), new_messages^, False
                )

            if not assistant.has_tool_calls():
                events.append(Event.turn_end())
                events.append(Event.agent_end())
                return AgentRun(
                    events^, self.messages.copy(), new_messages^, True
                )

            var calls = assistant.tool_calls()
            if len(calls) == 0:
                var reason = String(
                    "assistant requested tools but none parsed "
                    "(a malformed or truncated call, likely a length cutoff)"
                )
                var bad = Message.error(reason)
                self.messages.append(bad.copy())
                new_messages.append(bad.copy())
                events.append(Event.error(bad.error_message))
                events.append(Event.message(bad))
                events.append(Event.turn_end())
                events.append(Event.agent_end())
                sink.on_error(bad.error_message)
                return AgentRun(
                    events^, self.messages.copy(), new_messages^, False
                )
            for call in calls:
                events.append(
                    Event.tool_start(call.name, call.id, call.arguments)
                )
                sink.on_tool_start(call.name, call.id, call.arguments)
                var result = self._execute[R](runner, call)
                var tool_msg = Message.tool_result(
                    call.id, call.name, result.content, result.is_error
                )
                self.messages.append(tool_msg.copy())
                new_messages.append(tool_msg.copy())
                events.append(
                    Event.tool_end(
                        call.name, call.id, result.content, result.is_error
                    )
                )
                sink.on_tool_end(
                    call.name, call.id, result.content, result.is_error
                )
                events.append(Event.message(tool_msg))

            events.append(Event.turn_end())
            events.append(Event.turn_start())
            turn += 1

    def _execute[
        R: ToolRunner
    ](self, runner: R, call: ToolCall) raises -> ToolResult:
        var idx = find_tool(self.tools, call.name)
        if not idx:
            return ToolResult.error(String("Tool ", call.name, " not found"))
        return runner.run(self.tools[idx.value()], call, self.cwd)
