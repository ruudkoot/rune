# SML/NJ 110.99.9 for 64 bits: functions share GC code that does not save all their roots, so a collection loses a real or a `Word64`

## Status: the cause of open #299; a one-line fix

* **[#299](https://github.com/smlnj/legacy/issues/299)** (open, 64-bit):
  `PackWord64Big.update` "is nondeterministic". John Reppy found there that
  the value "is not being correctly preserved across the garbage
  collection". Its reproducer (https://github.com/Skyb0rg007/smlnj-bug)
  fails on 7 to 10 of 10 loads with 110.99.9 and on none with `fix.diff`.
* **Not [#381](https://github.com/smlnj/legacy/issues/381)**
  (smlnj/smlnj #394, a record of mixed raw numbers and pointers after arity
  lowering): its program still fails with `fix.diff`.
* **The 2026 series** does not have the code: smlnj/smlnj at `a5f3fa7` has
  no `invokegc.sml`, as its back end is LLVM (by reading the code; no 2026
  build was run).

**What is worth sending SML/NJ:** a comment on #299 with the cause,
`fix.diff` and `bug.sml` (`upstream.md` is the text).

## Summary

* **The trigger:** in a 64-bit build, a garbage collection at the entry
  of an escaping function or continuation that has a real, or an untagged
  64-bit number (`Int64`, `Word64`), in a register, when another function of
  the same compilation unit has the same registers but fewer such
  arguments.
* **What goes wrong:** the collection loses the value. The real or word
  that the function then uses is whatever the collector left in the
  register, or a heap address.
  - `bug.sml` computes the bits of a real 300,000 times and gets 83 wrong,
    and 590 with `@SMLalloc=128k`, which makes collections frequent.
  - The wrong words are `0wxFFF0000000000000` (the mantissa of
    `Real.toManExp` read as 0.0) and heap addresses such as
    `0wx732032D40000`.
  - Rune's `tests/lib/property/core.sml` fails now and then. The "bogus
    fault" stops it also has come from another bug,
    [GC/spilled-word64-argument](../spilled-word64-argument/BUGREPORT.md).
* **Required behaviour:** the result of a pure function does not depend on
  when the collector runs.

## Where it happens

| Build | `bug.sml`, `@SMLalloc=128k` | `bug.sml`, default | #299, loads failing |
|---|---|---|---|
| 64-bit 110.94 (the first 64-bit release for Linux) | 512, 513 | not run | not run |
| 64-bit 110.96, 110.98, 110.99, 110.99.3, 110.99.5, 110.99.7, 110.99.8 | 515 - 953 | not run | not run |
| 64-bit 110.99.9 release | 587 - 590 | 83 | 7 - 10 of 10 |
| 64-bit 110.99.9 with `fix.diff` | 0 (3 runs) | 0 | 0 of 10 |
| 32-bit 110.99.9 release | 0 | not run | n/a |

```
$ sml @SMLalloc=128k bug.sml            # 110.99.9, 64-bit
bits 31C0000000000000 -> FFF0000000000000
bits E20000000000000 -> 732032D40000
bits 7350000000000000 -> 732032D40000
bits 61B0000000000000 -> FFF0000000000000
bits 3E10000000000000 -> 732032D40000
587 of 300000 wrong
```

Which calls go wrong, and how many, changes from run to run.

## The cause

Each function tests the heap limit on entry and, when it is reached, jumps
to code that saves the function's arguments, calls the collector, restores
them and jumps back. `invokegc.sml` sorts the arguments into three root
lists: pointers (`boxed`), untagged numbers (`int`) and reals (`float`).
Untagged numbers and reals are packed into a raw record, which the
collector moves but does not scan.

For escaping functions and continuations, the GC code is shared across the
compilation unit: `emitLongJumpsToGCInvocation` reuses the code of an
earlier function when `sameCallingConvention` says that the two have the
same roots
(`base/compiler/CodeGen/cpscompile/invokegc.sml`):

```sml
	  in
	    ListPair.all eqR (b1, b2)
	      andalso eqR(ret1, ret2)
	      andalso ListPair.all eqR (i1, i2)
	      andalso ListPair.all eqF (f1, f2)
	  end
```

[`ListPair.all`](https://smlfamily.github.io/Basis/list-pair.html)
ignores the excess elements of the longer list, so `[]` and `[xmm0]` count
as the same float roots. A function whose argument is a real in `%xmm0`
then shares the GC code of a function without one, which does not save
`%xmm0`. The collector, which is C, is free to overwrite it. In the same
way, the lists of pointers and untagged numbers may differ in their
length:
* an untagged number can be passed to the collector as a pointer, or not
  at all;
* a pointer can be left out and not be updated when its object moves.

In `bug.sml`, the continuation that receives the mantissa and exponent of
`Real.toManExp` takes the mantissa in `%xmm0`. Its heap check goes to GC
code that saves nothing:

```
L8:                                     # the continuation (110.99.9)
	...
	cmpq	%r14, %rdi
	ja	L20
	...
L20:	jmp	L15
L15:                                    # shared with a function without reals
	movq	$1, %r8
	movq	$1, %r9
	call	*8240(%rsp)             # call gc
	jmp	*%rsi
```

With `fix.diff` it goes to GC code of its own:

```
L24:
	movq	$150, (%rdi)            # a raw record of one word
	movsd	 %xmm0, 8(%rdi)
	leaq	8(%rdi), %r8
	addq	$16, %rdi
	movq	$1, %r9
	call	*8240(%rsp)             # call gc
	movsd	 (%r8), %xmm0
	jmp	*%rsi
```

The code is the same for every target and has been since at least 110.94.
The 32-bit builds did not fail in these runs.

## How it was found

Changing the SML code made the fault move or vanish, so the test changed
the runtime instead. A runtime that sets every SSE register to 0.75 when
control returns from the runtime to SML made `bits 16D0000000000000` come
back as `16D8000000000000`. That is the result for a mantissa of 0.75, so
`%xmm0` had not been saved across the collection. The machine code of the
continuation (MLRISC flag `dump-cfg-after-all-ra`) then showed the shared
GC code.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9)
compares the three lists with `ListPair.allEq`, which is false when their
lengths differ. The module has somewhat more GC code (7 blocks instead of 4
for `bug.sml`'s functions).

**How it was tested:**
* 110.99.9 with only `fix.diff`, built to a fixed point for 64 bits:
  - `bug.sml` gives 0 wrong in three runs with `@SMLalloc=128k` and one with
    the default;
  - #299's reproducer fails on 0 of 10 loads;
  - with the runtime that sets the SSE registers to 0.75, the same;
  - #394's program still fails (a separate bug).
* 110.99.9 with `fix.diff` and the other fixes of this directory (except
  [GC/spilled-word64-argument](../spilled-word64-argument/BUGREPORT.md)),
  built to a fixed point for 64 bits:
  - the same results for `bug.sml` and #299;
  - Rune's Basis suite has no new failure;
  - Rune's `property.core` passes 10 of 20 runs, where it passes none
    without `fix.diff`. The other 10 stop with "bogus fault", which the fix
    of GC/spilled-word64-argument removes: with both, it passes 20 of 20.

## How Rune met it

Rune's `tests/lib/property/core.sml` round-trips reals through their bits
and fails on SML/NJ's 64-bit build now and then. `bug.sml` is `realOf`/`bitsOf` of `lib/test/property`, cut down to
what still fails.
