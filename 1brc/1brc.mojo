from ffi import external_call
from sys.info import simd_width_of
from memory import pack_bits
from bit import count_leading_zeros, count_trailing_zeros
from algorithm import parallelize
from sys import num_physical_cores
from benchmark import run, Unit
from testing import assert_equal
import os


# parametrized trait would be nice
comptime Measurement = Copyable & Stringable & TrivialRegisterType & Writable


@fieldwise_init
struct MeasurementFloat(Measurement):
    var min: Float64
    var mean: Float64
    var max: Float64
    var n: Float64

    fn __init__(out self, val: Float64):
        self.min = val
        self.max = val
        self.mean = val
        self.n = 1.0

    fn update(mut self, val: Float64):
        self.min = min(val, self.min)
        self.max = max(val, self.max)
        self.n += 1.0
        self.mean += (val - self.mean) / self.n

    fn __str__(self) -> String:
        var min = round(self.min, 1)
        var max = round(self.max, 1)
        var mean = round(self.mean, 1)
        return "{}/{}/{}".format(min, mean, max)

    fn write_to(self, mut writer: Some[Writer]):
        writer.write(self.__str__())


struct MeasurementInt(Measurement):
    var min: Int
    var sum: Int
    var max: Int
    var n: Int

    fn __init__(out self, val: Int):
        self.min = val
        self.max = val
        self.sum = val
        self.n = 1

    @always_inline
    fn update(mut self, val: Int):
        self.min = min(val, self.min)
        self.max = max(val, self.max)
        self.sum += val
        self.n += 1

    @always_inline
    fn merge(mut self, other: Self):
        self.min = min(other.min, self.min)
        self.max = max(other.max, self.max)
        self.sum += other.sum
        self.n += other.n

    fn __str__(self) -> String:
        var min = round(Float32(self.min) / 10.0, 1)
        var max = round(Float32(self.max) / 10.0, 1)
        var mean = round(Float32(self.sum) / 10.0 / Float32(self.n), 1)
        return "{}/{}/{}".format(min, mean, max)

    fn write_to(self, mut writer: Some[Writer]):
        writer.write(self.__str__())


fn format_output[M: Measurement](d: Dict[String, M]) raises -> String:
    var cities = ["{}={}".format(entry.key, entry.value) for entry in d.items()]
    sort(cities)
    return "{" + ", \n".join(cities) + "}"


fn format_output[
    M: Measurement
](
    d: Dict[UInt64, M],
    city_names: Dict[UInt64, StringSlice[ImmutAnyOrigin]],
) raises -> String:
    var cities = [
        "{}={}".format(entry.value, d[entry.key])
        for entry in city_names.items()
    ]
    sort(cities)
    return "{" + ", \n".join(cities) + "}"


