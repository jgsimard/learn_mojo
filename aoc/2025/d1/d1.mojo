from testing import assert_equal
from benchmark import run, Unit
from aoc.aoc_utils import input_paths

fn part_1(file_path: String) raises -> Int:
    var pos = 50
    var n_zero = 0
    with open(file_path, "r") as f:
        var lines = f.read().split("\n")
        for line in lines:
            if len(line) == 0:
                continue
            var dir_letter = line[0]
            var mag = atol(line[1:])
            var dir: Int
            if dir_letter == "L":
                dir = -1
            elif dir_letter == "R":
                dir = 1
            else:
                raise Error("bad dir" + dir_letter)

            pos = (pos + dir * mag) % 100
            if pos == 0:
                n_zero += 1
    return n_zero


fn part_2(file_path: String) raises -> Int:
    var pos = 50
    var n_zero = 0
    with open(file_path, "r") as f:
        var lines = f.read().split("\n")
        for line in lines:
            if len(line) == 0:
                continue
            var dir_letter = line[0]
            var mag = atol(line[1:])
            var dir: Int
            if dir_letter == "L":
                dir = -1
            elif dir_letter == "R":
                dir = 1
            else:
                raise Error("bad dir" + dir_letter)
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

    assert_equal(part_1(test_file_path), 3)
    print("part 1: ", part_1(file_path))

    assert_equal(part_2(test_file_path), 6)
    print("part 2: ", part_2(file_path))

    @parameter
    fn bench[part: Int]() raises:
        fn bench_fn() raises:
            @parameter
            if part == 1:
                _ = part_1(file_path)
            else:
                _ = part_2(file_path)

        var time_ns = run[bench_fn](max_iters=30).mean(Unit.ns)
        var time_us = round(time_ns / 1000.0, 1)
        print("part {}, t = {} us".format(part, time_us))

    bench[1]()
    bench[2]()
