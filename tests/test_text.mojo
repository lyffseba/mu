from std.testing import assert_equal, assert_true, TestSuite

from mu.text import (
    count_occurrences,
    detect_line_ending,
    first_whitespace,
    is_blank,
    is_session_id,
    join_lines,
    normalize_cwd,
    normalize_lf,
    ranges_overlap,
    replace_at,
    replace_first,
    restore_line_endings,
    split_lines,
    strip_text,
)


def test_count_occurrences() raises:
    assert_equal(count_occurrences("aaa", "a"), 3)
    assert_equal(count_occurrences("ababab", "ab"), 3)
    assert_equal(count_occurrences("hello", "x"), 0)
    assert_equal(count_occurrences("hello", ""), 0)


def test_replace_first() raises:
    assert_equal(replace_first("one two one", "one", "ONE"), "ONE two one")
    assert_equal(replace_first("abc", "z", "Z"), "abc")


def test_replace_at() raises:
    assert_equal(replace_at("abcdef", 2, 2, "XY"), "abXYef")


def test_split_and_join() raises:
    var lines = split_lines("a\nb\nc")
    assert_equal(len(lines), 3)
    assert_equal(lines[1], "b")
    assert_equal(join_lines(lines), "a\nb\nc")


def test_line_endings() raises:
    assert_equal(normalize_lf("a\r\nb\r\n"), "a\nb\n")
    assert_equal(detect_line_ending("a\r\nb"), "\r\n")
    assert_equal(detect_line_ending("a\nb"), "\n")
    assert_equal(restore_line_endings("a\nb\n", "\r\n"), "a\r\nb\r\n")


def test_overlap() raises:
    assert_true(ranges_overlap(0, 3, 2, 5))
    assert_true(not ranges_overlap(0, 3, 3, 6))


def test_session_id() raises:
    assert_true(is_session_id("abc-1"))
    assert_true(not is_session_id("../x"))


def test_normalize_cwd() raises:
    assert_equal(normalize_cwd("/tmp/foo/"), "/tmp/foo")
    assert_equal(normalize_cwd("/tmp/foo//"), "/tmp/foo")
    assert_equal(normalize_cwd("/"), "/")
    assert_equal(normalize_cwd(""), "")


def test_first_whitespace() raises:
    assert_equal(first_whitespace("a b"), 1)
    assert_equal(first_whitespace("ab\tc"), 2)
    assert_equal(first_whitespace("ab"), -1)


def test_blank() raises:
    assert_true(is_blank("   \t"))
    assert_true(not is_blank("x"))
    assert_equal(strip_text("  hi  "), "hi")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
