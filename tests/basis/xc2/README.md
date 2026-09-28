# xc2: a host's Basis Library on Rune

The configurations of `tests/basis/run-matrix.sh` cover the four ways to
pair a compiler with a Basis Library:

| | Rune's library | the host's library |
|---|---|---|
| Rune's compiler | `rune` | `xc2:HOST` |
| the host's compiler | `xc1:HOST` | `native:HOST` |

`xc2:HOST` compiles the Basis Library of HOST, the sources the host's
compiler itself compiles, with `bin/rune`, and runs the suite on it with
`bin/runevm`. A test then checks the host's library code compiled by Rune:
where `native:HOST` fails a check because of the host's library, `xc2:HOST`
fails it too, and a check that fails in one and not in the other is a
difference between the compilers (or a defect of the shim below). So the
configuration tests Rune's compiler on another implementation's SML, as the
test programs use it. There are two:

* `xc2:mlton`: MLton's library (`lib/mlton/sml/basis` of the host), some
  37,000 lines in 387 files.
* `xc2:mlkit`: MLKit's (`lib/mlkit/basis`), some 25,000 lines in 139 files.

SML/NJ and Poly/ML have none; see the end.

## How a program is made

`HOST/gen.sh OUTDIR LIB` writes what a program compiles before its own files
(`OUTDIR/prefix`):

1. **The sources.** The host's `basis.patch` is applied to a copy of its
   library. `mlb-flatten.awk` and `flatten.sh` flatten its `basis.mlb` into
   the SML files it loads, in order. The scoping of `local A in B end` is
   kept by saving the structures `A` rebinds before `A` and restoring them
   after `B` (`toplevel.awk` finds the names).
2. **The host's extensions.** `HOST/rewrite.awk` replaces the host's way of
   naming a primitive or a C function by a name of the shim, keeping the
   line breaks.
