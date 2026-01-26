from sys import argv
from reflection import (
    struct_field_count,
    struct_field_names,
    struct_field_types,
    get_type_name,
    is_struct_type,
)
from utils.numerics import max_finite, min_finite


fn parse[T: Defaultable & Movable]() raises -> T:
    __comptime_assert is_struct_type[T]()

    comptime bool = get_type_name[Bool]()
    comptime int = get_type_name[Int]()
    comptime i8 = get_type_name[Int8]()
    comptime f32 = get_type_name[Float32]()
    comptime f64 = get_type_name[Float64]()
    comptime str = get_type_name[String]()

    var args = argv()
    var instance = T()

    # Compile-time reflection metadata
    comptime field_count = struct_field_count[T]()
    comptime field_names = struct_field_names[T]()
    comptime field_types = struct_field_types[T]()

    var i = 1
    while i < len(args):
        var arg = args[i]

        if arg.startswith("--"):
            var arg_name = arg.strip("-")
            var found = False

            @parameter
            for idx in range(field_count):
                comptime field_name = field_names[idx]
                comptime field_type = field_types[idx]
                comptime field_type_name = get_type_name[field_type]()

                if arg_name == field_name:
                    found = True
                    print("found", arg_name)

                    ref field = __struct_field_ref(idx, instance)

                    @parameter
                    if field_type_name == bool:
                        field = rebind[type_of(field)](True)
                    else:
                        if i + 1 < len(args):
                            i += 1
                            var arg = args[i]
                            print(arg)

                            @parameter
                            if field_type_name == int:
                                var value = atol(arg)
                                field = rebind[type_of(field)](value)
                            elif field_type_name == i8:
                                var raw_value = atol(arg)
                                comptime min = Int(min_finite[DType.int8]())
                                comptime max = Int(max_finite[DType.int8]())
                                if not min <= raw_value <= max:
                                    raise Error(
                                        "value {} for field '{}' of type {}"
                                        " is out of bounds [{}, {}]".format(
                                            raw_value,
                                            field_name,
                                            field_type_name,
                                            min,
                                            max,
                                        )
                                    )
                                var value = Int8(raw_value)
                                field = rebind[type_of(field)](value)
                            elif field_type_name == f32:
                                var value = Float32(atof(arg))
                                field = rebind[type_of(field)](value)
                            elif field_type_name == f64:
                                var value = atof(arg)
                                field = rebind[type_of(field)](value)
                            elif field_type_name == str:
                                var value = String(arg)
                                field = rebind[type_of(field)](value)
                            else:
                                raise Error(
                                    "Cannot parse CLI value for unknown"
                                    " type: {}, value:{}".format(
                                        field_type_name, arg
                                    )
                                )
                        else:
                            raise Error(
                                "Arg -- {} requires a value".format(arg_name)
                            )

            if not found:
                raise Error("Warning: Unknown arg --{}".format(arg_name))
        i += 1

    return instance^


@fieldwise_init
struct Config(Copyable, Defaultable, Writable):
    var name: String
    var port: Int
    var verbose: Bool
    var threshold: Float64
    var limit: Float32
    var hello: Int8

    fn __init__(out self):
        self.name = "default"
        self.port = 8080
        self.verbose = False
        self.threshold = 0.5
        self.limit = 0.1
        self.hello = 12


fn main() raises:
    # pixi run mojo clap.mojo --verbose --port 123 --threshold 0.456 --name "alice & bob" --hello 1000
    var config = parse[Config]()

    print(config)
