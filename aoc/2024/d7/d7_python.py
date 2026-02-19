def next_power_of_10(n):
    if n < 10:
        return 10
    elif n < 100:
        return 100
    return 1000


def try_ops(line, target, idx, try_concat):
    v = line[idx]
    if idx == 0:
        return target == v

    if v > target:
        return False

    m = False
    if target % v == 0:
        m = try_ops(line, target // v, idx - 1, try_concat)

    a = try_ops(line, target - v, idx - 1, try_concat)

    if not try_concat:
        return a or m

    c = False
    np = next_power_of_10(v)
    n = target % np
    if n == v:
        c = try_ops(line, target // np, idx - 1, try_concat)
    return a or m or c


def parse(inp):
    p1, p2 = 0, 0

    for line in inp.splitlines():
        s = line.split(":")
        target = int(s[0])
        res = [int(v) for v in s[1].split()]
        if try_ops(res, target, len(res) - 1, False):
            p1 += target
            p2 += target
        elif try_ops(res, target, len(res) - 1, True):
            p2 += target

    return p1, p2


def main():
    with open("input.txt", "r") as f:
        inp = f.read()
    p1, p2 = parse(inp)
    print("Part 1:", p1)
    print("Part 2:", p2)


if __name__ == "__main__":
    main()
