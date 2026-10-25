# Linting the compiler's representations

Claude, 2026-10-25, during the functors-units roadmap. The owner asked for
every test's compiles to be linted, which was done then (`RUNE_LINT`,
below), and for the rest of what was found to be written down for later.

## What each representation is checked for

| Representation | Types | Checked by |
|---|---|---|
| The syntax (`Ast`) | none: the source as parsed | the elaborator, always: the type checker of the Definition, whose errors are the program's. The elaborated program is not checked again by anything independent of it. |
| `Lambda` | every node, `Ty.ty`, with `Inst` at each use of a polymorphic variable | `LambdaLint`: scope, a stamp bound once, where `Fail` and `Jump` stand, a letrec of functions, and the types, worked out from the parts |
| `Mid` | in the manner of System F: every binder says its type and the variables it abstracts over | `MidLint` after every pass of Mid: scope, a stamp bound once, jumps to join points in scope, the types checked against what each context wants (nothing inferred), calls of workers, and casts under `--functors=functions` |
| `Low` | none, but a representation for each variable: int, word, real, char, a nullary constructor, a pointer, unit, anything | `LowLint`: SSA, blocks and their jumps, handlers, calls, closures, and that representations agree |
| The instruction lists, stack and register | none | nothing ([ir.md](../../ir.md): "none yet") |
| A `.rbc` or an image | -- | the VM's loader, always (`validate_program`): opcodes, operands' ranges, jump targets and function entries on instruction boundaries, the stack's depth. That is for memory safety, since a `.rbc` is untrusted input, not for types. `runevm --checked`, which the runs of `tests/lang` use, also tests a constructor's tag where `DECON` and `FIELD` take it apart. |

`--lint` (`Pass.stage`) runs the lint of each representation on what every
pass makes and stops at the first breach with `Error.Bug`, naming the
pass; it also makes the elaborator hold each functor application's copy to
the functor's summary (`Elaborate.lintSummaries`). A breach is a bug of the
compiler, never of the program.

## Where it runs

Before 2026-10-25, with `--lint`: the bootstrap (`bin/rune.rbc`, with
`--mid-roundtrip`), `make check-levels` (every program of `tests/lang` and
`tests/perf` at `-O0` and `-O2`), `make test-ir`, the benchmarks'
measurement builds, and the functors-units roadmap's runs (MLton's 606
files, the corpora, the generator of functor programs).

Since then, every compile a test makes: `bin/rune-test` sets `RUNE_LINT=1`
unless it is set, and `Pass.linting ()` reads it, in the driver, the REPL
and the compiler library alike ([testing.md](../../testing.md), *Running the
tests*). The budgets clear it, since they count the compiler as shipped.
Turning it on found, in programs that compiled and ran right without it:
* the REPL's units linted without the schemes of the globals of the units
  before them, which only the batch driver set: every transcript stopped
  with "global g... is not defined". The schemes are now set where any
  session of units begins (`UnitBasis.startSession`);
* a datatype's global that Lower's `results` shares between constructors
  -- an int of one, a string of another -- given the representation of
  the first binding Lower met, which the register code hands the JIT:
  `lib/terminal`'s programs, `examples/readline` on every host compiler
  (the generator of functor programs found it first). Such a variable
  holds anything now;
* a `_dynamic` structure's slots, set in a function that the declaration
  hands RuneDynamic.load, missing from the globals Mid's `Do` lists: every
  scenario of dynamic modules. ToMid walks the whole declaration now.

The IntInf hardening fixtures call primitives at the wrong types on
purpose, for the runtime to refuse them; their compiles clear `RUNE_LINT`.

It is not on for a user's compile, for its cost (below), and because what
it finds is never the user's.

## What it costs

Measured on 2026-10-25, processor time of `bin/rune` on `runevm`, twice
each:

| Compile | Without | With `--lint` |
|---|---:|---:|
| HaMLet, 23k lines (`examples/benchmarks/hamlet` with `shared/input.sml`) | 3.0-3.2 s | 5.6 s (the checks 1.7-2.0 s) |
| a small program of `tests/lang` | 0.34 s | 0.45 s |

`midcanon`'s lint about doubled that stage's time on HaMLet.

## What it found, and what it cannot

