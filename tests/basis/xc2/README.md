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
test programs use it. There are four:

* `xc2:mlton`: MLton's library (`lib/mlton/sml/basis` of the host), some
  37,000 lines in 387 files.
* `xc2:mlkit`: MLKit's (`lib/mlkit/basis`), some 25,000 lines in 139 files.
* `xc2:smlnj-legacy`: SML/NJ 110.99.9's (`system/Basis` of the release, and
  the part of `system/smlnj/init` that is not the compiler's primitives),
  some 26,000 lines in 265 files.
* `xc2:polyml`: Poly/ML's (`basis` of its source release), some 20,000
  lines in 84 files.

## What it checks, and what it does not

`xc1` shows that Rune's *library* does not depend on accidents of Rune's
compiler, and `native` that the *tests* are not a misreading of the
specification. Neither puts Rune's *compiler* in front of a large body of
SML written by other people to another compiler's habits: that is what
`xc2` is for, and why it is worth having although nobody will run MLton's
Basis Library on Rune's machine. The four libraries are some 108,000 lines.

What the runs have shown (2026-10-09):

* **Rune's compiler.** No failure in the four configurations is Rune's.
  Each is explained by a line about the host's library (a `native:HOST` or
  `*:HOST` line, which holds for `xc2:HOST` too) or by one of six lines of
  `xc2`'s own, all bugs of the host's library that only `xc2` reaches
  (`docs/basis-compat.md`, *Where the hosts depart from the specification*,
  and `docs/bugreport`). One suspected difference, the scope of an explicit
  type variable in MLKit's `TableSlice`, turned out to be MLKit's: Rune,
  MLton and Poly/ML reject that code.
* **Rune's machine.** The JIT's tier 2 of `bin/runevm-int64`, the build
  that `xc2:mlton` runs on, goes wrong on MLton's library (*xc2:mlton*
  below). The other three run on `bin/runevm`, the JIT included.
* **Rune's limits.** The signature `BASIS_EXTRA` of MLton's library, one
  declaration, needs some 21 million steps of type inference, which is
  why the default of `--type-work` became 50 million.
* **The host's compiler, not its library.** A check that fails natively
  and passes here fails because of the host's compiler or runtime: SML/NJ's
  match of an exception value under another name of the exception
  (`General.*/as-value`) and MLKit's x86-64 code generator (a word constant
  pushed as an immediate, a `NULL` from C never seen) are told apart from
  the libraries' bugs this way.

What it does not check:

* **The host's library on its own terms.** The shim makes the library run
  on Rune's primitives, so what is tested is Rune's compiler on the host's
  SML: a difference in, say, `Real.fmt` is the host's algorithm over Rune's
  arithmetic. Where the shim makes a C function from what it is for
  (MLton's runtime), a bug of the host's C code does not show; where the
  library is written against its runtime's behaviour (MLKit, SML/NJ,
  Poly/ML), the shim copies that behaviour, bugs included, and they show as
  they do natively.
