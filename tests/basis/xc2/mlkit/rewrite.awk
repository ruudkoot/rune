# rewrite.awk: an SML source of MLKit's Basis Library with MLKit's
# primitives, `prim ("NAME", ARG)`, replaced by the names the shim binds:
#   prim ("NAME", ARG)        XC2KPrim.ID ( ARG)
#   _export ("NAME", F)       XC2KPrim.export ("NAME", F)
#   _IntInf                   XC2_IntInf
# ID is NAME spelled as an identifier (= is EQ, @f is AT_f, __f is P__f, ...). A cast,
# which MLKit writes `fun f (x : T1) : T2 = prim ("id", x)`, is given its
# types from the line of the fun: id__T1__T2; so is every name of the file
# `typed` ("NAME" lines). Line breaks are kept. With -v table=FILE, a line
# "ID<TAB>NAME<TAB>FILE" per primitive is appended to FILE.
#   awk [-v table=FILE] [-v typed=FILE] -f rewrite.awk FILE.sml > OUT.sml
BEGIN {
  TYPED["id"] = 1; TYPED["unsafe_cast"] = 1
  if (typed != "") while ((getline l < typed) > 0) TYPED[l] = 1
}
{ lines[++n] = $0 }
END {
  for (k = 1; k <= n; k++) {
    line = lines[k]; out = ""
    while (match(line, /(^|[^A-Za-z0-9_'.])prim[ \t]*\([ \t]*"[^"]*"[ \t]*,/)) {
      pre = substr(line, 1, RSTART - 1); m = substr(line, RSTART, RLENGTH); rest = substr(line, RSTART + RLENGTH)
      lead = ""; if (m !~ /^prim/) { lead = substr(m, 1, 1); m = substr(m, 2) }
      name = m; sub(/^prim[ \t]*\([ \t]*"/, "", name); sub(/"[ \t]*,$/, "", name)
      id = ident(name)
      if (name in TYPED) id = id "__" types(pre)
      if (table != "") print id "\t" name "\t" FILENAME >> table
      out = out pre lead "XC2KPrim." id " ("
      line = rest
    }
    while (match(line, /_export[ \t]*\(/)) line = substr(line, 1, RSTART - 1) "XC2KPrim.export (" substr(line, RSTART + RLENGTH)
    # MLKit's constructor _IntInf: an identifier of SML may not begin with _
    gsub(/_IntInf/, "XC2_IntInf", line)
    print out line
  }
}
function ident(s,   r) {
  if (s == "=") return "EQ"
  if (s == "!") return "DEREF"
  if (s == ":=") return "ASSIGN"
  r = s; sub(/^@/, "AT_", r); gsub(/[^A-Za-z0-9_]/, "_", r)
  if (r !~ /^[A-Za-z]/) r = "P" r
  return r
}
# the types of the fun whose line PRE begins: "T1__T2" of
# `fun f (x : T1) : T2 =` or `fun f (x : T1, ...) : T2 =` (its first
# argument), "unit__T2" of `fun f () : T2 =`
function types(pre,   h, a, r) {
  # the header of the fun, anywhere before the prim on its line
  if (!match(pre, /(\([ \t]*\)|\([^():]*:[^()]*\))[ \t]*:[^=]*=/)) return "UNTYPED"
  h = substr(pre, RSTART, RLENGTH)
  r = h; sub(/^.*\)[ \t]*:/, "", r); sub(/=$/, "", r)
  if (h ~ /^\([ \t]*\)/) a = "unit"
  else { a = h; sub(/^\([^:]*:/, "", a); sub(/[),].*$/, "", a) }
  return mangle(a) "__" mangle(r)
}
function mangle(t) {
  gsub(/->/, " to ", t); gsub(/\*/, " x ", t); gsub(/'/, "q", t); gsub(/\./, "_", t)
  gsub(/[^A-Za-z0-9_]+/, "_", t); sub(/^_+/, "", t); sub(/_+$/, "", t)
  return t
}
