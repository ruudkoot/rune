#!/usr/bin/env python3
"""Integer Park-Miller generator plus Python sort, independent of the port."""
from pathlib import Path


def summary(n):
    seed, values = 117, []
    for _ in range(n):
        values.append(1 + seed * 99999 // 2147483647)
        seed = seed * 16807 % 2147483647
    values.sort()
    value = 0
    for item in values:
        value = (value * 16777619 + item) & 0xffffffff
    return f"{n} {sum(values)} {value:X}\n"


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2] / "examples/benchmarks/kitqsort_no_basislib"
    for profile,n in (("smoke",100),("normal",25000),("large",100000)):
        assert (root/(profile+".expected")).read_text() == summary(n)
    print("qsort oracle: three independently derived fixtures agree")
