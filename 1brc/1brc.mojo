from sys.ffi import external_call
from sys.info import simd_width_of
from memory import pack_bits
from bit import count_leading_zeros, count_trailing_zeros
from algorithm import parallelize
from sys import num_physical_cores
from benchmark import run, Unit

# =============================================================================
# Constants
# =============================================================================
alias simd_width = simd_width_of[DType.uint8]()
alias bits_type = DType.uint64 if simd_width == 64 else DType.uint32

alias middle = ord(";")
alias new_line = ord("\n")
alias NEG = ord("-")
alias ZERO = ord("0")
alias DOT = ord(".")


# =============================================================================
# Measurement struct
# =============================================================================
@fieldwise_init
@register_passable("trivial")
struct MeasurementFloat(Copyable & Movable & Writable):
    var min: Float64
    var mean: Float64
    var max: Float64
    var n: Float64

    fn update(mut self, val: Float64):
        self.min = min(val, self.min)
        self.max = max(val, self.max)
        self.mean = (self.mean * self.n + val) / (self.n + 1.0)
        self.n += 1.0

    fn __str__(self) -> String:
        return String(
            round(self.min, 1),
            "/",
            round(self.mean, 1),
            "/",
            round(self.max, 1),
        )

    fn write_to(self, mut writer: Some[Writer]):
        writer.write(self.__str__())


@register_passable("trivial")
struct MeasurementInt(Copyable & Movable & Writable):
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
        var min = Float32(self.min) / 10.0
        var max = Float32(self.max) / 10.0
        var mean = Float32(self.sum) / 10.0 / Float32(self.n)
        return String(round(min, 1), "/", round(mean, 1), "/", round(max, 1))

    fn write_to(self, mut writer: Some[Writer]):
        writer.write(self.__str__())


# =============================================================================
# format_output
# =============================================================================
fn format_output[
    M: Copyable & Movable & Writable
](d: Dict[String, M]) raises -> String:
    """
    Format the results in the expected 1BRC format: {city1=min/mean/max, city2=min/mean/max, ...}
    Cities are sorted alphabetically.
    """
    var cities = List[String]()
    for entry in d.items():
        cities.append(entry.key)
    sort(cities)

    var result = String("{")
    for i in range(len(cities)):
        var city = cities[i]
        var measurement = d[city].copy()
        if i > 0:
            result += ", \n"
        result += city + "=" + String(measurement)
    result += "}"
    return result


fn format_output[
    M: Copyable & Movable & Writable
](
    final_dict: Dict[UInt64, M],
    city_names: Dict[UInt64, String],
) raises -> String:
    var cities = List[String]()
    for entry in city_names.items():
        cities.append(entry.value)
    sort(cities)

    var result = String("{")
    for i in range(len(cities)):
        var city = cities[i]
        var city_bytes = city.as_bytes()
        var hash_city = fast_hash(city_bytes.unsafe_ptr(), len(city_bytes))
        var measurement = final_dict[hash_city].copy()
        if i > 0:
            result += ", \n"
        result += city + "=" + String(measurement)

    result += "}"
    return result


# =============================================================================
# process_chunk
# =============================================================================
fn fast_hash(data: UnsafePointer[UInt8], length: Int) -> UInt64:
    # Simple inline hash - no string allocation!
    var h: UInt64 = 0
    for i in range(length):
        h = h * 31 + UInt64(data[i])
    return h


