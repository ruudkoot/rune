#!/bin/sh
# What the REPL costs a person at a terminal (docs/plans/repl.md, M1 and
# Measuring): the start to the first prompt, an entry to its answer, and a
# paste of 10, 100, 1,000 and 2,000 declarations to the answer of the last,
# each measured on a pty by tests/terminal/ptyraw.py, best of RUNS runs; and
# what lib/terminal's editor does for a key at 10 to 1,000 lines
# (tests/terminal/keystroke.sml, M5). The entries and the pastes are typed to
# the basic mode (--basic), which M1's baselines measured and which reads a
# paste a line at a time; the start is measured with the editor too (M6).
#   scripts/perf-repl.sh [RUNS]
# The load average is printed with the table: the numbers mean little on a
# machine that runs something else.
set -u
cd "$(dirname "$0")/.."
runs=${1:-5}
out=tests/out/perf-repl
mkdir -p "$out"
repl="bin/runevm --heap-size 67108864 --restore bin/rune-repl.img -- -q --no-init --color=never"
best() { sort -n | head -1; }
# measure SCRIPT LABEL [OPTION]: the best of the runs of one script's REPORT
# LABEL, the REPL given OPTION (--basic by default)
measure() {
  i=0
  while [ $i -lt "$runs" ]; do
    # shellcheck disable=SC2086
    python3 tests/terminal/ptyraw.py 80 24 "$1" -- $repl ${3---basic} | sed -n "s/^REPORT $2 \([0-9.]*\) ms$/\1/p"
    i=$((i + 1))
  done | best
}
printf 'mark start\nuntil - 30\nreport start\nmark entry\nwrite 1;\\r\nuntil val it = 1 : int\\r\\n- 30\nreport entry\nwrite \\x04\nquiet 300\n' > "$out/start.script"
printf '%-36s %12s\n' "what" "best, ms"
printf '%-36s %12s\n' "start to the first prompt" "$(measure "$out/start.script" start)"
printf 'mark start\nuntil - 30\nreport start\nwrite \\x04\nquiet 300\n' > "$out/start-editor.script"
printf '%-36s %12s\n' "start to the editor's first prompt" "$(measure "$out/start-editor.script" start "")"
printf '%-36s %12s\n' "1; to its answer" "$(measure "$out/start.script" entry)"
for n in 10 100 1000 2000; do
  python3 - "$n" "$out/paste$n.script" << 'EOF'
import sys
n, path = int(sys.argv[1]), sys.argv[2]
lines = ["val x%d = %d" % (i, i) for i in range(n)]
lines[-1] += ";"
text = "\\r".join(lines) + "\\r"
# the prompt after the last echo, which comes in the order of the names
open(path, "w").write("until - 30\nmark paste\nwrite %s\nuntil : int\\r\\n- 600\nreport paste\nwrite \\x04\nquiet 300\n"
                      % text)
EOF
  r=$runs; [ "$n" -ge 1000 ] && runs=2
  printf '%-36s %12s\n' "a paste of $n lines" "$(measure "$out/paste$n.script" paste)"
  runs=$r
done
# what lib/terminal's editor does for a key (M5): tests/terminal/keystroke.sml
if bin/rune --library terminal tests/terminal/keystroke.sml -o "$out/keystroke.rbc" > /dev/null; then
  bin/runevm "$out/keystroke.rbc"
fi
echo "load average: $(cut -d' ' -f1-3 /proc/loadavg 2> /dev/null || uptime)"
