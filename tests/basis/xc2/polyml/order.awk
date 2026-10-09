# The files of Poly/ML's library, in the order in which its build.sml
# compiles them for a 64-bit Unix system, one per line, and the structures
# that build.sml declares between them, as "@decl DECLARATION". Left out:
# the alternatives for other systems and other sizes of int (Int31,
# IntAsLargeInt, Word32, Word32InLargeWord64, PackReal32Boxed, Windows),
# and what is not the Basis Library but Poly/ML's compiler and extensions:
# the foreign-function interface, weak references, signals, single
# assignment, hash tables, the printer of exceptions, and the files that
# make the PolyML structure and the top level.
#   awk -f order.awk basis/build.sml
BEGIN {
  split("Int31.sml IntAsLargeInt.sml Word32.sml Word32InLargeWord64.sml PackReal32Boxed.sml " \
        "Windows.sml ExnPrinter.sml ForeignConstants.sml ForeignMemory.sml Foreign.sml Weak.sml " \
        "Signal.sml SingleAssignment.sml HashArray.ML UniversalArray.ML PrettyPrinter.sml ASN1.sml " \
        "Statistics.ML InitialPolyML.ML FinalPolyML.sml TopLevelPolyML.sml", out, " ")
  for (i in out) left[out[i]] = 1
}
/^structure [A-Za-z]+ = struct .* end;/ { print "@decl " $0; next }
{
  line = $0
  while (match(line, /"basis\/[A-Za-z0-9_.]+"/)) {
    f = substr(line, RSTART + 7, RLENGTH - 8)
    if (!(f in left) && !(f in seen)) { print f; seen[f] = 1 }
    line = substr(line, RSTART + RLENGTH)
  }
}
