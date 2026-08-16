"""The plugin this build ships. Hermes overwrites master's NullPlugin."""

from mu.hermes.plugin import HermesPlugin


comptime ActivePlugin = HermesPlugin


def create_plugin() -> ActivePlugin:
    return HermesPlugin()
