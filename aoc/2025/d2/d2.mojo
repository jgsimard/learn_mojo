from testing import assert_equal
from bit import count_leading_zeros, count_trailing_zeros
from math import log10, floor
from benchmark import run, Unit
from itertools import product

from aoc.aoc_utils import sum_file, input_paths


fn part_1[ver: Int, parallel: Bool = False](file_path: String) raises -> Int:
    fn process_range[version: Int](range_id: StringSlice) raises -> Int:
        var value = 0
        var temp = range_id.split("-")
        var id_min = atol(temp[0])
        var id_max = atol(temp[1])

        @parameter
        if version == 0:
            for id in range(id_min, id_max + 1):
                var id_str = String(id)
                len_id = len(id_str)
                mid = len_id // 2
                if id_str[:mid] == id_str[mid:]:
                    value += id

        elif version == 1:
            var n_digits = (get_n_digits(id_min) + 1) & ~1

            var divisor = 10 ** (n_digits // 2)

            var lower_bound = max(id_min, 10 ** (n_digits - 1))
            for var id in range(lower_bound, id_max + 1):
                # value_tested += 1

                var left = id // divisor
                var right = id % divisor

                if left == right:
                    value += id

        elif version == 2:
            # valid id = (10^k + 1) * X , with n_digits(X)==k
            var k = (get_n_digits(id_min) + 1) // 2
            var multiplier = 10**k + 1

            var start = (
                max((id_min - 1) // multiplier + 1, 10 ** (k - 1)) * multiplier
            )
            var end = min(id_max, (10**k - 1) * multiplier) + 1

            for candidate in range(start, end, multiplier):
                value += candidate

        else:
            raise Error("unsupported version")

        return value

    return sum_file[process_range[ver], parallel, ","](file_path)


@always_inline
fn get_n_digits[version: String = "str"](v: Int) -> Int:
    @parameter
    if version == "log10":
        return Int(floor(log10(Float64(v)))) + 1

    elif version == "str":
        return len(String(v))

    else:  # basic
        var temp = v
        var n_digits = 0
        while temp > 0:
            temp //= 10
            n_digits += 1
        return n_digits


fn part_2[parallel: Bool = False](file_path: String) raises -> Int:
    fn process_range(range_id: StringSlice) raises -> Int:
        var parts = range_id.split("-")
        var id_min = atol(parts[0])
        var id_max = atol(parts[1])
        var total = 0

        for id in range(id_min, id_max + 1):
            var n_digits = get_n_digits(id)

            var is_valid = False
            for k in range(1, n_digits // 2 + 1):
                if n_digits % k == 0:
                    var stride = 10**k
                    var multiplier = 0
                    var current_pow = 1
                    for _ in range(n_digits // k):
                        multiplier += current_pow
                        current_pow *= stride

                    var pattern = id % stride

                    if pattern * multiplier == id:
                        is_valid = True
                        break

            if is_valid:
                total += id
        return total

    return sum_file[process_range, parallel, ","](file_path)


fn main() raises:
    comptime test_file_path, file_path = input_paths[2025, 2]()

    print("\nAoC 2025 - Day 2")

    comptime ver = [0, 1, 2]
    comptime par = [False, True]

    @parameter
    for v, p in product(ver, par):
        assert_equal(part_1[v, p](test_file_path), 1227775554)

    print("part 1:", part_1[2](file_path))

    assert_equal(part_2(test_file_path), 4174379265)
    print("part 2:", part_2(file_path))

    @parameter
    fn bench[part: Int, v: Int, parallel: Bool = False]() raises:
        fn bench_fn() raises:
            @parameter
            if part == 1:
                _ = part_1[v, parallel](file_path)
            else:
                _ = part_2[parallel](file_path)

        var time_us = run[func1=bench_fn](max_iters=30).mean(Unit.us)
        time_us = round(time_us, 1)
        print("part {}, v{} : {} us".format(part, v, time_us))

    # print("Sequential")
    # bench[1, 0]()
    # bench[1, 1]()
    # bench[1, 2]()

    # print("Parallel")
    # bench[1, 0, True]()
    # bench[1, 1, True]()
    bench[1, 2, True]()

    # bench[2, 0]()
    bench[2, 0, True]()
