#!/bin/sh
# Numerical application checkers must reject a perturbed complete-state fixture.
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
out=$(mktemp -d "$root/tests/out/benchmarks/state-negative.XXXXXX")
for name in simple kitsimple simple-smlnj; do
  job=$out/$name
  mkdir -p "$job/data/expected"
  python3 - "$root" "$job" "$name" <<'PY'
import csv, sys
from pathlib import Path
root, job, name = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
suite = root / "examples/benchmarks"
row = next(r for r in csv.DictReader((suite / "manifest.tsv").open(), delimiter="\t")
           if r["benchmark"] == name and r["profile"] == "smoke")
(job / "sources").write_text("\n".join(str(suite / f) for f in row["sources"].split(",")) + "\n")
(job / "input").write_text(name + "\n" + row["args"] + "\n" + (suite / row["expected"]).read_text())
reference = row["args"].split()[-1]
lines = (suite / name / reference).read_text().splitlines()
values = lines[1].split()
values[0] = str(float(values[0].replace("~", "-")) + 1.0).replace("-", "~")
lines[1] = " ".join(values)
(job / "data" / reference).write_text("\n".join(lines) + "\n")
(job / "files").write_text(reference + "\n")
PY
  if RUNE_BENCH_COMPILE_OPTIONS=-O2 RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs rune --program-list "$job/sources" \
    --program-input "$job/input" --program-data "$job/data" --program-data-list "$job/files" \
    --program-out "$job/matrix" < /dev/null > "$job/result.log" 2>&1; then
    echo "state checker accepted perturbed $name" >&2
    exit 1
  fi
  grep -q "^FAIL $name -- Fail: hydrodynamic state" "$job/matrix/rune/program/stdout"
  grep -q '^SUMMARY 1 checks, 1 failed' "$job/matrix/rune/program/stdout"
  echo "PASS $name rejects perturbed full state"
done
