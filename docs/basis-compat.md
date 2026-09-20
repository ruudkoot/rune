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

## Summary

The last run of `make matrix` (every configuration). A check that fails is explained by a line of
`tests/basis/deviations.txt` or fails the run. A test is absent where the
system lacks a structure it requires (an optional one: the hosts lack most
of the monomorphic families and some of `IntN`, `WordN` and `Pack*`; see the
table of structures below), and N/A in an `xc1` configuration whose host does
not load the file of lib/basis it needs.

| Configuration | Checks | Pass | Explained | Tests absent | Tests N/A |
|---|---:|---:|---:|---:|---:|
| `rune` | 132,672 | 132,671 | 1 | 0 | 0 |
| `native:mlton@20241230` | 132,560 | 132,216 | 344 | 2 | 0 |
| `native:smlnj@110.99.9` | 60,598 | 59,943 | 655 | 45 | 0 |
| `native:smlnj32@110.99.9` | 51,190 | 49,731 | 1,459 | 45 | 0 |
| `native:polyml@5.9.2` | 67,182 | 66,466 | 716 | 36 | 0 |
| `xc1:mlton@20241230` | 132,652 | 132,344 | 308 | 0 | 0 |
| `xc1:smlnj@110.99.9` | 132,665 | 132,259 | 406 | 0 | 0 |
| `xc1:smlnj32@110.99.9` | 89,870 | 87,770 | 2,100 | 0 | 35 |
| `xc1:polyml@5.9.2` | 132,624 | 132,266 | 358 | 0 | 0 |

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
| `WideTextIO` | | | | |
| `WideTextPrimIO` | | | | |
| `Windows` | | | | |
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

| Type | Representation |
|---|---|
| `int`, `Int.int`, `LargeInt`... | `int`: 64-bit two's complement, `Overflow` checked; `LargeInt` is `IntInf` |
| `word`, `Word.word` | 64 bits; `LargeWord` and `SysWord` are `Word` |
| `Int8.int`, `Int16.int`, `Int32.int` | an `int` kept in the range of the precision (`Overflow` beyond it); `Int64` and `FixedInt` are `Int` |
| `Word8.word`, `Word16.word`, `Word32.word` | a `word` whose upper bits are zero; `Word64` is `Word` |
| `real` | IEEE double; `LargeReal` is `Real` |
| `Real32.real` | abstract: an IEEE double that binary32 represents, every result rounded to binary32 in the current rounding mode |
| `char`, `string` | 8-bit characters; strings are immutable byte sequences |
| `IntInf.int` | a datatype in SML: sign and base-2^30 limbs |
| `Word8Vector.vector`, `CharVector.vector` | `string` (not abstract) |
| `Word8Array.array` | an `array` of `Word8.word`, one VM value per byte |
| `BoolVector.vector`, `IntVector.vector`, `RealVector.vector`, ... | a `Vector.vector` of the elements (`RuneMonoVectorFn`); the arrays are `Array.array` values, the slices a triple of their own |
| `BoolArray2.array`, `CharArray2.array`, ... | an `Array2.array` of the elements; rows and columns are the vectors of the family |
| `Int64Vector`, `Word64Vector`, `LargeWordVector`, `Real64Vector`, `LargeRealVector` and their families | the structures of `Int`, `Word` and `Real` (`Int64` is `Int`, `Word64` and `LargeWord` are `Word`, `Real64` and `LargeReal` are `Real`) |
| `TextIO.instream`, `BinIO.instream` | a reference to a functional stream (so it admits equality); an `outstream` holds a function and does not |
| `Time.time` | microseconds in an `int`; the conversions take and give `LargeInt.int` |
| `OS.IO.iodesc`, `Posix.FileSys.file_desc` | the descriptor of the system |
| `Socket.sock` | the descriptor of the system, with the family and the mode as phantom types; a `sock_addr` is the bytes of the `sockaddr` |
| `NetHostDB.in_addr` | the dotted text of an IPv4 address |

## Where Rune departs from the specification

One check fails on Rune, a reading of the specification: `Char.fromString
"\""` converts the double quote, where the test takes the reading of MLton
and SML/NJ (`NONE`); see the table of readings below.

Not implemented:

* `Windows`;
* IPv6.

`WideChar` is there: a wide character is a Unicode code point (`maxOrd`
0x10FFFF), with `WideString`, `WideSubstring`, `WideText` and the vectors and
arrays of the family, and `WideTextIO` over `WideTextPrimIO`, whose files
hold UTF-8 (the specification names no encoding; no host has a `WideTextIO`
to compare with). Its classes and case conversions are those of ASCII,
which the specification leaves to the implementation, and a character above
255 is written `\uXXXX` or `\UXXXXXXXX`, as MLton writes it.

The functor `StreamIO` takes `VectorSlice` and `ArraySlice` besides the
arguments of the specification, as MLton's does, and its `PrimIO` must have
positions of type `Position.int`.

