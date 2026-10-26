# The Basis's list functions and Rune's bounded stack

Claude, 2026-10-25, during the functors-units roadmap. The owner asked for
these findings to be written down as an avenue to explore later; only the
first item below was done then.

## What happened

Rune's VM stops a program whose stack would pass `--stack-size`, 1 GiB by
default (`rt.stack` of `docs/language.md`), rather than grow it until the
machine has no memory left. Other compilers grow their stacks: SML/NJ's
frames are on the heap, and MLton and Poly/ML grow theirs. So a function
that recurses once for each element of a list, which is fine on every
other system, stops Rune with "stack overflow" on a long enough list: at
about 100 bytes a frame, around ten million elements.

The functors-units roadmap met it in the compiler. The fingerprint of a
functor's signature, written whole, is a buffer of about 10 MB, and turning
that buffer into a string with `CharArraySlice.vector` stopped the compiler
on MLton's sources. That function made the string with `CharVector.tabulate`,
which made it with `implode (List.tabulate ...)`, and `List.tabulate`
recursed once for each byte (`List.go` 322,466 frames deep under a 32 MB
stack, in the trace).

## What was fixed

`CharVector.tabulate` and `Word8Vector.tabulate` (`RuneStringVectorFn`,
`lib/basis/mono_vector_fn.sml`) make a vector of more than 1,024 elements
in place, in the VM's array of bytes, and a shorter one as before. The
length is tested only by the two tests `Size` already needed, so a short
vector costs what it did. `CharArraySlice.vector` and
`Word8ArraySlice.vector` go through `tabulate` and are fixed with it.
`tests/lang/basis.charvector_long` holds it under a 1 MB stack.

What it cost, in the bytecode instructions of `tests/perf` (`bin/rune-budget`,
against the same tree without the change):
- no program runs more instructions;
- `hash_mod`, which builds an 8 KB string, allocates 0.15 of the bytes and
  0.08 of the objects;
- compiling costs a little more, since the Basis's code is a few lines
  longer and a whole compile compiles it: +0.03% on the bootstrap, +1,528
  instructions on `compile-hello` (+0.08%).

What did not work as well:

| version of `CharVector.tabulate` | bootstrap | worst program |
|---|---:|---:|
| always in place | +0.15% | the compiler's many short strings (its hashes' hex digits) cost more in place than by a list and `implode` |
| a list to 1,024, in place beyond, a test of the length of its own | +0.03% | `runedoc-ir` +0.10%: three instructions a call, on 8,000 calls |
| the same, with the loop in `RuneBytes` | +0.035% | `compile-sigs` +0.22% |
| the same, with the loop in a structure outside the functor | +0.036% | every compile +1,200 to +3,100 instructions |
| **a list to 1,024, in place beyond, in the tests of `Size`** (kept) | +0.03% | none at run time |

## What was not fixed: the list functions

The same recursion is in the Basis's functions that make a list in order or
fold from the right:
- `@`, `map` and `foldr` (`lib/basis/pervasive.sml`, which `List` shares);
- `List.concat`, `mapPartial`, `filter` and `tabulate` (`lib/basis/list.sml`);
- `ListPair.zip`, `zipEq`, `unzip`, `map`, `mapEq`, `foldr` and `foldrEq`
  (`lib/basis/listpair.sml`);
- and what is made of them: `String.concatWith`, `String.map`,
  `String.translate`, `String.tokens`, `Substring.explode` and others.

Each stops at the stack's limit on a list of some ten million elements.

**One try: bounded recursion.** Each function recursed on the first 1,000
elements, as before, and did the rest in a loop, the rest reversed then
walked, which keeps the order `f` is applied in and where `UnequalLengths`
is raised. It held: a 300,000-element list under a 1 MB stack, through
every function above. It cost too much:

| program (`tests/perf`) | bytecode instructions |
|---|---:|
| `list_ops` | +42.5% |
| `compile-sig` | +33.0% |
| `string_ops` | +27.7% |
| `compile-hello` | +14.0% |
| `compile-where` | +13.9% |
| `compile-expo` | +11.8% |
| the bootstrap | +8.6% |
| the others | +1.4% in the geometric mean |

The cost is far more than the counter the fast path adds. The likely
reason, not checked, is that `map`, `@` and `foldr` were small enough for
`Simplify` to inline and to specialise to a known function, and with two
local functions each they no longer are. `List.tabulate` alone in a loop
with a reversal cost `list_ops` +15.9%. With recursion to 1,000 and a loop
after, it cost +15.4%, which again points at what the optimiser does with a
larger body, more than at the work.

## Ways to try

- **Tail recursion modulo cons** in the compiler, as OCaml 4.14 has it:
  `f x :: go xs` made into a loop that fills the cell's tail in place
  (destination-passing style). It is the general answer: no stack, no
  second pass, the same order, and the Basis's definitions unchanged. It
  needs a cons cell whose tail can be written once while it is still
  private, and the collector's barrier to allow it.
- **A stack that grows past its limit by segments**, or frames smaller than
  about 100 bytes, in the VM, so that the limit stops runaway recursion
  only: the limit is there to stop a recursion without end before it takes
  the machine.
- **Teach `Simplify` the bounded form**: specialise a function whose body
  is a recursion with a counter, so that bounded `map` and `foldr` cost
  what they did. That is narrower than the first.
- **Vectors and strings without lists** where it pays, by size, as
  `CharVector.tabulate` is now: `String.map`, `String.translate`,
  `Vector.fromList` of a long list.
- **A slice of an array of bytes made a vector in one copy.**
  `CharArraySlice.vector` and `Word8ArraySlice.vector` come from the one
  slice functor of every array type (`RuneMonoArraySliceFn`), which makes
  the vector element by element through `tabulate`: on a 10 MB buffer, 79
  machine instructions a byte more than `CharArray.vector` and
  `String.substring`, which are two copies (1,133.7M instructions against
  344.4M, the building of the array included). A copy of the bytes
  themselves (`RuneBytes.extract`) needs the slice to see them, which
  `CharArray`'s and `Word8Array`'s opaque seals do not let it:
  the representation would have to be shared between an array and its
  slices inside the Basis, as a type several structures share is made
  abstract where it is declared (AGENTS.md). The compiler takes the two
  copies in `Pickle.contents` for this reason: the slice's way would cost
  MLton's 606 files in units about 12%, since 1.1 GB of bases and
  fingerprints pass through it.

The test that held all of them, a 300,000-element list through every
function above under `--stack-size 1048576`, is in the campaign's drafts
(`~/.cache/claude-rune-drafts/functors-units/impl/basis-list-long/`), ready
for `tests/lang` once the list functions are fixed.
