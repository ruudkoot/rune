"""Chudnovsky reference, independent of the imported iterative spigot."""
from decimal import Decimal, localcontext
from pathlib import Path


def digits(n):
    with localcontext() as ctx:
        ctx.prec = n + 60
        coefficient, linear, power, k = 1, 13591409, 1, 6
        total = Decimal(linear)
        for i in range(1, n // 14 + 5):
            coefficient = coefficient * (k * k * k - 16 * k) // (i * i * i)
            linear += 545140134
            power *= -262537412640768000
            total += Decimal(coefficient * linear) / power
            k += 12
        pi = 426880 * Decimal(10005).sqrt() / total
        return str(pi).replace(".", "")[:n]


if __name__ == "__main__":
    base = Path(__file__).resolve().parent
    for profile, count in (("smoke", 30), ("normal", 100), ("large", 2000)):
        expected = digits(count)
        assert len(expected) == count and expected.startswith("31415926535897932384626433832795"[:count])
        assert (base / (profile + ".expected")).read_text() == expected + "\n"
    print("iter-pidigits oracle: three independent fixtures agree")
