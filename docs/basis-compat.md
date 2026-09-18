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

## Representation choices in Rune

| Type | Representation |
|---|---|
| `int`, `Int.int` | 64-bit two's complement, `Overflow` checked |
| `word`, `Word.word` | 64 bits |
| `real` | IEEE double |
| `char`, `string` | 8-bit characters; strings are immutable byte sequences |
| `IntInf.int` | a datatype in SML: sign and base-2^30 limbs |
| `Word8Vector.vector` | `string` |
| `TextIO.instream`, `outstream` | a record around a VM file handle; `BinIO` shares them |

## Where Rune departs from the specification

The `RUNE-DEV` lines of `tests/basis/deviations.txt` (M0: 17,619 of 17,975
checks pass on Rune; 17 of the 45 tests need a structure Rune lacks). Missing
members and structures are the subject of [plans/basis.md](plans/basis.md);
the behaviour that is wrong in what exists today:

| Structure | Departure |
|---|---|
| `Bool` | `fromString` accepts exactly `"true"` and `"false"`: case and initial whitespace are not ignored, and characters after the word give `NONE`. |
| `Int` | `fromString` does not skip a leading vertical tab or form feed. |
| `Word` | `fromString` skips no whitespace, does not accept the prefixes `0wX` and `0X`, gives `NONE` for a prefix that no digit follows (the number is the `0`), and wraps around instead of raising `Overflow`. |
| `Real` | `signBit` is false for every NaN (so `~`, `sameSign`, `copySign` ignore the sign of a NaN); `checkFloat` raises `Domain` on NaN, not `Div`; `realFloor`, `realCeil`, `realTrunc`, `realRound` go through `int`: `Overflow` on huge values and infinities, `Domain` on NaN, a zero result loses its sign, and `realRound (2^52 + 1)` is `2^52 + 2`. |
| `Math` | `pow (1.0, NaN)` and `pow (±1.0, ±inf)` are 1.0 (C `pow`), not NaN; `sinh` and `tanh` of `~0.0` are `0.0`; `tanh` is NaN for infinities and for \|x\| > 710. |
| `Char`, `String` | `fromString` converts non-printing characters instead of stopping at them, does not limit `\^c` to the range `@`..`_`, has no `\uxxxx`, and `String.fromString` gives `NONE` instead of the prefix converted before an improper escape; `Char.fromString` has no `\f...f\`; `String.fromString` passes over an unterminated one. |
| `Vector` | `update` with an index out of range returns a copy instead of raising `Subscript`. |
| `Array` | `copy` copies the elements that fit before it raises `Subscript`, and raises nothing for an empty `src` with `di` out of range. |
| `Array`, `Vector` | `tabulate` applies `f` before `n` is compared with `maxLen`. |
| `TextIO` | input on a closed stream raises `Io {cause = ClosedStream}` instead of behaving as at end-of-stream; `output1` on a closed stream reports the function `"output"`. |

The `xc1` configurations reproduce these check for check, so they are
properties of the library source and not of Rune's compiler or VM. The
departures that `xc1` does not reproduce come from the VM's primitives
(`Math.pow`, `sinh`, `tanh` follow C).

Added since M0, with their deviation lines removed: `exnName` and `exnMessage`
(at top level and in `General`, which now matches `GENERAL`), and the three
`*NotSupported` exceptions and `buffer_mode` of `IO`, which now matches `IO`.

Fixed since M0, with their deviation lines removed: `IntInf.*` with a zero
first operand and a second operand of two or more limbs gave a non-canonical
zero (it printed as `0`, was not equal to 0, had `sign` 1 and corrupted
later sums).

## Where the hosts depart from the specification

The `HOST-BUG` and `HOST-ABSENT` lines, for the installed versions (M0; the
current releases are compared in M8). Checks that fail, of about 22,900:
MLton 20210117 195, Poly/ML 5.7.1 87, SML/NJ 110.79 409.

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
  report lists the files and the first error. At M0:

  | Host | File | Why |
  |---|---|---|
  | SML/NJ 110.79 | `intinf.sml` | the limb base 2^30 is not a 31-bit `int` constant |
  | SML/NJ 110.79 | `real.sml` | the host raises `BadReal` on the literal `4.9E~324` (a host bug with subnormal literals) |
  | SML/NJ 110.79, 110.99.9; Poly/ML 5.7.1, 5.9.2 | `int.sml` | `minInt`/`maxInt` are written as 64-bit literals |

  So of the 45 tests, 14 are N/A on SML/NJ 110.79 and 3 on Poly/ML 5.7.1.
  Where `int.sml` is left out and `intinf.sml` is not, `Int.toLarge` is the
  host's and does not produce Rune's `LargeInt.int`, so the `word` test does
  not load either (a `WIDTH` line).

  MLton compiles the `xc1` programs with `-default-type int64 -default-type
  word64` and loads every file. The precision-dependent constants move to one
  configuration structure in M2, after which the hosts load these files.
* `option`, `order` and the exceptions of the initial basis are the host's in
  an `xc1` program, because the host's own library and the primitives share
  them with the program; Rune's declarations of them are not compiled.
* The top-level values of the specification (`exnName`, `map`, ...) are
  rebound to a useless value before `lib/basis` is loaded, so that a test
  cannot pass with the host's `exnName` where Rune defines none.
* `RunePrim` does not go through host functions that the suite shows to be
  wrong: files use `Posix.IO` and not the host's streams (MLton's `inputAll`
  after `input1`), and `real_round` is written with `floor` (Poly/ML's
  `round`). Writing it showed three primitives whose contract was only in the
  C code; `vm/prims.def` now states the 100000000-element limit of arrays and
  vectors, the newline that `file_read_line` adds to a last line, and what
  the two read primitives do after an end of file.
* The host's `OS.Process.exit` knows two statuses, so
  `RunePrim.exit` maps 0 and 1 to them and leaves other statuses to
  `Posix.Process.exit`.
* `poly_eq` and `ptr_eq` are what Rune's compiler makes of `=` and of
  exception matching. No library source names them and they are not part of
  `RUNE_PRIM`.