fn process_chunk[
    temp_alg: String = "v5", simd_parsing: Bool = True
](
    data: Span[UInt8, ImmutAnyOrigin],
    start: Int,
    end: Int,
    mut d: Dict[UInt64, MeasurementInt],
    mut city_names: Dict[UInt64, StringSlice[ImmutAnyOrigin]],
) raises -> None:
    var pos = start

    @parameter
    if simd_parsing:
        comptime simd_width = simd_width_of[DType.uint8]()
        comptime bits_type = DType.uint64 if simd_width == 64 else DType.uint32

        comptime SEMICOLON = ord(";")
        comptime NEW_LINE = ord("\n")
        comptime MINUS = ord("-")
        comptime ZERO = ord("0")
        comptime DOT = ord(".")

        var data_ptr = data.unsafe_ptr()
        var line_start = pos

        while pos + simd_width < end:
            var chunk = data_ptr.load[width=simd_width](pos)
            var newlines = pack_bits[bits_type](chunk.eq(NEW_LINE))
            var semicolons = pack_bits[bits_type](chunk.eq(SEMICOLON))

            if newlines == 0:
                # to not break temperature in two chunks
                pos += Int(count_leading_zeros(semicolons))
                continue

            var start_of_line_idx = 0

            while newlines != 0:
                var newline_idx = count_trailing_zeros(newlines)
                var search_mask = (1 << newline_idx) - (1 << start_of_line_idx)

                # Parse city
                var semicolon_idx = count_trailing_zeros(
                    semicolons & search_mask
                )
                var city_len = pos + Int(semicolon_idx) - line_start
                var hash_city = hash(data_ptr + line_start, city_len)

                # parse value
                comptime vec_3d = SIMD[DType.int16, 4](100, 10, 0, 1)  # dd.d
                comptime vec_2d = SIMD[DType.int16, 4](10, 0, 1, 0)  # d.dX

                var val_start_idx = pos + semicolon_idx + 1
                var num_len = newline_idx - (semicolon_idx + 1)

                var is_neg = Int(data[val_start_idx] == MINUS)
                var sign = 1 - (is_neg << 1)

                var val_abs_start = val_start_idx + is_neg

                var val: Int

                @parameter
                if temp_alg == "v2":
                    # slower if i load from chunk-- why ???
                    # base = semicolon_idx + 1 + Int(is_neg)
                    # var digits = SIMD[DType.int16, 4](chunk.as_bytes().unsafe_ptr().load[width=4](base) - ZERO)
                    # var bob = chunk.slice[4]()
                    # var bb = chunk.shift_left()
                    var digits = SIMD[DType.int16, 4](
                        data_ptr.load[width=4](val_abs_start) - ZERO
                    )
                    var val_long = (digits * vec_3d).reduce_add()
                    var val_short = (digits * vec_2d).reduce_add()

                    var is_short = Int((num_len - is_neg) == 3)  # d.d
                    var val_abs = val_short * is_short + val_long * (
                        1 - is_short
                    )
                    val = Int(sign * val_abs)

                elif temp_alg == "v5":
                    comptime vec_digits = vec_3d.interleave(vec_2d)

                    var digits_4 = SIMD[DType.int16, 4](
                        data_ptr.load[width=4](val_abs_start) - ZERO
                    )

                    # reduce_add[2] give the sum of the *interleaved* elements
                    var digits_8 = digits_4.interleave(digits_4)
                    var vals = (digits_8 * vec_digits).reduce_add[2]()

                    var is_short = Int((num_len - is_neg) == 3)  # d.d
                    var val_abs = vals[0] * (1 - is_short) + vals[1] * is_short
                    val = Int(sign * val_abs)
                else:
                    raise "unsuported version"

                try:
                    d[hash_city].update(val)
                except:
                    d[hash_city] = MeasurementInt(val)
                    city_names[hash_city] = StringSlice(
                        from_utf8=data[line_start : pos + Int(semicolon_idx)]
                    )

                start_of_line_idx = Int(newline_idx) + 1
                line_start = pos + start_of_line_idx
                newlines &= newlines - 1

            pos += start_of_line_idx

    # tail = scalar
    if pos < end:
        var tail = StringSlice(from_utf8=data[pos : end - 1])
        for l in tail.split("\n"):
            if len(l) == 0:
                continue
            var station = l.split(";")
            var city = station[0]
            var val = atol(station[1].replace(".", ""))

            var hash_city = hash(city.unsafe_ptr(), len(city))

            try:
                d[hash_city].update(val)
            except:
                d[hash_city] = MeasurementInt(val)
                city_names[hash_city] = city


# parallel
fn find_next_newline(data: Span[UInt8], start: Int) -> Int:
    """Find the next newline after start position."""
    for i in range(start, len(data)):
        if data[i] == ord("\n"):
            return i + 1  # Return position AFTER newline
    return len(data)


fn process_parallel(data: Span[UInt8, ImmutAnyOrigin]) raises -> String:
    var num_workers = num_physical_cores()

    # Calculate aligned chunk boundaries
    var approx_chunk_size = len(data) // num_workers
    var chunk_starts = List[Int]()
    var chunk_ends = List[Int]()

    chunk_starts.append(0)

    for i in range(1, num_workers):
        var approx_start = i * approx_chunk_size
        var aligned_start = find_next_newline(data, approx_start)
        chunk_starts.append(aligned_start)
        chunk_ends.append(aligned_start)

    chunk_ends.append(len(data))

    # Create per-thread storage
    var thread_dicts = List[Dict[UInt64, MeasurementInt]](
        length=num_workers, fill={}
    )
    var thread_city_names = List[Dict[UInt64, StringSlice[ImmutAnyOrigin]]](
        length=num_workers, fill={}
    )

    # Process chunks in parallel
    @parameter
    fn process_worker(worker_id: Int):
        try:
            process_chunk(
                data,
                chunk_starts[worker_id],
                chunk_ends[worker_id],
                thread_dicts[worker_id],
                thread_city_names[worker_id],
            )
        except:
            print("oopsie")

    parallelize[process_worker](num_workers)

    # Merge results from all threads
    ref final_dict = thread_dicts[0]
    ref final_city_names = thread_city_names[0]

    for worker_id in range(1, num_workers):  # skip first one
        for entry in thread_dicts[worker_id].items():
            var hash_key = entry.key
            var measurement = entry.value

            if hash_key in final_dict:
                final_dict[hash_key].merge(measurement)
            else:
                final_dict[hash_key] = measurement
                final_city_names[hash_key] = thread_city_names[worker_id][
                    hash_key
                ]

    return format_output(final_dict, final_city_names)


