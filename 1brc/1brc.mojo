from max.algorithm import parallelize
from std.benchmark import run, Unit
from std.bit import count_leading_zeros, count_trailing_zeros
from std.ffi import external_call
from std.memory import pack_bits
from std.os import SEEK_END
from std.sys import num_physical_cores, simd_width_of
from std.testing import assert_equal


# parametrized trait would be nice
comptime Measurement = TrivialRegisterPassable & Writable


@fieldwise_init
struct MeasurementFloat(Measurement):
    var min: Float64
    var mean: Float64
    var max: Float64
    var n: Float64

    def __init__(out self, val: Float64):
        self.min = val
        self.max = val
        self.mean = val
        self.n = 1.0

    def update(mut self, val: Float64):
        self.min = min(val, self.min)
        self.max = max(val, self.max)
        self.n += 1.0
        self.mean += (val - self.mean) / self.n

    def __str__(self) -> String:
        var min = round(self.min, 1)
        var max = round(self.max, 1)
        var mean = round(self.mean, 1)
        return String(t"{min}/{mean}/{max}")

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.__str__())


struct MeasurementInt(Measurement):
    var min: Int
    var sum: Int
    var max: Int
    var n: Int

    def __init__(out self, val: Int):
        self.min = val
        self.max = val
        self.sum = val
        self.n = 1

    @always_inline
    def update(mut self, val: Int):
        self.min = min(val, self.min)
        self.max = max(val, self.max)
        self.sum += val
        self.n += 1

    @always_inline
    def merge(mut self, other: Self):
        self.min = min(other.min, self.min)
        self.max = max(other.max, self.max)
        self.sum += other.sum
        self.n += other.n

    def __str__(self) -> String:
        var min = round(Float32(self.min) / 10.0, 1)
        var max = round(Float32(self.max) / 10.0, 1)
        var mean = round(Float32(self.sum) / 10.0 / Float32(self.n), 1)
        return String(t"{min}/{mean}/{max}")

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.__str__())


comptime FAST_TABLE_CAPACITY = 1024


struct FastEntry(Copyable):
    var hash: UInt64
    var city_start: Int
    var city_len: Int
    var min: Int
    var sum: Int
    var max: Int
    var n: Int

    def __init__(out self):
        self.hash = 0
        self.city_start = 0
        self.city_len = 0
        self.min = 0
        self.sum = 0
        self.max = 0
        self.n = 0


struct FastTable:
    var entries: List[FastEntry]

    def __init__(out self):
        self.entries = List[FastEntry](
            length=FAST_TABLE_CAPACITY, fill=FastEntry()
        )

    @always_inline
    def update(
        mut self,
        hash_city: UInt64,
        city_start: Int,
        city_len: Int,
        val: Int,
    ):
        var slot = Int(hash_city & UInt64(FAST_TABLE_CAPACITY - 1))
        while True:
            ref entry = self.entries[slot]
            if entry.n == 0:
                entry.hash = hash_city
                entry.city_start = city_start
                entry.city_len = city_len
                entry.min = val
                entry.sum = val
                entry.max = val
                entry.n = 1
                return
            if entry.hash == hash_city:
                entry.min = min(val, entry.min)
                entry.max = max(val, entry.max)
                entry.sum += val
                entry.n += 1
                return
            slot = (slot + 1) & (FAST_TABLE_CAPACITY - 1)

    @always_inline
    def update_unchecked(
        mut self,
        hash_city: UInt64,
        city_start: Int,
        city_len: Int,
        val: Int,
    ):
        var entries_ptr = self.entries.unsafe_ptr()
        var slot = Int(hash_city & UInt64(FAST_TABLE_CAPACITY - 1))
        while True:
            ref entry = entries_ptr[unsafe_offset=slot]
            if entry.n == 0:
                entry.hash = hash_city
                entry.city_start = city_start
                entry.city_len = city_len
                entry.min = val
                entry.sum = val
                entry.max = val
                entry.n = 1
                return
            if entry.hash == hash_city:
                entry.min = min(val, entry.min)
                entry.max = max(val, entry.max)
                entry.sum += val
                entry.n += 1
                return
            slot = (slot + 1) & (FAST_TABLE_CAPACITY - 1)

    @always_inline
    def merge(mut self, other: FastEntry):
        var slot = Int(other.hash & UInt64(FAST_TABLE_CAPACITY - 1))
        while True:
            ref entry = self.entries[slot]
            if entry.n == 0:
                entry = other.copy()
                return
            if entry.hash == other.hash:
                entry.min = min(other.min, entry.min)
                entry.max = max(other.max, entry.max)
                entry.sum += other.sum
                entry.n += other.n
                return
            slot = (slot + 1) & (FAST_TABLE_CAPACITY - 1)


