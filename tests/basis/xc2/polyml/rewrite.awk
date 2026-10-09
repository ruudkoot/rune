# Rewrite a file of Poly/ML's library for Rune (tests/basis/xc2/README.md),
# keeping its lines:
# * an overloading of RunCall.addOverload becomes (), since Rune overloads
#   the operators on its own types;
# * a cast whose types its line gives, `: T1 -> T2 = RunCall.unsafeCast`,
#   becomes the shim's conversion for a word, an int and a char;
# * a call of the runtime, RunCall.rtsCallFullN "NAME" (or rtsCallFastN, or
#   Real's rtsCallFastR_R and its kind), becomes XC2PR.NAME;
# * a call of one of the runtime's dispatchers, PolyBasicIOGeneral and
#   PolyOSSpecificGeneral, which take a code and arguments whose types
#   depend on it, becomes XC2PR.NAME_CODE of the other arguments, when the
#   code is a constant: a local the dispatcher is bound to (`val doIo = ...`,
#   `val doCall = osSpecificGeneral`) is followed through the file.
# Each NAME, and NAME_CODE, goes to the file `table`.
function bound(l,    m) {
  # the name the line binds with val, and, fun, or ""
  if (match(l, /(^|[^A-Za-z0-9_'])(val|and|fun) +[A-Za-z][A-Za-z0-9_']*/)) {
    m = substr(l, RSTART, RLENGTH)
    sub(/^.*(val|and|fun) +/, "", m)
    return m
  }
  return ""
}
{
  line = $0
  gsub(/RunCall\.addOverload[^"]*"[^"]*"/, "()", line)
  gsub(/: *word *-> *int *= *RunCall\.unsafeCast/, ": word -> int = XC2P.wordToInt", line)
  gsub(/: *int *-> *word *= *RunCall\.unsafeCast/, ": int -> word = XC2P.intToWord", line)
  gsub(/: *char *-> *int *= *RunCall\.unsafeCast/, ": char -> int = XC2P.charToInt", line)
  gsub(/: *int *-> *char *= *RunCall\.unsafeCast/, ": int -> char = XC2P.intToChar", line)

  # the dispatchers: a name bound here is one if its value is
  name = bound(line)
  if (name != "") { last = name; delete disp[name] }
  if (match(line, /"(PolyBasicIOGeneral|PolyOSSpecificGeneral)"/)) {
    d = substr(line, RSTART + 1, RLENGTH - 2)
    if (last != "") disp[last] = d
  } else if (name != "" && match(line, "(val|and) +" name "[^=]*= *[A-Za-z][A-Za-z0-9_']* *$")) {
    rhs = substr(line, RSTART, RLENGTH)
    sub(/^.*= */, "", rhs); sub(/ *$/, "", rhs)
    if (rhs in disp) disp[name] = disp[rhs]
  }
  for (n in disp) {
    out = ""
    while (match(line, "(^|[^A-Za-z0-9_'.])" n " *\\( *[0-9]+ *, *")) {
      call = substr(line, RSTART, RLENGTH)
      pre = (substr(call, 1, length(n)) == n) ? "" : substr(call, 1, 1)
      code = substr(call, length(pre) + length(n) + 1)
      sub(/^ *\( */, "", code); sub(/ *,.*$/, "", code)
      print disp[n] "_" code >> table
      out = out substr(line, 1, RSTART - 1) pre "XC2PR." disp[n] "_" code " ("
      line = substr(line, RSTART + RLENGTH)
    }
    line = out line
  }

  out = ""
  while (match(line, /(RunCall\.rtsCall(Full|Fast)[0-9]|(Real\.|Real32\.)?rtsCallFast(R_R|RR_R|RI_R|I_R|F_F|FF_F|FI_F|I_F)) *"[A-Za-z0-9_]+"/)) {
    call = substr(line, RSTART, RLENGTH)
    name = call
    sub(/^[^"]*"/, "", name)
    sub(/"$/, "", name)
    print name >> table
    out = out substr(line, 1, RSTART - 1) "XC2PR." name
    line = substr(line, RSTART + RLENGTH)
  }
  print out line
}
