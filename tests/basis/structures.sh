#!/bin/sh
# Which structures of the Basis Library each system provides: a Markdown
# table for docs/basis-compat.md.
#   tests/basis/structures.sh
# Every structure of the specification, required and optional, is probed
# with `structure Probe = NAME` on Rune (bin/rune) and on the MLton, SML/NJ
# and Poly/ML that `make hosts` installed under
# ${RUNE_HOSTS:-$HOME/.local/rune-hosts} (override: MLTON=, SMLNJ=, POLY=;
# the 32-bit SML/NJ has the library of the 64-bit one). A system has a
# structure when that declaration compiles in its default environment.
set -u
cd "$(dirname "$0")/../.."
root=$(pwd)
work=$root/tests/out/structures
rm -rf "$work"
mkdir -p "$work"
hosts=${RUNE_HOSTS:-$HOME/.local/rune-hosts}

# The specification's structures, in the order of its index (functors and
# signatures are left out).
names="Array ArraySlice BinIO BinPrimIO Bool Byte Char CharArray CharArraySlice
CharVector CharVectorSlice CommandLine Date General IEEEReal IO Int LargeInt
LargeReal LargeWord List ListPair Math OS OS.FileSys OS.IO OS.Path OS.Process
Option Position Real String StringCvt Substring Text TextIO TextPrimIO Time
Timer Vector VectorSlice Word Word8 Word8Array Word8ArraySlice Word8Vector
Word8VectorSlice
Array2 BoolArray BoolArray2 BoolArraySlice BoolVector BoolVectorSlice
CharArray2 FixedInt GenericSock INetSock Int8 Int16 Int32 Int64 IntInf
IntArray IntArray2 IntArraySlice IntVector IntVectorSlice Int8Array
Int8Array2 Int8ArraySlice Int8Vector Int8VectorSlice Int16Array Int16Array2
Int16ArraySlice Int16Vector Int16VectorSlice Int32Array Int32Array2
Int32ArraySlice Int32Vector Int32VectorSlice Int64Array Int64Array2
Int64ArraySlice Int64Vector Int64VectorSlice LargeIntArray LargeIntArray2
LargeIntArraySlice LargeIntVector LargeIntVectorSlice LargeRealArray
LargeRealArray2 LargeRealArraySlice LargeRealVector LargeRealVectorSlice
LargeWordArray LargeWordArray2 LargeWordArraySlice LargeWordVector
LargeWordVectorSlice NetHostDB NetProtDB NetServDB PackRealBig
PackRealLittle PackReal64Big PackReal64Little PackWord16Big PackWord16Little
PackWord32Big PackWord32Little PackWord64Big PackWord64Little Posix
RealArray RealArray2 RealArraySlice RealVector RealVectorSlice Real32
Real32Array Real32Array2 Real32ArraySlice Real32Vector Real32VectorSlice
PackReal32Big PackReal32Little Real64
Real64Array Real64Array2 Real64ArraySlice Real64Vector Real64VectorSlice
SML90 Socket Unix UnixSock WideChar WideCharArray WideCharVector WideString
WideSubstring WideText WideTextIO WideTextPrimIO Windows WordArray
WordArray2 WordArraySlice WordVector WordVectorSlice Word16 Word16Array
Word16Array2 Word16ArraySlice Word16Vector Word16VectorSlice Word32
Word32Array Word32Array2 Word32ArraySlice Word32Vector Word32VectorSlice
Word64 Word64Array Word64Array2 Word64ArraySlice Word64Vector
Word64VectorSlice Word8Array2"

for n in $names; do
  echo "structure Probe = $n" > "$work/$(echo "$n" | tr . _).sml"
done

# probe SYSTEM COMMAND...: "SYSTEM NAME yes|no" per structure.
probe_rune() {
  for n in $names; do
    f=$work/$(echo "$n" | tr . _).sml
    if "$root/bin/rune" --typecheck-only "$f" > /dev/null 2>&1; then r=yes; else r=no; fi
    echo "$1 $n $r"
  done
}
probe_mlton() {
  for n in $names; do
    f=$work/$(echo "$n" | tr . _).sml
    m=$work/$1.$(echo "$n" | tr . _).mlb
    printf '$(SML_LIB)/basis/basis.mlb\n"%s"\n' "$f" > "$m"
    if "$2" -stop tc "$m" > /dev/null 2>&1; then r=yes; else r=no; fi
    echo "$1 $n $r"
  done
}
# SML/NJ and Poly/ML: one session that uses every probe and survives failures.
probe_session() {
  d=$work/$1.driver.sml
  : > "$d"
  for n in $names; do
    f=$work/$(echo "$n" | tr . _).sml
    printf 'val () = (use "%s"; print "PROBE %s yes\\n") handle _ => print "PROBE %s no\\n";\n' "$f" "$n" "$n" >> "$d"
  done
  shift
  "$@" "$d" < /dev/null 2> /dev/null | sed -n "s/^PROBE /$system /p"
}

systems="rune"
mlton=${MLTON:-$hosts/mlton/bin/mlton}
smlnj=${SMLNJ:-$hosts/smlnj/bin/sml}
poly=${POLY:-$hosts/polyml/bin/poly}
{
  probe_rune rune
  system=mlton; probe_mlton "$system" "$mlton"
  system=smlnj; probe_session "$system" "$smlnj"
  system=polyml; probe_session "$system" "$poly" -q --use
} > "$work/results"

version() {
  case "$1" in
    rune) echo Rune ;;
    mlton) echo "MLton $("$mlton" 2> /dev/null | sed -n '1s/^MLton \([0-9.]*\).*/\1/p')" ;;
    smlnj) echo "SML/NJ $("$smlnj" @SMLversion 2> /dev/null | sed -n '1s/^sml \([0-9.]*\).*/\1/p')" ;;
    polyml) echo "Poly/ML $("$poly" -v 2> /dev/null | sed -n '1s/^Poly\/ML \([0-9.]*\).*/\1/p')" ;;
  esac
}

ids=$(cut -d ' ' -f 1 "$work/results" | awk '!seen[$0]++')
printf '| Structure |'
for s in $ids; do printf ' %s |' "$(version "$s")"; done
echo
printf '|---|'
for s in $ids; do printf '%s' ':---:|'; done
echo
# A row per structure that some system lacks; the rest are summed up below.
all=""
for n in $names; do
  row=$(for s in $ids; do awk -v s="$s" -v n="$n" '$1 == s && $2 == n { print $3 }' "$work/results"; done | tr '\n' ' ')
  case " $row" in
    *" no "*) printf '| `%s` |' "$n"
              for r in $row; do if [ "$r" = yes ]; then printf ' yes |'; else printf ' |'; fi; done
              echo ;;
    *) all="$all $n" ;;
  esac
done
echo
echo "Provided by all of them:$(for n in $all; do printf ' `%s`' "$n"; done | sed 's/` `/`, `/g')."