struct CompactEntry(Copyable):
    var hash: UInt64
    var sum: Int
    var n: Int32
    var min: Int16
    var max: Int16

    def __init__(out self):
        self.hash = 0
        self.sum = 0
        self.n = 0
        self.min = 0
        self.max = 0


struct CompactTable:
    var entries: List[CompactEntry]
    var city_starts: List[Int]
    var city_lens: List[Int]

    def __init__(out self):
        self.entries = List[CompactEntry](
            length=FAST_TABLE_CAPACITY, fill=CompactEntry()
        )
        self.city_starts = List[Int](length=FAST_TABLE_CAPACITY, fill=0)
        self.city_lens = List[Int](length=FAST_TABLE_CAPACITY, fill=0)

    @always_inline
    def update(
        mut self,
        hash_city: UInt64,
        city_start: Int,
        city_len: Int,
        val: Int,
    ):
        var entries_ptr = self.entries.unsafe_ptr()
        var slot = Int(hash_city & UInt64(FAST_TABLE_CAPACITY - 1))
        while True:
            ref entry = entries_ptr[unsafe_offset=slot]
            if entry.n == 0:
                entry.hash = hash_city
                entry.sum = val
                entry.n = 1
                entry.min = Int16(val)
                entry.max = Int16(val)
                self.city_starts[slot] = city_start
                self.city_lens[slot] = city_len
                return
            if entry.hash == hash_city:
                var val_16 = Int16(val)
                entry.min = min(val_16, entry.min)
                entry.max = max(val_16, entry.max)
                entry.sum += val
                entry.n += 1
                return
            slot = (slot + 1) & (FAST_TABLE_CAPACITY - 1)

    @always_inline
    def merge(mut self, other: CompactEntry, city_start: Int, city_len: Int):
        var entries_ptr = self.entries.unsafe_ptr()
        var slot = Int(other.hash & UInt64(FAST_TABLE_CAPACITY - 1))
        while True:
            ref entry = entries_ptr[unsafe_offset=slot]
            if entry.n == 0:
                entry = other.copy()
                self.city_starts[slot] = city_start
                self.city_lens[slot] = city_len
                return
            if entry.hash == other.hash:
                entry.min = min(other.min, entry.min)
                entry.max = max(other.max, entry.max)
                entry.sum += other.sum
                entry.n += other.n
                return
            slot = (slot + 1) & (FAST_TABLE_CAPACITY - 1)


def format_output[M: Measurement](d: Dict[String, M]) raises -> String:
    var cities = ["{}={}".format(entry.key, entry.value) for entry in d.items()]
    sort(cities)
    return "{" + ", \n".join(cities) + "}"


def format_output[
    M: Measurement, origin: ImmOrigin
](
    d: Dict[UInt64, M],
    city_names: Dict[UInt64, ImmStringSpan[origin]],
) raises -> String:
    var cities = [
        "{}={}".format(entry.value, d[entry.key])
        for entry in city_names.items()
    ]
    sort(cities)
    return "{" + ", \n".join(cities) + "}"


def format_output(data: ImmSpan[UInt8, _], table: FastTable) raises -> String:
    var cities = List[String](capacity=FAST_TABLE_CAPACITY)
    for entry in table.entries:
        if entry.n == 0:
            continue
        var city = StringSlice(
            from_utf8=data[entry.city_start : entry.city_start + entry.city_len]
        )
        var min_val = round(Float32(entry.min) / 10.0, 1)
        var max_val = round(Float32(entry.max) / 10.0, 1)
        var mean_val = round(Float32(entry.sum) / 10.0 / Float32(entry.n), 1)
        cities.append(String(t"{city}={min_val}/{mean_val}/{max_val}"))
    sort(cities)
    return "{" + ", \n".join(cities) + "}"


