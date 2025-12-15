from testing import assert_equal
from benchmark import run, Unit

from aoc.aoc_utils import input_paths


struct Grid(Copyable):
    var data: List[Int]
    var h: Int
    var w: Int

    fn __init__(out self, w: Int, h: Int):
        self.data = List[Int](length=h * w, fill=0)
        self.h = h
        self.w = w

    fn get(self, i: Int, j: Int) -> Int:
        return self.data[i * self.w + j]

    fn set(mut self, i: Int, j: Int, v: Int):
        self.data[i * self.w + j] = v


fn day6_p1(file_path: String) raises -> Int:
    var total = 0
    with open(file_path, "r") as f:
        var content = f.read().split("\n")
        var nb_line_numbers = len(content) - 1
        var nums = List[List[Int]]()

        for line in content[:nb_line_numbers]:
            var raw = line.split(" ")
            var filtered = List[Int]()
            for e in raw:
                if len(e) == 0:
                    continue
                filtered.append(atol(e))
            nums.append(filtered^)

        var operators = List[Int]()
        for e in content[-1].split(" "):
            if len(e) == 0:
                continue
            operators.append(ord(e))

        for j, operator in enumerate(operators):
            var val = 0 if operator == ord("+") else 1
            for i in range(nb_line_numbers):
                if operator == ord("+"):
                    val += nums[i][j]
                else:
                    val *= nums[i][j]

            total += val
    return total


fn day6_p2(file_path: String) raises -> Int:
    var total = 0
    with open(file_path, "r") as f:
        var content = f.read().split("\n")
        var nb_line_numbers = len(content) - 1
        var nb_char = len(content[0])

        # make values
        var grid = Grid(nb_char, nb_line_numbers)
        for i in range(nb_line_numbers):
            for j, e in enumerate(content[i].as_bytes()):
                var value: Int
                if e == ord(" "):
                    value = -1
                else:
                    value = Int(e) - ord("0")
                grid.set(i, j, value)

        var values = List[Int](capacity=nb_char)
        for j in range(nb_char):
            var val = 0
            for i in range(nb_line_numbers):
                var value = grid.get(i, j)
                if value != -1:
                    val = val * 10 + value
            values.append(val)

        # get output
        var current_operator = ""
        var current_val = 0
        for op, val in zip(content[-1].codepoint_slices(), values):
            if current_operator == "":
                current_operator = String(op)
                current_val = val

            elif val == 0:
                total += current_val
                current_operator = ""

            elif current_operator == "+":
                current_val += val

            else:
                current_val *= val

        total += current_val

    return total


fn main() raises:
    comptime test_file_path, file_path = input_paths[6]()

    print("\nAoC 2025 - Day 6")

    assert_equal(day6_p1(test_file_path), 4277556)
    print("part 1:", day6_p1(file_path))

    assert_equal(day6_p2(test_file_path), 3263827)
    print("part 2:", day6_p2(file_path))

    @parameter
    fn bench[p: Int]() raises:
        fn bench_fn() raises:
            if p == 1:
                _ = day6_p1(file_path)
            else:
                _ = day6_p2(file_path)

        var time_ns = run[bench_fn](max_iters=30).mean(Unit.ns)
        var time_us = round(time_ns / 1000.0, 1)
        print("part {}, t = {} us".format(p, time_us))

    bench[1]()
    bench[2]()