The signatures of the specification are all there (row `basis.signatures`
of [language.md](language.md)), and every structure that Rune has matches
its signature. The suite checks every
value and exception those signatures specify, on Rune and on the hosts:
`scripts/check-basis-coverage.sh` counts 1,481 of them.

Fixed along the way, each with the deviation lines it removed: the
`fromString` of `Bool`, `Int`, `Word`, `IntInf`, `Char` and `String`
(whitespace, prefixes, escapes, `Overflow`); the bounds checks of
`Vector.update`, `Array.copy` and `tabulate`; `IntInf` with a zero first
operand and a second operand of two or more limbs, which gave a zero that was
not equal to 0; `exnName` and `exnMessage`; the input functions of a closed
`TextIO` stream. Found by MLton's regression programs (M8): `OS.Path.mkRelative`
canonicalised its `path` and dropped its trailing `/`, `mkAbsolute` and
`mkRelative` did not raise `Path` for a relative `relativeTo`,
`joinDirFile` doubled the `/` of the root, `Posix.Process.exit` flushed
the buffers, `OS.IO.poll` and `Socket.select` took a descriptor of the
system for a handle of the VM, and `Socket` did not have the shape of
`SOCKET` (`Ctl`, the `NB` functions, `sameAddr`).

## Where the hosts depart from the specification

The `HOST-BUG`, `HOST-ABSENT` and `HOST-FLAKY` lines; the counts in the
summary above also include the `WIDTH` and `SPEC-AMBIGUOUS` lines of the
hosts. What follows names the themes, not every line.

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

The `SPEC-AMBIGUOUS` lines, and places where the suite had to choose without
a host disagreeing. The suite takes the reading of the majority of the hosts
and says so in a comment at the check.

| Where | The text | Reading taken |
|---|---|---|
| `Char.fromString "\""`, `String.fromString "a\"b"` | names only non-printing characters and improper escapes as reasons to stop | per function, the majority: `Char` gives `NONE` (MLton, SML/NJ; Poly/ML and Rune convert), `String` converts the quote (SML/NJ, Poly/ML, Rune; MLton stops) |
| `Real.fmt` of `~0.0` | the formats say only `[~]?` | the sign is printed (SML/NJ, Poly/ML; MLton omits it) |
| `Real.nextAfter (~0.0, 0.0)`, `(0.0, ~0.0)` | "If r = t then it returns r", where comparisons ignore the sign of a zero | `r`, the zero with its sign, in `Real` and `Real32` (SML/NJ; MLton and Poly/ML return `t`, as C's `nextafter` does) |
| `Math.cosh negInf` | "cosh ±infinity = ±infinity" beside the definition (e^x + e^-x)/2 | `posInf`, the definition (MLton follows the table) |
| `Math.pow (±1, ±inf)`, `pow (1, NaN)` | the table says NaN; C99 and IEEE 754-2008 say 1 | NaN, the page (MLton, SML/NJ) |
| `Io {function}` of `outputSubstr` | "equivalent to output (strm, Substring.string ss)" against "the name of the function raising the exception" | `"output"` (MLton, Poly/ML) |
| `Io {function}` | does not say whether the name is qualified | unqualified (MLton, SML/NJ; Poly/ML reports `"TextIO.openIn"`) |
| input after an end-of-stream of a file that grows | "it is possible that ... input operations will deliver new elements" | the `STREAM_IO` model: `inputLine` and `endOfStream` do not consume the end-of-stream, `input`, `input1` and `inputAll` do (MLton, SML/NJ) |
| `ListPair.allEq` | the "equivalent" expression applies `f` to nothing when the lengths differ; the implementation note applies it to the common prefix | the implementation note (all hosts) |
| `tabulate` beyond `maxLen` | "equivalent to fromList (List.tabulate (n, f))" against "if maxLen < n, then Size is raised" | `Size` before `f` is applied |
| `Array.copy` raising `Subscript` | does not say whether `dst` may be partly modified | nothing is copied (all hosts) |
| `Word.scan` with a bare prefix | no note like INTEGER's `"0xg"` | INTEGER's: the number is the `0` |
| `Bool.scan` whitespace | "initial whitespace" | `Char.isSpace`, as `StringCvt.skipWS` |
| `CommandLine.arguments` | "operating system and implementation-specific" | `[]` under the runner; `poly --use` reports the compiler's own options |

Errata noticed: the REAL and STRING_CVT pages lose the grouping of their
grammars; CHAR's sample table has the illegal string `"a\\ \\\q"`; WORD's
`fmt` writes "Ow" with a letter O; `datatype bool = false | true` and
`datatype 'a list = nil | ::` are not legal specifications (Definition,
Section 2.9) and `eqtype 'a vector = 'a vector` is none either, so
`tests/basis/spec-sigs` uses replication and `type`; General says `Domain` is
raised by MATH functions, which never raise it; the `exnMessage Div = "Div"`
example contradicts "may vary".

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
