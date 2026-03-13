# def next_power_of_10(n: Int) -> Int:
#     if n < 10:
#         return 10
#     elif n < 100:
#         return 100
#     else:
#         return 1000

# def try_ops(line: List[Int], target: Int, idx: Int, try_concat: Bool) -> Bool:
#     v = line[idx]
#     if idx == 0:
#         return target == v

#     if v > target:
#         return False

#     m = False
#     if target % v == 0:
#         m = try_ops(line, target//v, idx-1, try_concat)

#     a = try_ops(line, target-v, idx-1, try_concat)
#     if not try_concat:
#         return a or m

#     c = False
#     np = next_power_of_10(v)
#     n = target % np
#     if n == v:
#         c = try_ops(line, target // np, idx-1, try_concat)
#     return a or m or c

# def parse(inp: String) raises -> Tuple[Int, Int]:
#     p1 = 0
#     p2 = 0
#     res = List[Int]()

#     for line in inp.splitlines():
#         s = line.split(":")
#         target = atol(s[0])
#         for v in s[1].split():
#             res.append(atol(v))
#         if try_ops(res, target, len(res)-1, False):
#             p1 += target
#             p2 += target
#         elif try_ops(res, target, len(res)-1, True):
#             p2 += target
#         res.clear()

#     return p1, p2

# def main() raises:
#     with open("input.txt", "r") as f:
#         inp = f.read()
#     p1, p2 = parse(inp)
#     print("Part 1:", p1)
#     print("Part 2:", p2)


from testing import assert_equal
from benchmark import run, Unit
from memory import memset_zero

from aoc.aoc_utils import input_paths, basic_bench


def next_power_of_10(n: Int) -> Int:
    if n < 10:
        return 10
    elif n < 100:
        return 100
    else:
        return 1000


def try_ops(line: List[Int], target: Int, idx: Int, try_concat: Bool) -> Bool:
    v = line[idx]
    if idx == 0:
        return target == v

    if v > target:
        return False

    m = False
    if target % v == 0:
        m = try_ops(line, target // v, idx - 1, try_concat)

    a = try_ops(line, target - v, idx - 1, try_concat)
    if not try_concat:
        return a or m

    c = False
    np = next_power_of_10(v)
    n = target % np
    if n == v:
        c = try_ops(line, target // np, idx - 1, try_concat)
    return a or m or c


def day7[p: Int](file_path: String) raises -> Int:
    with open(file_path, "r") as f:
        p1 = 0
        p2 = 0
        res = List[Int]()

        for line in f.read().split("\n"):
            if len(line) == 0:
                continue
            s = line.split(":")
            target = atol(s[0])
            for v in s[1].split():
                res.append(atol(v))
            if try_ops(res, target, len(res) - 1, False):
                p1 += target
                p2 += target
            elif try_ops(res, target, len(res) - 1, True):
                p2 += target
            res.clear()

        return p1 if p == 1 else p2


def main() raises:
    comptime test_file_path, file_path = input_paths[2024, 7]()

    print("\nAoC 2024 - Day 7")

    # assert_equal(day7[1](test_file_path), 21)
    print("part 1:", day7[1](file_path))

    # assert_equal(day7[2](test_file_path), 40)
    print("part 2:", day7[2](file_path))

    basic_bench[day7, 1, file_path]()
    basic_bench[day7, 2, file_path]()
