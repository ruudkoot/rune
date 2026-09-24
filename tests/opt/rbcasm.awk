# An .rbc from a listing, written as the escapes of printf(1) (every byte as
# \ooo), for the tests of runeopt to make programs the compiler never would:
#   printf "$(awk -v opdefs=vm/opcodes.def -v primdefs=vm/prims.def \
#                 -f tests/opt/rbcasm.awk LISTING)" > FILE.rbc
# The numbers of the opcodes and primitives come from the .def files. A
# listing has, one to a line (# begins a comment):
#   const NAME int N          a constant, named for CONST and NEWEXN
#   const NAME string "TEXT"  (\n is a newline)
#   globals N
#   function NAME LOCALS      the functions, in order: code follows each
#   LABEL:                    a place in the code
#   OPCODE OPERAND...         an operand is a number, @LABEL, %CONST,
#                             &FUNCTION, or for PRIM the primitive's name
# There is no debug information.
function le(v, bytes,    s, i, b) {
  s = ""
  if (v < 0) v += 2 ^ (8 * bytes)
  for (i = 0; i < bytes; i++) { b = v % 256; s = s sprintf("\\%03o", b); v = (v - b) / 256 }
  return s
}
function str(t,    s, i) {
  s = ""
  for (i = 1; i <= length(t); i++) s = s sprintf("\\%03o", ord[substr(t, i, 1)])
  return s
}
BEGIN {
  for (i = 0; i < 256; i++) ord[sprintf("%c", i)] = i
  n = 0
  while ((getline l < opdefs) > 0) {
    if (l ~ /^#/ || l ~ /^[ \t]*$/) continue
    split(l, f, /[ \t]+/)
    opnum[f[1]] = n++
    opargs[f[1]] = (f[2] == "-") ? 0 : split(f[2], junk, ",")
  }
  n = 0
  while ((getline l < primdefs) > 0) {
    if (l ~ /^#/ || l ~ /^[ \t]*$/) continue
    split(l, f, /[ \t]+/)
    primnum[f[1]] = n++
  }
  nconsts = 0; nglobals = 0; nfuncs = 0; nins = 0; pc = 0
}
{ sub(/[ \t]*#.*$/, "") }
/^[ \t]*$/ { next }
$1 == "const" {
  constidx[$2] = nconsts
  if ($3 == "int") consts[nconsts++] = "\\000" le($4, 8)
  else {
    t = $0; sub(/^[^"]*"/, "", t); sub(/"[ \t]*$/, "", t); gsub(/\\n/, "\n", t)
    consts[nconsts++] = "\\003" le(length(t), 4) str(t)
  }
  next
}
$1 == "globals" { nglobals = $2; next }
$1 == "function" { funcidx[$2] = nfuncs; fname[nfuncs] = $2; flocals[nfuncs] = $3; foffset[nfuncs++] = pc; next }
/^[ \t]*[A-Za-z0-9_]+:$/ { l = $1; sub(/:$/, "", l); label[l] = pc; next }
{
  if (!($1 in opnum)) { print "rbcasm: unknown opcode " $1 > "/dev/stderr"; exit 1 }
  ins[nins] = $0; inspc[nins++] = pc
  pc += 1 + 4 * opargs[$1]
}
END {
  code = ""
  for (k = 0; k < nins; k++) {
    split(ins[k], f, /[ \t]+/)
    j = (f[1] == "") ? 2 : 1
    op = f[j]
    code = code sprintf("\\%03o", opnum[op])
    for (a = 1; a <= opargs[op]; a++) {
      x = f[j + a]
      if (op == "PRIM") v = primnum[x]
      else if (x ~ /^@/) v = label[substr(x, 2)]
      else if (x ~ /^%/) v = constidx[substr(x, 2)]
      else if (x ~ /^&/) v = funcidx[substr(x, 2)]
      else v = x + 0
      code = code le(v, 4)
    }
  }
  out = "RUNE" le(2, 4) le(nconsts, 4)
  for (k = 0; k < nconsts; k++) out = out consts[k]
  out = out le(nglobals, 4) le(nfuncs, 4)
  for (k = 0; k < nfuncs; k++) out = out le(foffset[k], 4) le(flocals[k], 4) le(length(fname[k]), 4) str(fname[k])
  out = out le(pc, 4) code le(0, 4) le(0, 4) le(0, 4)
  printf "%s", out
}
