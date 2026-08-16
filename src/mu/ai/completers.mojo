"""Completer implementations used by the CLI."""

from mu.agent.loop import Completer
from mu.agent.messages import Message
from mu.agent.provider import Completion, ProviderConfig
from mu.agent.sink import EventSink
from mu.agent.tools import Tool
from mu.ai.fake import FakeProvider, ScriptedTurn, complete_echo
from mu.ai.openai import complete_openai


@fieldwise_init
struct EchoCompleter(Completer):
    """Reply with the last user text. No network."""

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
        var done = complete_echo(model, system, messages, tools)
        if done.message.content.byte_length() > 0:
            sink.on_text(done.message.content)
        return done


struct OpenAICompleter(Completer):
    """Live OpenAI-compatible chat-completions provider."""

    var config: ProviderConfig
    var stream: Bool

    def __init__(out self, var config: ProviderConfig, stream: Bool = True):
        self.config = config^
        self.stream = stream

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
        _ = model
        return complete_openai[S](
            self.config, system, messages, tools, sink, self.stream
        )


struct ScriptCompleter(Completer):
    """Replay canned turns. Used by tests and `mu --fake`."""

    var inner: FakeProvider

    def __init__(
        out self, var turns: List[ScriptedTurn] = List[ScriptedTurn]()
    ):
        self.inner = FakeProvider(turns^)

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
        var done = self.inner.complete(model, system, messages, tools)
        if done.message.content.byte_length() > 0:
            sink.on_text(done.message.content)
        return done
