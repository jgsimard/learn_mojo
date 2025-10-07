@fieldwise_init
struct Measurement(Copyable & Movable, Writable):
    var min: Float32
    var mean: Float32
    var max: Float32
    var n: Float32

    fn __str__(self) -> String:
        return String(round(self.min, 1), "/", round(self.mean, 1), "/", round(self.max, 1))

    fn write_to(self, mut writer: Some[Writer]):
        writer.write(self.__str__())


fn v0(file_path: String) raises -> String:
    var d = Dict[String, Measurement]()
    with open(file_path, "r") as f:
        var lines = f.read().split("\n")
        for l in lines:
            var ss = l.split(";")
            var city = String(ss[0])
            var val = Float32(atof(ss[1]))
            var bob = d.get(city)
            if bob:
                var m = bob.value().copy()
                if val < m.min:
                    m.min = val
                elif val > m.max:
                    m.max = val
                m.mean = (m.mean * m.n + val) / (m.n + 1.0)
                m.n += 1.0
                d[city] = m^
            else:
                d[city] = Measurement(val, val, val, 1.0)
    
    # var out_dict = Dict[String, String]()
    # for e in d.items():
    #     out_dict[e.key] = String(e.value)

    # return out_dict^
    return String("V0, Assab: ", d["Assab"], ", Detroit: ", d["Detroit"],  ", Veracruz: ", d["Veracruz"])

