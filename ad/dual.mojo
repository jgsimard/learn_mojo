from math import (
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
    copysign
)


@fieldwise_init
struct Dual[dtype: DType where dtype.is_floating_point()](
    Copyable, TrivialRegisterType, Writable
):
    """Dual numbers 
    based on https://20k.github.io/c++/2024/05/18/forward-backward-differentiation.html .
    """

    var a: Scalar[Self.dtype]
    """Real part (Value)."""
    var b: Scalar[Self.dtype]
    """ε part (Derivative)."""

    fn __add__(self, other: Self) -> Self:
        return Self(self.a + other.a, self.b + other.b)

    fn __add__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.a + other, self.b)

    fn __radd__(self, other: Scalar[Self.dtype]) -> Self:
        return self + other

    fn __sub__(self, other: Self) -> Self:
        return Self(self.a - other.a, self.b - other.b)

    fn __sub__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.a - other, self.b)

    fn __rsub__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(other - self.a, -self.b)

    fn __mul__(self, other: Self) -> Self:
        return Self(self.a * other.a, self.a * other.b + self.b * other.a)

    fn __mul__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.a * other, self.b * other)

    fn __rmul__(self, other: Scalar[Self.dtype]) -> Self:
        return self * other

    fn __truediv__(self, other: Self) -> Self:
        return Self(
            self.a / other.a,
            (self.b * other.a - self.a * other.b) / (other.a * other.a),
        )

    fn __truediv__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.a / other, self.b / other)

    fn __rtruediv__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(other / self.a, (-other * self.b) / (self.a * self.a))

    fn __pow__(self, n: Scalar[Self.dtype]) -> Self:
        # Rule: (a + bε)^n = a^n + (n * a^(n-1) * b)ε
        return Self(pow(self.a, n), n * pow(self.a, n - 1) * self.b)

    fn __pow__(self, other: Self) -> Self:
        # Rule: (a + bε)^(c + dε) = a^c + (a^c * (b*c/a + d*log(a)))ε
        var val = pow(self.a, other.a)
        return Self(
            val, val * (self.b * other.a / self.a + other.b * log(self.a))
        )

    fn log(self) -> Self:
        return Self(log(self.a), self.b / self.a)

    fn exp(self) -> Self:
        var val = exp(self.a)
        return Self(val, self.b * val)

    fn sin(self) -> Self:
        return Self(sin(self.a), self.b * cos(self.a))

    fn cos(self) -> Self:
        return Self(cos(self.a), -self.b * sin(self.a))

    fn tan(self) -> Self:
        var val = tan(self.a)
        return Self(val, self.b / pow(cos(self.a), 2))

    fn sinh(self) -> Self:
        return Self(sinh(self.a), self.b * cosh(self.a))

    fn cosh(self) -> Self:
        return Self(cosh(self.a), self.b * sinh(self.a))

    fn tanh(self) -> Self:
        var val = tanh(self.a)
        return Self(val, self.b * (1 - pow(val, 2)))

    fn asin(self) -> Self:
        return Self(asin(self.a), self.b / sqrt(1 - pow(self.a, 2)))

    fn acos(self) -> Self:
        return Self(acos(self.a), -self.b / sqrt(1 - pow(self.a, 2)))

    fn atan(self) -> Self:
        return Self(atan(self.a), self.b / (1 + pow(self.a, 2)))

    fn atan2(self, other: Self) -> Self:
        # Rule: atan2(a, c) + ((bc - ad) / (c^2 + a^2))ε
        return Self(
            atan2(self.a, other.a),
            (self.b * other.a - self.a * other.b)
            / (pow(other.a, 2) + pow(self.a, 2)),
        )

    fn __abs__(self) -> Self:
        # Rule: |a| + sign(a)*bε
        var sign = copysign(Scalar[Self.dtype](1), self.a)
        return Self(abs(self.a), sign * self.b)

    fn __lt__(self, other: Self) -> Bool:
        return self.a < other.a

    fn __gt__(self, other: Self) -> Bool:
        return self.a > other.a

    fn __le__(self, other: Self) -> Bool:
        return self.a <= other.a

    fn __ge__(self, other: Self) -> Bool:
        return self.a >= other.a

    fn __eq__(self, other: Self) -> Bool:
        return self.a == other.a

    fn __ne__(self, other: Self) -> Bool:
        return self.a != other.a

    fn max(self, other: Self) -> Self:
        return self if self.a >= other.a else other


# --- Usage Example ---
fn main():
    # Define a variable x = 2.0, and we want d/dx, so b=1.0
    var x = Dual(2.0, 1.0)

    # f(x) = x^2 + sin(x)
    # f'(x) = 2x + cos(x)
    var res = (x * x) + x.sin()

    print(res)
    # Value: 2^2 + sin(2) ≈ 4 + 0.909 = 4.909
    # Deriv: 2(2) + cos(2) ≈ 4 - 0.416 = 3.583
