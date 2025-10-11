from benchmark import run, Unit
import time
from sys import num_physical_cores
from benchmark import keep

from v0_basics import v0
from v1_int import v1
from v2_simd import v2
from v3_no_string import v3
from v4_register_passable import v4
from v5_simd2 import v5
from v6_parallel import v6
from v7_mmap import v7
from v8_swar import v8

alias file_path = "./measurements.txt"


fn process_and_save[func: fn (String) raises -> String, name: String]() raises:
    var output = func(file_path)
    var output_hash = hash(output)

    print("hash ", name, " : ", output_hash)

    var filename = String("output_", name, ".txt")
    with open(filename, "w") as f:
        f.write(output)


fn bench[v: fn (String) raises -> String]() raises:
    var d = v(file_path)


fn bench_compare[
    v: fn (String) raises -> String, name: String
](t0: Float64) raises:
    var t = run[bench[v]](max_iters=10).mean(Unit.ms)
    print(name, " = ", round(t, 1), ", X", round(t0 / t, 1))


fn main() raises:
    var nb_lines = 1_000_000
    print("Nb lines = ", nb_lines)
    print("Nb cores = ", num_physical_cores())
    # var line_start = pos  # Track where current line started
    # alias bits_type = DType.uint64 if simd_width == 64 else DType.uint32

    process_and_save[v0, "v0"]()
    process_and_save[v1, "v1"]()
    process_and_save[v2, "v2"]()
    process_and_save[v3, "v3"]()
    process_and_save[v4, "v4"]()
    process_and_save[v5, "v5"]()
    process_and_save[v6, "v6"]()
    process_and_save[v7, "v7"]()
    # process_and_save[v8, "v8"]()

    # var t0 = 156.6
    # bench_compare[v0, "v0"](t0)
    # bench_compare[v1, "v1"](t0)
    # bench_compare[v2, "v2"](t0)
    # bench_compare[v3, "v3"](t0)
    # bench_compare[v4, "v4"](t0)
    # bench_compare[v5, "v5"](t0)
    # bench_compare[v6, "v6"](t0)
    # bench_compare[v7, "v7"](t0)
