from sys.ffi import external_call
from sys.info import simd_width_of
from memory import pack_bits
from bit import count_leading_zeros, count_trailing_zeros


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


fn v3(file_path: String) raises -> String:
    var d = Dict[UInt64, Measurement](power_of_two_initial_capacity=1024)
    var city_names = Dict[UInt64, String](
        power_of_two_initial_capacity=1024
    )  # Only for final output
    var file = open(file_path, "r")
    var data = Span[mut=False](file.read_bytes())

    var start: Int = 0
    var end = len(data) - 1
    var i = 0

    alias middle = ord(";")
    alias new_line = ord("\n")
    alias NEG = ord("-")
    alias ZERO = ord("0")
    alias DOT = ord(".")

    var data_ptr = data.unsafe_ptr()

    while start < end:
        # tail = scalar
        if start + simd_width > end:
            var tail = String(bytes=data[start : end - 1])
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
            break

        var chunk = data_ptr.load[width=simd_width](start)
        var newlines = pack_bits[DType.uint64](chunk.eq(new_line))
        var semicolons = pack_bits[DType.uint64](chunk.eq(middle))

        var start_of_line_idx = 0

        while newlines != 0:
            var newline_idx = count_trailing_zeros(newlines)

            var search_mask = (1 << newline_idx) - (1 << start_of_line_idx)

            # Parse city
            var semicolon_idx = count_trailing_zeros(semicolons & search_mask)
            var city_len = Int(semicolon_idx) - start_of_line_idx
            var hash_city = fast_hash(
                data_ptr + start + start_of_line_idx, city_len
            )

            # parse value
            alias vec_3d = SIMD[DType.int32, 4](100, 10, 0, 1)  # dd.d
            alias vec_2d = SIMD[DType.int32, 4](10, 0, 1, 0)  # d.d

            var val_start_idx = start + semicolon_idx + 1
            var num_len = newline_idx - (semicolon_idx + 1)

            var is_neg = data[val_start_idx] == NEG
            var sign = 1 - (Int(is_neg) << 1)

            var val_abs_start = val_start_idx + Int(is_neg)
            var digits = SIMD[DType.int32, 4](
                data_ptr.load[width=4](val_abs_start) - ZERO
            )
            var val_long = (digits * vec_3d).reduce_add()
            var val_short = (digits * vec_2d).reduce_add()

            var is_short = (num_len - Int(is_neg)) == 3  # d.d
            var val = sign * (
                val_short * Int(is_short) + val_long * Int(not is_short)
            )

            if d.get(hash_city):
                d[hash_city].update(Int(val))
            else:
                d[hash_city] = Measurement(Int(val))
                city_names[hash_city] = String(
                    bytes=data[
                        start
                        + start_of_line_idx : start
                        + Int(semicolon_idx)
                    ]
                )

            start_of_line_idx = Int(newline_idx) + 1
            newlines &= ~(1 << newline_idx)

        start += start_of_line_idx

    var output = format_output(d, city_names)
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
        var measurement = final_dict[hash_city].copy()

        # Add to result
        if i > 0:
            result += ", \n"

        result += city + "=" + String(measurement)

    result += "}"
    return result
