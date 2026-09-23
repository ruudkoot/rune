# runeopt --disasm prints a real constant as the text the .rbc carries, and
# runevm --disasm prints the number with C's %g. awk's printf is C's, so this
# turns the one into the other -- but for the sign of a negative zero, which
# awk's conversion from text loses.
/^const [0-9]+ = -?([0-9]*\.[0-9]*|[0-9]+)([eE][-+]?[0-9]+)?$/ && /[.eE]/ {
  t = substr($0, index($0, "= ") + 2)
  g = sprintf("%g", t + 0)
  if (t ~ /^-/ && g !~ /^-/) g = "-" g
  print substr($0, 1, index($0, "= ") + 1) g
  next
}
{ print }
