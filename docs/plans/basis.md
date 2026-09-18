# Plan: the full Standard ML Basis Library

This document covers bringing Rune's library from the subset in `lib/basis`
(19 files, about 1,100 lines, no signatures) to the full
[SML Basis Library](https://smlfamily.github.io/Basis/), with a test suite
that is checked against MLton, SML/NJ and Poly/ML, a record of how the four
implementations differ ([docs/basis-compat.md](../basis-compat.md)), and
`make doctor`. Written 2026-09-18.

## Status

| Milestone | State |
|---|---|
| Part 0, `make doctor` | done |
| M0, suite, matrix and cross-check scaffolding | done |
| M1, compiler and runtime prerequisites | done, except what moved to its first user (below) |
| M2, text conversion and numbers | done; `IntN`/`WordN` omitted for now (below) |
| M3–M8 | not started |

M0 delivered the harness and conventions (`tests/basis/README.md`), 45 test
programs for the 19 existing structures (17,975 checks on Rune, about 22,900
on a host, 394 specified members covered), the matrix runner with the `rune`,
`native:HOST` and `xc1:HOST` configurations, `scripts/fetch-hosts.sh` (MLton
20241230, SML/NJ 110.99.9, Poly/ML 5.9.2), `scripts/check-basis-coverage.sh`,
and the suite programs in `make check-cross`. `make matrix-quick` is green:
every failure on the seven configurations is a line of
`tests/basis/deviations.txt`. What the suite found, in Rune and in the hosts,
is in [docs/basis-compat.md](../basis-compat.md); the departures of Rune's
existing code listed there are fixed in M2–M5 with the structure they belong
to, and their deviation lines go with them.

M1 delivered, one commit each: `runevm --count` and `--gc-stress` with
`make test-stress`, and a map for `Prims.find`; inlined applications of
variables bound to a primitive (the bootstrap went from 541.7 M to 491.9 M
instructions and from 916 MB to 650 MB allocated); the overload registry
`src/elab/overload.sml` (bytecode-identical); the primitive `word_neg`;
overloaded int and word constants with compile-time range errors, and the
`_overload` declaration, with `IntInf.int` as the first registered type;
MANIFEST v2 and the demand-driven loader (`--basis all`, `--basis-deps`,
`--basis-check`); the always-loaded part reduced to `initial.sml` and
`pervasive.sml`, 91 lines (hello: 64 KB of bytecode to 4.3 KB, 0.53 s to
0.04 s to compile with `bin/rune`); `exn_name` with `exnName` and `exnMessage`;
`make perf-check` (`tests/perf`), part of `make check`.

Moved from M1 to the milestone of their first user, so that they arrive
tested: the object kind for mutable bytes, `_primtype` and the block
primitives (M3, with the monomorphic arrays and slices); the `print` hook and
the `SysErr`/`Io` declarations in `initial.sml` (M4, with the I/O stack and
`sys_init`); the exit hook (M5, with `OS.Process.atExit`).

M2 delivered `StringCvt`, `Substring`, `scan` and `fmt` for `Bool`, `Int`,
`Word`, `IntInf`, `Char` and `String` (with `toCString`/`fromCString`), the
rest of `IntInf` (`log2`, bit operations, shifts), `LargeWord`, the complete
`Real` and `Math`, `IEEEReal`, and `LargeReal`. `Int` and `Word` no longer
depend on the precision, so Poly/ML loads all of `lib/basis` under `xc1`.
On Rune 25,748 of 25,802 checks pass; the 5 absent tests need `Word8` or
`Time`.

**Omitted for now: `IntN` and `WordN`, except a minimal `Word8`.** The
fixed-width structures (`Int8`, `Int16`, `Int32`, `Int64`, `Word16`,
`Word32`, `Word64`) are not implemented. `Word8` exists
(`lib/basis/word8.sml`, sealed with `signature WORD`, registered with
`_overload word Word8 8`) because the byte-oriented structures cannot do
without it; it is written directly, not as an instance of a functor, and its
test is one application of `tests/basis/fn/word_fn.sml`. The groundwork is in place: a functor with a `val bits`
parameter and opaque sealing works in Rune, `_overload int Int32 32` would
register such a type with range-checked constants, and the test functors
`tests/basis/fn/integer_fn.sml`, `integer_scan_fn.sml`, `word_fn.sml`,
`word_large_fn.sml` and `word_scan_fn.sml` take any INTEGER or WORD structure
and its name. What is missing is the signature `INTEGER` in `lib/basis`, the functors, one
file per instance, and their rows and tests.

Left for later milestones: the deviation lines for the current host releases
(M8; `make matrix` reports their differences as unexplained until then),
tests that need a second process (exit status, `atExit` order, what `print`
writes, stdin contents, command-line arguments), and a per-test time limit
for checks that hang a host (`OS.Process.sleep` of a negative time).

## Scope

Every required module of the specification, and every optional module that
makes sense on Linux: `IntN`/`WordN`, `IntInf`, `RealN` aliases, `Array2`,
the monomorphic vector, array and slice families, `Pack*`, the
`PrimIO`/`StreamIO`/`ImperativeIO` stack, `OS.FileSys`/`Path`/`Process`/`IO`,
`Time`, `Date`, `Timer`, `IEEEReal`, `Posix` (its eight substructures), `Unix`,
`Socket`/`INetSock`/`UnixSock`/`GenericSock`, `NetHostDB`/`NetProtDB`/`NetServDB`.

Out of scope: `WideChar`/`WideText` (characters are 8 bits wide, and no host
ships them) and `Windows`.

## Constraints (hold at every milestone)

* `make check` is green, the bootstrap fixed point holds and the four builds
  emit identical bytecode. The compiler's own sources use the library, so
  every library edit re-bootstraps. Every commit satisfies this.
* `vm/prims.def` is append-only: primitive numbers are positions.
* The documentation contract of `AGENTS.md`: every module has a
  `docs/language.md` row and a test, every primitive is in `docs/bytecode.md`.
* Library sources and tests do not depend on the precision of `int` and
  `word`. Measured on the hosts: SML/NJ 110.79 31 bits, MLton 32 (64 with
  `-default-type`), Poly/ML and SML/NJ 110.99 63. `Int` and `Word` find
  their precision with the arithmetic itself (doubling until `Overflow`,
  shifting a bit out).
* Tests are portable Standard ML '97 plus the Basis Library, nothing else.
* The core VM uses only ISO C99. POSIX code lives only in `vm/sys_posix.c`,
  behind `vm/sys.h`, with `vm/sys_none.c` as the fallback.

## Design

### Compiler prerequisites

1. **Extensible overloading.** A registry from type constructor stamp to
   `{kind, operations, literal range}` in a new `src/elab/overload.sml`
   replaces the five builtin classes. `Unify` asks the registry for the kind,
   `Translate.builtinPrim` looks the primitive up by stamp, literals get a
   fresh overloaded type variable and are range-checked after resolution. A
   privileged declaration, `_overload <kind> <longstrid> [bits | via <longvid>]`,
   registers a type from a library file. `IntN`/`WordN` are opaque types built
   by functors over `int`/`word`; `Int64`, `FixedInt`, `Position` are `Int`,
   `Word64`, `LargeWord`, `SysWord` are `Word`, `LargeInt` is `IntInf`. A new
   primitive `word_neg` fixes `~` at `word`. `_primtype "bytearray"` names an
   abstract VM type. The first commit of this refactoring changes no bytecode.
2. **Inline `val`-bound `_prim` aliases** (item 2 of
   [performance.md](performance.md)). Without it every overloaded operation
   at a registered type costs a global, a tuple, a call and two selects.
3. **Demand-driven loading.** `lib/basis/MANIFEST` becomes
   `file | always/demand | host yes/swap/no | provides | requires`, in load
   order. The driver scans the tokens of the program for the names in the
   provides column and loads the requires-closure: it can load too much,
   never too little, and the order is fixed. The always-loaded part stays
   under about 400 lines; `print` goes through a hook that `TextIO` replaces.
   Flags: `--basis all`, `--basis-deps`, `--basis-check`. Eager loading of the
   full library would cost about 15 s per compile on `bin/rune`; a
   demand-loaded hello should drop from 0.75 s to about 0.3 s.
4. **Runtime support.** `exn_name`; an object kind for mutable bytes
   (identity equality; GC-critical); block primitives `array_blit`,
   `array_to_vector`, `vector_concat`; an exit hook for `atExit` and stream
   flushing; `runevm --count` and `--gc-stress`; a map instead of the linear
   search in `Prims.find`.

### VM primitives (109 to about 285)

Pure primitives stay in `vm/prims.c` and a new `vm/prims_real.c`; about 135
system primitives go to `vm/sys_posix.c`. `sys_init : exn -> unit` registers
the `SysErr` constructor as a GC root so that C can raise
`SysErr (strerror, SOME errno)`; one `posix_const : string -> int` supplies
the numeric constants. GC discipline is unchanged (arguments stay on the VM
stack until the result exists) and is verified with `make vm-asan` and
`--gc-stress` over the whole suite.

### Test suite (`tests/basis`)

Self-checking portable programs; `tests/basis/README.md` has the conventions.
The layers: signature conformance against an independent transcription of
every signature of the specification (`spec-sigs/`), a check for every
specified member (`scripts/check-basis-coverage.sh`) and for every "raises"
clause, property tests (`IntInf` against `Int`, `scan ∘ fmt`, slices against a
list model, `Pack` inverses, `OS.Path` laws, a functional model of
`StreamIO`), and system tests in scratch directories, on the loopback
interface and with port 0 only. `tests/basis/deviations.txt` lists every known
failure with its category; an unlisted failure fails the run, and so does a
line that no longer matches one.

### Cross-checks

* **XC2, `native:HOST`:** the suite against the host's own library. It
  checks the tests: an expectation that three independent implementations
  reject is probably a misreading of the specification.
* **XC1, `xc1:HOST`:** the suite against Rune's library compiled by the host.
  `tests/basis/host/gen-host-basis.sh` turns `_prim "x"` into `RunePrim.x` and
  generates `signature RUNE_PRIM` from `vm/prims.def`;
  `tests/basis/host/rune-prim.sml` implements it on the host's library. So the
  host type-checks every `_prim` annotation, which Rune takes on trust, and
  runs Rune's library code without Rune's compiler or VM. Thin system-call
  wrappers and literal overloading are N/A there, never a pass.

Hosts: the installed MLton 20210117, SML/NJ 110.79 and Poly/ML 5.7.1, and the
current releases that `make hosts` builds under `~/.local/rune-hosts`.
`make matrix-quick` runs the installed ones, `make matrix` both generations.
Neither is part of `make check`.

### Performance suite (`tests/perf`)

Deterministic budgets on `runevm --count` values (`make perf-check`, part of
`make check`, including the bootstrap and the hello compile), scaling checks
that run at n and 4n, and a wall-clock table against the hosts (`make perf`).

## Milestones (each leaves `make check` green)

| | Content |
|---|---|
| M0 | `make doctor`; harness, specification signatures and portable tests for the 19 existing structures; deviations file; matrix runner for `rune`, `native` and `xc1`; `fetch-hosts.sh`; this document and the compatibility document. Surfaces discrepancies before any library code changes. |
| M1 | In order, each its own commit: `Prims` map, `--count`, `--gc-stress`; inlined `_prim` aliases; the overload registry (bytecode-identical); literals, `_overload`, `_primtype`, `IntInf` registration, `word_neg`; MANIFEST v2 and the loader; the pervasive split; `exn_name`, exit hook, byte objects; `perf-check`. |
| M2 | `StringCvt`, `Substring`, `fmt`/`scan` everywhere, `IntN`/`WordN`, aliases, `IntInf` and `Real` completion, `IEEEReal`. |
| M3 | Slices, the monomorphic families, `Array2`, `Byte`, `Pack*`, `Text`. |
| M4 | `IO`, `PrimIO`/`StreamIO`/`ImperativeIO`, `BinIO`/`TextIO` on file descriptor primitives, swapped in one step. |
| M5 | `Time`, `Date`, `Timer`, `OS.FileSys`/`Path`/`Process`/`IO`. |
| M6 | `Posix`, `Unix`, `sys_none.c`. |
| M7 | Sockets and the network databases. |
| M8 | Current-release matrix, wall-clock table, final compatibility document. |

Success metric besides the suite: `tests/external/mlton-skip.txt` shrinks from
142 entries to about 60, all of them MLton-specific.

## Risks

1. Bootstrap or determinism breakage from the overload and loader changes:
   land them as bytecode-neutral refactorings first; load order is MANIFEST
   order; `--basis all` and every suite program are in `make check-cross`.
2. Compile time and bytecode growth from functor duplication: one file per
   functor instance, a small always-loaded set, instruction budgets.
3. XC1 on narrow hosts: host-provided `option`, `order` and exceptions,
   automatic N/A for what a host cannot load, a 64-bit MLton configuration.
4. A wrong oracle or an ambiguous specification: three hosts adjudicate, the
   `SPEC-AMBIGUOUS` category records the reading taken, stale lines fail.
5. GC bugs and flaky system tests across about 135 C primitives: shared
   helpers, ASan, `--gc-stress`, scratch directories, loopback and port 0.

## Verification

* `make doctor`: all scopes are ok; hiding a tool from `PATH` reports it as
  MISSING with an install line and exit status 1.
* Per milestone: `make check`; `make vm-asan && sh tests/run-tests.sh --vm
  bin/runevm-asan`; the suite under `runevm --gc-stress`; `make bootstrap`.
* For the refactoring commits of M1: `cmp` of every `tests/out/*.rbc` before
  and after.
* `make matrix-quick`, then `make hosts && make matrix`: every cell is a pass,
  an explained failure or N/A.
* `sh tests/external/run-mlton.sh <mlton>/regression`: no regressions.
