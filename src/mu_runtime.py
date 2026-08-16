"""Python helpers used by Mu.

Imported once per process. Keeping HTTP, JSON, SSE, and subprocess here
avoids `Python.evaluate` on every tool call and provider turn.
"""

from __future__ import annotations

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from typing import Any, Callable, Iterator, TypeVar


def dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False)


def dumps_pretty(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False)


def loads(text: str) -> Any:
    return json.loads(text)


def read_stdin() -> str:
    return sys.stdin.read()


def stdin_is_tty() -> bool:
    try:
        return sys.stdin.isatty()
    except Exception:
        return True


def write_out(text: str) -> None:
    sys.stdout.write(text)
    sys.stdout.flush()


def write_err(text: str) -> None:
    sys.stderr.write(text)
    sys.stderr.flush()


def now_stamp() -> str:
    now = datetime.now()
    return now.strftime("%Y%m%d-%H%M%S") + "-" + now.strftime("%f")


RETRYABLE_HTTP = {429, 500, 502, 503, 504}
T = TypeVar("T")


def retryable_status(code: int) -> bool:
    return code in RETRYABLE_HTTP


def retryable_message(message: str) -> bool:
    for code in RETRYABLE_HTTP:
        if f"HTTP {code}" in message:
            return True
    return message.startswith("request failed:")


def _retry(fn: Callable[[], T], retries: int = 3) -> T:
    delay = 0.4
    last: Exception | None = None
    for attempt in range(retries):
        try:
            return fn()
        except urllib.error.HTTPError as e:
            last = e
            if e.code not in RETRYABLE_HTTP or attempt == retries - 1:
                detail = e.read().decode("utf-8", errors="replace")
                raise RuntimeError("HTTP " + str(e.code) + ": " + detail) from e
        except urllib.error.URLError as e:
            last = e
            if attempt == retries - 1:
                raise RuntimeError("request failed: " + str(e.reason)) from e
        time.sleep(delay)
        delay *= 2
    raise RuntimeError("request failed: " + str(last))


def http_post(url: str, body: str, api_key: str, timeout: int) -> str:
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + api_key,
    }
    req = urllib.request.Request(
        url, data=body.encode("utf-8"), headers=headers, method="POST"
    )

    def once() -> str:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode("utf-8")

    return _retry(once)


def iter_sse(url: str, body: str, api_key: str, timeout: int) -> Iterator[str]:
    """Yield `data:` payloads from a chat-completions SSE stream."""
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + api_key,
        "Accept": "text/event-stream",
    }
    req = urllib.request.Request(
        url, data=body.encode("utf-8"), headers=headers, method="POST"
    )
    resp = _retry(lambda: urllib.request.urlopen(req, timeout=timeout))

    with resp:
        while True:
            raw = resp.readline()
            if not raw:
                break
            line = raw.decode("utf-8", errors="replace").strip()
            if not line:
                continue
            if not line.startswith("data:"):
                # Some providers send a JSON error as the whole body.
                if line.startswith("{"):
                    yield line
                continue
            data = line[5:].strip()
            if data == "[DONE]":
                break
            if data:
                yield data


def gen_next(gen: Iterator[str]) -> str | None:
    try:
        return next(gen)
    except StopIteration:
        return None


class StreamAcc:
    """Accumulate OpenAI-style chat-completion SSE chunks."""

    def __init__(self) -> None:
        self.content = ""
        self.tool_calls: dict[int, dict[str, str]] = {}
        self.finish = "stop"
        self.error = ""
        self.saw_choice = False

    def apply(self, chunk: str) -> str:
        """Apply one SSE payload. Returns any new text delta."""
        try:
            data = json.loads(chunk)
        except json.JSONDecodeError:
            return ""

        if isinstance(data, dict) and data.get("error"):
            err = data["error"]
            if isinstance(err, dict):
                self.error = str(err.get("message") or err)
            else:
                self.error = str(err)
            return ""

        choices = data.get("choices") if isinstance(data, dict) else None
        if not choices:
            return ""
        self.saw_choice = True
        choice = choices[0]
        finish = choice.get("finish_reason")
        if finish:
            self.finish = str(finish)

        delta = choice.get("delta") or choice.get("message") or {}
        text = delta.get("content") or ""
        if text:
            self.content += text

        for item in delta.get("tool_calls") or []:
            idx = int(item.get("index") or 0)
            slot = self.tool_calls.setdefault(
                idx, {"id": "", "name": "", "arguments": ""}
            )
            if item.get("id"):
                slot["id"] = str(item["id"])
            function = item.get("function") or {}
            if function.get("name"):
                slot["name"] = str(function["name"])
            if function.get("arguments"):
                slot["arguments"] += str(function["arguments"])

        return text if isinstance(text, str) else ""

    def message(self) -> dict[str, Any]:
        calls = []
        for idx in sorted(self.tool_calls):
            slot = self.tool_calls[idx]
            calls.append(
                {
                    "id": slot["id"] or f"call_{idx}",
                    "name": slot["name"],
                    "arguments": slot["arguments"] or "{}",
                }
            )
        return {
            "content": self.content,
            "tool_calls": calls,
            "finish": self.finish,
            "error": self.error,
            "had_data": bool(self.saw_choice or self.error),
        }


def new_stream_acc() -> StreamAcc:
    return StreamAcc()


def run_shell(
    command: str,
    cwd: str,
    timeout: float | None,
    extra_env: dict[str, str] | None = None,
) -> dict[str, Any]:
    import os

    env = os.environ.copy()
    env["AI_AGENT"] = "mu"
    env["MU_CODING_AGENT"] = "true"
    if extra_env:
        env.update(extra_env)
    kwargs: dict[str, Any] = dict(
        args=command,
        shell=True,
        cwd=cwd,
        capture_output=True,
        text=True,
        env=env,
    )
    if timeout and timeout > 0:
        kwargs["timeout"] = timeout
    try:
        completed = subprocess.run(**kwargs)
        stdout = completed.stdout or ""
        stderr = completed.stderr or ""
        combined = stdout
        if stderr:
            combined = (combined + "\n" if combined else "") + stderr
        return {
            "ok": True,
            "code": completed.returncode,
            "output": combined,
            "timeout": False,
        }
    except subprocess.TimeoutExpired as e:
        stdout = e.stdout or ""
        stderr = e.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode("utf-8", errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
        combined = stdout
        if stderr:
            combined = (combined + "\n" if combined else "") + stderr
        return {
            "ok": False,
            "code": None,
            "output": combined,
            "timeout": True,
        }


def preview_session(path: str, limit: int = 60) -> str:
    """Return the first user prompt from a JSONL session without loading it all."""
    try:
        with open(path, "r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if obj.get("type") == "message" and obj.get("role") == "user":
                    text = str(obj.get("content") or "")
                    if len(text) > limit:
                        return text[: limit - 3] + "..."
                    return text
    except OSError:
        return ""
    return ""
