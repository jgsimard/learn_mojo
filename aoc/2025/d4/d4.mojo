from testing import assert_equal
from benchmark import run, Unit
from itertools import product

from aoc.aoc_utils import sum_file, input_paths, basic_bench


struct Grid(Copyable):
    var data: List[Int8]
    var h: Int
    var w: Int

    fn __init__(out self, w: Int, h: Int):
        self.data = List[Int8](length=h * w, fill=0)
        self.h = h
        self.w = w

    fn __getitem__(mut self, i: Int, j: Int) -> ref [self.data] Int8:
        return self.data[i * self.w + j]


fn day4[part: Int](file_path: String) raises -> Int:
    var grid: Grid
    with open(file_path, "r") as f:
        var content = f.read().split("\n")
        var nb_line = len(content[0])
        # hard code zero padding for 3x3 kernel
        grid = Grid(nb_line + 2, nb_line + 2)

        for i, line in enumerate(content):
            if len(line) == 0:
                continue
            for j, e in enumerate(line.as_bytes()):
                if e == ord("@"):
                    grid[i + 1, j + 1] = 1

    var num = 0
    var changed = List[Tuple[Int, Int]]()
    while True:
        # # convolution
        # for x, y in product(range(len_x), range(len_y)):
        #     var cell_value = 0
        #     for dx, dy in product(range(-1, 2), range(-1, 2)):
        #         var nx = x + dx
        #         var ny = y + dy
        #         if nx >= 0 and nx < len_x and ny >= 0 and ny < len_y:
        #             cell_value += grid[nx][ny] * kernel[dx + 1][dy + 1]

        # hard coded convolution
        for x, y in product(range(1, grid.h + 1), range(1, grid.w + 1)):
            var cell_value: Int8 = 0
            cell_value += grid[x - 1, y - 1]
            cell_value += grid[x - 1, y]
            cell_value += grid[x - 1, y + 1]
            cell_value += grid[x, y - 1]
            # cell_value += grid.get(x, y)
            cell_value += grid[x, y + 1]
            cell_value += grid[x + 1, y - 1]
            cell_value += grid[x + 1, y]
            cell_value += grid[x + 1, y + 1]

            if cell_value < 4 and grid[x, y] == 1:
                num += 1
                changed.append((x, y))

        @parameter
        if part == 1:
            break

        if len(changed) == 0:
            break

        for cx, cy in changed:
            grid[cx, cy] = 0
        changed.clear()

    return num


fn main() raises:
    comptime test_file_path, file_path = input_paths[4]()

    print("\nAoC 2025 - Day 4")

    assert_equal(day4[1](test_file_path), 13)
    print("part 1: ", day4[1](file_path))

    assert_equal(day4[2](test_file_path), 43)
    print("part 2: ", day4[2](file_path))

    basic_bench[day4, 1, file_path]()
    basic_bench[day4, 2, file_path]()
