# Basis Library suite

Self-checking tests of the [SML Basis Library](https://smlfamily.github.io/Basis/),
written in portable Standard ML '97 so that the same files run

* on Rune (`make test-basis`, part of `make check`),
* against the Basis Library of MLton, SML/NJ and Poly/ML ("native"
  configurations), which checks the *tests*: an expectation that three
  independent implementations reject is probably a misreading of the
  specification, and
* against Rune's Basis Library compiled by those systems ("xc1"
  configurations), which checks that Rune's implementation does not depend on
  accidents of Rune.

An `xc1` test used to compile the whole of lib/basis before its own code,
which was most of what a run cost. Three things now keep that down, and a
filtered run of four tests went from 1 m 18 s to 5 s on SML/NJ, 1 m 40 s to
5 s on its 32-bit build, 16 s to 4 s on Poly/ML and 51 s to 10 s on MLton:

* SML/NJ (`exportML`) and Poly/ML (`PolyML.SaveState`) save an image with the
  library in it once the probe has found which of its files load, and each
  test starts from that image with only its own sources.
* MLton compiles whole programs and has no session, so it is given only the
  part of the library the test loads, which `rune --basis-deps` works out: a
  test of `List` compiles 49 files of the 241 rather than all of them. A
  program that then fails to compile is tried once more with the library
  whole, so a wrong subset costs time and never a wrong result.
* A test that does not load whole is cut down by halving its sections, and
  each try compiles the library again. What the halving finds depends only on
  the library, the tools and the test, so it is kept in
  `tests/out/matrix/CONFIG/TEST.sections` against a checksum of those and
  looked for again only when one of them changes: `word8` on Poly/ML went
  from 1 m 37 s to 16 s. `--refresh` looks again and rewrites them.

`RUNE_MATRIX_NO_IMAGE=1` and `RUNE_MATRIX_NO_SUBSET=1` turn the first two
off, which is how the numbers above were measured.

The hosts are the releases `make hosts` installs (scripts/fetch-hosts.sh):
MLton, SML/NJ built for 64 and for 32 bits (its 31-bit `int` and `word` have
found many portability bugs), and Poly/ML, never the machine's own.
`make matrix` runs every configuration, `make matrix-quick` Rune and the
`xc1` ones, and `sh tests/basis/run-matrix.sh --configs all [FILTER]` runs
the tests whose names contain FILTER; the script's header describes the
configurations, the report, the timing statistics it ends with and the exit
status.
Differences between implementations are recorded in `deviations.txt` and
described in [docs/basis-compat.md](../../docs/basis-compat.md).

## Files

| File | Contents |
|---|---|
| `harness.sml` | structure `T`: checks, value printers, exception predicates, a portable pseudo-random generator |
| `finish.sml` | prints the `SUMMARY` line and sets the exit status |
| `<name>.sml` | behaviour of one structure; `<name>` is the id of its row in `docs/language.md` without the `basis.` prefix (`int`, `os.path`); more files for the same row are called `<name>_<what>.sml` |
| `<name>_sig.sml` | the structure matches the signature of the specification |
| `spec-sigs/<SIG>.sml` | `signature SPEC_<SIG>`: the signature transcribed from the specification page, independently of `lib/basis` |
| `fn/<name>.sml` | helpers and test functors shared by tests, named in their `uses:` headers |
| `host/` | what the `xc1` configurations need: `gen-host-basis.sh` and `rune-prim.sml`, the VM's primitives on a host's library |
| `deviations.txt` | every known failure, with its category and reason |
| `run-examples.sh` | tries the examples of the library's documentation that are equations (`docs/doc-comments.md`): `runedoc --examples` writes a program for each signature into `tests/out/basis-examples`, and each is compiled and run with Rune. `make test-basis` runs it after the suite |
| `annotations.txt` | what `deviations.txt` says about the hosts, in the format the documentation generator reads (`runedoc --annotations`); made by `gen-annotations.sh`, committed, and checked by `make check-docs`. After a change to a host line of `deviations.txt`: `sh tests/basis/gen-annotations.sh`, then `make docs` |

## Writing a test

Every program runs in the same time zone, whatever the machine's:
`run-matrix.sh` (and `tests/run-tests.sh`) set `TZ` to a POSIX rule, 3:30
west of UTC with summer time, which the C library reads without a time zone
database. A check of local time may rely on that zone being different from
UTC, but not on any other property of it.