fn process_chunk[
    temp_alg: String = "v5", try_update: Bool = False
](
    data: Span[UInt8],
    start: Int,
    end: Int,
    mut d: Dict[UInt64, MeasurementInt],
    mut city_names: Dict[UInt64, String],
) raises -> None:
    var data_ptr = data.unsafe_ptr()
    var pos = start
    var line_start = pos

    while pos + simd_width < end:
        var chunk = data_ptr.load[width=simd_width](pos)
        var newlines = pack_bits[bits_type](chunk.eq(new_line))
        var semicolons = pack_bits[bits_type](chunk.eq(middle))

        if newlines == 0:
            # to not break temperature in two chunks
            pos += Int(count_leading_zeros(semicolons))
            continue

        var start_of_line_idx = 0

        while newlines != 0:
            var newline_idx = count_trailing_zeros(newlines)
            var search_mask = (1 << newline_idx) - (1 << start_of_line_idx)

            # Parse city
            var semicolon_idx = count_trailing_zeros(semicolons & search_mask)
            var city_len = pos + Int(semicolon_idx) - line_start
            var hash_city = fast_hash(data_ptr + line_start, city_len)

            # parse value
            alias vec_3d = SIMD[DType.int16, 4](100, 10, 0, 1)  # dd.d
            alias vec_2d = SIMD[DType.int16, 4](10, 0, 1, 0)  # d.dX

            var val_start_idx = pos + semicolon_idx + 1
            var num_len = newline_idx - (semicolon_idx + 1)

            var is_neg = data[val_start_idx] == NEG
            var sign = 1 - (Int(is_neg) << 1)

            var val_abs_start = val_start_idx + Int(is_neg)

            var val: Int16

            @parameter
            if temp_alg == "v2":
                var digits = SIMD[DType.int16, 4](
                    data_ptr.load[width=4](val_abs_start) - ZERO
                )
                var val_long = (digits * vec_3d).reduce_add()
                var val_short = (digits * vec_2d).reduce_add()

                var is_short = (num_len - Int(is_neg)) == 3  # d.d
                val = sign * (
                    val_short * Int(is_short) + val_long * Int(not is_short)
                )
            elif temp_alg == "v5":
                alias vec_digits = vec_3d.interleave(vec_2d)

                var digits_4 = SIMD[DType.int16, 4](
                    data_ptr.load[width=4](val_abs_start) - ZERO
                )

                # reduce_add[2] give the sum of the *interleaved* elements
                var digits_8 = digits_4.interleave(digits_4)
                var vals = (digits_8 * vec_digits).reduce_add[2]()

                var is_short = (num_len - Int(is_neg)) == 3  # d.d
                var val_abs = vals[0] * Int(not is_short) + vals[1] * Int(
                    is_short
                )
                val = sign * val_abs
            else:
                raise "unsuported version"

            @parameter
            if try_update:
                try:
                    d[hash_city].update(Int(val))
                except:
                    d[hash_city] = MeasurementInt(Int(val))
                    city_names[hash_city] = String(
                        bytes=data[line_start : pos + Int(semicolon_idx)]
                    )
            else:
                if hash_city in d:
                    d[hash_city].update(Int(val))
                else:
                    d[hash_city] = MeasurementInt(Int(val))
                    city_names[hash_city] = String(
                        bytes=data[line_start : pos + Int(semicolon_idx)]
                    )

            start_of_line_idx = Int(newline_idx) + 1
            line_start = pos + start_of_line_idx
            newlines &= ~(1 << newline_idx)

        pos += start_of_line_idx

    # tail = scalar
    if pos < end:
        var tail = String(bytes=data[pos : end - 1])
        for l in tail.split("\n"):
            if len(l) == 0:
                continue
            var station = l.split(";")
            var city = String(station[0])
            var val = atol(station[1].replace(".", ""))

            # Hash the city for tail processing
            var city_bytes = city.as_bytes()
            var hash_city = fast_hash(city_bytes.unsafe_ptr(), len(city_bytes))

            if d.get(hash_city):
                d[hash_city].update(val)
            else:
                d[hash_city] = MeasurementInt(val)
                city_names[hash_city] = city


# =============================================================================
# parallel
# =============================================================================
fn find_next_newline(data: Span[UInt8], start: Int) -> Int:
    """Find the next newline after start position."""
    for i in range(start, len(data)):
        if data[i] == ord("\n"):
            return i + 1  # Return position AFTER newline
    return len(data)


fn process_parallel[
    try_update: Bool = False
](data: Span[UInt8]) raises -> String:
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
    var thread_city_names = List[Dict[UInt64, String]](
        length=num_workers, fill={}
    )

    # Process chunks in parallel
    @parameter
    fn process_worker(worker_id: Int):
        var start = chunk_starts[worker_id]
        var end = chunk_ends[worker_id]
        try:
            process_chunk[try_update=try_update](
                data,
                start,
                end,
                thread_dicts[worker_id],
                thread_city_names[worker_id],
            )
        except:
            print("oopsie")

    parallelize[process_worker](num_workers)

    # Merge results from all threads
    var final_dict = thread_dicts[0].copy()
    var final_city_names = thread_city_names[0].copy()

    for worker_id in range(1, num_workers):  # skip first one
        for entry in thread_dicts[worker_id].items():
            var hash_key = entry.key
            var measurement = entry.value

            try:
                final_dict[hash_key].merge(measurement)
            except:
                final_dict[hash_key] = measurement
                final_city_names[hash_key] = thread_city_names[worker_id][
                    hash_key
                ]

    return format_output(final_dict, final_city_names)


