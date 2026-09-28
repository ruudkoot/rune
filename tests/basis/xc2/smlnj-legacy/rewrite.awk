# rewrite.awk: an SML source of SML/NJ's Basis Library or of its init
# library with SML/NJ's extensions and its runtime's C functions replaced:
#   #[e1, ..., en]                          XC2N.vector [e1, ..., en]
#   InLine.= and InlineT.=                  op = (a long identifier may not end in =)
#   Assembly.vector0                        (XC2N.vector0 ()) (no value of SML makes a
#                                           polymorphic empty vector)
#   CInterface.c_function "LIB" "NAME"      XC2NC.LIB_NAME
#   B "NAME", where the file has            XC2NC.LIB_NAME
#     fun B x = CInterface.c_function "LIB" x
# LIB_NAME is LIB and NAME with a character that no identifier takes as _.
# Line breaks are kept. With -v table=FILE, a line "ID<TAB>LIB<TAB>NAME" per
# C function is appended to FILE.
#   awk [-v table=FILE] -f rewrite.awk FILE.sml > OUT.sml
function ident(lib, name,   id) {
  id = lib "_" name; gsub(/[^A-Za-z0-9_]/, "_", id)
  if (table != "") print id "\t" lib "\t" name >> table
  return "XC2NC." id
}
{
  line = $0
  gsub(/#\[/, "XC2N.vector [", line)
  gsub(/(InLine|InlineT)\.=/, "op =", line)
  gsub(/([A-Za-z_][A-Za-z0-9_]*\.)*Assembly\.vector0/, "(XC2N.vector0 ())", line)
  # a binder of the C functions of a library
  if (match(line, /fun[ \t]+[A-Za-z_][A-Za-z0-9_']*[ \t]+x[ \t]*=[ \t]*(CInterface|CI)\.c_function[ \t]+"[^"]*"[ \t]+x/)) {
    t = substr(line, RSTART, RLENGTH); b = t; sub(/^fun[ \t]+/, "", b); sub(/[ \t].*/, "", b)
    l = t; sub(/.*c_function[ \t]+"/, "", l); sub(/".*/, "", l); LIB[b] = l
    print line; next
  }
  out = ""
  while (match(line, /(CInterface|CI)\.c_function[ \t]+"[^"]*"[ \t]+"[^"]*"/)) {
    t = substr(line, RSTART, RLENGTH); gsub(/^[A-Za-z]*\.c_function[ \t]+"|"$/, "", t); split(t, a, /"[ \t]+"/)
    out = out substr(line, 1, RSTART - 1) ident(a[1], a[2]); line = substr(line, RSTART + RLENGTH)
  }
  line = out line
  for (b in LIB) {
    out = ""
    while (match(line, "(^|[^A-Za-z0-9_'.])" b "[ \t]+\"[^\"]*\"")) {
      t = substr(line, RSTART, RLENGTH); lead = ""
      if (substr(t, 1, length(b)) != b) { lead = substr(t, 1, 1); t = substr(t, 2) }
      n = t; sub(/^[^"]*"/, "", n); sub(/"$/, "", n)
      out = out substr(line, 1, RSTART - 1) lead ident(LIB[b], n); line = substr(line, RSTART + RLENGTH)
    }
    line = out line
  }
  print line
}