* **What the shims do not make:** threads (Poly/ML's library gets one),
  signal handlers, continuations, `MLton.World`, profiling and the controls
  of the collector. No check of the suite fails for want of them: there is
  no `XC2-NA` line.
* **Strict Standard ML '97.** The libraries are not all written in it:
  SML/NJ's uses or-patterns, which Rune compiles with `--or-patterns`;
  MLKit's scopes an explicit type variable at an enclosing `fun` in one
  place, which the patch annotates otherwise; MLton's relies on the scoping
  of its `.mlb` files, which the generator flattens into one program.
* **Rune's own `int` and `word` with MLton.** MLton's library can be built
  for 32- or 64-bit `int` and `word` but not for 63, Rune's, so
  `xc2:mlton` runs on the build of Rune's machine that keeps 64 bits. The
  `int` and `word` of the other three hosts have 63 bits, as Rune's do, and
  their libraries are built as they are natively.

## Running it

```
make hosts                    # the hosts, with the sources of their libraries
make bin/runevm-int64         # the machine xc2:mlton runs on
sh tests/basis/run-matrix.sh -j 12 --configs xc2              # all four
sh tests/basis/run-matrix.sh -j 12 --configs xc2:polyml real  # one, tests named *real*
```

`scripts/fetch-hosts.sh` keeps what the generators read: MLton's and
MLKit's libraries are in their installations, SML/NJ's `system.tgz` is
unpacked into its installation's `system`, and Poly/ML's `basis` is kept
from its source release. A run of the four on 12 job slots took 18
minutes on 2026-10-09, two thirds of it `xc2:mlton`, whose programs each
compile MLton's whole library; most of the rest is the halving of tests
whose sections do not all load. The results are in
`tests/out/matrix/report.md`, one directory per configuration beside it.
`xc2` is not part of `make check`, nor of `make matrix` (`--configs all`): run it
after a change to the compiler's back end, the JIT, the collector or the
primitives of the machine, and before a change to the primitives' names or
to how a value is represented, which the shims depend on.

## How a program is made

`HOST/gen.sh OUTDIR LIB` writes what a program compiles before its own files
(`OUTDIR/prefix`), the options of Rune's compiler it needs besides
`--allow-prim` (`OUTDIR/flags`), and those of the machine (`OUTDIR/vmflags`):

1. **The sources.** The host's `basis.patch` is applied to a copy of its
   library. `mlb-flatten.awk` and `flatten.sh` flatten its `basis.mlb` into
   the SML files it loads, in order. The scoping of `local A in B end` is
   kept by saving the structures `A` rebinds before `A` and restoring them
   after `B` (`toplevel.awk` finds the names). The fixity the `.mlb` files
   give is kept too: MLton compiles parts of its library with `<` and `>`
   not infix (`fun > (a, b) = < (b, a)` in `util/real-comparisons.sml`), so
   its sources start where nothing is infix (the end of `stubs.sml`) and
   `top-level/infixes.sml` brings the infixes back. SML/NJ's library is
   described for CM instead, whose order the host's `sml` gives (below), and
   Poly/ML's by its `build.sml`.
2. **The host's extensions.** `HOST/rewrite.awk` replaces the host's way of
   naming a primitive or a C function by a name of the shim, keeping the
   line breaks.
3. **The shim.** `xc2.sml`, which all share (an array that is allocated
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
configuration for 64-bit `int` and `word`. MLton's library has no
configuration for Rune's `int` and `word`, of 63 bits, and the test
programs' constants are of Rune's `int`: so a program is compiled with
`--int-bits=64` (`OUTDIR/flags`) and run by `bin/runevm-int64`, the build
of Rune's machine whose `int` and `word` keep 64 bits (`make
bin/runevm-int64`), with the JIT's tier 1 alone (`--jit=baseline`,
`OUTDIR/vmflags`): on that build, tier 2 goes wrong on MLton's library.
Compiling only the closure `fn f => fn x => ...` of `make` in
`integer/embed-int.sml` at tier 2 makes the program of `mono.real` hang,
and with all of tier 2 it stops in a primitive that finds a value of the
wrong type (`word64_from_word`); the interpreter, tier 1 and `--jit=all`
run it. `mlton/rewrite.awk` replaces
`_prim "N": T;` by `(XC2Prim.N : T)`, `_import` by `XC2FFI.N`, `_symbol` by
`XC2Symbol.N`, and `_const`/`_build_const` by the value of the constant (from
MLton's `targets/self/constants`). A primitive used at more than one type
(`Word8_add` adds `Int8.int`s and `Word8.word`s) gets its type in its name
(`Word8_add__int_x_int_to_int`). `mlton/prologue.sml` gives MLton's
primitive types as Rune's (`int8` is `Int8.int`, ..., `int64` is `int`,
`real32` is `Real32.real`, `char8` is `char`, `intInf` is `IntInf.int`).
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
as Rune's: `int` and `int63` are Rune's `int`, of 63 bits as MLKit's, `int64`
Rune's `Int64.int` (and the words alike), `int31` and `word31` types of 31
bits (MLKit's `IntInf` counts on an `int31` that overflows where an
`Int32.int` does not), `chararray` and `'a array` arrays of `XC2`.

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

## xc2:smlnj-legacy

`smlnj-legacy/gen.sh OUTDIR SMLNJ` takes SML/NJ's installation: its `sml` gives
the order of the library's files, and `SMLNJ/system` their sources, which
`scripts/fetch-hosts.sh` unpacks from the release's `system.tgz` (the
installer does not fetch it). `smlnj-legacy/order.sml` asks CM for the portable
dependency graph of `Basis/basis-common.cm` (`CM.Graph.graph`), whose
definitions are in the order CM compiles them; the generator puts the files
of the group `TypesOnly` first, then `Implementation`, then `Exports`, which
rebinds names (`Socket`, `Posix`) that `Implementation`'s files mean as they
were in their own group. Before them come the files of the init library
(`smlnj/init`, in the order of `init.cmi`), except those that are the
compiler's primitives: `smlnj-legacy/rts.sml` is the runtime's `Assembly`,
`smlnj-legacy/core.sml` `Core` and `CoreIntInf`, and
`smlnj-legacy/inline.sml` `InlineT` (`InLine`'s primitives with their
types) and `MathInlineT`, all made of Rune's. `smlnj-legacy/prologue.sml`
gives `PrimTypes` as Rune's types (`int` and `word` are Rune's, of 63 bits
as SML/NJ's, `int64` and `word64` Rune's `Int64.int` and `Word64.word`,
`word8vector` is Rune's `string`, `word8array` an array of `Word8.word`,
...), and `smlnj-legacy/rewrite.awk` replaces the vector constants `#[...]`
and `CInterface.c_function "LIB" "NAME"`, a C function of the runtime, by
`XC2NC.LIB_NAME`: `smlnj-legacy/cfuns.sml` makes those the test
programs reach, and the generated stubs raise for the rest. The library
uses or-patterns, an extension of SML/NJ's: Rune compiles it with
`--or-patterns` (`OUTDIR/flags`).

