# SML/NJ 110.99.9 for 32 bits: a `Word64.word` loses bits 30 and 31 of its low half

## Status: reported and closed as fixed, but still there

SML/NJ was told of the literal half of this bug, and closed the report.
* **The report:** issue #260 of
  [smlnj/legacy](https://github.com/smlnj/legacy/issues/260), "64-bit word
  literals are parsed incorrectly on 32-bit systems" (2022-10-26, against
  110.99.3). Its example is `0wxFFFFFFFFFFFFFFFF : Word64.word`, which
  evaluates to `0wxFFFFFFFF3FFFFFFF`.
* **The claimed fix:** the issue is labelled `fixed-in-110.99.4`, and the
  [110.99.4 release notes](https://www.smlnj.org/dist/working/110.99.4/110.99.4-README.html)
  list it among the fixed issues.
* **Still there:** the 32-bit build of 110.99.9 gives the example the same
  wrong value.
* **Arithmetic is wrong too:** a result of arithmetic loses the same bits, so the bug is not only in the parsing of literals. The issue did not report this.

**What is worth sending SML/NJ** is a comment on #260, or a new issue that
names it, with the program below. It shows the literal of #260 on 110.99.9,
and an addition whose result loses the same bits.

## Summary

* **The trigger:** a `Word64.word` (or `LargeWord.word`) whose low 32 bits
  have bit 30 or bit 31 set, made by a literal or by arithmetic, in the
  32-bit build.
* **What goes wrong:** those two bits are cleared.
  - `0wx40000000 : Word64.word` is `0w0`.
  - `Word64.fromInt 1073741823 + 0w1` is `0w0`.
  - `0wxFFFFFFFFFFFFFFFF` is `0wxFFFFFFFF3FFFFFFF`.
  
  `Word64.fromLargeInt 1073741824` is right, and so are `Word32` and `Word` literals of the same value.
* **Required behaviour:** a `Word64.word` is an unsigned number of 64
  bits; the
  [Basis `WORD` specification](https://smlfamily.github.io/Basis/word.html)
  has its arithmetic modulo 2^64.
* **Probably related:** the same build gets `Int64` wrong throughout.
  `Int64.+ (~2, ~3)` is 1073741819, which Rune's Basis suite records as a
  host bug (`tests/basis/deviations.txt`). The suite never saw this `Word64`
  bug, because its `Word64` test does not load in that build: the compiler
  stops there with "Compiler bug: Num64Cnv: test64To".

## Environment

* **SML/NJ:** 110.99.9, the 32-bit build, from the sources of
  `smlnj.cs.uchicago.edu/dist/working/110.99.9`, built by Rune's `make
  hosts` (`scripts/fetch-hosts.sh`). The 64-bit build of the same sources gets
  every value below right.
* **System:** Linux x86-64 (WSL2, kernel 6.18), gcc 13.3.
* **Basis Library: SML/NJ's own.** The program is standalone,
  `sml bug.sml`, with nothing of Rune involved.

## The program

`bug.sml` makes four `Word64.word`s and prints each as a `LargeInt.int`,
so that the printing of words is not involved:

```
$ sml bug.sml                           # 110.99.9, 32-bit
0wx40000000 = 0
fromInt 1073741823 + 0w1 = 0
fromLargeInt 1073741824 = 1073741824
0wxFFFFFFFFFFFFFFFF = 18446744070488326143
```

The 64-bit build prints `1073741824`, `1073741824`, `1073741824` and
`18446744073709551615`. 18446744070488326143 is `0xFFFFFFFF3FFFFFFF`,
#260's value.

## How Rune met it

Rune's random-number library, `lib/random` (SplitMix64, whose constants
are 64-bit literals with those bits set), gives the published known answers
on Rune, MLton, SML/NJ 110.99.9 for 64 bits and 110.79, Poly/ML and MLKit,
and wrong ones on this build. Rune does not change the library for it: the
failure is a `HOST-BUG` line of `tests/lib/deviations.txt`.
