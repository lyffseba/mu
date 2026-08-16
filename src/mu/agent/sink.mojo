"""Optional live event sink. The loop never prints; a sink may."""


trait EventSink:
    """Called as the loop produces events. Implementations must be cheap."""

    def on_text(mut self, text: String) raises:
        ...

    def on_tool_start(
        mut self, name: String, tool_call_id: String, args: String
    ) raises:
        ...

    def on_tool_end(
        mut self,
        name: String,
        tool_call_id: String,
        result: String,
        is_error: Bool,
    ) raises:
        ...

    def on_error(mut self, text: String) raises:
        ...

    def wrote(self) -> Bool:
        ...


struct NullSink(EventSink):
    """Discard every event. Used by tests and batch mode."""

    var _unused: Int

    def __init__(out self):
        self._unused = 0

    def on_text(mut self, text: String) raises:
        _ = text

    def on_tool_start(
        mut self, name: String, tool_call_id: String, args: String
    ) raises:
        _ = name
        _ = tool_call_id
        _ = args

    def on_tool_end(
        mut self,
        name: String,
        tool_call_id: String,
        result: String,
        is_error: Bool,
    ) raises:
        _ = name
        _ = tool_call_id
        _ = result
        _ = is_error

    def on_error(mut self, text: String) raises:
        _ = text

    def wrote(self) -> Bool:
        return False


struct PrintSink(EventSink):
    """Stream tokens and tool markers to stdout as they arrive."""

    var wrote_text: Bool

    def __init__(out self):
        self.wrote_text = False

    def on_text(mut self, text: String) raises:
        if text.byte_length() == 0:
            return
        print(text, end="")
        self.wrote_text = True

    def on_tool_start(
        mut self, name: String, tool_call_id: String, args: String
    ) raises:
        _ = tool_call_id
        if self.wrote_text:
            print()
            self.wrote_text = False
        print(String("→ ", name, "(", args, ")"))

    def on_tool_end(
        mut self,
        name: String,
        tool_call_id: String,
        result: String,
        is_error: Bool,
    ) raises:
        _ = tool_call_id
        var mark = "✗" if is_error else "✓"
        print(String(mark, " ", name))
        if result.byte_length() > 0:
            var preview = result
            var cut = preview.find("\n")
            if cut >= 0:
                var first = String(preview[byte=0:cut])
                preview = first
            if preview.byte_length() > 120:
                var clipped = String(preview[byte=0:117]) + "..."
                preview = clipped
            print(preview)

    def on_error(mut self, text: String) raises:
        if self.wrote_text:
            print()
            self.wrote_text = False
        print(String("error: ", text))

    def wrote(self) -> Bool:
        return self.wrote_text

    def finish(mut self) raises:
        if self.wrote_text:
            print()
            self.wrote_text = False
