# Basis Library compatibility

How Rune's Basis Library relates to the
[specification](https://smlfamily.github.io/Basis/) and to the libraries of
MLton, SML/NJ and Poly/ML. Everything here comes from the suite in
`tests/basis`: each difference below is a line of
`tests/basis/deviations.txt`, and a run fails when a line no longer matches
what happens. [plans/basis.md](plans/basis.md) has the plan this belongs to.

Systems compared:

The hosts are the releases `make hosts` installs under
`${RUNE_HOSTS:-~/.local/rune-hosts}`, never ones the machine itself has:

| System | Version | `int` | `word` |
|---|---|---|---|
| Rune | | 64 bits | 64 bits |
| MLton | 20241230 | 32 bits (64 with `-default-type int64`) | 32 bits (64 with `-default-type word64`) |
| SML/NJ | 110.99.9, 64-bit build (`smlnj`) | 63 bits | 63 bits |
| SML/NJ | 110.99.9, 32-bit build (`smlnj32`) | 31 bits | 31 bits |
| Poly/ML | 5.9.2 | 63 bits | 63 bits |

The 32-bit SML/NJ is there for its narrow `int` and `word`, which have found
many places where the library or a test depended on their width.

## How to reproduce

```
make hosts                             # install the host systems, once
make matrix-quick                      # rune and Rune's library compiled by each host (xc1)
make matrix                            # and the suite on each host's own library
sh tests/basis/run-matrix.sh --configs all real   # tests whose name contains "real"
sh tests/basis/structures.sh           # which structures each system has
make perf                              # wall-clock times of tests/perf, one at a time
```

The report is `tests/out/matrix/report.md`; the logs of one test in one
configuration are in `tests/out/matrix/<configuration>/<test>.dir/`.

* `rune`: the suite on Rune.
* `native:HOST`: the suite on the host's own library. This checks the tests.
* `xc1:HOST`: the suite on Rune's library (`lib/basis`) compiled by the
  host, with the VM's primitives written on the host's library
  (`tests/basis/host/rune-prim.sml`). This checks that Rune's library is
  portable Standard ML, that its `_prim` annotations agree with
  `vm/prims.def`, and that its code is right independently of Rune's compiler
  and VM.
* `rune:windows` and `rune:windows32`: the suite on Rune, on the VMs of
  Windows (`make windows`, `make test-windows`; [building.md](building.md)).
  Their lines of `deviations.txt` are `WINDOWS`: what Windows does not
  have or does otherwise, which its system layer cannot make good (the
  modes of a group and of others, named pipes, datagrams in the Unix
  domain, process groups, stopping a process), and the checks that ask `sh`
  or start another program of POSIX; each says why it stays. They are not
  differences of the library, and are not described below.

## Summary

The last run of `make matrix` (every configuration). A check that fails is explained by a line of
`tests/basis/deviations.txt` or fails the run. A test is absent where the
system lacks a structure it requires (an optional one: the hosts lack most
of the monomorphic families and some of `IntN`, `WordN` and `Pack*`; see the
table of structures below), and N/A in an `xc1` configuration whose host does
not load the file of lib/basis it needs.

| Configuration | Checks | Pass | Explained | Tests absent | Tests N/A |
|---|---:|---:|---:|---:|---:|
| `rune` | 136,062 | 136,061 | 1 | 0 | 0 |
| `native:mlton@20241230` | 135,890 | 135,543 | 347 | 4 | 0 |
| `native:smlnj@110.99.9` | 60,598 | 59,944 | 654 | 56 | 0 |
| `native:smlnj32@110.99.9` | 51,190 | 49,731 | 1,459 | 56 | 0 |
| `native:polyml@5.9.2` | 67,182 | 66,467 | 715 | 47 | 0 |
| `xc1:mlton@20241230` | 136,042 | 135,734 | 308 | 0 | 0 |
| `xc1:smlnj@110.99.9` | 136,055 | 135,648 | 407 | 0 | 0 |
| `xc1:smlnj32@110.99.9` | 93,260 | 91,160 | 2,100 | 0 | 35 |
| `xc1:polyml@5.9.2` | 136,014 | 135,656 | 358 | 0 | 0 |

On Rune the one failure is a reading of the specification (below). The
`xc1` configurations fail it too, the checks the shim cannot run (sockets,
`poll`), the checks where a host's function under a primitive of the shim is
wrong, and on the 32-bit SML/NJ whatever needs more than 31 bits of `int`
(`Time` counts microseconds since 1970).

## Structures each system provides

`tests/basis/structures.sh` probes `structure Probe = NAME` for every
structure of the specification on each system (the 32-bit SML/NJ has the
library of the 64-bit one):

| Structure | Rune | MLton 20241230 | SML/NJ 110.99.9 | Poly/ML 5.9.2 |
|---|:---:|:---:|:---:|:---:|
| `BoolArray` | yes | yes | | yes |
| `BoolArray2` | yes | yes | | yes |
| `BoolArraySlice` | yes | yes | | |
| `BoolVector` | yes | yes | | yes |
| `BoolVectorSlice` | yes | yes | | |
| `CharArray2` | yes | yes | | yes |
| `Int8` | yes | yes | | |
| `Int16` | yes | yes | | |
| `Int64` | yes | yes | yes | |
| `IntArray` | yes | yes | | yes |
| `IntArray2` | yes | yes | | yes |
| `IntArraySlice` | yes | yes | | yes |
| `IntVector` | yes | yes | | yes |
| `IntVectorSlice` | yes | yes | | yes |
| `Int8Array` | yes | yes | | |
| `Int8Array2` | yes | yes | | |
| `Int8ArraySlice` | yes | yes | | |
| `Int8Vector` | yes | yes | | |
| `Int8VectorSlice` | yes | yes | | |
| `Int16Array` | yes | yes | | |
| `Int16Array2` | yes | yes | | |
| `Int16ArraySlice` | yes | yes | | |
| `Int16Vector` | yes | yes | | |
| `Int16VectorSlice` | yes | yes | | |
| `Int32Array` | yes | yes | | |
| `Int32Array2` | yes | yes | | |
| `Int32ArraySlice` | yes | yes | | |
| `Int32Vector` | yes | yes | | |
| `Int32VectorSlice` | yes | yes | | |
| `Int64Array` | yes | yes | | |
| `Int64Array2` | yes | yes | | |
| `Int64ArraySlice` | yes | yes | | |
| `Int64Vector` | yes | yes | | |
| `Int64VectorSlice` | yes | yes | | |
| `LargeIntArray` | yes | yes | | |
| `LargeIntArray2` | yes | yes | | |
| `LargeIntArraySlice` | yes | yes | | |
| `LargeIntVector` | yes | yes | | |
| `LargeIntVectorSlice` | yes | yes | | |
| `LargeRealArray` | yes | yes | | |
| `LargeRealArray2` | yes | yes | | |
| `LargeRealArraySlice` | yes | yes | | |
| `LargeRealVector` | yes | yes | | |
| `LargeRealVectorSlice` | yes | yes | | |
| `LargeWordArray` | yes | yes | | |
| `LargeWordArray2` | yes | yes | | |
| `LargeWordArraySlice` | yes | yes | | |
| `LargeWordVector` | yes | yes | | |
| `LargeWordVectorSlice` | yes | yes | | |
| `PackRealBig` | yes | yes | | yes |
| `PackRealLittle` | yes | yes | | yes |
| `PackReal64Big` | yes | yes | yes | |
| `PackReal64Little` | yes | yes | yes | |
| `PackWord64Big` | yes | yes | yes | |
| `PackWord64Little` | yes | yes | yes | |
| `RealArray2` | yes | yes | | yes |
| `Real32` | yes | yes | | yes |
| `Real32Array` | yes | yes | | |
| `Real32Array2` | yes | yes | | |
| `Real32ArraySlice` | yes | yes | | |
| `Real32Vector` | yes | yes | | |
| `Real32VectorSlice` | yes | yes | | |
| `PackReal32Big` | yes | yes | | yes |
| `PackReal32Little` | yes | yes | | yes |
| `Real64` | yes | yes | yes | |
| `Real64Array` | yes | yes | yes | |
| `Real64Array2` | yes | yes | | |
| `Real64ArraySlice` | yes | yes | yes | |
| `Real64Vector` | yes | yes | yes | |
| `Real64VectorSlice` | yes | yes | yes | |
| `SML90` | yes | | yes | yes |
| `WideChar` | yes | yes | | |
| `WideCharArray` | yes | yes | | |
| `WideCharVector` | yes | yes | | |
| `WideString` | yes | yes | | |
| `WideSubstring` | yes | yes | | |
| `WideText` | yes | yes | | |
| `WideTextIO` | yes | | | |
| `WideTextPrimIO` | yes | | | |
| `Windows` | yes | | | |
| `WordArray` | yes | yes | | |
| `WordArray2` | yes | yes | | |
| `WordArraySlice` | yes | yes | | |
| `WordVector` | yes | yes | | |
| `WordVectorSlice` | yes | yes | | |
| `Word16` | yes | yes | | yes |
| `Word16Array` | yes | yes | | |
| `Word16Array2` | yes | yes | | |
| `Word16ArraySlice` | yes | yes | | |
| `Word16Vector` | yes | yes | | |
| `Word16VectorSlice` | yes | yes | | |
| `Word32Array` | yes | yes | | |
| `Word32Array2` | yes | yes | | |
| `Word32ArraySlice` | yes | yes | | |
| `Word32Vector` | yes | yes | | |
| `Word32VectorSlice` | yes | yes | | |
| `Word64Array` | yes | yes | | |
| `Word64Array2` | yes | yes | | |
| `Word64ArraySlice` | yes | yes | | |
| `Word64Vector` | yes | yes | | |
| `Word64VectorSlice` | yes | yes | | |
| `Word8Array2` | yes | yes | | yes |

Provided by all of them: `Array`, `ArraySlice`, `BinIO`, `BinPrimIO`, `Bool`, `Byte`, `Char`, `CharArray`, `CharArraySlice`, `CharVector`, `CharVectorSlice`, `CommandLine`, `Date`, `General`, `IEEEReal`, `IO`, `Int`, `LargeInt`, `LargeReal`, `LargeWord`, `List`, `ListPair`, `Math`, `OS`, `OS.FileSys`, `OS.IO`, `OS.Path`, `OS.Process`, `Option`, `Position`, `Real`, `String`, `StringCvt`, `Substring`, `Text`, `TextIO`, `TextPrimIO`, `Time`, `Timer`, `Vector`, `VectorSlice`, `Word`, `Word8`, `Word8Array`, `Word8ArraySlice`, `Word8Vector`, `Word8VectorSlice`, `Array2`, `FixedInt`, `GenericSock`, `INetSock`, `Int32`, `IntInf`, `NetHostDB`, `NetProtDB`, `NetServDB`, `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `Posix`, `RealArray`, `RealArraySlice`, `RealVector`, `RealVectorSlice`, `Socket`, `Unix`, `UnixSock`, `Word32`, `Word64`.

## Representation choices in Rune

What the specification leaves to the implementation is written on the member
it belongs to, as an `Implementation:` note, and collected in
[generated/basis/readings.md](generated/basis/readings.md). The widths are in
the table at the top of this page.

## Where Rune departs from the specification

Every departure is written on the member it is about, as a `Deviation:` or a
`Limitation:` note, and is collected in
[generated/basis/readings.md](generated/basis/readings.md). Every structure
of the specification is implemented; `Windows`, which is Windows' own,
raises `OS.SysErr` with `ENOSYS` for every call of the system on another
system. IPv6 is not in the specification either -- it
was written before the protocol, and its `NetHostDB` gives the four dotted
numbers of IPv4 -- so Rune adds it as `INet6Sock` with a signature of its own,
`INET6_SOCK`, which is `INET_SOCK` read for 128-bit addresses. `Socket.AF`
knows the family, which the page allows (`AF.list` "returns a list of all the
available address families"), and `NetHostDB` stays what the specification
defines.

`Runtime` is the other structure of Rune's own, and the one the specification
had no reason to have: it is about the implementation a program is running on
rather than about anything the language defines. It gives a program the
counters the VM keeps anyway (instructions, bytes, objects, collections), a
`profile` that reports what a call cost, a collection on demand, the call
stack as data, the identity `=` uses for a `ref` where `=` is not available,
the version, and `save`, which writes the whole running program to a file for
`runevm --restore` to carry on. Nothing there ports, and nothing there is
needed to write Standard ML: a program that only wants the time a computation
took should use `Timer`, which is the specification's
([generated/basis/sig/RUNTIME.md](generated/basis/sig/RUNTIME.md),
[../examples/runtime](../examples/runtime)).

No check of the suite fails on Rune.

`WideChar` is there: a wide character is a Unicode code point (`maxOrd`
0x10FFFF), with `WideString`, `WideSubstring`, `WideText` and the vectors and
arrays of the family, and `WideTextIO` over `WideTextPrimIO`, whose files
hold UTF-8 (the specification names no encoding; no host has a `WideTextIO`
to compare with). Its classes and case conversions are those of ASCII,
which the specification leaves to the implementation, and a character above
255 is written `\uXXXX` or `\UXXXXXXXX`, as MLton writes it.

The signatures of the specification are all there (row `basis.signatures`
of [language.md](language.md)), and every structure that Rune has matches
its signature. The suite checks every value and exception those signatures
specify, on Rune and on the hosts; `runedoc` counts them when it makes the
documentation (`make docs`).

Fixed along the way, each with the deviation lines it removed: the
`fromString` of `Bool`, `Int`, `Word`, `IntInf`, `Char` and `String`
(whitespace, prefixes, escapes, `Overflow`); the bounds checks of
`Vector.update`, `Array.copy` and `tabulate`; `IntInf` with a zero first
operand and a second operand of two or more limbs, which gave a zero that was
not equal to 0; `exnName` and `exnMessage`; the input functions of a closed
`TextIO` stream; `IEEEReal.Unordered`, which was an exception of its own and
not the `Unordered` of the top-level environment. Found by MLton's regression
programs (M8): `OS.Path.mkRelative` canonicalised its `path` and dropped its
trailing `/`, `mkAbsolute` and `mkRelative` did not raise `Path` for a
relative `relativeTo`, `joinDirFile` doubled the `/` of the root,
`Posix.Process.exit` flushed the buffers, `OS.IO.poll` and `Socket.select`
took a descriptor of the system for a handle of the VM, and `Socket` did not
have the shape of `SOCKET` (`Ctl`, the `NB` functions, `sameAddr`).

## Where the hosts depart from the specification

The `HOST-BUG`, `HOST-ABSENT` and `HOST-FLAKY` lines; the counts in the
summary above also include the `WIDTH` and `SPEC-AMBIGUOUS` lines of the
hosts. What follows names the themes, not every line; the library's
documentation has every line under the member it is about, in a block
"Other implementations" (`tests/basis/gen-annotations.sh` makes
`tests/basis/annotations.txt` from `deviations.txt` for it).

* **MLton 20241230** (71 lines). `Bool.scan` and `fromString` are
  case-sensitive and skip no whitespace. `Real.rem (0.0, 0.0)` is 0.0, and
  `rem` is computed in floating point, so it can exceed `y`. `Char.scan`
  leaves an escaped formatting sequence in the stream after an escape;
  `fromCString` accepts `\uxxxx`, and `String.fromCString` gives `SOME ""`
  where no character converts. After `input1`, `inputLine`, `lookahead`,
  `endOfStream` or `canInput`, `inputAll` returns the rest of the stream
  without consuming it, and the `input1` that returns `NONE` leaves the
  stream before the end. `Byte.packString` of an empty substring does not
  check the offset, and `triml`/`trimr` check a negative count only once
  applied. `Time.fromReal` of a NaN raises `Domain`; `Date.offset` reports
  the offset modulo a day, and `toTime` raises for dates before 1970 or
  after 2038. `OS.IO.kind` calls every character device a terminal, and
  `poll` of a closed descriptor gives `[]`. `Posix.*.allSet` takes its
  arguments the other way round, `Posix.FileSys.ST.mode` keeps the file-type
  bits, and `Unix.fromStatus` misreads what `reap` returns.
  `Socket.Ctl.getNREAD` answers ~1 and `getATMARK` always true; `NetServDB`
  does not convert ports from network byte order. `getOutstream` and
  `setOutstream` do not flush.
* **SML/NJ 110.99.9, 64-bit** (151 lines). `exnMessage` of the standard
  exceptions does not contain `exnName`, and an exception value built under
  one name and matched under another takes the default rule.
  `Vector.update` out of range returns the vector; `Array.tabulate (~1, f)`
  applies `f`. `String.extract` near `Int.maxInt` crashes the system;
  `isSubstring "" ""` is false; `fromCString` has no `\^c` and wants the
  whole string to convert. The `scan` functions skip only space, tab and
  newline; `IntInf.fmt HEX` gives lower-case digits, `IntInf.pow (±1, j)` is
  0 for negative `j`, and `IntInf.scan` in `BIN` and `OCT` accepts digits
  the radix does not have. Of `Real`: `rem` of an infinity or by a zero is a
  zero, `realFloor`/`realCeil`/`realTrunc` are inexact beyond 2^52 and lose
  the sign of a zero, `ceil` of `minPos` is 0, `floor`/`ceil`/`trunc`/`round`
  wrap around above `maxInt`, `fmt` yields at most 15 digits and pads the
  digits of `minPos`, `scan` is not correctly rounded and consumes a point
  that no digit follows. `Math.atan2` ignores the sign of a zero and is NaN
  for two infinities; `tanh` is NaN for large arguments. `TextIO.inputAll
  (openString "")` raises `Io` with cause `Div`, and `inputN` with a
  negative count raises `Subscript`. On a loaded machine it sometimes gets a
  floating-point result wrong (about one run in ten of 32 at once, never
  alone): those are the `HOST-FLAKY` lines, which need not match.
* **SML/NJ 110.99.9, 32-bit** (159 lines). Everything of the 64-bit build,
  and: `Int64` is emulated with two words and comes out wrong throughout
  (`Int64.+ (~2, ~3)` is 1073741819), `Int32.div (minInt, ~1)` kills the
  runtime with the processor's trap instead of raising `Overflow`, the
  compiler fails with "Compiler bug: Num64Cnv" on the conversions of
  `Word32`, `Word64` and `LargeWord`, `PackWord*.update` writes the wrong
  bytes, and `lseek` with a negative offset gives a position of its own.
  Its `int` and `word` have 31 bits, which is what the `WIDTH` lines of that
  configuration record.
* **Poly/ML 5.9.2** (106 lines). `Real.round` and `realRound` of
  0.49999999999999994 give 1, `realRound (2^52 + 1)` is `2^52 + 2` and
  `realRound (~0.25)` loses the sign; `toString` and `GEN` print integral
  values with `.0` and do not choose the shorter notation; `toDecimal` gives
  `exp = 1` for zeros, infinities and NaNs, and `fmt EXACT` of a zero is
  `"0.0E1"`; `nextAfter (posInf, 0.0)` is `maxFinite`; `Math.pow (±1.0,
  ±inf)` is 1.0. `Word.fromString` reads `0w12` as `0wx12`, and
  `IntInf.~>>` of a negative number beyond a machine word rounds towards
  zero. `Substring`, the slices and `Array2` raise `Overflow` where the
  specification says `Subscript`, and an `Array2` without rows has no number
  of columns. `Time.toSeconds` rounds a negative time towards minus
  infinity; `Date.fmt ""` raises `Date`. Characters buffered before
  `closeIn` are still read after it. `OS.Path` mishandles the root and the
  current arc; `OS.errorName` gives the C name. A forked child that calls
  `Posix.Process.exit` never ends, and the runtime ignores `SIGPIPE`.
* **All of them.** `fromCString` converts an unescaped double quote;
  `Char.fromCString` raises `Overflow` for a `\x` escape beyond
  `Int.maxInt`; `Char.scan` leaves a trailing escaped formatting sequence in
  the stream.

## Readings of the specification

Where the specification is silent, ambiguous or contradictory, the reading
Rune takes is written on the member it is about, in the library's
documentation; [generated/basis/readings.md](generated/basis/readings.md)
collects them all, with the checks that pin each one. The errata of the
specification are there too, under the members they belong to.

### `WideCharVector` must admit equality, and its declaration cannot say so

`MONO_VECTOR` writes `type vector`, not `eqtype`, so that `RealVector` can
exist. Where a vector has to admit equality the page says so on the instance:
`CharVector` is declared `where type vector = String.string`, and `STRING`
writes `eqtype string`. `WideCharVector` is declared `where type elem =
WideChar.char` and nothing more.

That is not enough. `TEXT` shares `String.string` with `CharVector.vector`,
and `WideText` is declared `where type String.string = WideString.string`, so
`WideText.CharVector.vector` is `WideString.string` and admits equality. Any
implementation whose `WideText.CharVector` is the top-level `WideCharVector`
-- every one that provides both -- must give `WideCharVector.vector`
equality, and the declaration the page gives it cannot. The omission is
`where type vector = WideString.string`.

The whole of the defect is that one missing constraint, which makes it a
milder fault than the `ARRAY2` one below: there, no constraint can help,
because there is no type to pin to; here `WideString.string` is already there
and `STRING` already makes it an equality type.

**What Rune does:** seals `WideCharVector` with `MONO_VECTOR_EQ`, a signature
of its own that is `MONO_VECTOR` with `eqtype vector`. That follows from this
library's order rather than from the fault: `WideString` is built on
`WideCharVector`, so `WideCharVector` is where the type name is born and
there is nothing yet to pin it to. Following the page as it should have been
written would mean giving `WideString` a representation of its own and
pinning `WideCharVector` to it, and then `MONO_VECTOR_EQ` would be
unnecessary. The notes are `MONO_VECTOR/WideCharVector-must-admit-equality`
and `MONO_VECTOR_EQ/not-in-the-specification`.

### The largest one: `ARRAY2` cannot be sealed and keep its equality

The page of `ARRAY2` asks for three things that Standard ML cannot give
together. It declares `structure Array2 :> ARRAY2`; it writes
`eqtype 'a array`; and it says "Thus, the type `ty array` admits equality
even if `ty` does not". Any two of those hold, and all three cannot: only the
built-in type names of the language admit equality whatever they hold --
`ref`, named in Section 4.4 of the Definition, and the `array` of the top
level -- and no signature can specify one. Through `eqtype 'a t`, a `ty t`
admits equality exactly when `ty` does, so an opaque seal makes a fresh type
name and the third clause fails at `real` and at a function type.

`ARRAY` carries the same sentence without the defect, because the top level
pins `'a array` to `Array.array`: that type *is* the built-in, and the seal
settles nothing. `Array2` is optional and has no such anchor -- no system has
a top-level `'a array2` -- so its seal bites. `VECTOR` writes
`eqtype 'a vector` and says nothing of the kind, and `MONO_ARRAY2` has no
defect at all, because its `eqtype array` is monomorphic and a record over a
built-in array satisfies it.

**The reading Rune takes:** the seal and `eqtype 'a array` stand, and the
sentence does not apply. `Array2.array` is abstract, `real Array2.array`
admits no equality, and the monomorphic two-dimensional arrays do admit it
whatever they hold, because `MONO_ARRAY2` asks only for a monomorphic
`eqtype array`. MLton and SML/NJ read it the same way. Poly/ML takes the
other reading and leaves `'a Array2.array` a record, which lets a program
reach inside it. The note is
`ARRAY2/sealed-and-equal-at-any-element`.

## What XC1 cannot check

* A file of `lib/basis` that a host does not load is left out of the `xc1`
  configuration of that host; the tests of its structures are N/A there. The
  report lists the files and the first error. Today four are left out, all
  on the 32-bit SML/NJ:

  | Host | File | Why |
  |---|---|---|
  | SML/NJ 110.99.9, 32-bit | `intinf.sml` | the limb base 2^30 is not a 31-bit `int` constant |
  | SML/NJ 110.99.9, 32-bit | `int32.sml` | `Int32` needs constants beyond a 31-bit `int` |
  | SML/NJ 110.99.9, 32-bit | `timer.sml` | it counts microseconds in an `int` |
  | SML/NJ 110.99.9, 32-bit | `pack_real32.sml` | the 32 bits of binary32 are no 31-bit `word` constant |

  So 35 of the 202 tests are N/A there, and none elsewhere. Four files have
  been made portable to get that far: `int.sml` and `word.sml` find their
  precision by doubling until `Overflow` and by shifting a bit out,
  `real.sml` computes `minPos` as `minNormalPos / 2^52` (SML/NJ misreads the
  literal `4.9E~324`), and `unix.sml` builds its exit status with
  `Word8.fromInt` (a host cannot type the literal `0w127` at Rune's `Word8`).
  On a 31-bit `int` some of Rune's code overflows where the VM's 64 bits do
  not: `Time.now` (microseconds since 1970) and the conversions between
  `real` and `LargeInt`; those are the `WIDTH` lines of that configuration.

  MLton compiles the `xc1` programs with `-default-type int64 -default-type
  word64`, the precision of the VM.
* `option`, `order` and the exceptions of the initial basis are the host's in
  an `xc1` program, because the host's own library and the primitives share
  them with the program; Rune's declarations of them are not compiled.
* The top-level values of the specification (`exnName`, `map`, ...) are
  rebound to a useless value before `lib/basis` is loaded, so that a test
  cannot pass with the host's `exnName` where Rune defines none.
* `RunePrim` does not go through host functions that the suite shows to be
  wrong: files use `Posix.IO` and not the host's streams (MLton's `inputAll`
  after `input1`), `real_round` is written with `floor` (Poly/ML's `round`;
  `trunc`, which would suit a 31-bit `int` better, gives `maxInt` for `minInt`
  on SML/NJ 110.99.9), and `time_sleep` sleeps again for what is left
  (Poly/ML 5.9.2 can return early). Where the shim does call the host's
  function, the host's bug shows in the `xc1` configuration too: a host line
  that names `*:HOST` explains both. Writing it showed three primitives whose contract was only in the
  C code; `vm/prims.def` now states the 100000000-element limit of arrays and
  vectors, the newline that `file_read_line` adds to a last line, and what
  the two read primitives do after an end of file.
* The sockets and the network databases are left out. The hosts keep a
  socket and its address behind types indexed by the family and the mode,
  where Rune's primitives pass descriptors and bytes. The shim would need a
  table of host sockets per family and mode to bridge them, so its socket
  and database primitives fail with `ENOSYS`. The tests of M7 are in
  `tests/lang`, which runs on Rune only.
* The host's `OS.Process.exit` knows two statuses, so
  `RunePrim.exit` maps 0 and 1 to them and leaves other statuses to
  `Posix.Process.exit`.
* `poly_eq` and `ptr_eq` are what Rune's compiler makes of `=` and of
  exception matching. No library source names them and they are not part of
  `RUNE_PRIM`.

## Performance

`make perf PERF_CONFIGS=all` on an x86_64 machine with 16 CPUs, idle but for
the one program being timed (2026-09-20). Each cell is the milliseconds of
one run of a program of `tests/perf`: the program is run R times in a row
(the `wall R` line of its `.budget` file) in three rounds, and the fastest
round counts; SML/NJ and Poly/ML compile it before the timer starts, like the
others. In parentheses: the time divided by the baseline of the same
configuration, the geometric mean of `fib` and `tak`, which use no Basis
Library. That ratio separates what a library costs from how fast a system
runs code at all.

| Program | rune | native:mlton@20241230 | native:smlnj@110.99.9 | native:smlnj32@110.99.9 | native:polyml@5.9.2 | xc1:mlton@20241230 | xc1:smlnj@110.99.9 | xc1:smlnj32@110.99.9 | xc1:polyml@5.9.2 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| array_sieve | 39.61 (3.9) | 0.43 (1.7) | 1.36 (4.0) | 0.91 (2.4) | 0.61 (2.5) | 0.50 (1.6) | 1.33 (4.0) | n/a | 0.55 (2.2) |
| fib | 11.19 (1.1) | 0.44 (1.8) | 0.43 (1.3) | 0.49 (1.3) | 0.36 (1.5) | 0.53 (1.7) | 0.44 (1.3) | n/a | 0.32 (1.3) |
| intinf_fact | 295.00 (29.3) | 0.03 (0.1) | 0.24 (0.7) | 0.44 (1.1) | 0.13 (0.5) | n/a | n/a | n/a | n/a |
| list_ops | 34.27 (3.4) | 1.80 (7.3) | 1.70 (5.0) | 1.52 (4.0) | 1.54 (6.4) | 1.15 (3.7) | 2.01 (6.1) | n/a | 0.84 (3.3) |
| real_nbody | 9.53 (0.9) | 0.57 (2.3) | 0.55 (1.6) | 0.55 (1.4) | 1.29 (5.4) | 0.58 (1.9) | 0.54 (1.6) | n/a | 0.99 (3.9) |
| string_ops | 33.67 (3.3) | 1.40 (5.6) | 2.42 (7.1) | 2.10 (5.5) | 2.38 (9.9) | 2.75 (8.9) | 3.78 (11.4) | n/a | 2.56 (10.1) |
| tak | 9.07 (0.9) | 0.14 (0.6) | 0.27 (0.8) | 0.30 (0.8) | 0.16 (0.7) | 0.18 (0.6) | 0.25 (0.8) | n/a | 0.20 (0.8) |
| word_bits | 14.62 (1.5) | 0.12 (0.5) | 0.28 (0.8) | 0.27 (0.7) | 0.17 (0.7) | 0.13 (0.4) | 0.31 (0.9) | n/a | 0.18 (0.7) |

Not measured: `intinf_fact` in the `xc1` configurations (its `IntInf`
constants would need the host's overloading to include the `IntInf` of
`lib/basis`); anything on `xc1:smlnj32`, where the `Timer` and `LargeInt` the
wrapper times with are not those of `lib/basis` (`timer.sml` and `intinf.sml`
do not load on a 31-bit `int`).

What the table says:

* Rune's VM runs plain code 20 to 80 times slower than the native code of
  the hosts (`fib` 12 ms against 0.3 to 0.5 ms, `tak` 10 ms against 0.13 to
  0.3 ms). This is the interpreter; it is the subject of
  [plans/performance.md](plans/performance.md).
* Relative to that baseline, the library costs Rune what it costs the hosts:
  `array_sieve`, `list_ops` and `string_ops` take 3 to 4 times the baseline on
  Rune, 2 to 12 times on the hosts.
* `IntInf` is the exception: 30 times the baseline on Rune, 0.2 to 1.5 times
  on the hosts, which use GMP (MLton) or native code. Its limbs of 30 bits
  are an SML datatype, and every limb operation runs on the interpreter.
* The `xc1` columns run Rune's library compiled by each host, and they are
  about as fast as that host's own library (`list_ops` 1.2 ms on MLton against
  1.8 ms native, `string_ops` 2.8 against 1.4): the algorithms of `lib/basis`
  are not what makes Rune slow.