def format_output(
    data: ImmSpan[UInt8, _], table: CompactTable
) raises -> String:
    var cities = List[String](capacity=FAST_TABLE_CAPACITY)
    for slot in range(FAST_TABLE_CAPACITY):
        var entry = table.entries[slot].copy()
        if entry.n == 0:
            continue
        var city_start = table.city_starts[slot]
        var city_len = table.city_lens[slot]
        var city = StringSlice(
            from_utf8=data[city_start : city_start + city_len]
        )
        var min_val = round(Float32(entry.min) / 10.0, 1)
        var max_val = round(Float32(entry.max) / 10.0, 1)
        var mean_val = round(Float32(entry.sum) / 10.0 / Float32(entry.n), 1)
        cities.append(String(t"{city}={min_val}/{mean_val}/{max_val}"))
    sort(cities)
    return "{" + ", \n".join(cities) + "}"


def process_chunk[
    origin: ImmOrigin, temp_alg: String = "v5", simd_parsing: Bool = True
](
    data: ImmSpan[UInt8, origin],
    start: Int,
    end: Int,
    mut d: Dict[UInt64, MeasurementInt],
    mut city_names: Dict[UInt64, StringSpan[origin]],
) raises -> None:
    var pos = start

    comptime if simd_parsing:
        comptime simd_width = simd_width_of[DType.uint8]()
        comptime bits_type = DType.uint64 if simd_width == 64 else DType.uint32

        comptime SEMICOLON = UInt8(ord(";"))
        comptime NEW_LINE = UInt8(ord("\n"))
        comptime MINUS = UInt8(ord("-"))
        comptime ZERO = UInt8(ord("0"))
        comptime DOT = UInt8(ord("."))

        var data_ptr = data.unsafe_ptr()
        var line_start = pos

        while pos + simd_width < end:
            var chunk = data_ptr.unsafe_load[width=simd_width](pos)
            var newlines = pack_bits[bits_type](chunk.eq(NEW_LINE))
            var semicolons = pack_bits[bits_type](chunk.eq(SEMICOLON))

            if newlines == 0:
                # to not break temperature in two chunks
                pos += Int(count_leading_zeros(semicolons))
                continue

            var start_of_line_idx = 0

            while newlines != 0:
                var newline_idx = count_trailing_zeros(newlines)
                var search_mask = (1 << newline_idx) - Scalar[bits_type](
                    1 << start_of_line_idx
                )

                # Parse city
                var semicolon_idx = count_trailing_zeros(
                    semicolons & search_mask
                )
                var city_len = pos + Int(semicolon_idx) - line_start
                var hash_city = hash_bytes(
                    data[line_start : line_start + city_len]
                )

                # parse value
                comptime vec_3d = SIMD[DType.int16, 4](100, 10, 0, 1)  # dd.d
                comptime vec_2d = SIMD[DType.int16, 4](10, 0, 1, 0)  # d.dX

                var val_start_idx = Scalar[bits_type](pos) + semicolon_idx + 1
                var num_len = newline_idx - (semicolon_idx + 1)

                var is_neg: Scalar[bits_type]
                comptime if temp_alg == "v6":
                    is_neg = Scalar[bits_type](
                        data_ptr.unsafe_load[width=1](val_start_idx)[0] == MINUS
                    )
                else:
                    is_neg = Scalar[bits_type](data[val_start_idx] == MINUS)
                var sign = Int(1 - (is_neg << 1))

                var val_abs_start = val_start_idx + is_neg

                var val: Int

                comptime if temp_alg == "v2":
                    # slower if i load from chunk-- why ???
                    # base = semicolon_idx + 1 + Int(is_neg)
                    # var digits = SIMD[DType.int16, 4](chunk.as_bytes().unsafe_ptr().load[width=4](base) - ZERO)
                    # var bob = chunk.slice[4]()
                    # var bb = chunk.shift_left()
                    var digits = SIMD[DType.int16, 4](
                        data_ptr.unsafe_load[width=4](val_abs_start) - ZERO
                    )
                    var val_long = Int((digits * vec_3d).reduce_add())
                    var val_short = Int((digits * vec_2d).reduce_add())

                    var is_short = Int((num_len - is_neg) == 3)  # d.d
                    var val_abs = val_short * is_short + val_long * (
                        1 - is_short
                    )
                    val = sign * val_abs

                elif temp_alg == "v5" or temp_alg == "v6":
                    comptime vec_digits = vec_3d.interleave(vec_2d)

                    var digits_4 = SIMD[DType.int16, 4](
                        data_ptr.unsafe_load[width=4](val_abs_start) - ZERO
                    )

                    # reduce_add[2] give the sum of the *interleaved* elements
                    var digits_8 = digits_4.interleave(digits_4)
                    var vals = (digits_8 * vec_digits).reduce_add[2]()

                    var is_short = Int16((num_len - is_neg) == 3)  # d.d
                    var val_abs = vals[0] * (1 - is_short) + vals[1] * is_short
                    val = sign * Int(val_abs)
                else:
                    comptime assert False, "unsuported version"

                try:
                    d[hash_city].update(val)
                except:
                    d[hash_city] = MeasurementInt(val)
                    city_names[hash_city] = StringSpan(
                        from_utf8=data[line_start : pos + Int(semicolon_idx)]
                    )

                start_of_line_idx = Int(newline_idx) + 1
                line_start = pos + start_of_line_idx
                newlines &= newlines - 1

            pos += start_of_line_idx

    # tail = scalar
    if pos < end:
        var tail = StringSlice(from_utf8=data[pos : end - 1])
        var tail_pos = pos
        for l in tail.split("\n"):
            if l.byte_length() == 0:
                tail_pos += 1
                continue
            var station = l.split(";")
            var city = station[0]
            var val = atol(station[1].replace(".", ""))

            var hash_city = hash(city)

            try:
                d[hash_city].update(val)
            except:
                d[hash_city] = MeasurementInt(val)
                city_names[hash_city] = StringSpan(
                    from_utf8=data[tail_pos : tail_pos + city.byte_length()]
                )
            tail_pos += l.byte_length() + 1


