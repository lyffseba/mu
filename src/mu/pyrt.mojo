"""Cached import of `mu_runtime`.

Every JSON, HTTP, SSE, and bash call goes through this module so the
Python helper is imported once per process. Search paths cover `mojo run`
from the repo, a compiled binary next to `mu_runtime.py`, and `~/.mu`.
"""

from std.os.env import getenv
from std.pathlib import Path, cwd
from std.python import Python, PythonObject
from std.sys import argv


def runtime() raises -> PythonObject:
    """Return the cached `mu_runtime` module."""
    try:
        return Python.import_module("mu_runtime")
    except e:
        _ = e
    var roots = List[String]()
    roots.append("src")
    roots.append(String(cwd() / "src"))
    roots.append(String(cwd()))
    if len(argv()) > 0:
        var exe = Path(String(argv()[0])).expanduser()
        var parent = parent_of(exe)
        roots.append(String(parent))
        roots.append(String(parent / "src"))
    var home = getenv("MU_HOME", "")
    if home.byte_length() > 0:
        roots.append(home)
        roots.append(String(Path(home) / "src"))
    roots.append(String(Path.home() / ".mu"))
    for root in roots:
        try:
            Python.add_to_path(root)
            return Python.import_module("mu_runtime")
        except err:
            _ = err
    raise Error(
        "could not import mu_runtime (expected src/mu_runtime.py next to mu)"
    )


def parent_of(path: Path) -> Path:
    var name = path.name()
    var full = String(path)
    if name.byte_length() == 0 or full == name:
        return Path(".")
    var cut = full.byte_length() - name.byte_length()
    if cut > 0 and String(full[byte = cut - 1 : cut]) == "/":
        cut -= 1
    if cut <= 0:
        return Path("/")
    var parent = String(full[byte=0:cut])
    if parent.byte_length() == 0:
        return Path("/")
    return Path(parent)


def rt_dumps(value: PythonObject) raises -> String:
    return String(py=runtime().dumps(value))


def rt_loads(text: String) raises -> PythonObject:
    return runtime().loads(text)
