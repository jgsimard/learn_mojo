from std.math import (
    sin,
    cos,
    tan,
    log,
    exp,
    sqrt,
    pow,
    acos,
    asin,
    atan,
    atan2,
    sinh,
    cosh,
    tanh,
    abs,
    copysign,
)


@fieldwise_init
struct Dual[dtype: DType where dtype.is_floating_point()](
    Copyable, TrivialRegisterPassable, Writable
):
    """Dual numbers
    based on https://20k.github.io/c++/2024/05/18/forward-backward-differentiation.html .
    """

    var a: Scalar[Self.dtype]
    """Real part (Value)."""
    var b: Scalar[Self.dtype]
    """ε part (Derivative)."""

    def __add__(self, other: Self) -> Self:
        return Self(self.a + other.a, self.b + other.b)

    def __add__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.a + other, self.b)

    def __radd__(self, other: Scalar[Self.dtype]) -> Self:
        return self + other

    def __sub__(self, other: Self) -> Self:
        return Self(self.a - other.a, self.b - other.b)

    def __sub__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.a - other, self.b)

    def __rsub__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(other - self.a, -self.b)

    def __mul__(self, other: Self) -> Self:
        return Self(self.a * other.a, self.a * other.b + self.b * other.a)

    def __mul__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.a * other, self.b * other)

    def __rmul__(self, other: Scalar[Self.dtype]) -> Self:
        return self * other

    def __truediv__(self, other: Self) -> Self:
        return Self(
            self.a / other.a,
            (self.b * other.a - self.a * other.b) / (other.a * other.a),
        )

    def __truediv__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.a / other, self.b / other)

    def __rtruediv__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(other / self.a, (-other * self.b) / (self.a * self.a))

    def __pow__(self, n: Scalar[Self.dtype]) -> Self:
        # Rule: (a + bε)^n = a^n + (n * a^(n-1) * b)ε
        return Self(pow(self.a, n), n * pow(self.a, n - 1) * self.b)

    def __pow__(self, other: Self) -> Self:
        # Rule: (a + bε)^(c + dε) = a^c + (a^c * (b*c/a + d*log(a)))ε
        var val = pow(self.a, other.a)
        return Self(
            val, val * (self.b * other.a / self.a + other.b * log(self.a))
        )

    def log(self) -> Self:
        return Self(log(self.a), self.b / self.a)

    def exp(self) -> Self:
        var val = exp(self.a)
        return Self(val, self.b * val)

    def sin(self) -> Self:
        return Self(sin(self.a), self.b * cos(self.a))

    def cos(self) -> Self:
        return Self(cos(self.a), -self.b * sin(self.a))

    def tan(self) -> Self:
        var val = tan(self.a)
        return Self(val, self.b / pow(cos(self.a), 2))

    def sinh(self) -> Self:
        return Self(sinh(self.a), self.b * cosh(self.a))

    def cosh(self) -> Self:
        return Self(cosh(self.a), self.b * sinh(self.a))

    def tanh(self) -> Self:
        var val = tanh(self.a)
        return Self(val, self.b * (1 - pow(val, 2)))

    def asin(self) -> Self:
        return Self(asin(self.a), self.b / sqrt(1 - pow(self.a, 2)))

    def acos(self) -> Self:
        return Self(acos(self.a), -self.b / sqrt(1 - pow(self.a, 2)))

    def atan(self) -> Self:
        return Self(atan(self.a), self.b / (1 + pow(self.a, 2)))

    def atan2(self, other: Self) -> Self:
        # Rule: atan2(a, c) + ((bc - ad) / (c^2 + a^2))ε
        return Self(
            atan2(self.a, other.a),
            (self.b * other.a - self.a * other.b)
            / (pow(other.a, 2) + pow(self.a, 2)),
        )

    def __abs__(self) -> Self:
        # Rule: |a| + sign(a)*bε
        var sign = copysign(Scalar[Self.dtype](1), self.a)
        return Self(abs(self.a), sign * self.b)

    def __lt__(self, other: Self) -> Bool:
        return self.a < other.a

    def __gt__(self, other: Self) -> Bool:
        return self.a > other.a

    def __le__(self, other: Self) -> Bool:
        return self.a <= other.a

    def __ge__(self, other: Self) -> Bool:
        return self.a >= other.a

    def __eq__(self, other: Self) -> Bool:
        return self.a == other.a

    def __ne__(self, other: Self) -> Bool:
        return self.a != other.a

    def max(self, other: Self) -> Self:
        return self if self.a >= other.a else other


# --- Usage Example ---
def main():
    # Define a variable x = 2.0, and we want d/dx, so b=1.0
    var x = Dual(2.0, 1.0)

    # f(x) = x^2 + sin(x)
    # f'(x) = 2x + cos(x)
    var res = (x * x) + x.sin()

    print(res)
    # Value: 2^2 + sin(2) ≈ 4 + 0.909 = 4.909
    # Deriv: 2(2) + cos(2) ≈ 4 - 0.416 = 3.583