# =============================================================================
# Memory Mapped File
# =============================================================================
struct MMap:
    """Simple memory-mapped file for reading."""

    var _data: UnsafePointer[UInt8, MutOrigin.external]
    var _size: Int

    fn __init__(out self, path: String) raises:
        """Memory map a file for reading.
        Args:
            path: Path to the file.
        """
        # Open file
        var fd = external_call["open", Int](path.unsafe_ptr(), 0, 0)  # O_RDONLY
        if fd < 0:
            raise Error("Failed to open file: " + path)

        # Get file size
        var stat_buf = alloc[Int](20)
        var ret = external_call["fstat", Int](fd, stat_buf)
        if ret != 0:
            stat_buf.free()
            _ = external_call["close", Int](fd)
            raise Error("Failed to get file size")

        self._size = stat_buf[6]  # st_size
        stat_buf.free()

        # Memory map the file
        # mmap returns a pointer - we specify the return type and Mojo handles the conversion
        self._data = external_call[
            "mmap", UnsafePointer[UInt8, MutOrigin.external]
        ](
            UnsafePointer[
                UInt8, MutOrigin.external
            ](),  # addr (let kernel choose)
            self._size,  # length
            1,  # PROT_READ
            1,  # MAP_SHARED
            fd,  # fd
            0,  # offset
        )

        # Close fd (not needed after mmap)
        _ = external_call["close", Int](fd)

        # Check if mmap failed (returns MAP_FAILED which is -1 cast to pointer)
        if Int(self._data) == -1:
            raise Error("mmap failed")

    fn __del__(deinit self):
        """Unmap the memory."""
        if self._data:
            _ = external_call["munmap", Int](self._data, self._size)

    fn __getitem__(self, idx: Int) -> UInt8:
        """Get byte at index."""
        return self._data[idx]

    fn read[width: Int](self, start: Int) -> SIMD[DType.uint8, width]:
        """Read a SIMD vector of bytes at the given offset."""
        return self._data.load[width=width](start)

    fn as_span[
        mut: Bool,
        origin: Origin[mut], //,
    ](ref [origin]self) -> Span[UInt8, origin]:
        return Span(
            ptr=self._data.mut_cast[mut]().unsafe_origin_cast[origin](),
            length=self._size,
        )


# =============================================================================
# dispatch function
# =============================================================================
fn process_1brc[version: Int](file_path: String) raises -> String:
    """
    Unified 1BRC processor using compile-time version selection.

    Versions:
    - 0: Basic string operations with Float64
    - 1: Fixed-point Int arithmetic
    - 2: SIMD parsing + Hash-based city lookup (no string allocation)
    - 3: Improved SIMD with interleave
    - 4: Parallel processing
    - 5: Memory Mapped File
    - 6: if-else -> try-catch
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
                if d.get(city):
                    d[city].update(val)
                else:
                    d[city] = MeasurementFloat(val, val, val, 1.0)
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
                var m_maybe = d.get(city)
                if m_maybe:
                    var m = m_maybe.value().copy()
                    m.min = min(val, m.min)
                    m.max = max(val, m.max)
                    m.n += 1
                    m.sum += val
                    d[city] = m
                else:
                    d[city] = MeasurementInt(val)
        return format_output(d)

    elif version == 2:
        var d = Dict[UInt64, MeasurementInt](power_of_two_initial_capacity=1024)
        var city_names = Dict[UInt64, String](
            power_of_two_initial_capacity=1024
        )
        var file = open(file_path, "r")
        var data = Span[mut=False](file.read_bytes())

        process_chunk[temp_alg="v2"](
            data,
            0,
            len(data) - 1,
            d,
            city_names,
        )
        return format_output(d, city_names)

    elif version == 3:
        var d = Dict[UInt64, MeasurementInt](power_of_two_initial_capacity=1024)
        var city_names = Dict[UInt64, String](
            power_of_two_initial_capacity=1024
        )
        var file = open(file_path, "r")
        var data = Span[mut=False](file.read_bytes())

        process_chunk(
            data,
            0,
            len(data) - 1,
            d,
            city_names,
        )

        return format_output(d, city_names)

    elif version == 4:
        var file = open(file_path, "r")
        var data = Span[mut=False](file.read_bytes())
        file.close()
        return process_parallel(data)

    elif version == 5:
        var mmap_file = MMap(file_path)
        var data = mmap_file.as_span()
        return process_parallel(data)

    elif version == 6:
        var mmap_file = MMap(file_path)
        var data = mmap_file.as_span()
        return process_parallel[True](data)

    else:
        raise "unsuported version"


fn main() raises:
    alias file_path = "./measurements.txt"

    print("1BRC Unified Implementation")
    print("Cores:", num_physical_cores())
    print()

    @parameter
    fn test_version[v: Int]():
        try:
            print("Testing v" + String(v) + "...")
            var result = process_1brc[v](file_path)
            var result_hash = hash(result)
            print("  Hash:", result_hash)

            # Save output
            var filename = String("output_v", v, ".txt")
            with open(filename, "w") as f:
                f.write(result)
        except e:
            print("  Error:", e)

    test_version[0]()
    test_version[1]()
    test_version[2]()
    test_version[3]()
    test_version[4]()
    test_version[5]()
    test_version[6]()

    print("\nBenchmarking...")

    @parameter
    fn bench_version[v: Int]() raises:
        fn bench_fn() raises:
            _ = process_1brc[v](file_path)

        var time_ms = run[bench_fn](max_iters=10).mean(Unit.ms)
        print("v" + String(v) + ":", round(time_ms, 1), "ms")

    bench_version[0]()
    bench_version[1]()
    bench_version[2]()
    bench_version[3]()
    bench_version[4]()
    bench_version[5]()
    bench_version[6]()
