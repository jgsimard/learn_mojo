@fieldwise_init
struct Measurement(Copyable & Movable, Writable):
    var min: Int
    var sum: Int
    var max: Int
    var n: Int

    fn __str__(self) -> String:
        var min = Float32(self.min) / 10.0
        var max = Float32(self.max) / 10.0
        var mean = Float32(self.sum) / 10.0 / Float32(self.n)
        return String(round(min, 1), "/", round(mean, 1), "/", round(max, 1))

    fn write_to(self, mut writer: Some[Writer]):
        writer.write(self.__str__())


fn v1(file_path: String) raises -> String:
    var d = Dict[String, Measurement]()
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
                d[city] = m^
            else:
                d[city] = Measurement(val, val, val, 1)

    return format_output(d)


fn format_output(d: Dict[String, Measurement]) raises -> String:
    """Format the results in the expected 1BRC format: {city1=min/mean/max, city2=min/mean/max, ...}

    Cities are sorted alphabetically.
    """
    # Collect all city names and sort them
    var cities = List[String]()
    for entry in d.items():
        cities.append(entry.key)

    sort(cities)

    # Build output string
    var result = String("{")

    for i in range(len(cities)):
        var city = cities[i]
        var measurement = d[city].copy()

        if i > 0:
            result += ", \n"

        result += city + "=" + String(measurement)

    result += "}"
    return result