As with MLKit, the shim does what SML/NJ's C runtime (`base/runtime/c-libs`)
does, its bugs included: `fcntl_gfl` asks `F_GETFD` for the flags,
`getaddrfamily` looks the family up in the network's byte order (so that
`Socket.familyOfAddr` is `<UNKNOWN>`), `getservbyport` is given the port in
the machine's order, the library binds `ctlSNDBUF` for the receive buffer
too, and the poll of `OS.IO.poll` and `Socket.select` is `select`, which
fails for a descriptor that is not open and for a negative time.

What differs from SML/NJ, and why:

* **Strings and byte vectors.** SML/NJ allocates a string or a
  `Word8Vector` (`Assembly.A.create_s`) and fills it in place, and casts
  between `CharVector` and `Word8Vector` (`InlineT.cast`). Rune's strings
  are made whole: the patch fills an array of chars and converts it
  (`XC2N.buf`, `XC2N.bstr`), in some 30 files, and a cast becomes a copy.
  `Word8Vector.vector` is Rune's `string`, its elements the bytes of the
  chars.
* **The compiler's bugs.** A check that ends native SML/NJ runs here, and
  shows what the library does: an `Array2` of no elements
  (`no-elements-writes`), `String.extract` near `Int.maxInt`,
  `OS.IO.poll` for input and output at once. A bug of SML/NJ's compiler
  (`General.*/as-value`) does not show.
* **Not made.** Continuations (`SMLofNJ.Cont`), signal handlers, the
  collector's and the profiler's controls, `Unsafe.Object` and
  `Unsafe.blastRead`, exporting a heap, `NetDB` (outside the Basis), and
  the size of a terminal's window (`Posix.TTY.getWindowSz` gives `NONE`):
  their C functions raise, or answer as a system without them would.

## xc2:polyml

`polyml/gen.sh OUTDIR POLYML` takes Poly/ML's installation, whose `basis`
directory holds the sources of its library (`scripts/fetch-hosts.sh` keeps
them there from the source release). `polyml/order.awk` reads the order of
the files from the library's `build.sml`, as it is for a 64-bit Unix
system, with the structures `build.sml` declares between them, and leaves
out what is Poly/ML's compiler and extensions rather than the Basis Library
(the foreign-function interface, weak references, signals, the printer,
the top level). Poly/ML compiles its library in an initial environment of
its compiler's (`INITIALISE_.ML`): `polyml/prologue.sml` makes that
environment of Rune's (`XC2PolyBuiltin`, which a program opens after the
shim): `FixedInt.int` and `int` are Rune's `int` and `Word.word` Rune's
`word`, of 63 bits as Poly/ML's, `LargeWord.word` Rune's `Word64.word`,
`LargeInt.int` Rune's `IntInf.int`, and `RunCall`, `Bootstrap`, `Thread`
and `PolyML` have what the library uses of them. `polyml/rewrite.awk`
replaces a call of the runtime, `RunCall.rtsCallFullN "NAME"`, by
`XC2PR.NAME`, and a call of one of its dispatchers (`PolyBasicIOGeneral`,
`PolyOSSpecificGeneral`), which take a code and arguments whose types
depend on it, by `XC2PR.NAME_CODE` where the code is a constant;
`polyml/rts.sml` makes those the test programs reach, of Rune's, and the
generated stubs raise for the rest.

Poly/ML's library is written against its compiler's representations more
than the others are: 63 of its files call `RunCall`, it casts with
`RunCall.unsafeCast` some 150 times, and it builds strings, vectors and
`IntInf`s in raw memory. So the patch (33 files) is the largest of the
four:

