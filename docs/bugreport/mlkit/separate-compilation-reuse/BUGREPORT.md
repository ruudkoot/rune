# MLKit 4.7.23: "Impossible: LambdaStatSem.eqType" on a program it compiles alone

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a
specification bears on.** The compiler stops on an internal assertion
(`Impossible`) for a well-typed program, which it compiles and runs when the
same files are built in another order or another place; MLton, SML/NJ and
Poly/ML compile it every time.

## Status: not reported upstream, not reduced

**Not seen on the tree of 2026-10-13**, with MLKit 4.7.23 or 4.7.25:
`tests/lib/run-hosts.sh mlkit`, from a tree without `MLB` directories,
builds `unicode.utf8` and `terminal.emulator` after the programs before
them, and both pass. The libraries and the runner's order have changed
since; whether the bug is still in MLKit is not known. The two lines of
`tests/lib/deviations.txt` are gone (2026-10-14).

This has not been sent to MLKit, and the program has not been reduced to a
few lines: every smaller program tried compiled (below).

## What happens

`tests/lib/run-hosts.sh mlkit` builds, in one directory and in this order,
the programs of `lib/random` (`random.kat`, `random.props`), of
`lib/test/property` (`property.core`, `property.shrink`), and then
`unicode.utf8`: `$(SML_LIB)/basis/basis.mlb`, `lib/random`'s two files, the
eight files of `lib/unicode` and `tests/lib/unicode/utf8.sml`, each listed by
its absolute path in an `.mlb` file, built with `mlkit -o NAME NAME.mlb`.
From a clean tree (no `MLB` directory anywhere) the last of them stops with

```
Error in lambda type checking (LET):
The type

string

is not compatible with type

bool

Impossible: LambdaStatSem.eqType

let val s = encode c
in  (case
      eq_option
      <(fn <v304> => ...), decode <s,0>, SOME (c,PRIM(ccall __bytetable_size, [s]))>
...
```

at `Utf8Test.roundTrip` of `tests/lib/unicode/utf8.sml`, every time (two
runs in a row from clean, 2026-10-10).

## What does not

* The same `.mlb` file built by hand, after the failed run, in the same
  directory: it compiles and the program prints `PASS`.
* Any one of the earlier programs built first, then `unicode.utf8`: it
  fails (each of the four tried).
* The same files copied into one directory and listed by relative paths,
  with `lib/random`'s test program built first: it compiles and passes.
* The round trip alone, in a program of its own: it compiles and passes.

So the fault needs the earlier build of `lib/random`'s files in the tree
(their `MLB` directory) and the files of `lib/unicode` by absolute path; a
reuse of a unit compiled for another basis is the likely cause.

## Environment

* **MLKit:** v4.7.23, the official binary release (`make hosts`).
* **System:** Linux x86-64 under WSL2, Ubuntu 24.04.
* **Basis Library:** MLKit's own; nothing of Rune is involved.

## To reproduce

At the commit that adds this report, from the top of the tree:

```
rm -rf tests/out/lib-hosts
find lib tests/lib -type d -name MLB -prune -exec rm -rf {} +
sh tests/lib/run-hosts.sh mlkit
```

The line `FAIL mlkit unicode.utf8` is the fault; `tests/lib/deviations.txt`
explains it as a `HOST-BUG`.

## A second program

`terminal.emulator` (`lib/unicode`, `lib/terminal` and
`tests/lib/terminal/emulator.sml`), built by the runner after the
programs before it, stops with another internal assertion,

```
Impossible: LambdaStatSem.APP.argument type not arrow - type list is Types({})
```

and the same files copied to a fresh directory and built there compile
and pass (`tests/lib/deviations.txt`, `native:mlkit | terminal.emulator`).
