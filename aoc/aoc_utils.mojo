from std.algorithm import parallelize
from std.os import Atomic
from std.benchmark import run, Unit

comptime aoc_base_path = "/home/jgs/dev/mojo/learn_mojo/aoc"


fn input_paths[year: Int, day: Int]() -> Tuple[String, String]:
    test_file_path = t"{aoc_base_path}/{year}/d{day}/test_input.txt"
    file_path = t"{aoc_base_path}/{year}/d{day}/input.txt"
    return (test_file_path, file_path)


fn sum_file[
    process_fn: fn(StringSlice) raises -> Int,
    parallel: Bool,
    sep: String = "\n",
](file_path: String) raises -> Int:
    with open(file_path, "r") as f:
        content = f.read()
        lines = content.split(StringSlice(sep))

        comptime if parallel:
            total = Atomic[DType.int](0)

            fn worker(idx: Int) capturing:
                try:
                    line = lines[idx]
                    if len(line) == 0:
                        return
                    _ = total.fetch_add(Scalar[DType.int](process_fn(line)))
                except:
                    pass

            parallelize[worker](len(lines))

            return Int(total.load())

        else:
            var total = 0
            for line in lines:
                total += process_fn(line)
            return total


fn basic_bench[
    func: fn[Int](String) raises -> Int, p: Int, file_path: String
]() raises:
    fn bench_fn() raises:
        _ = func[p](file_path)

    var time_us = run[func1=bench_fn](max_iters=30).mean(Unit.us)
    time_us = round(time_us, 1)
    print(t"part {p}, t = {time_us} us")
