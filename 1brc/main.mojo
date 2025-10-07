from benchmark import run, Unit
import time

from v0_basics import v0
from v1_int import v1
from v2_simd_1 import v2
# from v3_simd_2 import v3

# from math import min, max

alias file_path = "./measurements.txt"
# alias simd_width = simd_width_of[UInt8]()

# The program should print out the min, mean, and max values per station, alphabetically ordered like so:

fn bench_V0() raises:
    var d = v0(file_path)

fn bench_V1() raises:
    var d = v1(file_path)

fn bench_V2() raises:
    var d = v2(file_path)

# fn bench_V3() raises:
#     var d = v3(file_path)

fn main() raises:
    print(v0(file_path))
    print(v1(file_path))
    print(v2(file_path))
    # print(v3(file_path))
    

    # print("V0 = ", run[bench_V0]().mean(Unit.ms))
    # print("V1 = ", run[bench_V1]().mean(Unit.ms))
    
    # var report2 = run[bench_V2]()
    # report2.print(Unit.ms)
    # print("V2 = ", report.mean(Unit.ms))

    # var report3 = run[bench_V3]()
    # report3.print(Unit.ms)
    
    # print(simd_width)


    # # reportV1.print()
    # var newline_vec = SIMD[DType.uint8, simd_width](ord('\n'))
    # print(newline_vec)