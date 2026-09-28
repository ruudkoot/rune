# prims.awk: the primitives of MLton that come in families, one member for
# each width and type (Word8_add, WordS16_extdToWord32, Real32_rndToWordU8,
# ...), made of the structures of shim.sml: an SML file
# with structure XC2PrimGen. The input is the table of gen-xc2-basis.sh
# ("prim<TAB>NAME<TAB>TYPE"); a primitive of no family is left to
# XC2PrimImpl of shim.sml, or to the stubs.
#   awk -v ctypes=FILE -v ambiguous=FILE -f prims.awk TABLE > prims.sml
BEGIN {
  FS = "\t"
  while ((getline l < ctypes) > 0) { split(l, f, "\t"); CTYPE[f[1]] = f[2] }
  while ((getline l < ambiguous) > 0) AMB[l] = 1
}
function die(msg) { print "prims.awk: " msg > "/dev/stderr"; exit 2 }
function mangle(t) {
  gsub(/->/, " to ", t); gsub(/\*/, " x ", t); gsub(/'/, "q", t)
  gsub(/[^A-Za-z0-9]+/, "_", t); sub(/^_/, "", t); sub(/_$/, "", t)
  return t
}
# the storage of an integer type of kind K (I or W) and width N: the
# structure of XC2Fixed, or one made here for an odd width
function inst(k, n,   s, rune) {
  n = n + 0
  if (k == "C") { s = "C" n; if (n != 8 && n != 16 && n != 32) die("char" n); return use(s) }
  s = k n
  if (n == 8 || n == 16 || n == 32 || n == 64) { EXTRA[s] = "XC2Fixed." s; return use(s) }
  if (!(s in EXTRA)) {
    rune = n < 8 ? 8 : n < 16 ? 16 : n < 32 ? 32 : 64
    if (k == "I") EXTRA[s] = "XC2FixedInt (type int = " (rune == 64 ? "Int" : "Int" rune) ".int val width = " n " val toInt = " (rune == 64 ? "fn x => x" : "Int" rune ".toInt") " val fromInt = " (rune == 64 ? "fn x => x" : "Int" rune ".fromInt") ")"
    else EXTRA[s] = "XC2FixedWord (type word = " (rune == 64 ? "Word" : "Word" rune) ".word val width = " n " val toLarge = " (rune == 64 ? "fn x => x" : "Word" rune ".toLarge") " val fromLarge = " (rune == 64 ? "fn x => x" : "Word" rune ".fromLarge") ")"
  }
  return use(s)
}
function use(s) { if (!(s in USED)) { USED[s] = 1; ORDER[++NORDER] = s }; return "O_" s }
# the storage of the type T (one type, no arrows): WIDTH gives a bare int,
# word, char or real its width; OTHER is the kind of the other bare name, for
# `big`
function res(t, width, other,   m, k) {
  gsub(/^ +| +$/, "", t); gsub(/^\(|\)$/, "", t)
  if (t == "int") return inst("I", width)
  if (t == "word") return inst("W", width)
  if (t == "char") return inst("C", width)
  if (t == "big") return inst(other, width)
  if (t == "real") return "R" width
  if (match(t, /^(Primitive\.)?Int[0-9]+\.(int|t)$/)) { m = t; sub(/^Primitive\./, "", m); sub(/^Int/, "", m); sub(/\..*/, "", m); return inst("I", m) }
  if (match(t, /^(Primitive\.)?Word[0-9]+\.(word|t)$/)) { m = t; sub(/^Primitive\./, "", m); sub(/^Word/, "", m); sub(/\..*/, "", m); return inst("W", m) }
  if (match(t, /^Real[0-9]+\.(real|t)$/)) { m = t; sub(/^Real/, "", m); sub(/\..*/, "", m); return "R" m }
  if (t == "SeqIndex.int") return inst("I", 64)
  if (match(t, /^C_[A-Za-z0-9_]+\.t$/)) {
    k = CTYPE[substr(t, 1, index(t, ".") - 1)]
    if (k ~ /^Int/) return inst("I", substr(k, 4)); if (k ~ /^Word/) return inst("W", substr(k, 5))
  }
  die("the type " t)
}
function kindOf(t) { gsub(/^ +| +$/, "", t); return t == "int" ? "I" : t == "word" ? "W" : t == "char" ? "C" : "" }
function emit(id, e) { if (!(id in DONE)) { DONE[id] = 1; OUT = OUT "  val " id " = " e "\n" } }
$1 == "prim" {
  name = $2; ty = $3
  id = name; if (("prim\t" name) in AMB) id = name "__" mangle(ty)
  # the argument and result types: T1 * T2 ... -> R
  arrow = index(ty, "->"); args = substr(ty, 1, arrow - 1); result = substr(ty, arrow + 2)
  nargs = split(args, A, "*")
  if (match(name, /^Word[0-9]+_(add|sub|neg|mul|andb|orb|xorb|notb|lshift|rol|ror)$/)) {
    n = name; sub(/^Word/, "", n); sub(/_.*/, "", n); op = name; sub(/^Word[0-9]+_/, "", op)
    emit(id, res(A[1], n) "." op)
  } else if (match(name, /^Word[SU][0-9]+_(lt|mul|quot|rem|rshift)$/)) {
    s = substr(name, 5, 1); n = substr(name, 6); sub(/_.*/, "", n); op = name; sub(/^Word[SU][0-9]+_/, "", op)
    emit(id, res(A[1], n) "." (op == "mul" ? "mul" : op s))
  } else if (match(name, /^WordS[0-9]+_(add|sub|mul|neg)CheckP$/)) {
    n = substr(name, 6); sub(/_.*/, "", n); op = name; sub(/^WordS[0-9]+_/, "", op)
    emit(id, res(A[1], n) "." op)
  } else if (match(name, /^Word[SU][0-9]+_extdToWord[0-9]+$/)) {
    s = substr(name, 5, 1); a = substr(name, 6); sub(/_.*/, "", a); b = name; sub(/.*extdToWord/, "", b)
    ka = kindOf(A[1]); kb = kindOf(result)
    x = res(A[1], a, kb); y = res(result, b, ka)
    emit(id, (x == y ? "fn x => x" : "fn x => " y ".fromBits (" x "." (s == "S" ? "sbits" : "bits") " x)"))
  } else if (match(name, /^Word[SU][0-9]+_rndToReal[0-9]+$/)) {
    s = substr(name, 5, 1); a = substr(name, 6); sub(/_.*/, "", a); b = name; sub(/.*rndToReal/, "", b)
    emit(id, res(A[1], a) ".toReal" b s)
  } else if (match(name, /^Real[0-9]+_rndToWord[SU][0-9]+$/)) {
    a = substr(name, 5); sub(/_.*/, "", a); b = name; sub(/.*rndToWord[SU]/, "", b)
    emit(id, res(result, b) ".fromReal" a)
  } else if (match(name, /^Real[0-9]+_rndToReal[0-9]+$/)) {
    a = substr(name, 5); sub(/_.*/, "", a); b = name; sub(/.*rndToReal/, "", b)
    emit(id, "XC2Real" a ".rndToReal" b)
  } else if (match(name, /^Real[0-9]+_castToWord[0-9]+$/)) {
    a = substr(name, 5); sub(/_.*/, "", a)
    emit(id, "XC2Real" a ".castToWord" a)
  } else if (match(name, /^Word[0-9]+_castToReal[0-9]+$/)) {
    a = substr(name, 5); sub(/_.*/, "", a)
    emit(id, "XC2Real" a ".castFromWord" a)
  } else if (match(name, /^Real[0-9]+_/)) {
    a = substr(name, 5); sub(/_.*/, "", a); op = name; sub(/^Real[0-9]+_/, "", op)
    emit(id, "XC2Real" a "." op)
  } else if (match(name, /^CPointer_(get|set)Word[0-9]+$/)) {
    n = name; sub(/.*Word/, "", n); b = n / 8
    if (name ~ /get/) emit(id, "fn (p, i) => " res(result, n) ".fromBits (XC2Mem.get (p, " b " * i, " b "))")
    else emit(id, "fn (p, i, x) => XC2Mem.set (p, " b " * i, " b ", " res(A[3], n) ".bits x)")
  } else if (match(name, /^CPointer_(get|set)Real[0-9]+$/)) {
    n = name; sub(/.*Real/, "", n); b = n / 8
    if (name ~ /get/) emit(id, "fn (p, i) => XC2Real" n ".castFromWord" n " (" inst("W", n) ".fromBits (XC2Mem.get (p, " b " * i, " b ")))")
    else emit(id, "fn (p, i, x) => XC2Mem.set (p, " b " * i, " b ", " inst("W", n) ".bits (XC2Real" n ".castToWord" n " x))")
  } else if (match(name, /^Word8(Array|Vector)_(sub|update)Word[0-9]+$/)) {
    n = name; sub(/.*Word/, "", n); b = n / 8; w = res((name ~ /update/ ? A[3] : result), n)
    get = (name ~ /Array/ ? "XC2.Array.sub" : "Vector.sub")
    if (name ~ /update/)
      emit(id, "fn (a, i, x) => let val v = " w ".bits x fun loop k = if k >= " b " then () else (XC2.Array.update (a, " b " * i + k, Word8.fromLarge (Word.>> (v, Word.fromInt (8 * k)))); loop (k + 1)) in loop 0 end")
    else
      emit(id, "fn (a, i) => let fun loop (k, v) = if k < 0 then v else loop (k - 1, Word.orb (Word.<< (v, 0w8), Word8.toLarge (" get " (a, " b " * i + k)))) in " w ".fromBits (loop (" (b - 1) ", 0w0)) end")
  }
}
END {
  print "(* Generated by tests/basis/xc2/mlton/gen.sh -- do not edit. *)"
  for (i = 1; i <= NORDER; i++) {
    s = ORDER[i]
    print "structure O_" s " = XC2FixedOps (" (s ~ /^C/ ? "XC2Fixed." s : EXTRA[s]) ")"
  }
  print "structure XC2PrimGen =\nstruct"
  printf "%s", OUT
  print "end"
}
