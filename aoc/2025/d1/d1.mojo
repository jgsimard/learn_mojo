from std.testing import assert_equal
from std.benchmark import run, Unit

from aoc.aoc_utils import input_paths, basic_bench


def day1[p: Int](file_path: String) raises -> Int:
    var pos = 50
    var n_zero = 0
    for line in open(file_path, "r").read().split("\n"):
        if len(line) == 0:
            continue

        var dir = -1 if line.as_bytes()[0] == UInt8(ord("L")) else 1
        var mag = atol(line[byte=1:])

        if p == 2:
            n_zero += mag // 100
            mag = mag % 100

            if (dir == -1 and mag > pos and pos != 0) or (
                dir == 1 and mag + pos > 100
            ):
                n_zero += 1

        pos = (pos + dir * mag) % 100
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