* **Casts.** Each `RunCall.unsafeCast` is replaced by the conversion its
  types call for (`XC2P.wordToInt`, `XC2P.largeToFixed`, ...), which
  `rewrite.awk` does where the line gives the types and the patch
  elsewhere.
* **Memory.** Poly/ML reads and writes the bytes of a string after its
  length word, of a byte array and of a byte vector, and allocates a
  string to fill it before it clears its mutable bit. `polyml/mem.sml`
  makes such an address of Rune's (`XC2P.address`): an array of bytes, a
  string, a string being made, whose bytes are at a string's offsets and
  which `XC2P.freeze` makes a string, or a byte vector. Vectors and arrays
  of any type are Rune's, one being made an array of `XC2`'s; `Array2`'s
  array is a `ref`, so that it admits equality as Poly/ML's does.
* **Overloading.** `RunCall.addOverload` is left out, since Rune's compiler
  overloads the operators at its own types; `Int32.int`, a type of
  Poly/ML's library (a `LargeInt.int`) and not Rune's, gets its operators
  and constants with Rune's `_overload`.
* **Threads.** Rune's machine has one: `Thread` is the part the library
  uses (its mutexes, never held by another thread), and forking a thread
  raises `Thread`.
* **Structures.** Rune's `Int64` and `Real64`, which the shim's part of
  Rune's library would bring and Poly/ML lacks, are taken out of it.

As with SML/NJ, the shim does what Poly/ML's C++ runtime (`libpolyml`) does:
a socket is non-blocking, as the runtime makes it, an I/O descriptor is a
`ref` that `close` clears, and a status of `OS.Process.system` is the
status of `waitpid`, which `OS.Process.exit` passes on (a host bug of the
library's that only xc2 shows: `deviations.txt`).

## Deviations

A line of `tests/basis/deviations.txt` for `native:HOST` or `*:HOST` also
explains the same failure in `xc2:HOST`: the same library source fails the
same way (such a line is not required to match in `xc2:HOST`, where a bug of
the host's compiler or runtime does not show). A line for `xc2:HOST` records
what differs: `XC2-NA` for what the shim does not make, a bug of the host's
library that shows only in xc2 (MLKit cannot load the test, SML/NJ does not
get through it), and otherwise a
defect of the shim or of Rune's compiler.

## Maintaining it

* **What it depends on.** The shims are written on Rune's lowest layer:
  the names and types of the primitives (`runtime/prims.def`), the
  representation of `int`, `word`, `Int64.int`, `Word64.word` and
  `LargeWord.word`, the names of the structures of `lib/basis` that
  `trim-lib.sh` keeps, and the compiler's options. A change there can break
  all four: making `int` and `word` 63 bits, with `Int64.int`, `Word64.word`
  and `LargeWord.word` types of their own (heap-layout M5), took some 250
  changed lines across the shims and patches. A change to Rune's Basis
  Library or to the specification does not reach them.
* **The hosts' versions.** Each patch is of one release: MLton 20241230,
  MLKit 4.7.23, SML/NJ 110.99.9 and Poly/ML 5.9.2. A new release means
  applying the patch again and fixing what does not apply. SML/NJ 2026.2,
  the host `smlnj-dev`, has no `xc2` configuration: against 110.99.9, 25 of
  the files of `system/Basis` differ and 5 are new (`WORD` gains
  `rotateL`, `countOnes`, `ceilLog2` and others), and 5 of `smlnj/init`,
  which the shim stands in for, differ.
* **Working on a patch.** Each `gen.sh` takes a directory with the patch
  already applied instead of applying it (`XC2_MLTON_BASIS`,
  `XC2_SMLNJ_BASIS`, `XC2_POLYML_BASIS`): keep the release's sources in
  `a/` and a patched copy in `b/`, edit `b/`, and write the patch again
  with `diff -ruN a b`, dropping the dates of the `---` and `+++` lines.
* **Its size.** Some 5,600 lines of generators and shims, and patches that
  change some 3,000 lines of 112 files of the hosts' libraries.
* **Before it was built.** `tests/external/probe-host-basis.sh` gives every
  file of a host's library to the compiler alone and counts how far each
  gets. On 2026-09-21, before `xc2` existed, 201 of MLton's 206 files
  already got past Rune's parser, and the 5 that did not were the ones a
  shim replaces: the measurement that showed the work was the shim and not
  the frontend. `tests/external/run-mlton.sh`, MLton's regression programs
  compiled by Rune, is the other way the suite puts Rune's compiler in
  front of SML written for another compiler.
