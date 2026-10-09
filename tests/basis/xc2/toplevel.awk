# toplevel.awk: the names of the structures an SML source binds at its top
# level (inside a top-level `local` too), one per line. Comments and strings
# are skipped; `struct`, `sig`, `let` and `abstype` open what an `end`
# closes, and so does `local`, which does not hide what it declares here.
#   awk -f toplevel.awk FILE.sml
{ text = text $0 "\n" }
END {
  L = length(text); depth = 0; n = 0; sp = 0; want = 0
  for (i = 1; i <= L; i++) {
    c = substr(text, i, 1)
    if (c == "(" && substr(text, i + 1, 1) == "*") {
      d = 1; i += 2
      while (i <= L && d > 0) {
        c2 = substr(text, i, 2)
        if (c2 == "(*") { d++; i += 2 } else if (c2 == "*)") { d--; i += 2 } else i++
      }
      i--; continue
    }
    if (c == "\"") {
      for (i++; i <= L; i++) { c = substr(text, i, 1); if (c == "\\") i++; else if (c == "\"") break }
      continue
    }
    if (c ~ /[A-Za-z_]/) {
      w = c
      while (i < L && substr(text, i + 1, 1) ~ /[A-Za-z0-9_']/) { i++; w = w substr(text, i, 1) }
      if (want) { if (!(w in SEEN)) { SEEN[w] = 1; print w }; want = 0; continue }
      if (w == "struct" || w == "sig" || w == "let" || w == "abstype") { stack[++sp] = "o"; hidden++ }
      else if (w == "local") stack[++sp] = "l"
      else if (w == "end") { if (sp > 0) { if (stack[sp] == "o") hidden--; sp-- } }
      else if ((w == "structure" || w == "and") && hidden == 0) want = (w == "structure" || lastdecl == "structure")
      if (w == "structure" || w == "signature" || w == "functor" || w == "val" || w == "fun" || w == "type" || w == "datatype" || w == "exception" || w == "open" || w == "infix" || w == "infixr" || w == "nonfix") lastdecl = w
      continue
    }
  }
}
