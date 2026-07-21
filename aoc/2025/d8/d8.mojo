from std.testing import assert_equal
from std.benchmark import run, Unit
from std.memory import memset_zero
from std.utils.numerics import max_finite

from aoc.aoc_utils import input_paths, basic_bench


@fieldwise_init
struct Point(Comparable, TrivialRegisterPassable, Writable):
    var x: Int
    var y: Int
    var z: Int
    var id: Int

    def __lt__(self: Self, rhs: Self) -> Bool:
        return self.x < rhs.x


@fieldwise_init
struct PairDist(Comparable, TrivialRegisterPassable, Writable):
    var dist: Int
    var id_0: Int
    var id_1: Int

    def __lt__(self: Self, rhs: Self) -> Bool:
        return self.dist < rhs.dist


struct MaxHeap[T: Comparable & Copyable & ImplicitlyDeletable](Sized):
    var data: List[Self.T]

    def __init__(out self, capacity: Int = 0):
        self.data = List[Self.T](capacity=capacity)

    def __len__(self) -> Int:
        return len(self.data)

    def top(ref self) -> Optional[Self.T]:
        if len(self.data) == 0:
            return None
        return self.data[0].copy()

    def push(mut self, var value: Self.T):
        self.data.append(value^)
        self._bubble_up(len(self.data) - 1)

    def pop(mut self) -> Self.T:
        if len(self.data) == 1:
            return self.data.pop()

        var root_val = self.data[0].copy()
        var v = self.data.pop()
        self.data[0] = v^
        self._bubble_down(0)
        return root_val^

    def replace_root(mut self, var value: Self.T):
        self.data[0] = value^
        self._bubble_down(0)

    def _bubble_up(mut self, index: Int):
        var curr = index
        while curr > 0:
            var parent = (curr - 1) // 2
            if self.data[curr] > self.data[parent]:
                self.data.swap_elements(curr, parent)
                curr = parent
            else:
                break

    def _bubble_down(mut self, index: Int):
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


def l2_squared(p1: Point, p2: Point) -> Int:
    var dx = p1.x - p2.x
    var dy = p1.y - p2.y
    var dz = p1.z - p2.z
    return dx * dx + dy * dy + dz * dz


struct DisjointSetUnion:
    var parent: List[Int]
    var size: List[Int]

    def __init__(out self, n: Int):
        self.parent = [i for i in range(n)]
        self.size = List[Int](length=n, fill=1)

    def find(mut self, i: Int) -> Int:
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

    def union(mut self, i: Int, j: Int):
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


def day8[p: Int, nb_to_connect: Int = 1000](file_path: String) raises -> Int:
    var points = List[Point]()
    with open(file_path, "r") as f:
        for i, line in enumerate(f.read().split("\n")):
            var xyz = line.split(",")
            var x = atol(xyz[0])
            var y = atol(xyz[1])
            var z = atol(xyz[2])
            points.append(Point(x, y, z, i))
    var nb_pts = len(points)

    comptime if p == 1:
        sort(points)  # sort by x

        var max_heap = MaxHeap[PairDist](nb_to_connect)
        for i in range(nb_pts):
            ref p_i = points[i]
            for j in range(i + 1, nb_pts):
                ref p_j = points[j]

                var dx = p_i.x - p_j.x
                var dx2 = dx * dx

                var top = max_heap.top()
                var current_max_dist = top.value().dist if top else Int.MAX

                if len(max_heap) == nb_to_connect and dx2 >= current_max_dist:
                    break

                var dy = p_i.y - p_j.y
                var dz = p_i.z - p_j.z

                var dist = dx2 + dy * dy + dz * dz

                if len(max_heap) < nb_to_connect:
                    max_heap.push(PairDist(dist, p_i.id, p_j.id))

                elif dist < current_max_dist:
                    max_heap.replace_root(PairDist(dist, p_i.id, p_j.id))

        var dsu = DisjointSetUnion(nb_pts)

        for pair in max_heap.data:
            dsu.union(pair.id_0, pair.id_1)

        var final_sizes = List[Int]()
        for i in range(nb_pts):
            if dsu.parent[i] == i:
                final_sizes.append(dsu.size[i])
        sort(final_sizes)
        _len = len(final_sizes)
        return (
            final_sizes[_len - 1]
            * final_sizes[_len - 2]
            * final_sizes[_len - 3]
        )

    else:
        var min_dist = [max_finite[DType.int64]() for _ in range(nb_pts)]
        var parent = [Int64(-1) for _ in range(nb_pts)]
        var visited = [False for _ in range(nb_pts)]

        min_dist[0] = 0

        var max_dist_found: Int64 = -1
        var last_u: Int64 = -1
        var last_v: Int64 = -1
        for _ in range(nb_pts):
            # find unvisited node with smallest min_dist
            var u = -1
            for i in range(nb_pts):
                if not visited[i]:
                    if u == -1 or min_dist[i] < min_dist[u]:
                        u = i

            visited[u] = True

            # track "last edge"
            if parent[u] != -1:
                var d = min_dist[u]
                if d > max_dist_found:
                    max_dist_found = d
                    last_u = parent[u]
                    last_v = Int64(u)

            # update distances to neighbors
            for v in range(nb_pts):
                if not visited[v]:
                    var d2 = Int64(l2_squared(points[u], points[v]))

                    if d2 < min_dist[v]:
                        min_dist[v] = d2
                        parent[v] = Int64(u)

        return points[last_u].x * points[last_v].x


def main() raises:
    comptime test_file_path, file_path = input_paths[2025, 8]()

    print("\nAoC 2025 - Day 8")

    assert_equal(day8[1, 10](test_file_path), 40)
    print("part 1:", day8[1, 1000](file_path))

    assert_equal(day8[2](test_file_path), 25272)
    print("part 2:", day8[2](file_path))

    basic_bench[day8[nb_to_connect=1000, _], 1, file_path]()
    basic_bench[day8[nb_to_connect=1000, _], 2, file_path]()
