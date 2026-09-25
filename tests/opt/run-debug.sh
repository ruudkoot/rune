#!/bin/sh
# The debug information of programs runeopt made (docs/native.md,
# Debug information):
#   tests/opt/run-debug.sh [--runeopt BIN] [-j N] RBC...
# For each program, translated as bin/runevm-opt translates it (or taken from
# its cache, tests/out/opt-cache):
#  * the line table of the executable, as llvm-dwarfdump reads it (file, line
#    and column) and as readelf decodes it (line), is the line table of the
#    .rbc, in the same order: the position of every instruction that has code
#    (a POP has none), as runeopt --disasm prints it;
#  * addr2line gives every function whose first instruction has a position
#    (all but the top level, which begins before the first), at the address
#    of its symbol, the line of that instruction.
# llvm-dwarfdump is looked for under its versioned names too; where it is
# not installed that part is left out, and said so. With --debuggers, gdb and
# lldb, where they are installed, stop at a line of the first program's own
# source.
set -u
opt=bin/runeopt-mlton
jobs=""
one=""
debuggers=0
while [ $# -gt 0 ]; do
  case $1 in
    --runeopt) opt=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    --one) one=$2; shift 2 ;;
    --debuggers) debuggers=1; shift ;;
    *) break ;;
  esac
