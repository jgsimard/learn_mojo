from std.algorithm import parallelize
from std.atomic import Atomic
from std.benchmark import run, Unit

comptime aoc_base_path = "/home/jgs/dev/mojo/learn_mojo/aoc"


def input_paths[year: Int, day: Int]() -> Tuple[String, String]:
    test_file_path = String(t"{aoc_base_path}/{year}/d{day}/test_input.txt")
    file_path = String(t"{aoc_base_path}/{year}/d{day}/input.txt")
    return (test_file_path, file_path)


def sum_file[
    process_fn: def(StringSlice) thin raises -> Int,
    parallel: Bool,
    sep: String = "\n",
](file_path: String) raises -> Int:
    with open(file_path, "r") as f:
        content = f.read()
        lines = content.split(StringSlice(sep))

        comptime if parallel:
            total = Atomic[DType.int](0)

            def worker(idx: Int) capturing:
                try:
                    line = lines[idx]
                    if line.byte_length() == 0:
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


def basic_bench[
    func: def[Int](String) thin raises -> Int, p: Int, file_path: String
]() raises:
    def bench_fn() raises:
        _ = func[p](file_path)

    var time_us = run(bench_fn, max_iters=30).mean(Unit.us)
    time_us = round(time_us, 1)
    print(t"part {p}, t = {time_us} us")
