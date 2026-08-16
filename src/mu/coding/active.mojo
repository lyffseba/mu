"""The plugin this build ships. Master: NullPlugin. Hermes overwrites this file."""

from mu.plugin import NullPlugin


comptime ActivePlugin = NullPlugin


def create_plugin() -> ActivePlugin:
    return NullPlugin()