done
cd "$(dirname "$0")/../.."
root=$(pwd)
case $opt in /*) ;; *) opt=$root/$opt ;; esac
out=$root/tests/out/opt-debug
cache=${RUNEOPT_CACHE:-$root/tests/out/opt-cache}
mkdir -p "$out" "$cache"

dwarfdump=""
for d in llvm-dwarfdump $(cd /usr/bin 2> /dev/null && ls llvm-dwarfdump-* 2> /dev/null | sort -t- -k3 -n -r); do
  command -v "$d" > /dev/null 2>&1 && { dwarfdump=$d; break; }
done

# exe RBC: the executable of a program, as bin/runevm-opt keeps it
exe() {
  e=$cache/$(sha256sum < "$1" | cut -c1-32)
  if [ ! -x "$e" ]; then
    "$opt" "$1" -o "$e.$$" > "$e.$$.log" 2>&1 || { rm -f "$e.$$" "$e.$$.s"; return 1; }
    rm -f "$e.$$.log"
    mv -f "$e.$$" "$e"
  fi
  echo "$e"
}

# collapse: consecutive equal lines as one
collapse() { awk 'NR == 1 || $0 != last { print } { last = $0 }'; }

if [ -n "$one" ]; then
  rbc=$one
  name=$(echo "$rbc" | tr '/' '_')
  e=$(exe "$rbc") || { echo "FAIL debug $rbc: runeopt failed"; exit 0; }
  # the position of every instruction that has code: a POP has none, and
  # where two positions fall on one address the assembler keeps the last
  "$opt" --disasm "$rbc" | awk '/\t; / && $2 != "POP" { p = $0; sub(/.*\t; /, "", p); print p }' |
    collapse > "$out/$name.rbc-lines"
  if [ -n "$dwarfdump" ]; then
    # DWARF 5 keeps a file as a directory and a name; directory 0 is where
    # the assembler ran, which a path without a directory of its own gets
    "$dwarfdump" --debug-line "$e" | awk '
      /^include_directories\[/ { d = $0; sub(/^include_directories\[ */, "", d); sub(/\].*/, "", d)
                                 v = $0; sub(/^[^"]*"/, "", v); sub(/"$/, "", v); dir[d] = v }
      /^file_names\[/ { n = $0; sub(/^file_names\[ */, "", n); sub(/\].*/, "", n) }
      /^ *name: "/ { f = $0; sub(/^ *name: "/, "", f); sub(/"$/, "", f); file[n] = f }
      /^ *dir_index: / { if ($2 != 0) file[n] = dir[$2] "/" file[n] }
      /^0x[0-9a-f]+ / && $0 !~ /end_sequence/ { print file[$4] ":" $2 ":" $3 }' | collapse > "$out/$name.dwarf-lines"
    cmp -s "$out/$name.rbc-lines" "$out/$name.dwarf-lines" ||
      { echo "FAIL debug $rbc: the DWARF line table is not the .rbc's (diff $out/$name.rbc-lines $out/$name.dwarf-lines)"; exit 0; }
  fi
  sed 's/:[0-9]*$//' "$out/$name.rbc-lines" | sed 's/.*://' | collapse > "$out/$name.rbc-lineno"
  readelf --debug-dump=decodedline "$e" 2> /dev/null | awk '$2 ~ /^[0-9]+$/ && $3 ~ /^0x/ { print $2 }' | collapse > "$out/$name.readelf-lineno"
  cmp -s "$out/$name.rbc-lineno" "$out/$name.readelf-lineno" ||
    { echo "FAIL debug $rbc: readelf decodes other lines than the .rbc has (diff $out/$name.rbc-lineno $out/$name.readelf-lineno)"; exit 0; }
  # the first line of each function, by its index, and addr2line at its symbol
  "$opt" --disasm "$rbc" | awk '
    /^function / { f = $2; want = 1; next }
    want { if (/\t; /) { p = $0; sub(/.*\t; /, "", p); sub(/:[0-9]+$/, "", p); print f, p } want = 0 }' > "$out/$name.first"
  nm "$e" | awk '$3 ~ /#[0-9]+$/ { n = $3; sub(/.*#/, "", n); print n, $1 }' | sort -k1,1 > "$out/$name.syms"
  sort -k1,1 "$out/$name.first" | join - "$out/$name.syms" > "$out/$name.joined"
  awk '{ print "0x" $3 }' "$out/$name.joined" | addr2line -e "$e" | sed 's/ (discriminator [0-9]*)//' > "$out/$name.a2l"
  # a relative path is taken from where the assembler ran, which is here
  awk '{ print $2 }' "$out/$name.joined" | paste -d' ' - "$out/$name.a2l" |
    awk -v here="$root" '$1 != $2 && here "/" $1 != $2 { print; bad++ } END { exit bad > 0 }' > "$out/$name.a2l-diff" ||
    { echo "FAIL debug $rbc: addr2line names another line than a function's first (see $out/$name.a2l-diff)"; exit 0; }
  echo OK
  exit 0
fi

[ -n "$jobs" ] || jobs=$(sh scripts/ncpus.sh)
[ -n "$dwarfdump" ] || echo "debug: no llvm-dwarfdump here, so only readelf reads the line tables"
results=$(printf '%s\n' "$@" | xargs -n 1 -P "$jobs" sh tests/opt/run-debug.sh --runeopt "$opt" --one)
n=$(printf '%s\n' "$results" | grep -c '^OK$')
failures=$(printf '%s\n' "$results" | grep -v '^OK$' | grep .)
[ -z "$failures" ] || printf '%s\n' "$failures"
status=0
[ -z "$failures" ] || status=1

# The debuggers, on the first program: a breakpoint at the last line of its
# own file in the line table -- its source is named as the .rbc is -- and
# where they stop. (Not the table's last line: code of the Basis Library
# inlined there may come after it, or be copied where it never runs.)
if [ $debuggers = 1 ] && [ $# -gt 0 ]; then
  e=$(exe "$1")
  src=$(basename "$1" .rbc).sml
  target=$("$opt" --lines "$1" | cut -d' ' -f2 | grep "\(^\|/\)$src:" | tail -1 | sed 's/:[0-9]*$//')
  file=${target%:*} line=${target##*:}
  base=$(basename "$file")
  if command -v gdb > /dev/null 2>&1; then
    gdb -batch -ex "break $base:$line" -ex run -ex "info line *\$pc" "$e" < /dev/null > "$out/gdb.log" 2>&1
    grep -q "Line $line of \"[^\"]*$base\"" "$out/gdb.log" ||
      { echo "FAIL debug gdb: no stop at $base:$line (see $out/gdb.log)"; status=1; }
  else echo "debug: no gdb here"
  fi
  if command -v lldb > /dev/null 2>&1; then
    lldb -b -o "breakpoint set -f $base -l $line" -o run "$e" < /dev/null > "$out/lldb.log" 2>&1
    grep -q "stop reason = breakpoint" "$out/lldb.log" && grep -q "$base:$line" "$out/lldb.log" ||
      { echo "FAIL debug lldb: no stop at $base:$line (see $out/lldb.log)"; status=1; }
  else echo "debug: no lldb here"
  fi
fi

echo "debug: $n programs have the line table of their bytecode$([ $debuggers = 1 ] && echo ', and the debuggers stop at a line')"
exit $status
