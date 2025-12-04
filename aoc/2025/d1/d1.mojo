from testing import assert_equal

comptime test_file_path = "./test_input.txt"
comptime file_path = "./input.txt"


fn part_1(file_path: String) raises -> Int:
    var pos = 50
    var n_zero = 0
    with open(file_path, "r") as f:
        var lines = f.read().split("\n")
        for line in lines:
            if len(line) == 0:
                continue
            var dir_letter = line[0]
            var mag = atol(line[1:])
            var dir: Int
            if dir_letter == "L":
                dir = -1
            elif dir_letter == "R":
                dir = 1
            else:
                raise Error("bad dir" + dir_letter)

            pos = (pos + dir * mag) % 100
            if pos == 0:
                n_zero += 1
    return n_zero


fn part_2(file_path: String) raises -> Int:
    var pos = 50
    var n_zero = 0
    with open(file_path, "r") as f:
        var lines = f.read().split("\n")
        for line in lines:
            if len(line) == 0:
                continue
            var dir_letter = line[0]
            var mag = atol(line[1:])
            var dir: Int
            if dir_letter == "L":
                dir = -1
            elif dir_letter == "R":
                dir = 1
            else:
                raise Error("bad dir" + dir_letter)
            n_zero_free = mag // 100
            n_zero += n_zero_free

            mag -= 100 * n_zero_free

            if (dir == -1 and mag > pos and pos != 0) or (
                dir == 1 and mag + pos > 100
            ):
                n_zero += 1

            pos = (pos + dir * mag) % 100
            if pos == 0:
                n_zero += 1
    return n_zero


fn main() raises:
    assert_equal(part_1(test_file_path), 3)
    print("part 1: ", part_1(file_path))

    assert_equal(part_2(test_file_path), 6)
    print("part 2: ", part_2(file_path))
