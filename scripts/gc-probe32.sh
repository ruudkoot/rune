#!/bin/sh
# The 32-bit address-space probe (docs/testing.md, *Measuring a collector*;
# docs/plans/garbage-collector-v2.md, *Memory today, and on 32-bit*, D1 and
# D13): how much live data a 32-bit VM's collector can hold.
# scripts/gc-probe32.sml grows its live data 16 MiB at a time, all of it kept,
# until the heap cannot grow. Each probe reports what the program held when it
# stopped and, from the collector's log, the most live data a collection
# completed with: the number D1's 32-bit target is about (1.5 GiB with the
# whole address space and 768 MiB under 2 GiB, where today's copier reaches
# 512 and 255 MiB).
#
#   scripts/gc-probe32.sh [--vm VM] [--fill P] [--latency] [--out DIR]
#
#   --vm VM     the VM (bin/runevm32, from make portability); it must take --gc-log
#   --fill P    also every probe at --heap-fill P
#   --latency   also latency-ring and latency-map of examples/benchmarks at the
#               32-bit size, 50,000 messages of 1 KiB for 1,000,000 steps
#               (about 52 MB live): peak resident memory, address space and
#               pauses
#   --out DIR   the logs and the report (tests/out/gc-probe32)
#
# The probes are bytes (byte arrays of 1 MiB) and tuples (small objects),
# each under ulimit -v 2 GiB (a 32-bit Windows process's user space) and
# 4.5 GiB (more than a 32-bit process can address on a 64-bit kernel: no
# limit). A probe ends when the VM cannot have its next space ("out of
# memory", exit 2, and the log without its end lines) or holds 4 GiB. About
# half a minute; --fill doubles it and --latency adds half a minute.
set -u
cd "$(dirname "$0")/.."
root=$(pwd)
vm=bin/runevm32 fill="" latency=0 out=tests/out/gc-probe32
while [ $# -gt 0 ]; do
  case $1 in
    --vm) vm=$2; shift 2 ;;
    --fill) fill=$2; shift 2 ;;
    --latency) latency=1; shift ;;
    --out) out=$2; shift 2 ;;
    *) sed -n '12,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
  esac
done
case $vm in /*) ;; *) vm=$root/$vm ;; esac
[ -x "$vm" ] || { echo "gc-probe32: no VM $vm (make portability builds bin/runevm32)" >&2; exit 2; }
mkdir -p "$out"
out=$(cd "$out" && pwd)
rm -f "$out"/*.exit
(ulimit -v 6291456; timeout 600 bin/rune scripts/gc-probe32.sml -o "$out/probe32.rbc") || exit 1

# run LABEL LIMIT-KIB INPUT VM-ARGUMENTS...: one run, its files OUT/LABEL.*
run() {
  label=$1 limit=$2 input=$3; shift 3
  (
    cd "$out" || exit 2
    ulimit -v "$limit"
    /usr/bin/time -f '%e %M' -o "$label.time" timeout 1800 "$vm" --gc-log "$label.gclog" "$@" \
      < "$input" > "$label.stdout" 2> "$label.stderr"
  )
  echo $? > "$out/$label.exit"
}

for kind in bytes tuples; do
  for f in 50 $fill; do
    for limit in 2097152 4718592; do
      label=$kind-$((limit / 1048576))g-fill$f
      echo "gc-probe32: $label"
      run "$label" "$limit" /dev/null --heap-fill "$f" probe32.rbc 16 "$kind" 4096
    done
  done
done

if [ $latency = 1 ]; then
  for p in latency-ring latency-map; do
    s=examples/benchmarks
    (ulimit -v 6291456; timeout 600 bin/rune -O2 --lint $s/shared/input.sml $s/shared/latency.sml \
      $s/$p/benchmark.sml $s/shared/main.sml -o "$out/$p.rbc") || exit 1
    printf '%s\n%s\n%s\n' "$p" "50000 1000000 1024 1" \
      "$(python3 tests/benchmarks/latency-oracle.py "$p" 50000 1000000 1024 1)" > "$out/$p.input"
    echo "gc-probe32: $p 50000"
    run "$p-50000" 4194304 "$out/$p.input" "$p.rbc"
  done
fi

python3 - "$out" "$vm" <<'EOF' | tee "$out/report.md"
import glob, os, re, sys
sys.path.insert(0, "tools")
import mmu
out, vm = sys.argv[1], sys.argv[2]
def read(label, ext):
    try:
        return open(os.path.join(out, label + "." + ext), errors="replace").read()
    except OSError:
        return ""
def mib(b):
    return "%d" % (b // 1048576)
print("The address space of %s (scripts/gc-probe32.sh)\n" % vm)
print("| Probe | ulimit -v | --heap-fill | Exit | Held MiB | Most live after a collection, MiB | Its semispace, MiB | Collections | Peak RSS MiB | Wall s |")
print("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
labels = sorted(os.path.basename(p)[:-5] for p in glob.glob(os.path.join(out, "*.exit")))
for label in labels:
    m = re.match(r"(bytes|tuples)-(\d+)g-fill(\d+)$", label)
    if not m:
        continue
    held = re.findall(r"^live (\d+) MiB$", read(label, "stdout"), re.M)
    passes = mmu.parse(os.path.join(out, label + ".gclog"))[3] if read(label, "gclog") else []
    # the last pass with the most live data: a collection that grows the
    # heap is two passes, and the second has the larger semispace
    most = max(passes, key=lambda p: (p["live_after"], p["seq"]), default=None)
    wall, rss = (read(label, "time").strip().splitlines() or ["- 0"])[-1].split()[:2]
    status = read(label, "exit").strip()
    why = read(label, "stderr").strip().splitlines()
    print("| %s | %s | %s | %s%s | %s | %s | %s | %d | %.0f | %s |" % (
        m.group(1), "2 GiB" if m.group(2) == "2" else "4.5 GiB (no limit)", m.group(3), status,
        " (%s)" % why[-1][:40] if status != "0" and why else "", held[-1] if held else "0",
        mib(most["live_after"]) if most else "-", mib(most["heap_size"]) if most else "-", len(passes),
        int(rss) / 1024, wall))
lat = [l for l in labels if l.startswith("latency-")]
if lat:
    print("\n| Run | Result | Peak RSS MiB | VmPeak MiB | Most live MiB | Semispace MiB | Pauses | Longest ms | p99 ms |")
    print("|---|---|---:|---:|---:|---:|---:|---:|---:|")
    for label in lat:
        wall, rss = (read(label, "time").strip().splitlines() or ["- 0"])[-1].split()[:2]
        g = mmu.analyse(os.path.join(out, label + ".gclog")) if read(label, "gclog") else None
        result = "PASS" if re.search(r"^PASS ", read(label, "stdout"), re.M) else "FAIL (exit %s)" % read(label, "exit").strip()
        if g:
            print("| %s | %s | %.0f | %s | %s | %s | %d | %.1f | %.1f |" % (
                label, result, int(rss) / 1024, "%.0f" % (g["vmpeak_kb"] / 1024) if g["vmpeak_kb"] else "-",
                mib(g["max_live_after"]), mib(g["max_heap_size"]), g["pauses"], g["longest_ns"] / 1e6, g["p99_ns"] / 1e6))
        else:
            print("| %s | %s | %.0f | - | - | - | - | - | - |" % (label, result, int(rss) / 1024))
EOF
