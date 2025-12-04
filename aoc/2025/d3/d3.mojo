from testing import assert_equal
from benchmark import run, Unit

comptime test_file_path = "./test_input.txt"
comptime file_path = "./input.txt"


fn max_argmax(numbers: Span[UInt8]) raises -> Tuple[Int, Int]:
    if len(numbers) == 0:
        raise Error("empty list")

    var max_val = numbers[0]
    var max_idx = 0

    for i in range(1, len(numbers)):
        if numbers[i] > max_val:
            max_val = numbers[i]
            max_idx = i
            comptime nine = ord("9")
            if max_val == nine:
                break

    return (Int(max_val - 48), max_idx)


fn day3[n: Int](file_path: String) raises -> Int:
    total = 0
    with open(file_path, "r") as f:
        for line in f.read().split("\n"):
            var bytes = line.as_bytes()
            var len = len(bytes)

            if len == 0:
                continue

            line_value = 0
            var pos_min_next = 0
            for i in range(n, 0, -1):
                v, p = max_argmax(bytes[pos_min_next : len - i + 1])
                line_value = line_value * 10 + v
                pos_min_next += p + 1
            total += line_value

    return total


fn main() raises:
    assert_equal(day3[2](test_file_path), 357)
    print("part 1: ", day3[2](file_path))

    assert_equal(day3[12](test_file_path), 3121910778619)
    print("part 2: ", day3[12](file_path))

    @parameter
    fn bench[n: Int]() raises:
        fn bench_fn() raises:
            _ = day3[n](file_path)

        var time_ms = run[bench_fn](max_iters=100).mean(Unit.ns)
        print(
            "n",
            n,
            round(time_ms / 1000.0, 1),
            "us",
        )

    bench[2]()
    bench[12]()
