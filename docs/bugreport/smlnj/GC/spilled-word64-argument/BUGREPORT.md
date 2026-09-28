# SML/NJ 110.99.9 for 64 bits: an `Int64` or `Word64` argument passed in a record is kept raw among pointers, so the function reads a box's address or the collector crashes

## Status: the legacy side of open #381

* **[#381](https://github.com/smlnj/legacy/issues/381)** (open) mirrors
  [smlnj/smlnj #394](https://github.com/smlnj/smlnj/issues/394), "`Int64.int`
  value is sometimes corrupted". There John Reppy found that "the arity
  lowering that happens in the `CPSTrans` pass is not wrapping the 64-bit
  integer argument", and that literals box raw numbers. He fixed both in
  2026.3 with a new `CPSTransFn` and new literal code, which the legacy
  branch does not have.
* **Legacy 110.99.9 has the bug.** #394's program gets a heap address as the
  fourth field on the 64-bit release, and 170000 with `fix.diff`.

**What is worth sending SML/NJ:** a comment on #381 with `bug.sml` and
`fix.diff`, a fix for legacy (`upstream.md` is the text).

## Summary

* **The trigger:** a 64-bit build, and a call with more arguments than the
  argument registers. On amd64 that is five or more general arguments: the
  return continuation and three arguments go in registers, and the rest in
  a record. One of the arguments in the record is an untagged `Int64.int`
  or `Word64.word`.
  - `Position.int` is `Int64.int`, so `Posix.IO.FLock.flock` is such a
    function.
  - So is any function whose argument tuple the compiler flattens.
* **What goes wrong:** the arguments that do not fit go in a record, and
  the number is stored in it raw, among the pointers.
  - **Constant arguments.** The record is a literal. The runtime builds
    literals with 64-bit numbers boxed, so the function reads the address
    of the box: `A.f (1, 2, 3, 4, 5, 0wx8000000000000000)` in `bug.sml`
    gives `0wx7C15AC717A4F`.
  - **Other arguments.** The collector scans the record as pointers.
    - A number with any of bits 48 to 63 set and bit 0 clear is looked up
      beyond the end of the collector's page table. The process stops with
      "Fatal error -- bogus fault not in ML" in a major collection.
    - A number that happens to equal the address of an object that moves
      would be changed into its new address (by reading the collector;
      not seen).
* **Required behaviour:** a function gets the arguments it is given, and a
  collection does not crash.

## Where it happens

| Build | constant call | loop, `@SMLalloc=64k` |
|---|---|---|
| 64-bit 110.94 (the first 64-bit release for Linux) | wrong | bogus fault |
| 64-bit 110.99.9 release | wrong | bogus fault (every run) |
| 64-bit 110.99.9 with the fix of [GC/real-corrupted-on-64-bit](../real-corrupted-on-64-bit/BUGREPORT.md) | wrong | bogus fault (every run) |
| 64-bit 110.99.9 with `fix.diff` and the other fixes of this directory | ok | 0 of 2,000,000 wrong |

The loop does not fail with the default allocation area (512k) in these
runs; a major collection must fall at the entry of `A.f`.

```
$ sml @SMLalloc=64k bug.sml             # 110.99.9, 64-bit
A.f (1, 2, 3, 4, 5, 0wx8000000000000000) = 7C15AC717A4F, expected 800000000000000F: WRONG
.../bin/sml: Fatal error -- bogus fault not in ML: pc = 0x5dbc31e45e10, sig = 11
```

## The cause

`CPStrans` (`base/compiler/CPS/convert/cpstrans.sml`) makes every call fit
the registers. Of the arguments that do not fit:
* reals go in a raw record (`RK_RAW64BLOCK`);
* everything else goes in an ordinary record (`RK_RECORD`), untagged
  numbers included (`spillIn`, and `spillOut` on the other side).

For the call in #394's program, after `cpstrans`:

```
std v137(v152[C],v145[PR2]) =
   ...
   {(I64)170000,(I63t)1} -> v163
   v146(v159,(I64)17000,(I63t)1,(I63t)0,v163)
```

`v163` is the record of the fourth and fifth arguments, with the `Int64`
raw.

* **The collector crash.** The collector takes any word with bit 0 clear
  in such a record for a pointer. On 64 bits the first level of the page
  table (the BIBOP) has 2^16 entries for bits 32 to 47 of an address
  (`include/bibop.h`). `ADDR_TO_PAGEID` of a word with higher bits set
  reads beyond it, and `MajorGC_CheckWord` faults.
* **The wrong value.** When the arguments are constants, `lit-split` makes
  the record a literal. The runtime builds it (`gc/build-literals.c`,
  `INT64`) with the number boxed, but the function selects it as a raw
  number.

A runtime that reports such words, instead of crashing on them, found the
word `0x8000000000000000` in a record while Rune's `property.core` ran. With
the loop of `bug.sml` it showed the whole record: the descriptor `0x182`
(three words), the tagged ints 3 and 4 (`A.f`'s fourth and fifth
arguments), and the raw word.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9)
puts the spilled arguments that are untagged machine words
(`NUMt{sz = Target.mlValueSz, tag = false}`) in a raw record
(`RK_RAWBLOCK`) of their own. That record goes in the ordinary record, as
the raw record of reals already does. `spillIn` and `spillOut` split the
arguments the same way, so the caller and the function agree.

On 32-bit targets the change applies to `Int32.int` and `Word32.word`,
whose raw values the collector could likewise take for pointers.

**How it was tested:**
* on 64 bits, with the other fixes of this directory, built to a fixed
  point:
  - `bug.sml` is right, with `@SMLalloc=64k` too;
  - #394's program gives 170000;
  - Rune's `property.core` passes 20 of 20 runs, where it stopped with
    "bogus fault" in 10 of 20 with the other fixes alone;
  - Rune's Basis suite has no new failure, and its `Posix.IO.FLock` checks
    pass (`tests/basis/deviations.txt` line 526);
* on 32 bits, with the other fixes, built to a fixed point: Rune's Basis
  suite fails the same checks as without `fix.diff`, and its library tests
  pass.

## How Rune met it

Rune's `tests/lib/property/core.sml` stopped with "bogus fault" now and
then on 64 bits, even with the fix of
[GC/real-corrupted-on-64-bit](../real-corrupted-on-64-bit/BUGREPORT.md). A
runtime that reports the words that crash the collector led to the record.
`tests/basis/deviations.txt` line 526 (`Posix.IO.FLock.*`: `FLock.start`
returns garbage) is the constant case.
