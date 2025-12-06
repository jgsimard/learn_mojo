from algorithm import parallelize
from os import Atomic

comptime aoc_2025_base_path = "/home/jgs/mojo/learn_mojo/aoc/2025"

fn input_paths[day: Int]() -> Tuple[String, String]:
    var test_file_path = aoc_2025_base_path + "/d" + String(day) + "/test_input.txt"
    var file_path = aoc_2025_base_path + "/d" + String(day) + "/input.txt"
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
