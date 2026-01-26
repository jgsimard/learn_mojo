from sys import argv
from reflection import (
    struct_field_count,
    struct_field_names,
    struct_field_types,
    get_type_name,
    is_struct_type,
)
from utils.numerics import max_finite, min_finite
from sys import exit


struct MojoClap[T: Defaultable & Movable]:
    @staticmethod
    fn parse() raises -> Self.T:
        __comptime_assert is_struct_type[Self.T]()

        # types
        comptime bool = get_type_name[Bool]()
        comptime str = get_type_name[String]()

        # index
        comptime int = get_type_name[Int]()
        comptime uint = get_type_name[UInt]()

        # ints
        comptime i8 = get_type_name[Int8]()
        comptime i16 = get_type_name[Int16]()
        comptime i32 = get_type_name[Int32]()
        comptime i64 = get_type_name[Int64]()

        comptime u8 = get_type_name[UInt8]()
        comptime u16 = get_type_name[UInt16]()
        comptime u32 = get_type_name[UInt32]()
        comptime u64 = get_type_name[UInt64]()

        comptime ints = {
            i8: DType.int8,
            i16: DType.int16,
            i32: DType.int32,
            i64: DType.int64,
            u8: DType.uint8,
            u16: DType.uint16,
            u32: DType.uint32,
            u64: DType.uint64,
        }

        # floats
        comptime f16 = get_type_name[Float16]()
        comptime f32 = get_type_name[Float32]()
        comptime f64 = get_type_name[Float64]()

        comptime floats = {
            f16: DType.float16,
            f32: DType.float32,
            f64: DType.float64,
        }

        var args = argv()
        var instance = Self.T()

        # help
        for arg in args:
            if arg == "--help" or arg == "-h":
                Self.print_help()
                exit(0)

        comptime field_count = struct_field_count[Self.T]()
        comptime field_names = struct_field_names[Self.T]()
        comptime field_types = struct_field_types[Self.T]()

        var i = 1
        while i < len(args):
            var arg = args[i]

            if arg.startswith("--"):
                var arg_name = arg.strip("-")

                if arg_name not in materialize[field_names]():
                    raise Error("Warning: Unknown arg --{}".format(arg_name))

                @parameter
                for idx in range(field_count):
                    comptime field_name = field_names[idx]
                    comptime field_type = field_types[idx]
                    comptime field_type_name = get_type_name[field_type]()

                    if arg_name == field_name:
                        ref field = __struct_field_ref(idx, instance)

                        @parameter
                        if field_type_name == bool:
                            field = rebind[type_of(field)](True)
                            continue

                        var arg: StringSlice[StaticConstantOrigin]
                        if i + 1 < len(args):
                            i += 1
                            arg = args[i]
                        else:
                            raise Error(
                                "Arg -- {} requires a value".format(arg_name)
                            )

                        @parameter
                        if field_type_name == str:
                            field = rebind[type_of(field)](String(arg))

                        # index types
                        elif field_type_name == int:
                            field = rebind[type_of(field)](atol(arg))

                        elif field_type_name == uint:
                            field = rebind[type_of(field)](UInt(atol(arg)))

                        # ints
                        elif field_type_name in ints:
                            comptime dtype = ints.get(field_type_name).value()
                            field = rebind[type_of(field)](
                                Self._parse_int[dtype](arg, field_name)
                            )

                        # floats
                        elif field_type_name in floats:
                            comptime dtype = floats.get(field_type_name).value()
                            field = rebind[type_of(field)](
                                Self._parse_float[dtype](arg, field_name)
                            )

                        else:
                            raise Error(
                                "Cannot parse CLI value for unknown"
                                " type: {}, value:{}".format(
                                    field_type_name, arg
                                )
                            )
            i += 1

        return instance^

    @staticmethod
    fn _parse_int[
        type: DType
    ](val: StringSlice[StaticConstantOrigin], name: String) raises -> Scalar[
        type
    ]:
        var raw = Int128(atol(val))
        comptime min = Int128(min_finite[type]())
        comptime max = Int128(max_finite[type]())
        if not min <= raw <= max:
            raise Error(
                "Value {} for --{}  is out of bounds for {} : [{}, {}]".format(
                    val, name, type, min, max
                )
            )
        return Scalar[type](raw)

    @staticmethod
    fn _parse_float[
        type: DType
    ](val: StringSlice[StaticConstantOrigin], name: String) raises -> Scalar[
        type
    ]:
        var raw = atof(val)
        comptime min = Float64(min_finite[type]())
        comptime max = Float64(max_finite[type]())
        if not min <= raw <= max:
            raise Error(
                "Value {} for --{}  is out of bounds for {} : [{}, {}]".format(
                    val, name, type, min, max
                )
            )
        return Scalar[type](raw)

    @staticmethod
    fn print_help():
        print("Usage: [options]")
        print("\nOptions:")

        comptime field_names = struct_field_names[Self.T]()
        comptime field_types = struct_field_types[Self.T]()
        comptime field_count = struct_field_count[Self.T]()

        @parameter
        for i in range(field_count):
            comptime field_name = field_names[i]
            comptime field_type = field_types[i]
            comptime field_type_name = get_type_name[field_type]()
            print("  --{} : {}".format(field_name, field_type_name))


@fieldwise_init
struct Config(Copyable, Defaultable, Writable):
    var name: String
    var port: Int
    var verbose: Bool
    var threshold: Float64
    var limit: Float32
    var hello: Int8
    var u: UInt8

    fn __init__(out self):
        self.name = "default"
        self.port = 8080
        self.verbose = False
        self.threshold = 0.5
        self.limit = 0.1
        self.hello = 12
        self.u = 10


fn main() raises:
    # pixi run mojo clap.mojo --verbose --port 123 --threshold 0.456 --name "alice & bob" --hello 1000
    var config = MojoClap[Config].parse()

    print(config)
