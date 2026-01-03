from testing import assert_equal
from benchmark import run, Unit
from aoc.aoc_utils import input_paths, basic_bench


fn day1[p: Int](file_path: String) raises -> Int:
    if p == 1:
        var pos = 50
        var n_zero = 0
        with open(file_path, "r") as f:
            for line in f.read().split("\n"):
                if len(line) == 0:
                    continue
                var dir_letter = line.as_bytes()[0]
                var mag = atol(line[1:])
                var dir = -1 if dir_letter == ord("L") else 1
                pos = (pos + dir * mag) % 100
                if pos == 0:
                    n_zero += 1
        return n_zero

    else:
        var pos = 50
        var n_zero = 0
        with open(file_path, "r") as f:
            for line in f.read().split("\n"):
                if len(line) == 0:
                    continue
                var dir_letter = line.as_bytes()[0]
                var mag = atol(line[1:])
                var dir = -1 if dir_letter == ord("L") else 1
                n_zero_free = mag // 100
                n_zero += n_zero_free

                mag -= 100 * n_zero_free

                if (dir == -1 and mag > pos and pos != 0) or (
                    dir == 1 and mag + pos > 100
                ):
                    n_zero += 1

                pos = (pos + dir * mag) % 100
                if pos == 0:
                    n_zero += 1
        return n_zero


fn main() raises:
    comptime test_file_path, file_path = input_paths[1]()

    print("AoC 2025 - Day 1")

    assert_equal(day1[1](test_file_path), 3)
    print("part 1: ", day1[1](file_path))

    assert_equal(day1[2](test_file_path), 6)
    print("part 2: ", day1[2](file_path))

    basic_bench[day1, 1, file_path]()
    basic_bench[day1, 2, file_path]()
