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

`sh tests/basis/run-matrix.sh --configs installed [FILTER]` runs a matrix;
the script's header describes configurations, the report and the exit status.
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

## Writing a test

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
  Every `val`, `exception` and constructor of the signature has at least one
  check whose label starts with `Structure.member/`
  (`scripts/check-basis-coverage.sh`). Checks that hold for every
  structure of a signature (`Int`, `IntInf`, `Int32`, ...) go in a functor in
  `fn/`, which takes the structure and its `name` and builds its labels with
  `lab "member/case"`. A structure that the specification defines as another
  one (`LargeInt` is `IntInf`) gets `(* alias: LargeInt = IntInf *)` in its
  `_sig.sml` test, beside checks that its types are those of the other.
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
native:smlnj@110.79 | Real.fmt/* | HOST-BUG | prints ~0.0 as 0.0
```

Categories: `RUNE-DEV` (Rune departs from the specification, or does not
implement the member yet), `HOST-BUG` (the host departs from it), `HOST-ABSENT`
(the host lacks the member), `SPEC-AMBIGUOUS` (the specification allows both
behaviours; the reason states the reading the test takes), `WIDTH` (follows
from the precision of a type), `XC1-NA` (not meaningful for Rune's library on
a host). A line that stops matching a failure is an error, so fixed
deviations must be removed. Besides checks, a label can be `@section/TEST/NAME`
(a section that does not load), `@load/TEST` (a test that does not load or
runs out of time) or, for `rune` only, `@absent/TEST` (a test that needs a
structure Rune lacks). A `RUNE-DEV` or `SPEC-AMBIGUOUS` line for `rune` holds
for the `xc1` configurations too, which run the same library source.
