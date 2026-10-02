#!/usr/bin/env python3
"""Independent set/neighbor oracle for the imported copying Life variants."""
from collections import Counter
from pathlib import Path

SEED = {
    (2,20),(3,19),(3,21),(4,18),(4,22),(4,23),(4,32),(5,7),(5,8),(5,18),
    (5,22),(5,23),(5,29),(5,30),(5,31),(5,32),(5,36),(6,7),(6,8),(6,18),
    (6,22),(6,23),(6,28),(6,29),(6,30),(6,31),(6,36),(7,19),(7,21),(7,28),
    (7,31),(7,40),(7,41),(8,20),(8,28),(8,29),(8,30),(8,31),(8,40),(8,41),
    (9,29),(9,30),(9,31),(9,32),
}


def summary(generations):
    living = SEED.copy()
    for _ in range(generations):
        counts = Counter((x+dx,y+dy) for x,y in living
                         for dx in (-1,0,1) for dy in (-1,0,1) if dx or dy)
        living = {p for p,n in counts.items() if n == 3 or (n == 2 and p in living)}
    value = 0
    for x,y in sorted(living):
        value = ((value * 16777619 + x) * 16777619 + y) & 0xffffffff
    return f"{len(living)} {value:X}"


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2] / "examples/benchmarks"
    for profile,generations,reps in (("smoke",10,1),("normal",50,3),("large",250,3)):
        expected = ";".join([summary(generations)] * reps) + "\n"
        for name in ("klife_eq","kitlife35u_smlnj"):
            assert (root/name/(profile+".expected")).read_text() == expected
    print("life oracle: six independently derived fixtures agree")
