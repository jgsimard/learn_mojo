from sys.ffi import external_call
from sys.info import simd_width_of
from memory import pack_bits, bitcast
from bit import count_leading_zeros, count_trailing_zeros, byte_swap
from algorithm import parallelize
from sys import num_physical_cores


@register_passable("trivial")
struct Measurement(Copyable, Movable, Writable):
    var min: Int
    var max: Int
    var sum: Int
    var n: Int

    fn __init__(out self, val: Int):
        self.min = val
        self.max = val
        self.sum = val
        self.n = 1

    fn update(mut self, val: Int):
        self.min = min(val, self.min)
        self.max = max(val, self.max)
        self.sum += val
        self.n += 1

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


alias simd_width = simd_width_of[DType.uint8]()
alias bits_type = DType.uint64 if simd_width == 64 else DType.uint32


fn fast_hash(data: UnsafePointer[UInt8], length: Int) -> UInt64:
    # Simple inline hash - no string allocation!
    var h: UInt64 = 0
    for i in range(length):
        h = h * 31 + UInt64(data[i])
    return h


fn process_chunk(
    data: Span[UInt8],
    start: Int,
    end: Int,
    mut d: Dict[UInt64, Measurement],
    mut city_names: Dict[UInt64, String],
) raises -> None:
    alias middle = ord(";")
    alias new_line = ord("\n")
    alias NEG = ord("-")
    alias ZERO = ord("0")
    alias DOT = ord(".")

    var data_ptr = data.unsafe_ptr()
    var pos = start
    var line_start = pos

    while pos + simd_width <= end:
        var chunk = data_ptr.load[width=simd_width](pos)
        var newlines = pack_bits[bits_type](chunk.eq(new_line))
        var semicolons = pack_bits[bits_type](chunk.eq(middle))

        if newlines == 0:
            # to no break temperature in two chunks
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
            # 1BRC merykitty’s Magic SWAR
            # https://questdb.com/blog/1brc-merykittys-magic-swar/
            alias MAGIC_MULTIPLIER: Int64 = (
                100 * 0x1000000 + 10 * 0x10000 + 1
            )
            alias DOT_DETECTOR: Int64 = 0x10101000
            alias ASCII_TO_DIGIT_MASK: Int64 = 0x0F000F0F00

            var val_start_idx = pos + semicolon_idx + 1

            var u8x8 = data_ptr.load[width=8](val_start_idx)
            var inputData = bitcast[DType.int64, 1](u8x8)

            # long negatedInput = ~inputData;
            var negatedInput = ~inputData
            # long broadcastSign = (negatedInput << 59) >> 63;
            var broadcastSign = (negatedInput << 59) >> 63
            # long maskToRemoveSign = ~(broadcastSign & 0xFF);
            var maskToRemoveSign = ~(broadcastSign & 0xFF)
            # long withSignRemoved = inputData & maskToRemoveSign;
            var withSignRemoved = inputData & maskToRemoveSign
            # int dotPos = Long.numberOfTrailingZeros(negatedInput & DOT_DETECTOR);
            var dotPos = count_trailing_zeros(negatedInput & DOT_DETECTOR)
            # long alignedToTemplate = withSignRemoved << (28 - dotPos);
            var alignedToTemplate = withSignRemoved << (28 - dotPos)
            # long digits = alignedToTemplate & ASCII_TO_DIGIT_MASK;
            var digits = alignedToTemplate & ASCII_TO_DIGIT_MASK
            # long absValue = ((digits * MAGIC_MULTIPLIER) >>> 32) & 0x3FF;
            var absValue = ((digits * MAGIC_MULTIPLIER) >> 32) & 0x3FF
            # long temperature = (absValue ^ broadcastSign) - broadcastSign;
            var temperature = (absValue ^ broadcastSign) - broadcastSign

            var val = temperature

            if hash_city in d:
                d[hash_city].update(Int(val))
            else:
                d[hash_city] = Measurement(Int(val))
                city_names[hash_city] = String(
                    bytes=data[line_start : pos + Int(semicolon_idx)]
                )

            start_of_line_idx = Int(newline_idx) + 1
            line_start = pos + start_of_line_idx
            newlines &= ~(1 << newline_idx)

        pos += start_of_line_idx

    # tail = scalar
    while pos < end:
        var line_start = pos

        var semicolon_pos = line_start
        while data[semicolon_pos] != middle:
            semicolon_pos += 1

        var city_len = semicolon_pos - line_start
        var city_ptr = data_ptr + line_start

        var hash_city = fast_hash(city_ptr, city_len)

        var val_pos = semicolon_pos + 1
        var sign = 1

        if data[val_pos] == NEG:
            sign = -1
            val_pos += 1

        var val: Int = 0
        while val_pos < end:
            var char = data[val_pos]
            if char == new_line:
                pos = val_pos + 1
                break

            if char != DOT:
                val = Int(val * 10 + (char - ZERO))

            val_pos += 1

        val *= sign

        if hash_city in d:
            d[hash_city].update(val)
        else:
            d[hash_city] = Measurement(val)
            city_names[hash_city] = String(bytes=data[line_start:semicolon_pos])