3. **The shim.** `xc2.sml`, which both share (an array that is allocated
   before it has elements, `XC2Sys`: the primitives of Rune's machine the
   shims use, and Rune's exceptions for a host to take for its own),
   `HOST/prologue.sml` (the host's primitive types as Rune's) and
   `HOST/shim.sml` (the primitives). A primitive the shim does not make
   raises `XC2.Unimplemented` when it is called (the generated `stubs.sml`).
4. **Rune's library**, cut down (`trim-lib.sh`) to the files the shim needs
   (`OUTDIR/lib`): a program that names a structure the host lacks finds
   none, as on the host. So the shared `xc2.sml` names no structure that
   MLKit lacks (`WideChar`, `Real32`, `PackWord16Big`, ...).

## xc2:mlton

`mlton/gen.sh OUTDIR [MLTON_LIB]` builds MLton's `basis.mlb` with MLton's
configuration for 64-bit `int` and `word`. `mlton/rewrite.awk` replaces
`_prim "N": T;` by `(XC2Prim.N : T)`, `_import` by `XC2FFI.N`, `_symbol` by
`XC2Symbol.N`, and `_const`/`_build_const` by the value of the constant (from
MLton's `targets/self/constants`). A primitive used at more than one type
(`Word8_add` adds `Int8.int`s and `Word8.word`s) gets its type in its name
(`Word8_add__int_x_int_to_int`). `mlton/prologue.sml` gives MLton's
primitive types as Rune's (`int8` is `Int8.int`, ..., `real32` is
`Real32.real`, `char8` is `char`, `intInf` is `IntInf.int`).
`mlton/shim.sml` implements the primitives: `mlton/prims.awk` generates the
families (`WordS16_extdToWord32`, `Real32_rndToWordU8`, ...) from the table
of step 2, on functors that work on the bits of a value; the rest, and
MLton's C functions, are written out, mostly on the primitives of Rune's
machine, which are C's functions with Rune's types.

What differs from MLton, and why:

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
  a block of bytes in `XC2Mem`, and C's `errno` is kept by the shim. The
  shim does what a C function is for, so a bug of MLton's C code does not
  show here, and a check can pass that fails natively.
* **Not made.** Threads (`MLton.Thread` switching), signal handlers,
  `MLton.World`, profiling, `MLton.Syslog`: their primitives raise, or do
  nothing where MLton's library calls them while it loads.

## xc2:mlkit

`mlkit/gen.sh OUTDIR MLKIT_LIB` builds MLKit's `basis.mlb`. MLKit's library
calls its primitives and the C functions of its runtime alike, `prim
("NAME", ARG)`, typed by the context; `mlkit/rewrite.awk` makes that
`XC2KPrim.ID (ARG)`, ID the name spelled as an identifier (`=` is `EQ`,
`@f` is `AT_f`, `__f` is `P__f`). A cast, `fun f (x : T1) : T2 = prim
("id", x)`, gets the types of its line in its name (`id__int__char`), and so
do the names of `mlkit/typed.txt`. `_export` and MLKit's constructor
`_IntInf` are renamed, and the constants of `IntInf.int`, which MLKit's
compiler reads itself, are overloaded on `IntInf.fromString` (a generated
file after `IntInf.sml`). `mlkit/prologue.sml` gives MLKit's primitive types
as Rune's: `int`, `int63` and `int64` are Rune's `int`, `int31` and `word31`
types of 31 bits (MLKit's `IntInf` counts on an `int31` that overflows where
an `Int32.int` does not), `chararray` and `'a array` arrays of `XC2`.

Here the shim does what MLKit's C runtime does, its bugs included, since the
library is written against it: `chmod` sets the flags of `open` as the mode,
`sml_getsockopt` always fails (it asks Linux for 8 bytes and gets 4),
`select` is given the greatest descriptor as `nfds`, a record the runtime
returns has its fields in the runtime's order, and the codes of modes, flags
and `whence` are MLKit's.

What differs from MLKit, and why:

* **Strings and byte tables.** MLKit's strings and `CharArray`s, and the
  vectors and arrays of `Word8`, are tables of bytes that the library fills
  in place after allocating them. Rune's strings are made whole: the patch
  builds a string through an array of `XC2`'s and converts it, and the
  functors of the tables (`ByteTable`, `ByteSlice`, `PolyTable`,
  `TableSlice`) take their primitives as arguments, which the shim makes
  (`XC2KCharString`, `XC2KWord8Array`, ...). The other
  monomorphic tables (`BoolVector`, `Word16Array`, `RealArray`, ...) are
  arrays of `XC2`'s (`XC2TableArg`).
* **Arrays.** As for MLton: MLKit's `'a array` and `'a vector` are arrays
  of `XC2`'s, whose cells are made at the first update.
* **Types the library's code takes apart.** A handful of places are
  patched: a type variable scoped by MLKit's rules and not by SML's
  (`TableSlice`), casts without types (`Char.chr`, `Socket.ioDesc`), an
  `eqtype` a functor needs, `Posix.ProcEnv.setuid`, which gives C's
  `setuid` no argument (the patch passes it), and a scanning buffer of
  `TextIO` written in place.
* **The compiler's bugs.** A failure of MLKit's X64 backend (a word
  constant on the stack, a misaligned stack, `__is_null`) or of the way it
  calls C (an `int` result read as a `long`, so that a failure is never
  seen) does not happen here. `posix_procenv` and `posix_sysdb`, which MLKit
  cannot load, run here, and show the library's own bugs
  (`Posix.ProcEnv.time`).
* **Not made.** The sockets of the file system (`sml_sock_*_unix`: MLKit has
  no `UnixSock` to make one), and the primitives of the code the patch
  leaves out; their stubs raise.

## SML/NJ and Poly/ML

Their libraries are written against their compilers' representations more
than MLton's and MLKit's are, and a shim cannot make that of Rune's:

* **SML/NJ** (23,000 lines in `system/Basis/Implementation`) is compiled in
  the compiler's primitive environment (`init.cmi`: `PrimTypes`, `InlineT`,
  `Core`), with CM's descriptions, not MLB. `InlineT`'s primitives have their
  types (`target64-inline.sml`), so a shim could make them as MLton's; but
  the library casts between representations 89 times (`InlineT.cast`: a
  `CharVector` operation used as `Word8Vector`'s, a `word ref` read as a
  `real ref` in `PackReal64Big`), allocates strings and byte vectors and
  fills them in place (`Assembly.A.create_s`; 107 uses of `Assembly`), and
  reaches its runtime by 62 `CInterface.c_function`s. Each cast would be a
  patch, and the strings and byte vectors a rewrite as large as MLKit's.
* **Poly/ML** (32,000 lines in `basis`, 63 of its 102 files calling
  `RunCall`) reaches its runtime by 220 `RunCall.rtsCall*`s, casts 147 times
  (`RunCall.unsafeCast`), and builds strings, vectors and `IntInf`s on raw
  memory (173 calls of `loadByte`, `storeByte`, `allocateByteMemory`, ...;
  `String.sml` reads a string's bytes after its length word, a `char` as a
  string through a table of words): its `String`, `CharVector`,
  `Word8Array` and `LargeInt` would have to be rewritten, and what ran would
  no longer be Poly/ML's library.

## Deviations

A line of `tests/basis/deviations.txt` for `native:HOST` or `*:HOST` also
explains the same failure in `xc2:HOST`: the same library source fails the
same way (such a line is not required to match in `xc2:HOST`, where a bug of
the host's compiler or runtime does not show). A line for `xc2:HOST` records
what differs: `XC2-NA` for what the shim does not make, a bug of the host's
library that shows only in xc2 (MLKit cannot load the test), and otherwise a
defect of the shim or of Rune's compiler.
