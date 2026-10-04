#!/bin/sh
# The census VM against the stock one (docs/census.md): one small program of
# tests/perf, compiled to the register bytecode by bin/rune, run by
# bin/runevm --jit=off --count and by bin/runevm-census with a trace
# directory. The two --count lines and the two outputs must be equal, the
# census's tables must account for every byte and object the count reports,
# the summary mode must report the same count, and the static census must
# describe every function of the program. Prints one line per check and
# exits 1 on a failure. Override the binaries with RUNE_NEW, RUNEVM_NEW and
# RUNEVM_CENSUS; PROGRAM names another source (default tests/perf/list_ops.sml).
set -u
rune=${RUNE_NEW:-bin/rune}
vm=${RUNEVM_NEW:-bin/runevm}
census=${RUNEVM_CENSUS:-bin/runevm-census}
prog=${PROGRAM:-tests/perf/list_ops.sml}
out=tests/out/census-check   # its own directory: scripts/census.sh keeps workloads under tests/out/census
rm -rf "$out"
mkdir -p "$out"
status=0
fail() { echo "FAIL census.$1"; status=1; }
if ! "$rune" "$prog" -o "$out/prog.rbc" 2> "$out/cerr"; then
  echo "FAIL census.compile: $(head -1 "$out/cerr")"; exit 1
fi
count() { sed -n 's/^runevm: count: //p' "$1" | tail -1; }
"$vm" --jit=off --count "$out/prog.rbc" < /dev/null > "$out/stock.stdout" 2> "$out/stock.stderr"
stock=$(count "$out/stock.stderr")
[ -n "$stock" ] || { echo "FAIL census.stock: no count line: $(head -1 "$out/stock.stderr")"; exit 1; }
# the full trace, with a forced collection every 64 KiB so that a small
# program still has samples
"$census" --jit=off --count --census-dir "$out/trace" --census-every 65536 "$out/prog.rbc" < /dev/null > "$out/census.stdout" 2> "$out/census.stderr"
traced=$(count "$out/census.stderr")
if [ "$traced" = "$stock" ]; then echo "ok   census.count: $stock"; else fail "count: stock [$stock] census [$traced]"; fi
if cmp -s "$out/stock.stdout" "$out/census.stdout"; then echo "ok   census.output"; else fail "output: the census VM's stdout differs"; fi
bytes=$(echo "$stock" | sed -n 's/.* instructions, \([0-9]*\) bytes, .*/\1/p')
objects=$(echo "$stock" | sed -n 's/.* bytes, \([0-9]*\) objects$/\1/p')
tbytes=$(sed -n 's/^# bytes_l0 \([0-9]*\).*/\1/p' "$out/trace/census.txt" | head -1)
tobjects=$(sed -n 's/^# objects \([0-9]*\).*/\1/p' "$out/trace/census.txt" | head -1)
if [ "$tbytes" = "$bytes" ] && [ "$tobjects" = "$objects" ]; then echo "ok   census.tables: $tobjects objects, $tbytes bytes"; else fail "tables: census.txt says $tobjects objects, $tbytes bytes"; fi
for f in alloc.bin fields.bin death.bin samples.bin pcs.bin; do
  [ -s "$out/trace/$f" ] || fail "trace: $f missing or empty"
done
[ -e "$out/trace/stores.bin" ] || fail "trace: stores.bin missing"   # empty for a program without refs or arrays
samples=$(sed -n 's/^# samples \([0-9]*\).*/\1/p' "$out/trace/census.txt" | head -1)
[ -n "$samples" ] && [ "$samples" -gt 0 ] && echo "ok   census.samples: $samples forced collections" || fail "samples: none recorded"
# the summary mode: the same count, census.txt alone
"$census" --jit=off --count --census-dir "$out/summary" --census-every 65536 --census-summary "$out/prog.rbc" < /dev/null > /dev/null 2> "$out/summary.stderr"
summary=$(count "$out/summary.stderr")
if [ "$summary" = "$stock" ] && [ -s "$out/summary/census.txt" ] && [ ! -e "$out/summary/alloc.bin" ]; then echo "ok   census.summary"; else fail "summary: count [$summary], files $(ls "$out/summary" 2>/dev/null | tr '\n' ' ')"; fi
# the static census: a line per function and a line per site
"$census" --census-static "$out/prog.rbc" > "$out/static.tsv" 2> "$out/static.stderr" || fail "static: exit $?"
nf=$(grep -c '^F	' "$out/static.tsv"); ns=$(grep -c '^S	' "$out/static.tsv")
funcs=$(sed -n 's/^# static census of .*: \([0-9]*\) functions.*/\1/p' "$out/static.tsv")
if [ "$nf" = "$funcs" ] && [ "$ns" -gt 0 ]; then echo "ok   census.static: $nf functions, $ns sites"; else fail "static: $nf of $funcs functions, $ns sites"; fi
[ $status = 0 ] && echo "check-census: ok"
exit $status
