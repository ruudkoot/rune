# Poly/ML 5.9.2: `IntInf.~>>` rounds a negative number below `Int.minInt` towards zero

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and 2026.2, and MLKit 4.7.23) does the same.** MLKit also rounds towards zero, for small negative numbers too; MLton and SML/NJ round down.

## Status: not reported upstream from here; reported by others, and fixed after 5.9.2

It has not been reported upstream from here, and need not be: it is
[polyml/polyml#243](https://github.com/polyml/polyml/issues/243),
"Incorrect result from PolyShiftRightArbitrary", reported on 2025-12-05
with the runtime's shift called on `~9223372036854775792` and `5`, which
"ultimately manifests in an incorrect result from `IntInf.~>>`", and
closed the same day by David Matthews's commit
[64eb08b](https://github.com/polyml/polyml/commit/64eb08b0a4bcb20d39167550034f30d05a61f121)
on `master`, the same change as
[ccd3e37](https://github.com/polyml/polyml/commit/ccd3e3717f7238b9b5d295fea4b5426182dfc0b6)
on the branch `fixes-5.9.2`. The search of the issues (`IntInf shift`,
`~>>`, `shift right`, `arithmetic shift`, `PolyShiftRightArbitrary`,
`IntInf negative`) found only that one. There has been no release since
5.9.2 (2025-08-11), so the release has the bug. The issue shows the
rounding; the commit also mends the shifts that shift out every bit, which
give 0 instead of `~1`.

The bug is new in 5.9.2: 5.9.1 had `fun ~>> (i: int, j: Word.word) =
LargeInt.div(i, pow(2, Word.toInt j))`, which is right, and the shift in the
runtime came with
[ed1ff06](https://github.com/polyml/polyml/commit/ed1ff06d7b536ec60d3f60c65616786961640e64) (2023-11-13),
"Implement arbitrary precision shifts in the RTS rather than using
multiplication for IntInf.<< and IntInf.~>>", to which a comment on #243
points.

## Summary

* **The trigger:** `IntInf.~>> (i, n)` with `i` below `Int.minInt`, which
  is `~4611686018427387904` (`~2^62`) on 64-bit Poly/ML, and `i` not a
  multiple of `2^n`.
* **What goes wrong:** the result is rounded towards zero, one more than
  it should be: `~>> (~4611686018427387905, 0w1)` is
  `~2305843009213693952`, where it should be `~2305843009213693953`. When
  every bit is shifted out the result is `0`, where it should be `~1`.
  From `Int.minInt` up, and for every positive number, `~>>` is right, as
  it is when only zeros are shifted out.
* **Required behaviour:** the
  [Basis `INT_INF` specification](https://smlfamily.github.io/Basis/int-inf.html)
  says of `~>> (i, n)`: it "shifts i to the right by n bit positions. When
  i and n are interpreted as integers, the latter non-negative, this
  returns **floor**(((i / 2<sup>(n)</sup>)))". Its discussion adds: "The
  bit-wise operations (andb, orb, notb, <<, etc.) treat the integer
  arguments as having 2's complement representation."

## Environment

* **Poly/ML:** 5.9.2 (`poly -v`: "Poly/ML 5.9.2 Release RTS version:
  X86_64-5.9.2"), built from the release's sources with `./configure`
  (with GMP) and `make`; the native x86-64 code generator.
* **System:** Linux x86-64, Ubuntu 24.04 on WSL2.
* **Basis Library: Poly/ML's own.** The program is standalone, `poly
  --script bug.sml`, with nothing of Rune involved.

## The program

`bug.sml`:

```sml
(* Poly/ML 5.9.2: IntInf.~>> of a negative number below Int.minInt.
   ~>> (i, n) is floor (i / 2^n), which is i div 2^n: it rounds down. *)
fun check (i, n) =
  let
    val got = IntInf.~>> (i, n)
    val floor = IntInf.div (i, IntInf.pow (2, Word.toInt n))
  in
    print (IntInf.toString i ^ " ~>> " ^ Int.toString (Word.toInt n) ^ " = "
           ^ IntInf.toString got
           ^ (if got = floor then "" else "    <- WRONG, should be " ^ IntInf.toString floor)
           ^ "\n")
  end

val p62 = IntInf.pow (2, 62)    (* Poly/ML's Int.minInt is ~p62 *)

val () = List.app check
  [(~p62, 0w1),                           (* Int.minInt: a short integer *)
   (~p62 + 1, 0w1),
   (~p62 - 1, 0w1),                       (* the first long one *)
   (~p62 - 1, 0w2),
   (~p62 - 2, 0w1),                       (* nothing shifted out but zeros *)
   (~p62 - 3, 0w1),
   (~(IntInf.pow (2, 63)) - 1, 0w1),
   (~9223372036854775792, 0w5),
   (~(IntInf.pow (2, 100)) - 1, 0w50),
   (~p62 - 1, 0w63),                      (* every bit shifted out *)
   (~(IntInf.pow (2, 100)), 0w101),
   (~5, 0w1),                             (* for contrast: short, and positive *)
   (~1, 0w100),
   (p62 + 1, 0w1)]
```

```
$ poly --script bug.sml
~4611686018427387904 ~>> 1 = ~2305843009213693952
~4611686018427387903 ~>> 1 = ~2305843009213693952
~4611686018427387905 ~>> 1 = ~2305843009213693952    <- WRONG, should be ~2305843009213693953
~4611686018427387905 ~>> 2 = ~1152921504606846976    <- WRONG, should be ~1152921504606846977
~4611686018427387906 ~>> 1 = ~2305843009213693953
~4611686018427387907 ~>> 1 = ~2305843009213693953    <- WRONG, should be ~2305843009213693954
~9223372036854775809 ~>> 1 = ~4611686018427387904    <- WRONG, should be ~4611686018427387905
~9223372036854775792 ~>> 5 = ~288230376151711743    <- WRONG, should be ~288230376151711744
~1267650600228229401496703205377 ~>> 50 = ~1125899906842624    <- WRONG, should be ~1125899906842625
~4611686018427387905 ~>> 63 = 0    <- WRONG, should be ~1
~1267650600228229401496703205376 ~>> 101 = 0    <- WRONG, should be ~1
~5 ~>> 1 = ~3
~1 ~>> 100 = ~1
4611686018427387905 ~>> 1 = 2305843009213693952
```

The first two lines and the last three are right: those numbers are short
integers or positive.

## The other implementations

The same program, each against its own Basis Library:

* **MLton 20241230** (`mlton bug.mlb`, the `.mlb` listing
  `$(SML_LIB)/basis/basis.mlb` and `bug.sml`), **SML/NJ 110.99.9 and
  2026.2** (64-bit; `sml bug.sml`) and **Rune** (`bin/rune bug.sml -o
  bug.rbc && bin/runevm bug.rbc` in this repository): no line is wrong.
* **MLKit 4.7.23** (`mlkit -o bug bug.mlb`) rounds towards zero too, small
  numbers included, and goes wrong in other ways for large ones:

  ```
  ~4611686018427387904 ~>> 1 = ~2305843009213693952
  ~4611686018427387903 ~>> 1 = ~2305843009213693951    <- WRONG, should be ~2305843009213693952
  ~4611686018427387905 ~>> 1 = ~2305843009213693952    <- WRONG, should be ~2305843009213693953
  ~4611686018427387905 ~>> 2 = ~1152921504606846976    <- WRONG, should be ~1152921504606846977
  ~4611686018427387906 ~>> 1 = ~2305843009213693953
  ~4611686018427387907 ~>> 1 = ~2305843009213693953    <- WRONG, should be ~2305843009213693954
  ~9223372036854775809 ~>> 1 = ~4611686018427387904    <- WRONG, should be ~4611686018427387905
  ~9223372036854775792 ~>> 5 = ~288230376151711743    <- WRONG, should be ~288230376151711744
  ~1267650600228229401496703205377 ~>> 50 = 0    <- WRONG, should be ~1125899906842625
  ~4611686018427387905 ~>> 63 = 0    <- WRONG, should be ~1
  ~1267650600228229401496703205376 ~>> 101 = 0    <- WRONG, should be ~1
  ~5 ~>> 1 = ~2    <- WRONG, should be ~3
  ~1 ~>> 100 = 0    <- WRONG, should be ~1
  4611686018427387905 ~>> 1 = 2305843009213693952
  ```

## The cause

`basis/IntInf.sml` (lines 128-146) shifts a short integer with
`Word.~>>`, an arithmetic shift of the tagged machine word, which rounds
down, and passes a long one to the runtime:

```sml
    local
        val shiftR: LargeInt.int * word -> LargeInt.int = RunCall.rtsCallFull2 "PolyShiftRightArbitrary"
        ...
    in
        ...
        fun ~>> (i: int, j: Word.word) =
            if LibrarySupport.largeIntIsSmall i
            then Word.toLargeIntX(Word.~>>(largeIntToWord i, j))
            else shiftR(i, j)
    end
```

A long integer is held as a sign and a magnitude, and
`PolyShiftRightArbitrary` in `libpolyml/arb.cpp` shifts the magnitude and
keeps the sign (lines 2121-2137, the GMP build):

```cpp
            POLYUNSIGNED srcLimbs = numLimbs(pushedArg->Word());
            POLYUNSIGNED shiftLimbs = shiftBy / (sizeof(mp_limb_t)*8), shiftBits = shiftBy & (sizeof(mp_limb_t)*8 - 1);
            if (shiftLimbs >= srcLimbs)
                result = taskData->saveVec.push(TAGGED(0));
            else
            {
                POLYUNSIGNED destLimbs = srcLimbs - shiftLimbs;
                int sign = OBJ_IS_NEGATIVE(GetLengthWord(pushedArg->Word())) ? -1 : 1;
                POLYUNSIGNED destWords = WORDS(destLimbs * sizeof(mp_limb_t));
                Handle z = alloc_and_save(taskData, destWords, F_MUTABLE_BIT | F_BYTE_OBJ);
                if (shiftBits == 0)
                    memcpy(DEREFLIMBHANDLE(z), DEREFLIMBHANDLE(pushedArg) + shiftLimbs, destLimbs * sizeof(mp_limb_t));
                else mpn_rshift(DEREFLIMBHANDLE(z), DEREFLIMBHANDLE(pushedArg) + shiftLimbs,
                        destLimbs, shiftBits);
                result = make_canonical(taskData, z, sign);
            }
```

That is `-(|i| div 2^n)`, the quotient rounded towards zero. For a negative
`i` it is one more than `floor (i / 2^n)` whenever a bit shifted out of the
magnitude is 1, and for a shift beyond every limb it is `0`, not `~1`. The
build without GMP (lines 2138-2168) does the same with bytes.

## The fix

The fix is upstream's. `fix.patch` is commit `ccd3e37` of `fixes-5.9.2` as
`git format-patch` gives it, by David Matthews; `64eb08b` on `master` is the
same change. In both branches of `PolyShiftRightArbitrary` it notes whether
a bit shifted out is 1 (in the limbs or bytes dropped, or out of the
lowest one kept) and, for a negative number, subtracts one from the
result; a shift beyond every limb or byte gives `~1` for a negative
number.

It has not been built or run here: Poly/ML cannot be rebuilt on this
machine. `git apply --check` of `fix.patch` passes against the sources of
5.9.2. In #243 its author reports it working with and without GMP, and
Isabelle's results there show the issue's two examples right with it, on
`x86_64-linux` and on `x86_64_32-linux`.

Until a release has it, a program on 5.9.2 can shift by the identity `i ~>>
n = notb (notb i ~>> n)`: for a negative `i`, `notb i = ~i - 1` is not
negative, where `~>>` is right:

```sml
structure IntInf =
struct
  open IntInf
  fun ~>> (i, n) =
      if i < 0 then IntInf.notb (IntInf.~>> (IntInf.notb i, n)) else IntInf.~>> (i, n)
end
```

Tested on 5.9.2: on 100,200 shifts (numbers of up to 300 bits, around
`Int.minInt` and beyond it, shifts up to 319) it agrees with `i div pow (2,
n)` every time, where the released `~>>` differs 44,570 times; and with it
in front, the eight laws of `INT_INF` (below) pass.

## How it was found

By the laws of Rune's Basis Library documentation: each `Law:` in the
comments of a signature is tested on generated values. The law of `~>>` in
`lib/basis/sig_int_inf.sml` is

```
Law: `~>> (i, n) = i div pow (2, Word.toInt n)`, run for `n` from
`Arb.wordRange (0w0, 0w4095)`, as `Word.toInt n` overflows for a larger
shift
```

`tests/basis/run-laws-hosts.py` runs the laws against the Basis Library of
each of the other compilers, here Poly/ML's own (`docs/plans/quickcheck-hunt.md`,
the sections "The other compilers (D10, 2026-10-10)" and "D10 on the split
library (2026-10-10 and 11)"). Poly/ML failed it:

```
FAIL INT_INF.~>>/law-1@IntInf: differ at case 10 (size 9): left ~2305843009213693952, right ~2305843009213693953
```

The line of `tests/basis/law-deviations.txt`:

```
native:polyml | INT_INF.~>>/law-1@IntInf | HOST-BUG | IntInf.~>> rounds a negative number of more than 62 bits towards zero: ~>> (~4611686018427387905, 0w1) is ~2305843009213693952, where the floor is ~2305843009213693953
```

Rune's Basis Library suite had met it before, in `tests/basis/intinf.sml`
(`IntInf.~>>/~2^100-by-101` is `0`, not `~1`): `tests/basis/deviations.txt`,
line 88.
