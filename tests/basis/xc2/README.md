# xc2: a host's Basis Library on Rune

The configurations of `tests/basis/run-matrix.sh` cover three of the four
ways to pair a compiler with a Basis Library:

| | Rune's library | the host's library |
|---|---|---|
| Rune's compiler | `rune` | `xc2:HOST` |
| the host's compiler | `xc1:HOST` | `native:HOST` |

`xc2:mlton` compiles MLton's Basis Library, the sources MLton itself
compiles (`lib/mlton/sml/basis` of the host), with `bin/rune`, and runs the
suite on it with `bin/runevm`. A test then checks MLton's library code
compiled by Rune: where `native:mlton` fails a check because of MLton's
library, `xc2:mlton` fails it too, and a check that fails in one and not in
the other is a difference between the compilers (or a defect of the shim
below). So the configuration tests Rune's compiler on some 37,000 lines of
another implementation's SML, as the test programs use them.

## How a program is made

`mlton/gen.sh OUTDIR [MLTON_LIB]` writes what a program compiles before
its own files (`OUTDIR/prefix`):

1. **The sources.** `mlb-flatten.awk` and `flatten.sh` flatten MLton's `basis.mlb` into the
   SML files it loads, in order (387, with MLton's configuration for 64-bit
   `int` and `word`). The scoping of `local A in B end` is kept by saving
   the structures `A` rebinds before `A` and restoring them after `B`
   (`toplevel.awk` finds the names). `mlton/basis.patch` is applied first.
2. **MLton's extensions.** `mlton/rewrite.awk` replaces `_prim "N": T;` by
   `(XC2Prim.N : T)`, `_import` by `XC2FFI.N`, `_symbol` by `XC2Symbol.N`,
   and `_const`/`_build_const` by the value of the constant (from MLton's
   `targets/self/constants`), keeping the line breaks. A primitive used at
   more than one type (`Word8_add` adds `Int8.int`s and `Word8.word`s) gets
   its type in its name (`Word8_add__int_x_int_to_int`).
3. **The shim.** `mlton/prologue.sml` gives MLton's primitive types as Rune's
   (`int8` is `Int8.int`, ..., `real32` is `Real32.real`, `char8` is `char`,
   `intInf` is `IntInf.int`). `mlton/shim.sml` implements the primitives:
   `mlton/prims.awk` generates the families (`WordS16_extdToWord32`,
   `Real32_rndToWordU8`, ...) from the table of step 2, on functors that
   work on the bits of a value; the rest, and MLton's C functions, are
   written out, mostly on the primitives of Rune's machine, which are C's
   functions with Rune's types. A primitive the shim does not make raises
   `XC2.Unimplemented` when it is called (`stubs.sml`).
4. **Rune's library**, cut down (`trim-lib.sh`) to the 79 files the shim needs
   (`OUTDIR/lib`): a program that names a structure MLton lacks
   (`INet6Sock`, `Runtime`) finds none, as on MLton.

## What differs from MLton, and why

* **Strings.** MLton's `string` is `char vector`; Rune's is a type of its
  own, the type of the string constants. `String8.string` is Rune's
  string, and the patch builds `CharVector` (and so `String` and
  `Substring`) by MLton's own `Sequence` functor over it, where MLton
  builds it over the polymorphic vector; `WideString` likewise over
  `WideString.string`. A handful of places that took a string for a vector
  are patched.
* **Arrays.** MLton allocates an array before it has an element to fill it
  with; Rune cannot make a polymorphic array without one. MLton's `'a array`
  is a `ref` to cells made at the first update (a `ref`, so that every
  array type admits equality). `Array2.tabulate`, which read the elements of
  a new array, is patched.
* **Overloading.** MLton overloads its operators in
  `top-level/overloads.sml`, which is left out: Rune's compiler overloads
  them at the same types, which are Rune's. `top-level/arithmetic.sml`,
  which bound them to `Int`'s for the rest of the library, is emptied.
* **Exceptions.** `Overflow`, `Div`, `Subscript`, `Size`, `Domain`, `Span`,
  `Chr` and `Fail` are Rune's, which Rune's machine and library raise.
* **The runtime.** MLton's C runtime is not used: the shim makes its
  functions of Rune's (`posix_*`, `os_*`, `socket_*`, ...), a C pointer is
  a block of bytes in `XC2Mem`, and C's `errno` is kept by the shim. So a
  bug of MLton's C code does not show here, and a check can pass that fails
  natively.
* **Not made.** Threads (`MLton.Thread` switching), signal handlers,
  `MLton.World`, profiling, `MLton.Syslog`: their primitives raise, or do
  nothing where MLton's library calls them while it loads.

## Deviations

A line of `tests/basis/deviations.txt` for `native:HOST` also explains the
same failure in `xc2:HOST`: the same library source fails the same way. A
line for `xc2:HOST` records what differs: `XC2-NA` for what the shim does
not make, and otherwise a defect of the shim or of Rune's compiler.