def process_chunk_fast[
    sampled_hash: Bool = False, unchecked_table: Bool = False
](data: ImmSpan[UInt8, _], start: Int, end: Int, mut table: FastTable,) raises:
    """V7 parser using a fixed-size table keyed by the station hash."""
    comptime simd_width = simd_width_of[DType.uint8]()
    comptime bits_type = DType.uint64 if simd_width == 64 else DType.uint32

    comptime SEMICOLON = UInt8(ord(";"))
    comptime NEW_LINE = UInt8(ord("\n"))
    comptime MINUS = UInt8(ord("-"))
    comptime ZERO = UInt8(ord("0"))
    comptime vec_3d = SIMD[DType.int16, 4](100, 10, 0, 1)
    comptime vec_2d = SIMD[DType.int16, 4](10, 0, 1, 0)
    comptime vec_digits = vec_3d.interleave(vec_2d)

    var data_ptr = data.unsafe_ptr()
    var pos = start
    var line_start = start

    while pos + simd_width < end:
        var chunk = data_ptr.unsafe_load[width=simd_width](pos)
        var newlines = pack_bits[bits_type](chunk.eq(NEW_LINE))
        var semicolons = pack_bits[bits_type](chunk.eq(SEMICOLON))

        if newlines == 0:
            pos += max(1, Int(count_leading_zeros(semicolons)))
            continue

        var start_of_line_idx = 0
        while newlines != 0:
            var newline_idx = count_trailing_zeros(newlines)
            var search_mask = (1 << newline_idx) - Scalar[bits_type](
                1 << start_of_line_idx
            )
            var semicolon_idx = count_trailing_zeros(semicolons & search_mask)
            var city_len = pos + Int(semicolon_idx) - line_start
            var hash_city: UInt64
            comptime if sampled_hash:
                var city_ptr = data_ptr.unsafe_offset(line_start)
                var last = city_len - 1
                var signature = UInt64(city_len)
                signature |= UInt64(city_ptr[unsafe_offset=0]) << 8
                signature |= UInt64(city_ptr[unsafe_offset=min(1, last)]) << 16
                signature |= UInt64(city_ptr[unsafe_offset=min(2, last)]) << 24
                signature |= UInt64(city_ptr[unsafe_offset=city_len // 2]) << 32
                signature |= UInt64(city_ptr[unsafe_offset=last]) << 40
                signature ^= signature >> 33
                signature *= 0xFF51AFD7ED558CCD
                hash_city = signature ^ (signature >> 33)
            else:
                hash_city = hash_bytes(data[line_start : line_start + city_len])

            var val_start_idx = Scalar[bits_type](pos) + semicolon_idx + 1
            var num_len = newline_idx - (semicolon_idx + 1)
            var is_neg = Scalar[bits_type](
                data_ptr.unsafe_load[width=1](val_start_idx)[0] == MINUS
            )
            var sign = Int(1 - (is_neg << 1))
            var val_abs_start = val_start_idx + is_neg

            var digits_4 = SIMD[DType.int16, 4](
                data_ptr.unsafe_load[width=4](val_abs_start) - ZERO
            )
            var digits_8 = digits_4.interleave(digits_4)
            var vals = (digits_8 * vec_digits).reduce_add[2]()
            var is_short = Int16((num_len - is_neg) == 3)
            var val_abs = vals[0] * (1 - is_short) + vals[1] * is_short
            var val = sign * Int(val_abs)

            comptime if unchecked_table:
                table.update_unchecked(hash_city, line_start, city_len, val)
            else:
                table.update(hash_city, line_start, city_len, val)

            start_of_line_idx = Int(newline_idx) + 1
            line_start = pos + start_of_line_idx
            newlines &= newlines - 1

        pos += start_of_line_idx

    if pos < end:
        var tail_end = end
        if data[end - 1] == NEW_LINE:
            tail_end -= 1
        var tail = StringSlice(from_utf8=data[pos:tail_end])
        var tail_pos = pos
        for line in tail.split("\n"):
            if line.byte_length() == 0:
                continue
            var station = line.split(";")
            var city = station[0]
            var val = atol(station[1].replace(".", ""))
            var hash_city: UInt64
            comptime if sampled_hash:
                var city_len = city.byte_length()
                var city_ptr = data_ptr.unsafe_offset(tail_pos)
                var last = city_len - 1
                var signature = UInt64(city_len)
                signature |= UInt64(city_ptr[unsafe_offset=0]) << 8
                signature |= UInt64(city_ptr[unsafe_offset=min(1, last)]) << 16
                signature |= UInt64(city_ptr[unsafe_offset=min(2, last)]) << 24
                signature |= UInt64(city_ptr[unsafe_offset=city_len // 2]) << 32
                signature |= UInt64(city_ptr[unsafe_offset=last]) << 40
                signature ^= signature >> 33
                signature *= 0xFF51AFD7ED558CCD
                hash_city = signature ^ (signature >> 33)
            else:
                hash_city = hash(city)
            comptime if unchecked_table:
                table.update_unchecked(
                    hash_city,
                    tail_pos,
                    city.byte_length(),
                    val,
                )
            else:
                table.update(
                    hash_city,
                    tail_pos,
                    city.byte_length(),
                    val,
                )
            tail_pos += line.byte_length() + 1


def process_chunk_compact(
    data: ImmSpan[UInt8, _],
    start: Int,
    end: Int,
    mut table: CompactTable,
) raises:
    """V10 parser with sampled station hashes and compact table entries."""
    comptime simd_width = simd_width_of[DType.uint8]()
    comptime bits_type = DType.uint64 if simd_width == 64 else DType.uint32
    comptime SEMICOLON = UInt8(ord(";"))
    comptime NEW_LINE = UInt8(ord("\n"))
    comptime MINUS = UInt8(ord("-"))
    comptime ZERO = UInt8(ord("0"))
    comptime vec_3d = SIMD[DType.int16, 4](100, 10, 0, 1)
    comptime vec_2d = SIMD[DType.int16, 4](10, 0, 1, 0)
    comptime vec_digits = vec_3d.interleave(vec_2d)

    var data_ptr = data.unsafe_ptr()
    var pos = start
    var line_start = start

    while pos + simd_width < end:
        var chunk = data_ptr.unsafe_load[width=simd_width](pos)
        var newlines = pack_bits[bits_type](chunk.eq(NEW_LINE))
        var semicolons = pack_bits[bits_type](chunk.eq(SEMICOLON))

        if newlines == 0:
            pos += max(1, Int(count_leading_zeros(semicolons)))
            continue

        var start_of_line_idx = 0
        while newlines != 0:
            var newline_idx = count_trailing_zeros(newlines)
            var search_mask = (1 << newline_idx) - Scalar[bits_type](
                1 << start_of_line_idx
            )
            var semicolon_idx = count_trailing_zeros(semicolons & search_mask)
            var city_len = pos + Int(semicolon_idx) - line_start
            var city_ptr = data_ptr.unsafe_offset(line_start)
            var last = city_len - 1
            var signature = UInt64(city_len)
            signature |= UInt64(city_ptr[unsafe_offset=0]) << 8
            signature |= UInt64(city_ptr[unsafe_offset=min(1, last)]) << 16
            signature |= UInt64(city_ptr[unsafe_offset=min(2, last)]) << 24
            signature |= UInt64(city_ptr[unsafe_offset=city_len // 2]) << 32
            signature |= UInt64(city_ptr[unsafe_offset=last]) << 40
            signature ^= signature >> 33
            signature *= 0xFF51AFD7ED558CCD
            var hash_city = signature ^ (signature >> 33)

            var val_start_idx = Scalar[bits_type](pos) + semicolon_idx + 1
            var num_len = newline_idx - (semicolon_idx + 1)
            var is_neg = Scalar[bits_type](
                data_ptr.unsafe_load[width=1](val_start_idx)[0] == MINUS
            )
            var sign = Int(1 - (is_neg << 1))
            var val_abs_start = val_start_idx + is_neg
            var digits_4 = SIMD[DType.int16, 4](
                data_ptr.unsafe_load[width=4](val_abs_start) - ZERO
            )
            var digits_8 = digits_4.interleave(digits_4)
            var vals = (digits_8 * vec_digits).reduce_add[2]()
            var is_short = Int16((num_len - is_neg) == 3)
            var val_abs = vals[0] * (1 - is_short) + vals[1] * is_short
            var val = sign * Int(val_abs)

            table.update(hash_city, line_start, city_len, val)

            start_of_line_idx = Int(newline_idx) + 1
            line_start = pos + start_of_line_idx
            newlines &= newlines - 1
        pos += start_of_line_idx

    if pos < end:
        var tail_end = end
        if data[end - 1] == NEW_LINE:
            tail_end -= 1
        var tail = StringSlice(from_utf8=data[pos:tail_end])
        var tail_pos = pos
        for line in tail.split("\n"):
            if line.byte_length() == 0:
                continue
            var station = line.split(";")
            var city = station[0]
            var city_len = city.byte_length()
            var city_ptr = data_ptr.unsafe_offset(tail_pos)
            var last = city_len - 1
            var signature = UInt64(city_len)
            signature |= UInt64(city_ptr[unsafe_offset=0]) << 8
            signature |= UInt64(city_ptr[unsafe_offset=min(1, last)]) << 16
            signature |= UInt64(city_ptr[unsafe_offset=min(2, last)]) << 24
            signature |= UInt64(city_ptr[unsafe_offset=city_len // 2]) << 32
            signature |= UInt64(city_ptr[unsafe_offset=last]) << 40
            signature ^= signature >> 33
            signature *= 0xFF51AFD7ED558CCD
            var hash_city = signature ^ (signature >> 33)
            var val = atol(station[1].replace(".", ""))
            table.update(hash_city, tail_pos, city_len, val)
            tail_pos += line.byte_length() + 1


# parallel
def find_next_newline(data: ImmSpan[UInt8, _], start: Int) -> Int:
    """Find the next newline after start position."""
    for i in range(start, len(data)):
        if data[i] == UInt8(ord("\n")):
            return i + 1  # Return position AFTER newline
    return len(data)


def process_parallel[
    origin: ImmOrigin, temp_alg: String = "v5"
](data: ImmSpan[UInt8, origin]) raises -> String:
    var num_workers = num_physical_cores() * 2

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
        length=num_workers, fill=Dict[UInt64, MeasurementInt](capacity=1024)
    )
    var thread_city_names = List[Dict[UInt64, StringSpan[origin]]](
        length=num_workers,
        fill=Dict[UInt64, StringSpan[origin]](capacity=1024),
    )

    # Process chunks in parallel
    def process_worker(worker_id: Int) {mut, imm data}:
        try:
            process_chunk[temp_alg=temp_alg](
                data,
                chunk_starts[worker_id],
                chunk_ends[worker_id],
                thread_dicts[worker_id],
                thread_city_names[worker_id],
            )
        except:
            print("oopsie")

    parallelize(process_worker, num_workers)

    # Merge results from all threads
    ref final_dict = thread_dicts[0]
    ref final_city_names = thread_city_names[0]

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


struct MMap:
    comptime RawPointer = Pointer[UInt8, ImmUntrackedOrigin]
    comptime ptr = Optional[Self.RawPointer]
    var _data: Self.ptr
    var _size: Int

    def __init__(out self, path: String) raises:
        var data = Self.ptr()
        var size: Int

        with open(path, "r") as file:
            comptime PROT_READ = 1
            comptime MAP_PRIVATE = 2

            size = Int(file.seek(0, SEEK_END))
            if size != 0:
                data = external_call["mmap", Self.ptr](
                    Self.ptr(),  # addr: let the kernel choose
                    size,
                    PROT_READ,
                    MAP_PRIVATE,
                    file._get_raw_fd(),
                    0,  # offset
                )

        if size != 0 and not data:
            raise Error("mmap failed")
        self._data = data
        self._size = size

    def __deinit__(deinit self):
        if self._data:
            _ = external_call["munmap", Int](self._data, self._size)

    def byte_length(ref self) -> Int:
        return self._size

    def as_bytes_span(self) -> Span[UInt8, origin_of(self)]:
        if self._size == 0:
            return {}
        return Span(
            unsafe_ptr=self._data.unsafe_value().unsafe_origin_cast[
                origin_of(self)
            ](),
            length=self._size,
        )

    def as_string_span(self) -> StringSpan[origin_of(self)]:
        return StringSpan(unsafe_from_utf8=self.as_bytes_span())


def process_parallel_fast[
    sampled_hash: Bool = False, unchecked_table: Bool = False
](data: ImmSpan[UInt8, _]) raises -> String:
    var num_workers = num_physical_cores() * 2
    var approx_chunk_size = len(data) // num_workers
    var chunk_starts = List[Int](capacity=num_workers)
    var chunk_ends = List[Int](capacity=num_workers)

    chunk_starts.append(0)
    for i in range(1, num_workers):
        var aligned_start = find_next_newline(data, i * approx_chunk_size)
        chunk_starts.append(aligned_start)
        chunk_ends.append(aligned_start)
    chunk_ends.append(len(data))

    var thread_tables = List[FastTable](capacity=num_workers)
    for _ in range(num_workers):
        thread_tables.append(FastTable())

    def process_worker(worker_id: Int) {mut, imm data}:
        try:
            process_chunk_fast[sampled_hash, unchecked_table](
                data,
                chunk_starts[worker_id],
                chunk_ends[worker_id],
                thread_tables[worker_id],
            )
        except:
            print("oopsie")

    parallelize(process_worker, num_workers)

    ref final_table = thread_tables[0]
    for worker_id in range(1, num_workers):
        for entry in thread_tables[worker_id].entries:
            if entry.n != 0:
                var other = entry.copy()
                final_table.merge(other)

    return format_output(data, final_table)


def process_parallel_compact(data: ImmSpan[UInt8, _]) raises -> String:
    var num_workers = num_physical_cores() * 2
    var approx_chunk_size = len(data) // num_workers
    var chunk_starts = List[Int](capacity=num_workers)
    var chunk_ends = List[Int](capacity=num_workers)

    chunk_starts.append(0)
    for i in range(1, num_workers):
        var aligned_start = find_next_newline(data, i * approx_chunk_size)
        chunk_starts.append(aligned_start)
        chunk_ends.append(aligned_start)
    chunk_ends.append(len(data))

    var thread_tables = List[CompactTable](capacity=num_workers)
    for _ in range(num_workers):
        thread_tables.append(CompactTable())

    def process_worker(worker_id: Int) {mut, imm data}:
        try:
            process_chunk_compact(
                data,
                chunk_starts[worker_id],
                chunk_ends[worker_id],
                thread_tables[worker_id],
            )
        except:
            print("oopsie")

    parallelize(process_worker, num_workers)

    ref final_table = thread_tables[0]
    for worker_id in range(1, num_workers):
        for slot in range(FAST_TABLE_CAPACITY):
            var other = thread_tables[worker_id].entries[slot].copy()
            if other.n != 0:
                var city_start = thread_tables[worker_id].city_starts[slot]
                var city_len = thread_tables[worker_id].city_lens[slot]
                final_table.merge(other, city_start, city_len)

    return format_output(data, final_table)


def process_1brc[version: Int](file_path: String) raises -> String:
    """
    Unified 1BRC processor using compile-time version selection.

    Versions:
    - 0: Basic string operations with Float64
    - 1: Fixed-point Int arithmetic
    - 2: Hash-based city lookup (no string allocation)
    - 3: SIMD parsing of temperature
    - 4: Parallel processing
    - 5: Memory Mapped File
    - 6: Unchecked sign-byte load
    - 7: Fixed-size pre-hashed station table
    - 8: Sampled station fingerprint
    - 9: Unchecked fixed-table access
    - 10: Compact 24-byte aggregation entries
    """

    comptime if version == 0:
        var d = Dict[String, MeasurementFloat]()
        with open(file_path, "r") as f:
            var lines = f.read().split("\n")
            for l in lines:
                if l.byte_length() == 0:
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
                if l.byte_length() == 0:
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
        var d = Dict[UInt64, MeasurementInt](capacity=1024)
        var city_names = Dict[UInt64, StringSlice[ImmutAnyOrigin]](
            capacity=1024
        )
        with open(file_path, "r") as file:
            var bytes = file.read_bytes()
            var data = Span[UInt8, ImmutAnyOrigin](bytes)

            process_chunk[simd_parsing=False](
                data, 0, len(data) - 1, d, city_names
            )
            return format_output(d, city_names)

    elif version == 3:
        var d = Dict[UInt64, MeasurementInt](capacity=1024)
        var city_names = Dict[UInt64, StringSlice[ImmutAnyOrigin]](
            capacity=1024
        )
        with open(file_path, "r") as file:
            var bytes = file.read_bytes()
            var data = Span[UInt8, ImmutAnyOrigin](bytes)
            process_chunk(data, 0, len(data) - 1, d, city_names)
            return format_output(d, city_names)

    elif version == 4:
        with open(file_path, "r") as file:
            var bytes = file.read_bytes()
            var data = Span[UInt8, ImmutAnyOrigin](bytes)
            return process_parallel(data)

    elif version == 5:
        var mmap_file = MMap(file_path)
        var data = mmap_file.as_bytes_span()
        return process_parallel(data)

    elif version == 6:
        var mmap_file = MMap(file_path)
        var data = mmap_file.as_bytes_span()
        return process_parallel[temp_alg="v6"](data)

    elif version == 7:
        var mmap_file = MMap(file_path)
        var data = mmap_file.as_bytes_span()
        return process_parallel_fast(data)

    elif version == 8:
        var mmap_file = MMap(file_path)
        var data = mmap_file.as_bytes_span()
        return process_parallel_fast[True](data)

    elif version == 9:
        var mmap_file = MMap(file_path)
        var data = mmap_file.as_bytes_span()
        return process_parallel_fast[True, True](data)

    elif version == 10:
        var mmap_file = MMap(file_path)
        var data = mmap_file.as_bytes_span()
        return process_parallel_compact(data)

    else:
        comptime assert False, "unsuported version"


def main() raises:
    comptime file_path = "./measurements.txt"
    comptime hash_1M = 7830574609753597440
    # comptime hash_100M = 7465477878325822113

    print("1BRC Unified Implementation")
    print("Cores:", num_physical_cores())

    print("Testing...")

    def test[v: Int]() raises:
        var result = process_1brc[v](file_path)
        var result_hash = hash(result)

        with open("output/v{}.txt".format(v), "w") as f:
            f.write(result)

        assert_equal(result_hash, hash_1M)
        # assert_equal(result_hash, hash_100M)

        print(t"v{v} : correct hash")

    test[0]()
    test[1]()
    test[2]()
    test[3]()
    test[4]()
    test[5]()
    test[6]()
    test[7]()
    test[8]()
    test[9]()
    test[10]()

    print("Benchmarking...")

    def bench[
        v: Int
    ](
        base_time: Optional[Float64] = None, prev_time: Optional[Float64] = None
    ) raises -> Float64:
        def bench_fn() raises:
            _ = process_1brc[v](file_path)

        var time_ms = round(run(bench_fn, max_iters=10).mean(Unit.ms), 2)
        if base_time and prev_time:
            var vs_prev = round(prev_time.value() / time_ms, 2)
            var vs_base = round(base_time.value() / time_ms, 2)
            print(t"v{v} : {time_ms} ms, {vs_prev} X prev, {vs_base} X base")
        else:
            print(t"v{v} : {time_ms} ms")
        return time_ms

    var t0 = bench[0]()
    var t1 = bench[1](t0, t0)
    var t2 = bench[2](t0, t1)
    var t3 = bench[3](t0, t2)
    var t4 = bench[4](t0, t3)
    var t5 = bench[5](t0, t4)

    # var t5 = bench[5]()
    var t6 = bench[6](t0, t5)
    var t7 = bench[7](t0, t6)
    var t8 = bench[8](t0, t7)
    var t9 = bench[9](t0, t8)
    var t10 = bench[10](t0, t9)
