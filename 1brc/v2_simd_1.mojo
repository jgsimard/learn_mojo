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


fn parse_station[
    simd_width: Int
](data: Span[UInt8], mut start: Int, end: Int) raises -> List[(String, Int)]:
    alias middle = ord(";")
    alias new_line = ord("\n")
    alias NEG = ord("-")
    alias ZERO = ord("0")
    alias DOT = ord(".")

    var data_ptr = data.unsafe_ptr()
    var stations = List[(String, Int)]()

    # tail = scalar
    if start + simd_width > end:
        var tail = String(bytes=data[start : end - 1])
        for l in tail.split("\n"):
            var station = l.split(";")
            var city = String(station[0])
            var val = atol(station[1].replace(".", ""))
            stations.append((city, val))
        start = end
        return stations^

    var chunk = data_ptr.load[width=simd_width](start)
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
            var city = String(
                bytes=data[
                    start + start_of_line_idx : start + Int(semicolon_idx)
                ]
            )

            # parse value
            var val_start_idx = start + semicolon_idx + 1
            var num_len = newline_idx - (semicolon_idx + 1)

            var is_neg = data[val_start_idx] == NEG
            var sign = 1 - (Int(is_neg) << 1)

            var val_abs_start = val_start_idx + Int(is_neg)
            var digits = data_ptr.load[width=4](val_abs_start) - ZERO
            var d0 = Int(digits[0])
            var d1 = Int(digits[1])
            var d2 = Int(digits[2])
            var d3 = Int(digits[3])

            var is_short = (num_len - Int(is_neg)) == 3  # d.d
            var val_short = d0 * 10 + d2
            var val_long = d0 * 100 + d1 * 10 + d3
            var val = sign * (
                val_short * Int(is_short) + val_long * Int(not is_short)
            )

            stations.append((city, val))

        start_of_line_idx = Int(newline_idx) + 1
        newlines &= ~(1 << newline_idx)

    start += start_of_line_idx

    return stations^


fn v2(file_path: String) raises -> String:
    var d = Dict[String, Measurement]()
    var file = open(file_path, "r")
    var data = Span[mut=False](file.read_bytes())
    file.close()

    var position: Int = 0
    var end = len(data)

    while position < end:
        var stations = parse_station[simd_width](data, position, end)
        for station in stations:
            var city = station[0]
            var val = station[1]

            if d.get(city):
                d[city].update(val)
            else:
                d[city] = Measurement(val)

    return String(
        "V2, Assab: ",
        d["Assab"],
        ", Detroit: ",
        d["Detroit"],
        ", Veracruz: ",
        d["Veracruz"],
    )
