# mlb-flatten.awk: the declarations of an ML Basis file (MLton's .mlb), in
# order, as lines
#   file PATH      an SML source, PATH absolute and normalised
#   local | in | end
#                  the scoping of `local BASDEC in BASDEC end`
# Every .mlb is read once (a second mention of it is its first); an SML source
# is listed as often as it is mentioned. `ann` annotations are dropped, and so
# are the bindings `structure A`, `signature A`, `functor A` of an .mlb (they
# re-export a name the flattened sources bind anyway) and `_prim`. A named
# basis (`basis B = bas ... end`, MLKit's) is its sources, in place; `open B`
# adds nothing, and `let D in E end` is scoped as `local D in E end`.
#   awk -v vars="NAME=VALUE ..." -f mlb-flatten.awk FILE.mlb
BEGIN {
  n = split(vars, vs, " ")
  for (k = 1; k <= n; k++) { eq = index(vs[k], "="); VAR[substr(vs[k], 1, eq - 1)] = substr(vs[k], eq + 1) }
}
{ next }
END {
  top = ARGV[1]
  if (top !~ /^\//) { "pwd" | getline cwd; top = cwd "/" top }
  mlb(normalise(top))
}
function die(msg) { print "mlb-flatten: " msg > "/dev/stderr"; exit 2 }
function normalise(p,   parts, n, k, out, m, r) {
  n = split(p, parts, "/"); m = 0
  for (k = 1; k <= n; k++) {
    if (parts[k] == "" || parts[k] == ".") continue
    if (parts[k] == "..") { if (m > 0) m--; continue }
    out[++m] = parts[k]
  }
  r = ""; for (k = 1; k <= m; k++) r = r "/" out[k]
  return r
}
function subst(p,   s, e, name) {
  while ((s = index(p, "$(")) > 0) {
    e = index(substr(p, s), ")")
    name = substr(p, s + 2, e - 3)
    if (!(name in VAR)) die("no value for $(" name ")")
    p = substr(p, 1, s - 1) VAR[name] substr(p, s + e)
  }
  return p
}
function resolve(dir, p) { p = subst(p); return normalise(p ~ /^\// ? p : dir "/" p) }
# tokenize the text of FILE into TOK[id, 1..NT[id]]: comments dropped, a
# string one token
function tokenize(file, id,   text, line, i, c, depth, tok, n, L) {
  text = ""
  while ((getline line < file) > 0) text = text line "\n"
  close(file)
  L = length(text); n = 0; tok = ""; depth = 0
  for (i = 1; i <= L; i++) {
    c = substr(text, i, 1)
    if (depth > 0) {
      if (c == "(" && substr(text, i + 1, 1) == "*") { depth++; i++ }
      else if (c == "*" && substr(text, i + 1, 1) == ")") { depth--; i++ }
      continue
    }
    if (c == "(" && substr(text, i + 1, 1) == "*") {
      if (tok != "") { TOK[id, ++n] = tok; tok = "" }
      depth = 1; i++; continue
    }
    if (c == "\"") {
      if (tok != "") { TOK[id, ++n] = tok; tok = "" }
      tok = c
      for (i++; i <= L; i++) { c = substr(text, i, 1); tok = tok c; if (c == "\\") { i++; tok = tok substr(text, i, 1) } else if (c == "\"") break }
      TOK[id, ++n] = tok; tok = ""; continue
    }
    if (c == " " || c == "\t" || c == "\n" || c == "\r" || c == ";") {
      if (tok != "") { TOK[id, ++n] = tok; tok = "" }
      continue
    }
    tok = tok c
  }
  if (tok != "") TOK[id, ++n] = tok
  NT[id] = n
}
function mlb(file,   id, dir, i) {
  if (file in SEEN) return
  SEEN[file] = 1
  id = ++NFILES
  dir = file; sub(/\/[^\/]*$/, "", dir)
  tokenize(file, id)
  DIR[id] = dir; NAME[id] = file
  i = basdecs(id, 1)
  if (i <= NT[id]) die(file ": unexpected " TOK[id, i])
}
function expect(id, i, t) {
  if (TOK[id, i] != t) die(NAME[id] ": expected " t ", found " (i <= NT[id] ? TOK[id, i] : "the end"))
  return i + 1
}
# basdecs(id, i): parse from token i up to `in`, `end` or the end; the index
# of that token
function basdecs(id, i,   t) {
  while (i <= NT[id]) {
    t = TOK[id, i]
    if (t == "in" || t == "end") return i
    if (t == "local") {
      print "local"; i = basdecs(id, i + 1); i = expect(id, i, "in")
      print "in"; i = basdecs(id, i); i = expect(id, i, "end"); print "end"
    } else if (t == "ann") {
      for (i++; i <= NT[id] && TOK[id, i] != "in"; i++) ;
      i = expect(id, i, "in"); i = basdecs(id, i); i = expect(id, i, "end")
    } else if (t == "structure" || t == "signature" || t == "functor") {
      i += 2
      if (TOK[id, i] == "=") { if (TOK[id, i + 1] != TOK[id, i - 1]) die(NAME[id] ": rebinding " TOK[id, i - 1] " = " TOK[id, i + 1]); i += 2 }
      while (TOK[id, i] == "and") { i += 2; if (TOK[id, i] == "=") i += 2 }
    } else if (t == "basis") {
      i = basexp(id, i + 3)
      while (TOK[id, i] == "and") i = basexp(id, i + 3)
    } else if (t == "open") {
      for (i++; i <= NT[id] && !keyword(TOK[id, i]) && TOK[id, i] !~ /\.(sml|sig|fun|mlb)$/; i++) ;
    } else if (t == "_prim") {
      i++
    } else if (t ~ /\.mlb$/) {
      mlb(resolve(DIR[id], t)); i++
    } else if (t ~ /\.(sml|sig|fun)$/) {
      print "file " resolve(DIR[id], t); i++
    } else die(NAME[id] ": cannot flatten " t)
  }
  return i
}
function keyword(t) { return t ~ /^(local|in|end|ann|structure|signature|functor|basis|open|and|bas|let|_prim)$/ }
# basexp(id, i): parse a basis expression; the index after it
function basexp(id, i) {
  if (TOK[id, i] == "bas") { i = basdecs(id, i + 1); return expect(id, i, "end") }
  if (TOK[id, i] == "let") {
    print "local"; i = basdecs(id, i + 1); i = expect(id, i, "in")
    print "in"; i = basexp(id, i); i = expect(id, i, "end"); print "end"
    return i
  }
  return i + 1
}