struct MMap:
    """Memory Mapped File."""

    comptime ptr = UnsafePointer[UInt8, ImmutAnyOrigin]
    var _data: Self.ptr
    var _size: Int

    fn __init__(out self, path: String) raises:
        with open(path, "r") as file:
            comptime PROT_READ = 1
            comptime MAP_SHARED = 1

            self._size = Int(file.seek(0, os.SEEK_END))

            self._data = external_call["mmap", Self.ptr](
                Self.ptr(),  # addr (let kernel choose)
                self._size,
                PROT_READ,
                MAP_SHARED,
                file._get_raw_fd(),
                0,  # offset
            )

        if Int(self._data) == -1:
            raise Error("mmap failed")

    fn __del__(deinit self):
        if self._data:
            _ = external_call["munmap", Int](self._data, self._size)

    fn as_span(self) -> Span[UInt8, ImmutAnyOrigin]:
        return Span(ptr=self._data, length=self._size)


fn process_1brc[version: Int](file_path: String) raises -> String:
    """
    Unified 1BRC processor using compile-time version selection.

    Versions:
    - 0: Basic string operations with Float64
    - 1: Fixed-point Int arithmetic
    - 2: Hash-based city lookup (no string allocation)
    - 3: SIMD parsing of temperature
    - 4: Parallel processing
    - 5: Memory Mapped File
    """

    @parameter
    if version == 0:
        var d = Dict[String, MeasurementFloat]()
        with open(file_path, "r") as f:
            var lines = f.read().split("\n")
            for l in lines:
                if len(l) == 0:
                    continue
                var station = l.split(";")
                var city = String(station[0])
                var val = atof(station[1])
                if city in d:
                    d[city].update(val)
                else:
                    d[city] = MeasurementFloat(val)
        return format_output(d)

    elif version == 1:
        var d = Dict[String, MeasurementInt]()
        with open(file_path, "r") as f:
            var lines = f.read().split("\n")
            for l in lines:
                if len(l) == 0:
                    continue
                var station = l.split(";")
                var city = String(station[0])
                var val = atol(station[1].replace(".", ""))
                if city in d:
                    d[city].update(val)
                else:
                    d[city] = MeasurementInt(val)
        return format_output(d)

    elif version == 2:
        var d = Dict[UInt64, MeasurementInt](power_of_two_initial_capacity=1024)
        var city_names = Dict[UInt64, StringSlice[ImmutAnyOrigin]](
            power_of_two_initial_capacity=1024
        )
        with open(file_path, "r") as file:
            var data = Span[UInt8, ImmutAnyOrigin](file.read_bytes())

            process_chunk[simd_parsing=False](
                data, 0, len(data) - 1, d, city_names
            )
        return format_output(d, city_names)

    elif version == 3:
        var d = Dict[UInt64, MeasurementInt](power_of_two_initial_capacity=1024)
        var city_names = Dict[UInt64, StringSlice[ImmutAnyOrigin]](
            power_of_two_initial_capacity=1024
        )
        with open(file_path, "r") as file:
            var data = Span[UInt8, ImmutAnyOrigin](file.read_bytes())
            process_chunk(data, 0, len(data) - 1, d, city_names)

        return format_output(d, city_names)

    elif version == 4:
        with open(file_path, "r") as file:
            var data = Span[UInt8, ImmutAnyOrigin](file.read_bytes())
            return process_parallel(data)

    elif version == 5:
        var mmap_file = MMap(file_path)
        var data = mmap_file.as_span()
        return process_parallel(data)

    else:
        raise "unsuported version"


fn main() raises:
    comptime file_path = "./measurements.txt"
    comptime hash_1M = 7830574609753597440
    comptime hash_100M = 7465477878325822113

    print("1BRC Unified Implementation")
    print("Cores:", num_physical_cores())

    print("Testing...")

    fn test[v: Int]() raises:
        var result = process_1brc[v](file_path)
        var result_hash = hash(result)

        with open("output/v{}.txt".format(v), "w") as f:
            f.write(result)

        assert_equal(result_hash, hash_1M)
        # assert_equal(result_hash, hash_100M)

        print("v{} : correct hash".format(v))

    @parameter
    for version in [0, 1, 2, 3, 4, 5]:
        test[version]()

    print("Benchmarking...")

    fn bench[
        v: Int
    ](
        base_time: Optional[Float64] = None, prev_time: Optional[Float64] = None
    ) raises -> Float64:
        fn bench_fn() raises:
            _ = process_1brc[v](file_path)

        var time_ms = round(run[func1=bench_fn](max_iters=10).mean(Unit.ms), 1)
        if base_time and prev_time:
            var prev_speedup = round(prev_time.value() / time_ms, 1)
            var base_speedup = round(base_time.value() / time_ms, 1)
            print(
                "v{} : {} ms, {} X prev, {} X base".format(
                    v, time_ms, prev_speedup, base_speedup
                )
            )
        else:
            print("v{} : {} ms".format(v, time_ms))
        return time_ms

    var t0 = bench[0]()
    var t1 = bench[1](t0, t0)
    var t2 = bench[2](t0, t1)
    var t3 = bench[3](t0, t2)
    var t4 = bench[4](t0, t3)
    var t5 = bench[5](t0, t4)
