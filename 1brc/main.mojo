from benchmark import run, Unit
import time
from sys import num_physical_cores


from v0_basics import v0
from v1_int import v1
from v2_simd import v2
from v3_no_string import v3
from v4_register_passable import v4
from v5_simd2 import v5
from v6_parallel import v6
from v7_mmap import v7


alias file_path = "./measurements.txt"


fn bench_v0() raises:
    var d = v0(file_path)


fn bench_v1() raises:
    var d = v1(file_path)


fn bench_v2() raises:
    var d = v2(file_path)


fn bench_v3() raises:
    var d = v3(file_path)


fn bench_v4() raises:
    var d = v4(file_path)


fn bench_v5() raises:
    var d = v5(file_path)


fn bench_v6() raises:
    var d = v6(file_path)


fn bench_v7() raises:
    var d = v7(file_path)


fn main() raises:
    var nb_lines = 1_000_000
    print("Nb lines = ", nb_lines)
    print("Nb cores = ", num_physical_cores())

    print(v0(file_path))
    print(v1(file_path))
    print(v2(file_path))
    print(v3(file_path))
    print(v4(file_path))
    print(v5(file_path))
    print(v6(file_path))
    print(v7(file_path))

    var t0 = run[bench_v0](max_iters=10).mean(Unit.ms)
    print("v0 = ", round(t0, 1), ", X", round(t0 / t0, 1))
    var t1 = run[bench_v1](max_iters=10).mean(Unit.ms)
    print("v1 = ", round(t1, 1), ", X", round(t0 / t1, 1))
    var t2 = run[bench_v2](max_iters=10).mean(Unit.ms)
    print("v2 = ", round(t2, 1), ", X", round(t0 / t2, 1))
    var t3 = run[bench_v3](max_iters=10).mean(Unit.ms)
    print("v3 = ", round(t3, 1), ", X", round(t0 / t3, 1))
    var t4 = run[bench_v4](max_iters=10).mean(Unit.ms)
    print("v4 = ", round(t4, 1), ", X", round(t0 / t4, 1))
    var t5 = run[bench_v5](max_iters=10).mean(Unit.ms)
    print("v5 = ", round(t5, 1), ", X", round(t0 / t5, 1))
    var t6 = run[bench_v6](max_iters=10).mean(Unit.ms)
    print("v6 = ", round(t6, 1), ", X", round(t0 / t6, 1))
    var t7 = run[bench_v7](max_iters=10).mean(Unit.ms)
    print("v7 = ", round(t7, 1), ", X", round(t0 / t7, 1))
