from std.testing import assert_equal
from std.benchmark import run, Unit

from aoc.aoc_utils import input_paths, basic_bench


def day1[p: Int](file_path: String) raises -> Int:
    var pos = 50
    var n_zero = 0
    with open(file_path, "r") as f:
        var content = f.read()
        var bytes = content.as_bytes()
        var i = 0
        while i < len(bytes):
            var right = bytes[i] == UInt8(ord("R"))
            i += 1
            var mag = 0
            while i < len(bytes) and bytes[i] != UInt8(ord("\n")):
                mag = 10 * mag + Int(bytes[i]) - Int(ord("0"))
                i += 1
            i += 1

            comptime if p == 2:
                n_zero += mag // 100
                mag %= 100
                if (right and mag + pos > 100) or (
                    not right and mag > pos and pos != 0
                ):
                    n_zero += 1

            pos = (pos + mag if right else pos - mag) % 100
            if pos == 0:
                n_zero += 1

    return n_zero


def main() raises:
    comptime test_file_path, file_path = input_paths[2025, 1]()

    print("AoC 2025 - Day 1")

    assert_equal(day1[1](test_file_path), 3)
    print("part 1: ", day1[1](file_path))

    assert_equal(day1[2](test_file_path), 6)
    print("part 2: ", day1[2](file_path))

    basic_bench[day1, 1, file_path]()
    basic_bench[day1, 2, file_path]()