### Native code

The same, on 2026-09-24, with `rune:opt`: every program translated into
native code by `runeopt` ([plans/codegen.md](plans/codegen.md)) and run so.
`rune` and `rune:opt` were timed together, the hosts in a run of their own
that day.

| Program | rune | rune:opt | native:mlton@20241230 | native:smlnj@110.99.9 | native:polyml@5.9.2 |
|---|---:|---:|---:|---:|---:|
| array_sieve | 39.21 (3.7) | 16.26 (3.5) | 0.43 (1.7) | 1.28 (3.8) | 0.56 (2.6) |
| fib | 10.75 (1.0) | 5.64 (1.2) | 0.44 (1.7) | 0.42 (1.2) | 0.32 (1.5) |
| intinf_fact | 333.32 (31.3) | 110.69 (24.1) | 0.05 (0.2) | 0.27 (0.8) | 0.13 (0.6) |
| list_ops | 30.65 (2.9) | 16.75 (3.6) | 2.18 (8.5) | 1.55 (4.6) | 1.88 (8.9) |
| real_nbody | 9.98 (0.9) | 2.50 (0.5) | 0.57 (2.2) | 0.50 (1.5) | 1.03 (4.9) |
| string_ops | 36.75 (3.5) | 18.36 (4.0) | 1.47 (5.7) | 2.16 (6.4) | 2.21 (10.4) |
| tak | 10.52 (1.0) | 3.74 (0.8) | 0.15 (0.6) | 0.27 (0.8) | 0.14 (0.7) |
| word_bits | 14.61 (1.4) | 6.02 (1.3) | 0.17 (0.7) | 0.27 (0.8) | 0.17 (0.8) |

* Native code runs these programs 1.8 to 4.0 times faster than the VM
  (`fib` 5.6 ms against 10.8, `tak` 3.7 against 10.5, `real_nbody` 2.5
  against 10.0), and the compiler compiles itself in 5.5 s against 10.2. It
  is still 10 to 40 times slower than the hosts: the translation keeps every
  value in memory, 16 bytes wide, and every call, return and allocation goes
  through the runtime's C.
* A profile of the compiler compiling itself natively (`perf record`) puts
  36% of the time in the translated code, 34% in calls and returns through
  the runtime, 12% in the collector, 6% in allocation and 2% in the
  primitives the code still calls; the rest is the C library and the
  system. What the plan says of it is under M7 of
  [plans/codegen.md](plans/codegen.md).
