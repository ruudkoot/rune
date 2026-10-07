#!/usr/bin/env python3
"""Independent results of the collector's latency workloads.

    python3 tests/benchmarks/latency-oracle.py PROGRAM ARG...
    python3 tests/benchmarks/latency-oracle.py --check [--all]

PROGRAM ARG... prints what latency-ring, latency-map or latency-static-map
(examples/benchmarks) print for those arguments, worked out from what their
comments define -- the messages, the generator, the requests and the digests
-- without running them. --check compares the smoke and normal profiles of
the three in examples/benchmarks/manifest.tsv, and the latency rows of
scripts/gc-eval.tsv at those sizes, with the results they expect; --all adds
the large profiles and the larger rows of the evaluation set (a few minutes).
"""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
MODULUS = 16777213


def window(n, steps, size):
    """Both windows digest every message in the order made: the first, middle
    and last byte of message i after its writes, and its size."""
    acc = 0
    for i in range(n + steps):
        def byte(k):
            if k == size - 1:
                return (i // 256) % 256
            if k == 0:
                return i % 256
            return i % 251
        acc = (acc * 31 + byte(0) * 65536 + byte(size // 2) * 256 + byte(size - 1) + size) % MODULUS
    return "%d %d %d %d" % (n, steps, size, acc)


def static_map(entries, vlen, requests, lookups, garbage):
    letters = "".join(chr(97 + j % 26) for j in range(vlen + 26))
    seed, acc = 42, 0
    for _ in range(requests):
        found = []
        for _ in range(lookups):
            seed = seed * 16807 % 1073741789
            k = seed % entries
            found.append(letters[k % 26:k % 26 + vlen])
        response = "".join(reversed(found))
        size = len(response)
        total = 0
        for j in range(1, garbage + 1):
            total = (total + j * ord(response[j * 7919 % size]) + size - j) % MODULUS
        acc = (acc * 31 + (total + size) % MODULUS) % MODULUS
    return "%d %d %d" % (entries, requests, acc)


def result(program, args):
    words = [int(a) for a in args]
    if program in ("latency-ring", "latency-map") and len(words) == 4:
        return window(*words[:3])
    if program == "latency-static-map" and len(words) == 6:
        return static_map(*words[:5])
    raise SystemExit("latency-oracle: unknown program or arguments: %s %s" % (program, " ".join(args)))


def cases(everything):
    """(where, program, args, expected) for the manifest's profiles and the
    evaluation set's latency rows"""
    suite = ROOT / "examples/benchmarks"
    with (suite / "manifest.tsv").open(newline="") as stream:
        for row in csv.DictReader(stream, delimiter="\t"):
            if row["benchmark"].startswith("latency-") and (everything or row["profile"] != "large"):
                yield ("manifest " + row["profile"], row["benchmark"], row["args"].split(),
                       (suite / row["expected"]).read_text().strip())
    for line in (ROOT / "scripts/gc-eval.tsv").read_text().splitlines():
        cols = line.split("\t")
        if line.startswith("#") or len(cols) < 8 or cols[5] != "bench" or not cols[6].startswith("latency-"):
            continue
        words = cols[6].split()
        if everything or int(words[1]) <= 130000:
            yield ("gc-eval.tsv " + cols[4], words[0], words[1:], cols[7])


def main(argv):
    if argv[:1] != ["--check"]:
        if not argv:
            print(__doc__, file=sys.stderr)
            return 2
        print(result(argv[0], argv[1:]))
        return 0
    failed = 0
    for where, program, args, expected in cases("--all" in argv):
        got = result(program, args)
        if got != expected:
            failed += 1
            print("FAIL %s: %s %s gives %s, expected %s" % (where, program, " ".join(args), got, expected))
        else:
            print("PASS %s: %s %s" % (where, program, " ".join(args)))
    print("latency-oracle: %s" % ("%d failed" % failed if failed else "OK"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
