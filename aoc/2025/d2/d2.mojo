from testing import assert_equal
from bit import count_leading_zeros, count_trailing_zeros
from math import log10, floor
from benchmark import run, Unit


comptime test_file_path = "./test_input.txt"
comptime file_path = "./input.txt"


fn part_1[version: Int, print_n: Bool = False](file_path: String) raises -> Int:
    var file = open(file_path, "r")
    var value = 0
    value_tested = 0

    for range_id in file.read().split(","):
        var temp = range_id.split("-")
        var id_min = atol(temp[0])
        var id_max = atol(temp[1])

        @parameter
        if version == 0:
            for id in range(id_min, id_max + 1):
                value_tested += 1
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
                value_tested += 1

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
                value_tested += 1
                value += candidate

        else:
            raise Error("unsupported version")

    @parameter
    if print_n:
        print("value_tested = ", value_tested)

    return value


@always_inline
fn get_n_digits[version: String = "str"](v: Int) -> Int:
    @parameter
    if version == "log10":
        return Int(floor(log10(Float64(v)))) + 1

    elif version == "str":
        return len(String(v))

    else:
        # basic
        var temp = v
        var n_digits = 0
        while temp > 0:
            temp //= 10
            n_digits += 1
        return n_digits


fn part_2(file_path: String) raises -> Int:
    var file = open(file_path, "r")
    var total = 0

    for range_str in file.read().split(","):
        var parts = range_str.split("-")
        var id_min = atol(parts[0])
        var id_max = atol(parts[1])

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


fn main() raises:
    assert_equal(part_1[0, True](test_file_path), 1227775554)
    assert_equal(part_1[1, True](test_file_path), 1227775554)
    assert_equal(part_1[2, True](test_file_path), 1227775554)
    print("part 1 v0: ", part_1[0, True](file_path))
    print("part 1 v1: ", part_1[1, True](file_path))
    print("part 1 v2: ", part_1[2, True](file_path))

    @parameter
    fn bench[part: Int, v: Int]() raises:
        fn bench_fn() raises:
            @parameter
            if part == 1:
                _ = part_1[v](file_path)
            else:
                _ = part_2(file_path)

        var time_ms = run[bench_fn](max_iters=30).mean(Unit.ns)
        print(
            "part",
            part,
            "v" + String(v) + ":",
            round(time_ms / 1000.0, 1),
            "us",
        )

    bench[1, 0]()
    bench[1, 1]()
    bench[1, 2]()

    assert_equal(part_2(test_file_path), 4174379265)
    print("part 2:", part_2(file_path))

    bench[2, 0]()
