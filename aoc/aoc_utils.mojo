from algorithm import parallelize
from os import Atomic
from benchmark import run, Unit

comptime aoc_2025_base_path = "/home/jgs/mojo/learn_mojo/aoc/2025"


fn input_paths[day: Int]() -> Tuple[String, String]:
    var test_file_path = "{}/d{}/test_input.txt".format(aoc_2025_base_path, day)
    var file_path = "{}/d{}/input.txt".format(aoc_2025_base_path, day)
    return (test_file_path, file_path)


fn sum_file[
    process_fn: fn (StringSlice) raises -> Int,
    parallel: Bool,
    sep: String = "\n",
](file_path: String) raises -> Int:
    var content: String
    with open(file_path, "r") as f:
        content = f.read()
    var lines = content.split(StringSlice(sep))

    @parameter
    if parallel:
        var total = Atomic[DType.int](0)

        @parameter
        fn worker(idx: Int):
            try:
                var line = lines[idx]
                if len(line) == 0:
                    return
                _ = total.fetch_add(process_fn(line))
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
    func: fn[Int] (String) raises -> Int, p: Int, file_path: String
]() raises:
    fn bench_fn() raises:
        _ = func[p](file_path)

    var time_us = run[func1=bench_fn](max_iters=30).mean(Unit.us)
    time_us = round(time_us, 1)
    print("part {}, t = {} us".format(p, time_us))
