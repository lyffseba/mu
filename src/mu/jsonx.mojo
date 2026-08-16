"""Thin JSON helpers. Parsing lives in Python; this is the Mojo face."""

from std.python import Python, PythonObject

from mu.pyrt import runtime, rt_dumps, rt_loads


def json_module() raises -> PythonObject:
    return Python.import_module("json")


def json_loads(text: String) raises -> PythonObject:
    """Parse a JSON document into a Python object."""
    return rt_loads(text)


def json_dumps(value: PythonObject) raises -> String:
    """Serialize a Python object to compact JSON."""
    return rt_dumps(value)


def json_pretty(value: PythonObject) raises -> String:
    """Serialize a Python object to indented JSON."""
    return String(py=runtime().dumps_pretty(value))


def py_str(value: PythonObject) raises -> String:
    """Convert any Python value to a Mojo string via `str()`."""
    return String(py=Python.str(value))


def py_is_none(value: PythonObject) -> Bool:
    return value is Python.none()


def py_is_str(value: PythonObject) raises -> Bool:
    var builtins = Python.import_module("builtins")
    return Python.type(value) is builtins.str


def json_as_text(value: PythonObject) raises -> String:
    """Return a JSON object/array as compact JSON, or a string as-is."""
    if py_is_none(value):
        return ""
    if py_is_str(value):
        return py_str(value)
    return json_dumps(value)


def json_get_str(
    obj: PythonObject, key: String, default: String = ""
) raises -> String:
    """Read a JSON object field as a string."""
    var value = obj.get(key)
    if py_is_none(value):
        return default
    return py_str(value)


def json_has(obj: PythonObject, key: String) raises -> Bool:
    var value = obj.get(key)
    return not py_is_none(value)


def json_get_int(
    obj: PythonObject, key: String, default: Int = 0
) raises -> Int:
    var value = obj.get(key)
    if py_is_none(value):
        return default
    try:
        return Int(py=value)
    except e:
        _ = e
        return default


def json_get_optional_int(
    obj: PythonObject, key: String
) raises -> Optional[Int]:
    var value = obj.get(key)
    if py_is_none(value):
        return None
    try:
        return Optional(Int(py=value))
    except e:
        _ = e
        return None


def empty_object() raises -> PythonObject:
    return Python.dict()


def empty_array() raises -> PythonObject:
    return Python.list()
