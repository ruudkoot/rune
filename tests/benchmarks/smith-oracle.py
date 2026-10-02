#!/usr/bin/env python3
"""Check recorded Smith diagonals against independent exact determinants/minors.

Fraction-free Bareiss elimination differs from the imported Euclidean row/column
reduction. A gcd-one collection of order n-1 minors proves the first n-1 invariant
factors are units. Together with divisibility and determinant product this checks
all absolute invariant factors; signed values preserve the source reduction.
"""
import ast
import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "examples/benchmarks"


def determinant(matrix):
    a = [row[:] for row in matrix]
    previous, sign = 1, 1
    for k in range(len(a) - 1):
        if a[k][k] == 0:
            j = next((j for j in range(k + 1, len(a)) if a[j][k]), None)
            if j is None:
                return 0
            a[k], a[j] = a[j], a[k]
            sign = -sign
        pivot = a[k][k]
        for i in range(k + 1, len(a)):
            for j in range(k + 1, len(a)):
                numerator = a[i][j] * pivot - a[i][k] * a[k][j]
                assert numerator % previous == 0
                a[i][j] = numerator // previous
        for i in range(k + 1, len(a)):
            a[i][k] = 0
        previous = pivot
    return sign * a[-1][-1]


def check():
    for row in csv.DictReader((ROOT / "manifest.tsv").open(), delimiter="\t"):
        if row["benchmark"] not in {"smith-normal-form", "smith-normal-form-mlkit", "smith-nf"}:
            continue
        code = (ROOT / row["benchmark"] / "benchmark.sml").read_text()
        start = code.index("[", code.index("val table"))
        depth = 0
        for end in range(start, len(code)):
            depth += (code[end] == "[") - (code[end] == "]")
            if depth == 0:
                break
        table = ast.literal_eval(code[start:end + 1].replace("~", "-"))
        n = int(row["args"].split()[0])
        a = [r[:n] for r in table[:n]]
        values = (ROOT / row["expected"]).read_text().strip().split(";")
        diag = [int(x.replace("~", "-")) for x in values[0].replace(",", " ").split()]
        assert len(diag) == n and all(v == values[0] for v in values)
        assert all(diag[i + 1] % diag[i] == 0 for i in range(n - 1))
        det = determinant(a)
        assert abs(math.prod(diag)) == abs(det)
        gcd, witnesses = 0, 0
        for i in range(n):
            for j in range(n):
                minor = [[a[x][y] for y in range(n) if y != j] for x in range(n) if x != i]
                gcd = math.gcd(gcd, determinant(minor))
                witnesses += 1
                if gcd == 1:
                    break
            if gcd == 1:
                break
        assert gcd == 1
        print(row["benchmark"], row["profile"], n, det, witnesses, gcd, sep="\t")


if __name__ == "__main__":
    check()
