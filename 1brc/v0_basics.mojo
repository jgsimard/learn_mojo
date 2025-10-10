@fieldwise_init
struct Measurement(Copyable & Movable, Writable):
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


fn v0(file_path: String) raises -> String:
    var d = Dict[String, Measurement]()
    with open(file_path, "r") as f:
        var lines = f.read().split("\n")
        for l in lines:
            if len(l) == 0:
                continue
            var station = l.split(";")
            var city = String(station[0])
            var val = atof(station[1])
            var bob = d.get(city)
            if bob:
                d[city].update(val)
            else:
                d[city] = Measurement(val, val, val, 1.0)

    var output = format_output(d)
    return output


fn format_output(d: Dict[String, Measurement]) raises -> String:
    """Format the results in the expected 1BRC format: {city1=min/mean/max, city2=min/mean/max, ...}
    
    Cities are sorted alphabetically.
    """
    # Collect all city names and sort them
    var cities = List[String]()
    for entry in d.items():
        cities.append(entry.key)
    
    # Simple bubble sort
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
        var measurement = d[city].copy()
        
        if i > 0:
            result += ", \n"
        
        result += city + "=" + String(measurement)
    
    result += "}"
    return result