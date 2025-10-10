from sys.ffi import external_call
from sys.info import simd_width_of
from memory import pack_bits
from bit import count_leading_zeros, count_trailing_zeros
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


# alias simd_width = simd_width_of[DType.uint8]()
alias simd_width = 64


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

    while pos + simd_width < end:
        var chunk = data_ptr.load[width=simd_width](pos)
        var newlines = pack_bits[DType.uint64](chunk.eq(new_line))
        var semicolons = pack_bits[DType.uint64](chunk.eq(middle))

        var start_of_line_idx = 0

        while newlines != 0:
            var newline_idx = count_trailing_zeros(newlines)

            var search_mask = (1 << newline_idx) - (1 << start_of_line_idx)
            var relevant_semicolons = semicolons & search_mask

            if relevant_semicolons != 0:
                # Parse city
                var semicolon_idx = count_trailing_zeros(relevant_semicolons)
                var city_len = Int(semicolon_idx) - start_of_line_idx
                var hash_city = fast_hash(
                    data_ptr + pos + start_of_line_idx, city_len
                )

                # parse value
                # interlived version of
                alias vec_3d = SIMD[DType.int16, 4](100, 10, 0, 1)  # dd.d
                alias vec_2d = SIMD[DType.int16, 4](10, 0, 1, 0)  # d.dX
                alias vec_digits = vec_3d.interleave(vec_2d)

                var val_start_idx = pos + semicolon_idx + 1
                var num_len = newline_idx - (semicolon_idx + 1)

                var is_neg = data[val_start_idx] == NEG
                var sign = 1 - (Int(is_neg) << 1)

                var val_abs_start = val_start_idx + Int(is_neg)
                var digits_4 = SIMD[DType.int16, 4](
                    data_ptr.load[width=4](val_abs_start) - ZERO
                )

                # reduce_add[2] give the sum of the *interleaved* elements
                var digits_8 = digits_4.interleave(digits_4)
                var vals = (digits_8 * vec_digits).reduce_add[2]()

                var is_short = (num_len - Int(is_neg)) == 3  # d.d
                # a little bit slower with the following simd
                # var mask = SIMD[DType.int16, 2](Int(not is_short), Int(is_short))
                # var val_abs = (vals * mask).reduce_add()
                var val_abs = vals[0] * Int(not is_short) + vals[1] * Int(
                    is_short
                )
                var val = sign * val_abs

                if hash_city in d:
                    d[hash_city].update(Int(val))
                else:
                    d[hash_city] = Measurement(Int(val))
                    city_names[hash_city] = String(
                        bytes=data[
                            pos + start_of_line_idx : pos + Int(semicolon_idx)
                        ]
                    )

            start_of_line_idx = Int(newline_idx) + 1
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
            var hash_city = fast_hash(
                city_bytes.unsafe_ptr(), len(city_bytes)
            )

            if d.get(hash_city):
                d[hash_city].update(val)
            else:
                d[hash_city] = Measurement(val)
                city_names[hash_city] = city


fn find_next_newline(data: Span[UInt8], start: Int) -> Int:
    """Find the next newline after start position."""
    for i in range(start, len(data)):
        if data[i] == ord("\n"):
            return i + 1  # Return position AFTER newline
    return len(data)


fn v6(file_path: String) raises -> String:
    var file = open(file_path, "r")
    var data = Span[mut=False](file.read_bytes())

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
    
    # Simple bubble sort (you could use a more efficient sort if needed)
    var n = len(cities)
    for i in range(n):
        for j in range(0, n - i - 1):
            if cities[j] > cities[j + 1]:
                var temp = cities[j]
                cities[j] = cities[j + 1]
                cities[j + 1] = temp
    
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