```sml
(* requires: Int StringCvt *)
(* uses: spec-sigs/INTEGER.sml *)
structure TestInt =
struct
  val eqI = T.eq T.int
  val () = eqI ("Int.+/basic", 5, fn () => Int.+ (2, 3))
  val () = T.raises ("Int.div/Div", T.isDiv, fn () => 1 div 0)
  (*<< fmt *)
  val () = T.eq T.string ("Int.fmt/hex", "ff", fn () => Int.fmt StringCvt.HEX 255)
  (*>> fmt *)
end
```

* One structure `Test<Name>` per file; everything the test computes happens
  inside the thunk of a check, so that an exception is a failed check and not
  a crash of the program.
* Labels are `Structure.member/case`, without spaces and unique in the file.
  Every `val` and `exception` of the signature has at least one check whose
  label starts with `Structure.member/`. `runedoc` reads the labels out of
  the sources of this suite with the compiler's parser, lists the checks of
  every member in the library's documentation (`docs/generated/basis`), and
  fails `make docs` and `make check-docs` for a member of a structure that
  has none. That makes the form of a label a convention to keep
  (`bin/runedoc --tests tests/basis --labels` prints what it finds):
  * the first literal of a label has the structure, the member and the
    slash; what follows may be computed (`"List.rev/involution-" ^ n`);
  * a helper or a table that makes several checks of one member is given the
    beginning of their labels, `"Structure.member/"`, as the first component
    of its argument or of each row (`named ("Posix.Error.acces/", "acces",
    E.acces)`, `table (lab "+/", ...)`);
  * a check that a structure matches a signature is labelled
    `Structure:SIG/case`, a check of a functor of the library `Functor/case`;
  * checks that hold for every structure of a signature (`Int`, `IntInf`,
    `Int32`, ...) go in a functor in `fn/`, which takes the structure and its
    `name`, a string literal at the application, and builds its labels with
    `lab "member/case"`.

  A structure that the specification defines as another one (`LargeInt` is
  `IntInf`) is checked under either name, and gets `(* alias: LargeInt =
  IntInf *)` in its `_sig.sml` test, beside checks that its types are those
  of the other.
* Expected values come from the text of the specification, worked out by
  hand, never from the output of an implementation. Cover the ordinary case,
  the boundary cases, every "raises" clause, the documented order of
  evaluation, and algebraic laws on pseudo-random inputs (`T.seed`, `T.range`).
* `(* requires: ... *)` names the structures the file cannot do without; a
  configuration that lacks one reports the test as ABSENT.
* Members that an implementation may lack go in a section
  (`(*<< name *)` ... `(*>> name *)`, each marker on its own line, not nested,
  independent of other sections). A section that does not load in a
  configuration is left out and reported as the failed check
  `@section/<test>/<name>`.
* Nothing may depend on the precision of `int` or `word`: the hosts have
  31, 32, 63 and 64 bit integers. Derive such values from `Int.precision`,
  `Int.maxInt`, `Word.wordSize`.
* Tests that touch the file system run in a scratch directory that is their
  current directory; they use relative file names only, sockets only on the
  loopback interface or Unix domain, and never a fixed port.
* The test must compile without warnings on Rune.

## Deviations

```
config-glob | label-glob | CATEGORY | reason
native:smlnj@110.99.9 | Real.fmt/* | HOST-BUG | prints ~0.0 as 0.0
```

Categories: `RUNE-DEV` (Rune departs from the specification, or does not
implement the member yet), `HOST-BUG` (the host departs from it), `HOST-ABSENT`
(the host lacks the member), `HOST-FLAKY` (the host fails the check only
sometimes), `SPEC-AMBIGUOUS` (the specification allows both behaviours; the
reason states the reading the test takes), `WIDTH` (follows from the
precision of a type), `XC1-NA` (not meaningful for Rune's library on a host).
A line that stops matching a failure is an error, so fixed deviations must be
removed; a `HOST-FLAKY` line is exempt. Besides checks, a label can be `@section/TEST/NAME`
(a section that does not load), `@load/TEST` (a test that does not load or
runs out of time) or, for `rune` only, `@absent/TEST` (a test that needs a
structure Rune lacks). A `RUNE-DEV` or `SPEC-AMBIGUOUS` line for `rune` holds
for the `xc1` configurations too, which run the same library source.