In the functors-units roadmap the lint alone found four bugs of the
prototype of functors compiled once: a hidden datatype of a recursive
group copied twice (`fxp`), an open constructor bound to a polymorphic
variable (MLton's `ssa2-to-rssa.fun`), and the two first failures of the
generator ([build-cache-issues.md](../build-cache-issues.md), *Found on the
way*). Each printed the right answer: the copies' layouts happened to
agree, or the program was not run.

It checks shape and types, not meaning. The independent review's two
worst findings passed it: a program's own `if n = 0` folded as though it
were a descriptor's test is well typed, and so is a constructor built
boxed in one function and taken apart flat in another. What finds those is
comparison: `-O0` against `-O2` (`check-levels`), the flag on against off,
the hosts' builds against each other (`check-cross`), whole against units
(S42), and generated programs run every way.

## Ways to go further

* **A lint of the instruction lists.** Nothing checks what `stack` and
  `registers` make. A checker of the register code's representations --
  each register's, from Low's, through moves, calls and the frame -- would
  catch a code generator's mistake before the VM runs it; the loader's
  validation only keeps it from reading outside the program.
* **Type variables in scope in Mid.** `MidLint` takes a type variable that
  nothing abstracts over for a type of its own, equal only to itself, and
  does not check that one is in scope. A substitution that leaves one free
  (the expansion's kind of bug) goes through.
* **Casts.** `MidLint`'s rule for `unsafe_cast` checks only a variable bound
  directly to a cast to `unit` and cast back to another ground type: it
  refuses a valid cast through `unit`, says nothing of a cast between two
  types neither of which is `unit`, and skips type variables (the review's
  sixth finding). A rule that tracks what each cast came from would close
  it.
* **Representations across functions.** `LowLint` holds a constructor's
  fields to the representation where it is made in the same function; a
  constructor made in one function and taken apart in another is held only
  by Mid's types, which say nothing of layout. Checking each constructor's
  layout against its datatype's (`Rep`) at every `Con` and `Field` would
  have caught the review's second finding.
* **The elaborated program checked again (`AstLint`).** The elaborator is
  checked only through what it hands on: `Lambda`'s types come from it, so
  a mistake that makes ill-typed code shows in `LambdaLint`, and one that
  types a program the Definition rejects shows nowhere. *The elaborated
  syntax* below says what a checker of it has to work with.
* **A cheaper lint, to run more often.** Lint only what the pipeline ends
  with (Mid before `lower`, and Low), which catches most bugs at a fraction
  of the cost, as a level between none and all; or memoise `midcanon`'s
  check. Then a user's build could afford it in a debug configuration.
* **Lint at the boundary of units.** A unit's Mid is checked against the
  schemes of the globals it imports as the session has them. Checking them
  against what the exporting unit's basis says, when an entry is taken from
  the cache, would catch an entry linked against a unit that changed
  under it -- the kind of hole build-cache-issues.md's 21 to 23 were.

## The elaborated syntax

What an `AstLint` would check, as found on 2026-10-25.

**The elaborator works on the syntax as parsed.** `Elaborate.elabTop` takes
`Ast.dec list`, and infers by unification (`Types.ty`, whose variables are
refs, with levels for generalisation). The core language's derived forms
stay nodes of their own -- `if`, `andalso`, `orelse`, `case`, `while`, a
`fun`'s clauses, lists, sequences -- and every node has its span, so an
error names the form the program wrote ("branches of if: type mismatch
between int and string"). The parser rewrites some of the module
language's derived forms (`structure S : SIG = e`, `functor F (spec)`,
`funid (strdec)`, `type` in a signature, `include`).

**It annotates the syntax in part.** Mutable slots, filled as it goes, and
read once `Elaborate.finish` has settled overloading and defaults:
* a variable's or a constructor's use: what it is and the instance of its
  scheme at this use (`varinfo`);
* the type of an integer or word constant, a list, a `fn`, a `#lab` and a
  `_prim`; a pattern's constant and record;
* a pattern variable's or constructor's identity (`patinfo`), and an
  exception binding's;
* a functor application's elaborated copy (`StrApp`).

Beside them, tables by stamp: every variable's scheme (`Ty.binders`), every
exception's argument, every datatype's constructors and every opaque
type's realisation. `CompilerFacts` reads the slots for the IDE's types at
a position, which is why `typeAt` answers for a variable, a constant or a
record and not for an application or a `case`.

**What a checker would lack.** No type is kept for most nodes: an
application, a tuple, a record expression, `if`, `case`, `let`, `handle`,
`raise`, a sequence; nor a constructor's instance in a pattern, a list
pattern's element type, or the type a `: ty` annotation elaborated to.
Nothing of the module language is kept on the syntax but the copies: no
structure's environment, no signature's, no realisation or thinning of a
match. So:
* **for the core language** a checker is within reach. Working as
  `MidLint` does -- each node checked against the type its context wants,
  each leaf's type from its slot or its binder's scheme -- it needs nothing
  more for most nodes; a constructor in a pattern is found by matching its
  declared type one way against the wanted type, not by unifying. It must
  also check what the elaborator decided: that each binder's scheme
  generalises its body's type and no more (the value restriction, and
  explicit type variables' scopes, Section 4.6), that `=` is used at types
  that admit equality, and that overloading was resolved as the defaults
  say. A `: ty` annotation needs the type environment at that point,
  which only the elaborator has: it would have to be kept (a slot), or the
  checker would elaborate types itself;
* **for the module language** a checker would re-do signature matching,
  unless the elaborator kept each structure expression's environment and
  each match's realisation, which it could then check against the
  signature, as the core's leaves are checked against schemes.

To be independent it must not share the elaborator's unification
(`Unify`) or matching (`SigMatch`), only the types and the tables:
`LambdaLint` finds the translation's bugs because it checks where the
translation inferred.

**For error messages.** The same annotations serve them: a type on every
node gives the IDE a type at every position and an error the types of the
parts it names. Better messages need more than that -- where a type came
from (the constraint that fixed it), the errors as data rather than
strings (`errror-messages.md`), and recovery that binds what failed to an
error type: today a declaration that fails leaves its names unbound, so
`fun f (x, y) = if x then y + 1 else "no"  val z = f (true, 2)` reports
the mismatch, then "unbound variable or constructor: f" at its use.
runespec's reference type checker ([specification.md](../specification.md)),
generated from the Definition, would be another such checker, of the core
and the modules alike.
