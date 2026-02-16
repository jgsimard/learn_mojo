from testing import assert_equal
from benchmark import run, Unit

from aoc.aoc_utils import input_paths, basic_bench


@fieldwise_init
struct Range(Comparable, Copyable, Writable):
    var min: Int
    var max: Int

    fn contains(self, value: Int) -> Bool:
        return self.min <= value <= self.max

    fn __lt__(self: Self, rhs: Self) -> Bool:
        return self.min < rhs.min


fn find_containing_range(ranges: List[Range], value: Int) -> Bool:
    var low = 0
    var high = len(ranges) - 1

    while low <= high:
        var mid = (low + high) // 2
        ref range = ranges[mid]

        if range.contains(value):
            return True
        elif value < range.min:
            high = mid - 1
        else:
            low = mid + 1
    return False


fn day5[p: Int](file_path: String) raises -> Int:
    var nb_fresh = 0
    with open(file_path, "r") as f:
        var sections = f.read().split("\n\n")
        var range_lines = sections[0].split("\n")
        var input_lines = sections[1].split("\n")

        # parse ranges sorted by min
        var ranges = List[Range](capacity=len(range_lines))
        for range_line in range_lines:
            var line = range_line.split("-")
            var min = atol(line[0])
            var max = atol(line[1])
            ranges.append(Range(min, max))

        sort(ranges)

        # merge overlaping ranges
        var no_overlap_ranges = List[Range]()
        no_overlap_ranges.append(ranges[0].copy())
        for r in ranges[1:]:
            ref last = no_overlap_ranges[-1]
            if r.min <= last.max + 1:  # +1 for [1-3][4-6] => [1-6]
                last.max = max(r.max, last.max)
            else:
                no_overlap_ranges.append(r.copy())

        @parameter
        if p == 1:
            for input_line in input_lines:
                if len(input_line) == 0:
                    continue
                var ingredient = atol(input_line)

                if find_containing_range(no_overlap_ranges, ingredient):
                    nb_fresh += 1

                # for range in no_overlap_ranges:
                #     if ingredient >= range.min and ingredient <= range.max:
                #         nb_fresh += 1
                #         break
                #     if ingredient < range.min:
                #         break
        else:
            for r in no_overlap_ranges:
                nb_fresh += r.max - r.min + 1

    return nb_fresh


fn main() raises:
    comptime test_file_path, file_path = input_paths[2025, 5]()

    print("\nAoC 2025 - Day 5")

    assert_equal(day5[1](test_file_path), 3)
    print("part 1:", day5[1](file_path))

    assert_equal(day5[2](test_file_path), 14)
    print("part 2:", day5[2](file_path))

    basic_bench[day5, 1, file_path]()
    basic_bench[day5, 2, file_path]()
