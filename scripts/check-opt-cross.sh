#!/bin/sh
# Verify that every build of runeopt (MLton, SML/NJ in 64 and 32 bits,
# Poly/ML and, when built, the one compiled by Rune) says the same of the same
# programs: what the native code generator makes of a program must not depend
# on who built it (docs/native.md). scripts/check-cross.sh runs this.
#   scripts/check-opt-cross.sh
set -u
cd "$(dirname "$0")/.."
out=tests/out/opt-cross
mkdir -p "$out"
builds="mlton smlnj smlnj32 polyml"
[ -x bin/runeopt-boot ] && builds="$builds boot"
status=0

# run NAME ARG...: every build on these arguments. What they print, what they
# complain about and how they exit must be the same.
run() {
  name=$1
  shift
  for c in $builds; do
    "bin/runeopt-$c" "$@" > "$out/$name.$c.out" 2> "$out/$name.$c.err"
    echo "exit status $?" >> "$out/$name.$c.err"
  done
  for c in $builds; do
    cmp -s "$out/$name.mlton.out" "$out/$name.$c.out" && cmp -s "$out/$name.mlton.err" "$out/$name.$c.err" ||
      { echo "FAIL opt-cross $name: the mlton and $c builds differ (diff $out/$name.mlton.out $out/$name.$c.out)"; status=1; }
  done
}

run facts --facts bin/rune.rbc bin/runedoc.rbc
run disasm-rune --disasm bin/rune.rbc
# a file the loader refuses
printf "$(sed -n 's/^# rbc header //p' vm/opcodes.def)\\001\\000\\000\\000\\003\\360\\377\\377\\377" > "$out/bad.rbc"
run refused --check "$out/bad.rbc"

# The assembly of a program, from every build: runeopt's own, and that of the
# program of tests/opt that runs every instruction.
printf "$(awk -v opdefs=vm/opcodes.def -v primdefs=vm/prims.def -f tests/opt/rbcasm.awk tests/opt/every-opcode.rasm)" > "$out/every-opcode.rbc"
for prog in bin/runeopt.rbc "$out/every-opcode.rbc"; do
  name=$(basename "$prog" .rbc)
  for c in $builds; do
    "bin/runeopt-$c" -S "$prog" -o "$out/$name.$c.s" 2> "$out/$name.$c.s.err" ||
      { echo "FAIL opt-cross $name: runeopt-$c -S failed: $(head -1 "$out/$name.$c.s.err")"; status=1; }
  done
  for c in $builds; do
    cmp -s "$out/$name.mlton.s" "$out/$name.$c.s" ||
      { echo "FAIL opt-cross $name: the mlton and $c builds write different assembly (diff $out/$name.mlton.s $out/$name.$c.s)"; status=1; }
  done
done

# The program of an image (--from-image), which a runevm wrote: every build
# must make the same .rbc of it, and the same assembly. They write to the same
# names in turn, since the assembly names the .rbc it embeds.
if bin/rune tests/lang/rt.save_first.sml -o "$out/first.rbc" 2> /dev/null && bin/runevm "$out/first.rbc" > /dev/null 2>&1; then
  for c in $builds; do
    "bin/runeopt-$c" --from-image tests/out/rt.save_first.img -S -o "$out/image.s" > "$out/image.$c.err" 2>&1 ||
      { echo "FAIL opt-cross image: runeopt-$c --from-image failed: $(head -1 "$out/image.$c.err")"; status=1; }
    mv -f "$out/image.s" "$out/image.$c.s" 2> /dev/null
    mv -f "$out/image.rbc" "$out/image.$c.rbc" 2> /dev/null
  done
  for c in $builds; do
    cmp -s "$out/image.mlton.rbc" "$out/image.$c.rbc" && cmp -s "$out/image.mlton.s" "$out/image.$c.s" ||
      { echo "FAIL opt-cross image: the mlton and $c builds make another program of the image"; status=1; }
  done
else
  echo "FAIL opt-cross image: no image of tests/lang/rt.save_first.sml"; status=1
fi

[ $status = 0 ] && echo "check-opt-cross: the builds of runeopt agree ($builds)"
exit $status
