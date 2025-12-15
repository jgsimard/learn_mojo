from testing import assert_equal
from benchmark import run, Unit
from memory import memset_zero

from aoc.aoc_utils import input_paths


fn day7[p: Int](file_path: String) raises -> Int:
    var total_split = 0
    var total_world = 1
    with open(file_path, "r") as f:
        var lines = f.read().split("\n")

        var current_origins = List[Int](length=len(lines[0]), fill=0)
        for i, e in enumerate(lines[0].codepoint_slices()):
            if e == "S":
                current_origins[i] = 1
                break
        var next_origins = List[Int](length=len(current_origins), fill=0)

        for new_line in lines[1:]:
            memset_zero(next_origins.unsafe_ptr(), len(next_origins))
            for i, (n, o) in enumerate(
                zip(new_line.codepoint_slices(), current_origins)
            ):
                if o > 0:
                    if n == "^":
                        total_split += 1
                        total_world += o
                        # never at a border so no need to check
                        next_origins[i - 1] += o
                        next_origins[i + 1] += o
                    elif n == ".":
                        next_origins[i] += o
            swap(current_origins, next_origins)

    return total_split if p == 1 else total_world


fn main() raises:
    comptime test_file_path, file_path = input_paths[7]()

    print("\nAoC 2025 - Day 7")

    assert_equal(day7[1](test_file_path), 21)
    print("part 1:", day7[1](file_path))

    assert_equal(day7[2](test_file_path), 40)
    print("part 2:", day7[2](file_path))

    @parameter
    fn bench[p: Int]() raises:
        fn bench_fn() raises:
            _ = day7[p](file_path)

        var time_ns = run[bench_fn](max_iters=30).mean(Unit.ns)
        var time_us = round(time_ns / 1000.0, 1)
        print("part {}, t = {} us".format(p, time_us))

    bench[1]()
    bench[2]()
