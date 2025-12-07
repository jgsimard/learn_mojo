from testing import assert_equal
from benchmark import run, Unit
from itertools import product

from aoc.aoc_utils import sum_file, input_paths


fn day4[part: Int](file_path: String) raises -> Int:
    var grid: List[List[Int]] = []
    with open(file_path, "r") as f:
        for line in f.read().split("\n"):
            var bob: List[Int] = []
            if len(line) == 0:
                continue
            for e in line.codepoint_slices():
                if e == ".":
                    bob.append(0)
                elif e == "@":
                    bob.append(1)
                else:
                    print("oops")
            grid.append(bob^)

    var new_grid = grid.copy()
    var len_y = len(grid[0])
    var len_x = len(grid)
    var kernel = [[1, 1, 1], [1, 0, 1], [1, 1, 1]]
    # print(len_y, len_x)

    var num = 0
    while True:
        var done_this_turn = 0
        # convolution
        for x, y in product(range(len_x), range(len_y)):
            var cell_value = 0
            for dx, dy in product(range(-1, 2), range(-1, 2)):
                var nx = x + dx
                var ny = y + dy
                if nx >= 0 and nx < len_x and ny >= 0 and ny < len_y:
                    cell_value += grid[nx][ny] * kernel[dx + 1][dy + 1]
            if cell_value < 4 and grid[x][y] == 1:
                num += 1
                new_grid[x][y] = 0
                done_this_turn += 1

        @parameter
        if part == 1:
            break

        if done_this_turn == 0:
            break

        grid = new_grid.copy()
        # print("turn done, ", done_this_turn)

    return num


fn main() raises:
    comptime test_file_path, file_path = input_paths[4]()

    print("\nAoC 2025 - Day 4")

    assert_equal(day4[1](test_file_path), 13)
    print("part 1: ", day4[1](file_path))

    assert_equal(day4[2](test_file_path), 43)
    print("part 2: ", day4[2](file_path))

    @parameter
    fn bench[part: Int]() raises:
        fn bench_fn() raises:
            _ = day4[part](file_path)

        var time_ns = run[bench_fn](max_iters=30).mean(Unit.ns)
        var time_us = round(time_ns / 1000.0, 1)
        print("part {}, t = {} us".format(part, time_us))

    bench[1]()
    bench[2]()
