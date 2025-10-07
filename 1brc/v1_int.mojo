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

    return String("V1, Assab: ", d["Assab"], ", Detroit: ", d["Detroit"],  ", Veracruz: ", d["Veracruz"])
    