fn find_next_newline(data: Span[UInt8], start: Int) -> Int:
    """Find the next newline after start position."""
    for i in range(start, len(data)):
        if data[i] == ord("\n"):
            return i + 1  # Return position AFTER newline
    return len(data)


struct MMap:
    """Simple memory-mapped file for reading."""

    var data: UnsafePointer[UInt8]
    var size: Int

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
        var stat_buf = UnsafePointer[Int].alloc(20)
        var ret = external_call["fstat", Int](fd, stat_buf)
        if ret != 0:
            stat_buf.free()
            _ = external_call["close", Int](fd)
            raise Error("Failed to get file size")

        self.size = stat_buf[6]  # st_size
        stat_buf.free()

        # Memory map the file
        var addr = external_call["mmap", UnsafePointer[UInt8]](
            UnsafePointer[UInt8](),  # addr (let kernel choose)
            self.size,  # length
            1,  # PROT_READ
            1,  # MAP_SHARED
            fd,  # fd
            0,  # offset
        )

        # Close fd (not needed after mmap)
        _ = external_call["close", Int](fd)

        if Int(addr) == -1:
            raise Error("mmap failed")

        self.data = addr

    fn __del__(deinit self):
        """Unmap the memory."""
        if self.data:
            _ = external_call["munmap", Int](self.data, self.size)

    fn __getitem__(self, idx: Int) -> UInt8:
        """Get byte at index."""
        return self.data[idx]

    fn read[width: Int](self, start: Int) -> SIMD[DType.uint8, width]:
        return self.data.load[width=width](start)


fn v8(file_path: String) raises -> String:
    var d = Dict[UInt64, Measurement](power_of_two_initial_capacity=1024)
    var city_names = Dict[UInt64, String](power_of_two_initial_capacity=1024)
    # var file = open(file_path, "r")
    # var data = Span[mut=False](file.read_bytes())
    var mmap_file = MMap(file_path)
    var data = Span[mut=False](mmap_file.data, mmap_file.size)

    var start: Int = 0
    var end = len(data) - 1

    var num_workers = num_physical_cores()
    var chunk_size = len(data) // num_workers

    # Calculate aligned chunk boundaries
    var chunk_starts = List[Int]()
    var chunk_ends = List[Int]()

    chunk_starts.append(0)

    for i in range(1, num_workers):
        var approx_start = i * chunk_size
        var aligned_start = find_next_newline(data, approx_start)
        chunk_starts.append(aligned_start)
        chunk_ends.append(aligned_start)

    chunk_ends.append(len(data))

    # Create per-thread storage
    var thread_dicts = List[Dict[UInt64, Measurement]](capacity=num_workers)
    var thread_city_names = List[Dict[UInt64, String]](capacity=num_workers)

    for _ in range(num_workers):
        thread_dicts.append(
            Dict[UInt64, Measurement](power_of_two_initial_capacity=1024)
        )
        thread_city_names.append(
            Dict[UInt64, String](power_of_two_initial_capacity=1024)
        )

    # Process chunks in parallel
    @parameter
    fn process_worker(worker_id: Int):
        var start = chunk_starts[worker_id]
        var end = chunk_ends[worker_id]
        try:
            process_chunk(
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
    var final_dict = Dict[UInt64, Measurement](
        power_of_two_initial_capacity=1024
    )
    var final_city_names = Dict[UInt64, String](
        power_of_two_initial_capacity=1024
    )

    for worker_id in range(num_workers):
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

    var output = format_output(final_dict, final_city_names)
    return output^


fn format_output(
    final_dict: Dict[UInt64, Measurement],
    city_names: Dict[UInt64, String],
) raises -> String:
    """Format the results in the expected 1BRC format: {city1=min/mean/max, city2=min/mean/max, ...}

    Cities are sorted alphabetically.
    """
    # Collect all city names and sort them
    var cities = List[String]()
    for entry in city_names.items():
        cities.append(entry.value)

    sort(cities)

    # Build output string
    var result = String("{")

    for i in range(len(cities)):
        var city = cities[i]

        # Get the hash for this city
        var city_bytes = city.as_bytes()
        var hash_city = fast_hash(city_bytes.unsafe_ptr(), len(city_bytes))

        # Get the measurement
        var measurement = final_dict[hash_city]

        # Add to result
        if i > 0:
            result += ", \n"

        result += city + "=" + String(measurement)

    result += "}"
    return result
