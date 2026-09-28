# rewrite.awk: an SML source of MLton's Basis Library with MLton's
# extensions replaced by the names the shim (tests/basis/xc2) binds:
#   _prim "N": T;                     (XC2Prim.N : T)
#   _import "N" ATTR...: T;           (XC2FFI.N : T)
#   _symbol "N" ATTR...: T;           (XC2Symbol.N : T)
#   _address "N" ATTR...: T;          (XC2Address.N : T)
#   _const "N": T;                    (V : T), V the value of N (consts)
#   _build_const "N": T;              likewise
#   _command_line_const "N": T = V;   (V : T)
# A name the file `ambiguous` lists ("KIND<TAB>NAME", a name used at more
# than one type) is given its type: N__T, T's text with its punctuation
# spelled (Word8_add__int_x_int_to_int).
# Line breaks are kept, so that a line of the output is the line of the
# source. With -v table=FILE, a line "KIND<TAB>NAME<TAB>TYPE" per extension
# is appended to FILE (the type on one line).
#   awk [-v table=FILE] -v consts=FILE -v ctypes=FILE [-v ambiguous=FILE] -f rewrite.awk FILE.sml
BEGIN {
  FS = "\t"
  while ((getline l < consts) > 0) { split(l, a, "\t"); CONST[a[1]] = a[2] }
  while ((getline l < ctypes) > 0) { split(l, a, "\t"); CTYPE[a[1]] = a[2] }
  if (ambiguous != "") while ((getline l < ambiguous) > 0) AMB[l] = 1
  FS = " "
}
{ text = text $0 "\n" }
END {
  out = ""
  while (match(text, /_(prim|import|const|build_const|command_line_const|symbol|address|export)[ \t\n]/)) {
    before = substr(text, 1, RSTART - 1)
    if (before ~ /[A-Za-z0-9_']$/) { out = out substr(text, 1, RSTART + RLENGTH - 1); text = substr(text, RSTART + RLENGTH); continue }
    kind = substr(text, RSTART + 1, RLENGTH - 2)
    rest = substr(text, RSTART + RLENGTH)
    out = out before
    if (!match(rest, /^[ \t\n]*("[^"]*"|\*)/)) die("no name after _" kind)
    name = substr(rest, RSTART, RLENGTH); gsub(/^[ \t\n]*"?|"$/, "", name)
    rest = substr(rest, RSTART + RLENGTH)
    c = index(rest, ":"); if (c == 0) die("no type after _" kind " " name)
    attrs = substr(rest, 1, c - 1); rest = substr(rest, c + 1)
    nl = attrs; gsub(/[^\n]/, "", nl)
    e = index(rest, ";"); if (e == 0) die("no ; after _" kind " " name)
    ty = substr(rest, 1, e - 1); rest = substr(rest, e + 1)
    t = ty; gsub(/[ \t\n]+/, " ", t); sub(/^ /, "", t); sub(/ $/, "", t)
    if (kind == "command_line_const") {
      q = index(ty, "="); val = substr(ty, q + 1); ty = substr(ty, 1, q - 1)
      out = out "(" val " :" nl ty ")"
    } else if (kind == "const" || kind == "build_const") {
      if (!(name in CONST)) die("no value for the constant " name)
      out = out "(" literal(CONST[name], t) " :" nl ty ")"
    } else {
      if (kind == "export") die("_export " name " is not supported")
      if (name == "*") die("_" kind " * is not supported")
      str = kind == "prim" ? "XC2Prim" : kind == "import" ? "XC2FFI" : kind == "symbol" ? "XC2Symbol" : "XC2Address"
      id = name; if ((kind "\t" name) in AMB) id = name "__" mangle(t)
      out = out "(" str "." id " :" nl ty ")"
      if (table != "") print kind "\t" name "\t" t >> table
    }
    text = rest
  }
  printf "%s", out text
}
function die(msg) { print "rewrite.awk: " FILENAME ": " msg > "/dev/stderr"; exit 2 }
# the text of a type as an identifier
function mangle(t) {
  gsub(/->/, " to ", t); gsub(/\*/, " x ", t); gsub(/'/, "q", t)
  gsub(/[^A-Za-z0-9]+/, "_", t); sub(/^_/, "", t); sub(/_$/, "", t)
  return t
}
# the value V of a constant as a literal of type T
function literal(v, t,   k) {
  if (t == "bool") return v
  if (t == "String8.string") return "\"" v "\""
  if (t ~ /^C_[A-Za-z0-9_]*\.t$/) { k = CTYPE[substr(t, 1, index(t, ".") - 1)]; if (k == "") die("unknown C type " t); sub(/[0-9]+$/, "", k) }
  else if (t ~ /^Int[0-9]+\.int$/) k = "Int"
  else if (t ~ /^Word[0-9]+\.word$/) k = "Word"
  else die("a constant of type " t)
  if (k == "Word") { if (v !~ /^[0-9]+$/) die("word constant " v); return "0w" v }
  if (k == "Int") { if (v !~ /^-?[0-9]+$/) die("int constant " v); sub(/^-/, "~", v); return v }
  die("a constant of type " t)
}
