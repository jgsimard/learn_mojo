from testing import assert_equal
from benchmark import run, Unit

from aoc.aoc_utils import sum_file, input_paths, basic_bench, basic_bench


fn max_argmax(numbers: Span[UInt8]) raises -> Tuple[Int, Int]:
    if len(numbers) == 0:
        raise Error("empty list")

    var max_val = numbers[0]
    var max_idx = 0

    for i in range(1, len(numbers)):
        if numbers[i] > max_val:
            max_val = numbers[i]
            max_idx = i
            comptime nine = UInt8(ord("9"))
            if max_val == nine:
                break

    return (Int(max_val - 48), max_idx)


fn day3[n: Int](file_path: String) raises -> Int:
    fn process_line(line: StringSlice) raises -> Int:
        var bytes = line.as_bytes()
        var len = len(bytes)

        if len == 0:
            return 0

        line_value = 0
        var pos_min_next = 0
        for i in range(n, 0, -1):
            v, p = max_argmax(bytes[pos_min_next : len - i + 1])
            line_value = line_value * 10 + v
            pos_min_next += p + 1
        return line_value

    return sum_file[process_line, parallel=True](file_path)


fn main() raises:
    comptime test_file_path, file_path = input_paths[3]()

    print("\nAoC 2025 - Day 3")

    assert_equal(day3[2](test_file_path), 357)
    print("part 1: ", day3[2](file_path))

    assert_equal(day3[12](test_file_path), 3121910778619)
    print("part 2: ", day3[12](file_path))

    basic_bench[day3, 2, file_path]()
    basic_bench[day3, 12, file_path]()
