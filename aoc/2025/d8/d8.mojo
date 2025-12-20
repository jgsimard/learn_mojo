from testing import assert_equal
from benchmark import run, Unit
from memory import memset_zero

from aoc.aoc_utils import input_paths


@register_passable
@fieldwise_init
struct Point(Comparable, Copyable, Representable, Writable):
    var x: Int
    var y: Int
    var z: Int
    var id: Int

    fn __lt__(self: Self, rhs: Self) -> Bool:
        return self.x < rhs.x

    fn __eq__(self, rhs: Self) -> Bool:
        return (
            self.x == rhs.x
            and self.y == rhs.y
            and self.z == rhs.z
            and self.id == rhs.id
        )

    fn __repr__(self) -> String:
        return "id {} : ({},{},{})".format(self.id, self.x, self.y, self.z)

    fn write_to(self, mut writer: Some[Writer]):
        writer.write(self.__repr__())


@register_passable
@fieldwise_init
struct PairDist(Comparable, Copyable, Representable, Writable):
    var dist: Int
    var id_0: Int
    var id_1: Int

    fn __lt__(self: Self, rhs: Self) -> Bool:
        return self.dist < rhs.dist

    fn __eq__(self: Self, rhs: Self) -> Bool:
        return (
            self.dist == rhs.dist
            and self.id_0 == rhs.id_0
            and self.id_1 == rhs.id_1
        )

    fn __repr__(self) -> String:
        return "dist={} ({},{})".format(self.dist, self.id_0, self.id_1)

    fn write_to(self, mut writer: Some[Writer]):
        writer.write(self.__repr__())


struct MaxHeap[T: Comparable & Copyable](Sized):
    var data: List[Self.T]

    fn __init__(out self, capacity: Int = 0):
        self.data = List[Self.T](capacity=capacity)

    fn __len__(self) -> Int:
        return len(self.data)

    fn top(self) -> ref [self.data] Self.T:
        return self.data[0]

    fn push(mut self, var value: Self.T):
        self.data.append(value^)
        self._bubble_up(len(self.data) - 1)

    fn pop(mut self) -> Self.T:
        if len(self.data) == 1:
            return self.data.pop()

        var root_val = self.data[0].copy()
        self.data[0] = self.data.pop()
        self._bubble_down(0)
        return root_val^

    fn replace_root(mut self, var value: Self.T):
        self.data[0] = value^
        self._bubble_down(0)

    fn _bubble_up(mut self, index: Int):
        var curr = index
        while curr > 0:
            var parent = (curr - 1) // 2
            if self.data[curr] > self.data[parent]:
                self.data.swap_elements(curr, parent)
                curr = parent
            else:
                break

    fn _bubble_down(mut self, index: Int):
        var curr = index
        var size = len(self.data)
        while True:
            var left = 2 * curr + 1
            var right = 2 * curr + 2
            var largest = curr

            if left < size and self.data[left] > self.data[largest]:
                largest = left
            if right < size and self.data[right] > self.data[largest]:
                largest = right

            if largest != curr:
                self.data.swap_elements(curr, largest)
                curr = largest
            else:
                break


fn l2_squared(p1: Point, p2: Point) -> Int:
    return (p1.x - p2.x) ** 2 + (p1.y - p2.y) ** 2 + (p1.z - p2.z) ** 2


struct DisjointSetUnion:
    var parent: List[Int]
    var size: List[Int]

    fn __init__(out self, n: Int):
        self.parent = List[Int](capacity=1000)
        self.size = List[Int](capacity=1000)
        for i in range(n):
            self.parent.append(i)
            self.size.append(1)

    fn find(mut self, i: Int) -> Int:
        var root = i
        while self.parent[root] != root:
            root = self.parent[root]

        # Path compression
        var curr = i
        while self.parent[curr] != root:
            var next_node = self.parent[curr]
            self.parent[curr] = root
            curr = next_node
        return root

    fn union(mut self, i: Int, j: Int):
        var root_i = self.find(i)
        var root_j = self.find(j)
        if root_i != root_j:
            # Union by size
            if self.size[root_i] < self.size[root_j]:
                self.parent[root_i] = root_j
                self.size[root_j] += self.size[root_i]
            else:
                self.parent[root_j] = root_i
                self.size[root_i] += self.size[root_j]


fn day8[p: Int, nb_to_connect: Int = 1000](file_path: String) raises -> Int:
    var points = List[Point]()
    with open(file_path, "r") as f:
        var cur_id = 0
        for line in f.read().split("\n"):
            var parts = line.split(",")
            var pt = Point(
                atol(parts[0]), atol(parts[1]), atol(parts[2]), cur_id
            )
            cur_id += 1
            points.append(pt^)

    @parameter
    if p == 1:
        sort(points)  # sort by x
        var nb_pts = len(points)
        var max_heap = MaxHeap[PairDist](nb_to_connect)

        for i in range(nb_pts):
            ref p0 = points[i]
            for j in range(i + 1, nb_pts):
                ref p1 = points[j]

                var dx = p0.x - p1.x
                var dx2 = dx * dx

                if (
                    len(max_heap) == nb_to_connect
                    and dx2 >= max_heap.top().dist
                ):
                    break

                var dist = dx2 + (p0.y - p1.y) ** 2 + (p0.z - p1.z) ** 2

                if len(max_heap) < nb_to_connect:
                    max_heap.push(PairDist(dist, p0.id, p1.id))

                elif dist < max_heap.top().dist:
                    max_heap.replace_root(PairDist(dist, p0.id, p1.id))

        var dsu = DisjointSetUnion(nb_pts)

        for pair in max_heap.data:
            dsu.union(pair.id_0, pair.id_1)

        var final_sizes = List[Int]()
        for i in range(nb_pts):
            if dsu.parent[i] == i:
                final_sizes.append(dsu.size[i])
        sort(final_sizes)
        return final_sizes[-1] * final_sizes[-2] * final_sizes[-3]

    else:
        var nb_pts = len(points)
        var dists = List[PairDist](capacity=nb_pts * nb_pts // 2)
        for i in range(nb_pts):
            for j in range(i + 1, nb_pts):
                var dist = l2_squared(points[i], points[j])
                dists.append(PairDist(dist, i, j))
        sort(dists)

        var dsu = DisjointSetUnion(nb_pts)
        var circuits_remaining = nb_pts

        for pair in dists:
            var root_0 = dsu.find(pair.id_0)
            var root_1 = dsu.find(pair.id_1)

            if root_0 != root_1:
                dsu.union(pair.id_0, pair.id_1)
                circuits_remaining -= 1

                if circuits_remaining == 1:
                    return points[pair.id_0].x * points[pair.id_1].x

        raise Error("part 2 - oops")


fn main() raises:
    comptime test_file_path, file_path = input_paths[8]()

    print("\nAoC 2025 - Day 8")

    assert_equal(day8[1, 10](test_file_path), 40)
    print("part 1:", day8[1, 1000](file_path))

    assert_equal(day8[2](test_file_path), 25272)
    print("part 2:", day8[2](file_path))

    @parameter
    fn bench[p: Int]() raises:
        fn bench_fn() raises:
            _ = day8[p](file_path)

        var time_ns = run[bench_fn](max_iters=30).mean(Unit.ns)
        var time_us = round(time_ns / 1000.0, 1)
        print("part {}, t = {} us".format(p, time_us))

    bench[1]()
    bench[2]()
