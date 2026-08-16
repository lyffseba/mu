"""What a model provider must return: one assistant message."""

from mu.agent.messages import Message
from mu.agent.tools import Tool


@fieldwise_init
struct ProviderConfig(Copyable, ImplicitlyCopyable, Movable):
    """How to reach an OpenAI-compatible chat-completions endpoint."""

    var name: String
    var base_url: String
    var api_key: String
    var model: String
    var timeout_seconds: Int

    @staticmethod
    def openai(model: String, api_key: String) -> ProviderConfig:
        return ProviderConfig(
            "openai",
            "https://api.openai.com/v1",
            api_key,
            model,
            120,
        )

    @staticmethod
    def compatible(
        name: String, base_url: String, model: String, api_key: String
    ) -> ProviderConfig:
        return ProviderConfig(name, base_url, api_key, model, 120)


@fieldwise_init
struct Completion(Copyable, ImplicitlyCopyable, Movable):
    """One completed assistant turn from a provider."""

    var message: Message
    var raw_json: String
