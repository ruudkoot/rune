# Basis Library compatibility

How Rune's Basis Library relates to the
[specification](https://smlfamily.github.io/Basis/) and to the libraries of
MLton, SML/NJ and Poly/ML. Everything here comes from the suite in
`tests/basis`: each difference below is a line of
`tests/basis/deviations.txt`, and a run fails when a line no longer matches
what happens. [plans/basis.md](plans/basis.md) has the plan this belongs to.

Systems compared:

| System | Installed | Current (`make hosts`) | `int` | `word` |
|---|---|---|---|---|
| Rune | | | 64 bits | 64 bits |
| MLton | 20210117 | 20241230 | 32 bits (64 with `-default-type int64`) | 32 bits (64 with `-default-type word64`) |
| SML/NJ | 110.79 (32-bit runtime) | 110.99.9 (64-bit runtime) | 31 bits; 63 bits | 31 bits; 63 bits |
| Poly/ML | 5.7.1 | 5.9.2 | 63 bits | 63 bits |

## How to reproduce

```
make matrix-quick                      # rune, native:HOST and xc1:HOST on the installed hosts
make hosts && make matrix              # the same with the current releases as well
sh tests/basis/run-matrix.sh --configs installed,xc1 real    # tests whose name contains "real"
sh tests/basis/structures.sh --current  # which structures each system has
make perf PERF_CONFIGS=all             # wall-clock times of tests/perf, one at a time
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

The last run of `make matrix` (every configuration, both generations of
hosts). A check that fails is explained by a line of
`tests/basis/deviations.txt` or fails the run. A test is absent where the
system lacks a structure it requires (an optional one: the hosts lack most
of the monomorphic families and some of `IntN`, `WordN` and `Pack*`; see the
table of structures below), and N/A in an `xc1` configuration whose host does
not load the file of lib/basis it needs.

| Configuration | Checks | Pass | Explained | Tests absent | Tests N/A |
|---|---:|---:|---:|---:|---:|
| `rune` | 127,899 | 127,892 | 7 | 0 | 0 |
| `native:mlton@20210117` | 127,848 | 127,457 | 391 | 0 | 0 |
| `native:smlnj@110.79` | 60,077 | 58,335 | 1,742 | 40 | 0 |
| `native:polyml@5.7.1` | 63,531 | 62,753 | 778 | 36 | 0 |
| `xc1:mlton@20210117` | 127,879 | 127,571 | 308 | 0 | 0 |
| `xc1:smlnj@110.79` | 85,338 | 83,197 | 2,141 | 0 | 32 |
| `xc1:polyml@5.7.1` | 127,826 | 127,355 | 471 | 0 | 0 |
| `native:mlton@20241230` | 127,848 | 127,510 | 338 | 0 | 0 |
| `native:smlnj@110.99.9` | 60,496 | 59,849 | 647 | 38 | 0 |
| `native:polyml@5.9.2` | 66,837 | 66,165 | 672 | 34 | 0 |
| `xc1:mlton@20241230` | 127,879 | 127,571 | 308 | 0 | 0 |
| `xc1:smlnj@110.99.9` | 127,892 | 127,490 | 402 | 0 | 0 |
| `xc1:polyml@5.9.2` | 127,851 | 127,496 | 355 | 0 | 0 |

On Rune the one failure is a reading of the specification (below). The
`xc1` configurations fail it too, the checks the shim cannot run (sockets,
`poll`), the checks where a host's function under a primitive of the shim is
wrong, and on SML/NJ 110.79 whatever needs more than 31 bits of `int`
(`Time` counts microseconds since 1970).

## Structures each system provides

`tests/basis/structures.sh --current` probes `structure Probe = NAME` for
every structure of the specification on each system:

| Structure | Rune | MLton 20210117 | SML/NJ 110.79 | Poly/ML 5.7.1 | MLton 20241230 | SML/NJ 110.99.9 | Poly/ML 5.9.2 |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `BoolArray` | yes | yes | | yes | yes | | yes |
| `BoolArray2` | yes | yes | | yes | yes | | yes |
| `BoolArraySlice` | yes | yes | | | yes | | |
| `BoolVector` | yes | yes | | yes | yes | | yes |
| `BoolVectorSlice` | yes | yes | | | yes | | |
| `CharArray2` | yes | yes | | yes | yes | | yes |
| `Int8` | yes | yes | | | yes | | |
| `Int16` | yes | yes | | | yes | | |
| `Int64` | yes | yes | yes | | yes | yes | |
| `IntArray` | yes | yes | | yes | yes | | yes |
| `IntArray2` | yes | yes | | yes | yes | | yes |
| `IntArraySlice` | yes | yes | | yes | yes | | yes |
| `IntVector` | yes | yes | | yes | yes | | yes |
| `IntVectorSlice` | yes | yes | | yes | yes | | yes |
| `Int8Array` | yes | yes | | | yes | | |
| `Int8Array2` | yes | yes | | | yes | | |
| `Int8ArraySlice` | yes | yes | | | yes | | |
| `Int8Vector` | yes | yes | | | yes | | |
| `Int8VectorSlice` | yes | yes | | | yes | | |
| `Int16Array` | yes | yes | | | yes | | |
| `Int16Array2` | yes | yes | | | yes | | |
| `Int16ArraySlice` | yes | yes | | | yes | | |
| `Int16Vector` | yes | yes | | | yes | | |
| `Int16VectorSlice` | yes | yes | | | yes | | |
| `Int32Array` | yes | yes | | | yes | | |
| `Int32Array2` | yes | yes | | | yes | | |
| `Int32ArraySlice` | yes | yes | | | yes | | |
| `Int32Vector` | yes | yes | | | yes | | |
| `Int32VectorSlice` | yes | yes | | | yes | | |
| `Int64Array` | yes | yes | | | yes | | |
| `Int64Array2` | yes | yes | | | yes | | |
| `Int64ArraySlice` | yes | yes | | | yes | | |
| `Int64Vector` | yes | yes | | | yes | | |
| `Int64VectorSlice` | yes | yes | | | yes | | |
| `LargeIntArray` | yes | yes | | | yes | | |
| `LargeIntArray2` | yes | yes | | | yes | | |
| `LargeIntArraySlice` | yes | yes | | | yes | | |
| `LargeIntVector` | yes | yes | | | yes | | |
| `LargeIntVectorSlice` | yes | yes | | | yes | | |
| `LargeRealArray` | yes | yes | | | yes | | |
| `LargeRealArray2` | yes | yes | | | yes | | |
| `LargeRealArraySlice` | yes | yes | | | yes | | |
| `LargeRealVector` | yes | yes | | | yes | | |
| `LargeRealVectorSlice` | yes | yes | | | yes | | |
| `LargeWordArray` | yes | yes | | | yes | | |
| `LargeWordArray2` | yes | yes | | | yes | | |
| `LargeWordArraySlice` | yes | yes | | | yes | | |
| `LargeWordVector` | yes | yes | | | yes | | |
| `LargeWordVectorSlice` | yes | yes | | | yes | | |
| `PackRealBig` | yes | yes | | yes | yes | | yes |
| `PackRealLittle` | yes | yes | | yes | yes | | yes |
| `PackReal64Big` | yes | yes | yes | | yes | yes | |
| `PackReal64Little` | yes | yes | yes | | yes | yes | |
| `PackWord64Big` | yes | yes | | | yes | yes | |
| `PackWord64Little` | yes | yes | | | yes | yes | |
| `RealArray2` | yes | yes | | yes | yes | | yes |
| `Real64` | yes | yes | yes | | yes | yes | |
| `Real64Array` | yes | yes | yes | | yes | yes | |
| `Real64Array2` | yes | yes | | | yes | | |
| `Real64ArraySlice` | yes | yes | yes | | yes | yes | |
| `Real64Vector` | yes | yes | yes | | yes | yes | |
| `Real64VectorSlice` | yes | yes | yes | | yes | yes | |
| `SML90` | | | yes | yes | | yes | yes |
| `WideChar` | | yes | | | yes | | |
| `WideCharArray` | | yes | | | yes | | |
| `WideCharVector` | | yes | | | yes | | |
| `WideString` | | yes | | | yes | | |
| `WideSubstring` | | yes | | | yes | | |
| `WideText` | | yes | | | yes | | |
| `WideTextIO` | | | | | | | |
| `WideTextPrimIO` | | | | | | | |
| `Windows` | | | | | | | |
| `WordArray` | yes | yes | | | yes | | |
| `WordArray2` | yes | yes | | | yes | | |
| `WordArraySlice` | yes | yes | | | yes | | |
| `WordVector` | yes | yes | | | yes | | |
| `WordVectorSlice` | yes | yes | | | yes | | |
| `Word16` | yes | yes | | | yes | | yes |
| `Word16Array` | yes | yes | | | yes | | |
| `Word16Array2` | yes | yes | | | yes | | |
| `Word16ArraySlice` | yes | yes | | | yes | | |
| `Word16Vector` | yes | yes | | | yes | | |
| `Word16VectorSlice` | yes | yes | | | yes | | |
| `Word32Array` | yes | yes | | | yes | | |
| `Word32Array2` | yes | yes | | | yes | | |
| `Word32ArraySlice` | yes | yes | | | yes | | |
| `Word32Vector` | yes | yes | | | yes | | |
| `Word32VectorSlice` | yes | yes | | | yes | | |
| `Word64Array` | yes | yes | | | yes | | |
| `Word64Array2` | yes | yes | | | yes | | |
| `Word64ArraySlice` | yes | yes | | | yes | | |
| `Word64Vector` | yes | yes | | | yes | | |
| `Word64VectorSlice` | yes | yes | | | yes | | |
| `Word8Array2` | yes | yes | | yes | yes | | yes |

Provided by all of them: `Array`, `ArraySlice`, `BinIO`, `BinPrimIO`, `Bool`, `Byte`, `Char`, `CharArray`, `CharArraySlice`, `CharVector`, `CharVectorSlice`, `CommandLine`, `Date`, `General`, `IEEEReal`, `IO`, `Int`, `LargeInt`, `LargeReal`, `LargeWord`, `List`, `ListPair`, `Math`, `OS`, `OS.FileSys`, `OS.IO`, `OS.Path`, `OS.Process`, `Option`, `Position`, `Real`, `String`, `StringCvt`, `Substring`, `Text`, `TextIO`, `TextPrimIO`, `Time`, `Timer`, `Vector`, `VectorSlice`, `Word`, `Word8`, `Word8Array`, `Word8ArraySlice`, `Word8Vector`, `Word8VectorSlice`, `Array2`, `FixedInt`, `GenericSock`, `INetSock`, `Int32`, `IntInf`, `NetHostDB`, `NetProtDB`, `NetServDB`, `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `Posix`, `RealArray`, `RealArraySlice`, `RealVector`, `RealVectorSlice`, `Socket`, `Unix`, `UnixSock`, `Word32`, `Word64`.

## Representation choices in Rune

| Type | Representation |
|---|---|
| `int`, `Int.int`, `LargeInt`... | `int`: 64-bit two's complement, `Overflow` checked; `LargeInt` is `IntInf` |
| `word`, `Word.word` | 64 bits; `LargeWord` and `SysWord` are `Word` |
| `Int8.int`, `Int16.int`, `Int32.int` | an `int` kept in the range of the precision (`Overflow` beyond it); `Int64` and `FixedInt` are `Int` |
| `Word8.word`, `Word16.word`, `Word32.word` | a `word` whose upper bits are zero; `Word64` is `Word` |
| `real` | IEEE double; `LargeReal` is `Real` |
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

22 checks fail on Rune, each with its `RUNE-DEV` or `SPEC-AMBIGUOUS` line.
One is a reading: `Char.fromString "\""` converts the double quote, where
the test takes the reading of MLton and SML/NJ (`NONE`); see the table of
readings below. The others are the parts of what follows that the suite
reaches.

Not implemented:

* `Real32`, and so `PackReal32Big`, `PackReal32Little` and the `Real32`
  vectors and arrays;
* `WideChar` and its family (characters have 8 bits), `SML90` and `Windows`;
* IPv6;
* the functors `PrimIO`, `StreamIO` and `ImperativeIO` under those names
  (`lib/basis` has them as `RunePrimIOFn`, `RuneStreamIOFn` and
  `RuneImperativeIOFn`).

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

The `HOST-BUG`, `HOST-ABSENT` and `HOST-FLAKY` lines. The counts of the
summary above include the `WIDTH` and `SPEC-AMBIGUOUS` lines of the hosts;
the installed versions first.

* **MLton 20210117.** `Bool.scan` and `fromString` are case-sensitive and skip
  no whitespace. `Word.scan` consumes a prefix (`0w`, `0wx`, `0x`) that no
  digit follows, and gives `NONE` for `0x42` in the radices `BIN`, `OCT`,
  `DEC`. `Real.rem (0.0, 0.0)` is 0.0; `rem` is computed in floating point and
  can exceed `y`. `Char.scan` leaves an escaped formatting sequence in the
  stream after an escape; `fromCString` accepts `\uxxxx`; `String.fromCString`
  gives `SOME ""` where no character converts. After `input1`, `inputLine`,
  `lookahead`, `endOfStream` or `canInput`, `inputAll` returns the rest of the
  stream without consuming it. `Byte.packString` of an empty substring does
  not check the offset.
* **Poly/ML 5.7.1.** `Real.round` and `realRound` of 0.49999999999999994 give
  1; `realRound (2^52 + 1)` is `2^52 + 2`; `fromLargeInt` drops the bits below
  the rounding position; `toString` and `GEN` print integral values with `.0`
  and do not choose the shorter notation; `scan` accepts a bare `.`, does not
  accept `inf` and `nan`, raises `Overflow` on a huge exponent and consumes
  the character after a complete exponent; `nextAfter (posInf, 0.0)` is
  `maxFinite`; `rem (posInf, posInf)` is `posInf`. `Math.pow (±1.0, ±inf)` is
  1.0. `Word.fromString` reads `0w12` as `0wx12`. Characters buffered before
  `closeIn` are still read after it.
* **SML/NJ 110.79.** `IEEEReal` is that of the 1997 Basis; `Real.fmt EXACT`,
  `nextAfter`, `toDecimal`, `fromDecimal` are unimplemented; `toManExp` does
  not normalise zeros, subnormals and reals from 2^1023, and `fromManExp` and
  `toLargeInt` loop forever on the latter; `split` and `realMod` lose signs;
  `realFloor`/`realCeil`/`realTrunc` are inexact beyond 2^52; `scan` is not
  correctly rounded; `fmt` yields at most 15 digits. `Math.atan2` ignores the
  sign of a zero; `tanh` is NaN for large arguments. `Int.sameSign (0, i)` is
  true for positive `i`; the `scan` functions skip only space, tab and
  newline; `IntInf.fmt HEX` gives lower-case digits, `IntInf.pow (±1, j)` is 0
  for negative `j`, `IntInf.mod (0, 0)` does not raise `Div`. `Vector.update`
  out of range returns the vector; `Array.tabulate (~1, f)` applies `f`.
  `String.extract` with a start or length near `Int.maxInt` crashes the
  system; `String.isSubstring "" ""` is false; `toCString #"\000"` is `"\\0"`;
  `fromCString` has no `\^c` and wants the whole string to convert.
  `exnMessage` of seven standard exceptions does not contain `exnName`.
  `TextIO.inputAll (openString "")` raises `Io` with cause `Div`; `inputN`
  with a negative count raises `Subscript`; `input1` never moves past an
  end-of-stream; `OS.Process.sleep` drops the fraction of a second.
* **All three.** `fromCString` converts an unescaped double quote;
  `Char.fromCString` raises `Overflow` for a `\x` escape beyond `Int.maxInt`;
  `Char.scan` leaves a trailing escaped formatting sequence in the stream;
  `Word.scan HEX` treats `0w` as a prefix.

The current releases, against the installed ones:

* **MLton 20241230** fixes the 14 `Word.scan` checks (`0w` is no longer
  taken for a prefix of the hexadecimal format) and adds nothing: 187 checks
  fail, each for a reason that 20210117 has too.
* **SML/NJ 110.99.9** (64-bit) fixes 272: the `Real` formatting, `nextAfter`,
  `fromManExp`, `toManExp` and `split`, the `IEEEReal` of the 2004 Basis, the
  `findi`, `subslice` and `collate` of the slices, `Int.sameSign`, `toCString`
  of `#"\000"`. New in it: `IntInf.scan` in the radices `BIN` and `OCT`
  accepts digits the radix does not have; `floor`, `ceil`, `trunc` and
  `round` wrap around above `maxInt` instead of raising `Overflow`, and
  `ceil` and `trunc` of `minInt` give `maxInt`; `rem` of an infinity or by a
  zero is a zero, not NaN; `Real.scan` and `IEEEReal.scan` consume a decimal
  point that no digit follows; `IEEEReal.toString` drops the sign of a NaN;
  `fmt` of `minPos` pads the digits of `5E~324` with zeros. It reads the
  literal `4.9E~324` as 0.0 (110.79 rejects it). And on a loaded machine it
  sometimes computes a floating-point result wrongly: in about one run in ten
  of 32 at once, `fromManExp (toManExp x)` differs from `x` in the last bits
  or a `Math.ln` law fails; alone it never happens. Those are the
  `HOST-FLAKY` lines, which are not required to match.
* **Poly/ML 5.9.2** fixes 33: the rounding of `Real.fromString` and
  `Real.scan`, `IEEEReal.fromString`, `Real.rem` of infinities, `fmt` and
  `round`. New in it: `IntInf.~>>` of a negative number beyond a machine word
  rounds towards zero instead of down (`~2^100 ~>> 0w101` is 0); `toDecimal`
  gives `exp = 1` for zeros, infinities and NaNs, and `fmt EXACT` of a zero
  is `"0.0E1"`; `fromManExp {man = minPos, exp = 2074}` is `inf`; and
  `fromString` of 2^53 + 1 + 10^-21 gives 2^53, as if the digits stopped at
  the tie.

The monomorphic sequences of the other element types (`BoolVector`,
`IntArraySlice`, `RealArray2`, ...), which came later:

* MLton and Poly/ML have the defects of their `Array2` in every `MONO_ARRAY2`
  structure too: MLton's `copy` within one array to the left or the right in
  the same rows, Poly/ML's arrays without rows, the `Overflow` of its region
  checks, `array (0, ~1, x)` without `Size` and two arrays without rows that
  are equal. The slices have the `Overflow` of the other slices on Poly/ML,
  and on SML/NJ 110.79 the `findi`, `subslice` and `collate` of the other
  slices; `RealVector.update` out of range returns the vector on SML/NJ.
* MLton 20241230 computes `BoolVector.length (BoolArray.vector
  (BoolArray.array (3, true)))` as 0 in a program that also uses
  `BoolArraySlice` or `BoolArray2` (3 by itself, and 3 in the same program on
  20210117).
* Which families a host has is in the table above: SML/NJ has only those of
  `Real` and `Real64`, without the `Array2`; Poly/ML those of `Bool` (without
  the slices), `Int` and `Real`; MLton all of them. A test of a family a host
  lacks is absent there.

Found while writing the suite, outside what the matrix can show:

* SML/NJ 110.79 compiles `case General.Div of Div => ...` to the default rule
  when an exception is built and matched under two names in one compilation
  unit (the suite's `General.*/as-value` checks).
* `OS.Process.sleep` of a negative time never returns on SML/NJ (110.79 from
  −1 s, 110.99.9 for any negative time), and raises `SysErr` on Poly/ML 5.7.1.
  The check is left out: it would cost a timeout per run.
* SML/NJ runs an `atExit` action that is registered from within an action
  ("Calls in f to atExit are ignored"). The suite cannot observe what happens
  after its own exit.
* Poly/ML 5.7.1 aborts compilation on `Array.update (a, ~1, 9)` with the
  constant index ("Overflow unexpectedly raised while compiling") and on one
  inlined real comparison ("InternalError: asGenReg"); the tests read the
  index from a ref and call the helper through a ref.

## Readings of the specification

The `SPEC-AMBIGUOUS` lines, and places where the suite had to choose without
a host disagreeing. The suite takes the reading of the majority of the hosts
and says so in a comment at the check.

| Where | The text | Reading taken |
|---|---|---|
| `Char.fromString "\""`, `String.fromString "a\"b"` | names only non-printing characters and improper escapes as reasons to stop | per function, the majority: `Char` gives `NONE` (MLton, SML/NJ; Poly/ML and Rune convert), `String` converts the quote (SML/NJ, Poly/ML, Rune; MLton stops) |
| `Real.fmt` of `~0.0` | the formats say only `[~]?` | the sign is printed (SML/NJ, Poly/ML; MLton omits it) |
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
  report lists the files and the first error. Today one file is left out:

  | Host | File | Why |
  |---|---|---|
  | SML/NJ 110.79 | `intinf.sml` | the limb base 2^30 is not a 31-bit `int` constant |

  So 9 of the 76 tests are N/A on SML/NJ 110.79, and none elsewhere. Three
  files have been made portable to get there: `int.sml` and `word.sml` find
  their precision by doubling until `Overflow` and by shifting a bit out,
  `real.sml` computes `minPos` as `minNormalPos / 2^52` (SML/NJ misreads the
  literal `4.9E~324`), and `unix.sml` builds its exit status with
  `Word8.fromInt` (a host cannot type the literal `0w127` at Rune's `Word8`).
  On a 31-bit `int` some of Rune's code overflows where the VM's 64 bits do
  not: `Time.now` (microseconds since 1970) and the conversions between
  `real` and `LargeInt`; those are the `WIDTH` lines of SML/NJ 110.79.

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
the one program being timed (2026-09-19). Each cell is the milliseconds of
one run of a program of `tests/perf`: the program is run R times in a row
(the `wall R` line of its `.budget` file) in three rounds, and the fastest
round counts; SML/NJ and Poly/ML compile it before the timer starts, like the
others. In parentheses: the time divided by the baseline of the same
configuration, the geometric mean of `fib` and `tak`, which use no Basis
Library. That ratio separates what a library costs from how fast a system
runs code at all.

| Program | rune | native:mlton@20210117 | native:smlnj@110.79 | native:polyml@5.7.1 | xc1:mlton@20210117 | xc1:smlnj@110.79 | xc1:polyml@5.7.1 | native:mlton@20241230 | native:smlnj@110.99.9 | native:polyml@5.9.2 | xc1:mlton@20241230 | xc1:smlnj@110.99.9 | xc1:polyml@5.9.2 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| array_sieve | 42.59 (3.9) | 0.43 (1.9) | 0.94 (2.8) | 0.65 (2.2) | 0.51 (1.9) | n/a | 0.64 (2.2) | 0.74 (2.1) | 1.24 (3.6) | 0.64 (3.1) | 0.46 (1.6) | 1.27 (3.6) | 0.50 (2.4) |
| fib | 12.03 (1.1) | 0.39 (1.7) | 0.41 (1.2) | 0.41 (1.4) | 0.40 (1.5) | n/a | 0.48 (1.6) | 0.41 (1.2) | 0.44 (1.3) | 0.33 (1.6) | 0.54 (1.8) | 0.53 (1.5) | 0.30 (1.5) |
| intinf_fact | 326.69 (29.5) | 0.04 (0.2) | 0.45 (1.4) | 0.45 (1.5) | n/a | n/a | n/a | 0.14 (0.4) | 0.25 (0.7) | 0.21 (1.0) | n/a | n/a | n/a |
| list_ops | 35.36 (3.2) | 1.72 (7.6) | 1.26 (3.8) | 1.81 (6.2) | 1.07 (4.0) | n/a | 1.19 (4.0) | 1.48 (4.3) | 1.58 (4.6) | 1.60 (7.7) | 1.21 (4.1) | 2.42 (6.9) | 0.77 (3.8) |
| real_nbody | 9.97 (0.9) | 0.58 (2.6) | 0.50 (1.5) | error | 0.59 (2.2) | n/a | error | 0.59 (1.7) | 0.52 (1.5) | 1.11 (5.4) | 0.60 (2.0) | 0.49 (1.4) | 1.06 (5.2) |
| string_ops | 36.70 (3.3) | 1.39 (6.2) | 2.16 (6.5) | 3.10 (10.6) | 2.10 (7.8) | n/a | 2.72 (9.3) | 1.78 (5.2) | 2.46 (7.1) | 2.12 (10.2) | 2.04 (6.9) | 3.60 (10.3) | 2.35 (11.5) |
| tak | 10.16 (0.9) | 0.13 (0.6) | 0.27 (0.8) | 0.21 (0.7) | 0.18 (0.7) | n/a | 0.18 (0.6) | 0.29 (0.8) | 0.27 (0.8) | 0.13 (0.6) | 0.16 (0.5) | 0.23 (0.7) | 0.14 (0.7) |
| word_bits | 16.26 (1.5) | 0.12 (0.5) | 0.26 (0.8) | 0.24 (0.8) | 0.10 (0.4) | n/a | 0.21 (0.7) | 0.16 (0.5) | 0.26 (0.8) | 0.15 (0.7) | 0.10 (0.3) | 0.28 (0.8) | 0.16 (0.8) |

Not measured: `real_nbody` on Poly/ML 5.7.1 (the compiler stops with
`InternalError: asGenReg`); `intinf_fact` in the `xc1` configurations (its
`IntInf` constants would need the host's overloading to include the `IntInf`
of `lib/basis`); anything on `xc1:smlnj@110.79`, where the `Time` of
`lib/basis`, which counts microseconds since 1970 in an `int`, overflows the
host's 31 bits.

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
  about as fast as that host's own library (`list_ops` 1.1 ms on MLton against
  1.7 ms native, `string_ops` 2.1 against 1.4): the algorithms of `lib/basis`
  are not what makes Rune slow.
