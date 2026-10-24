# Extensions of Standard ML '97

What other implementations accept beyond *The Definition of Standard ML
(Revised)* and the Basis Library, where Rune meets it, and what Rune does.
Rune compiles Standard ML '97 alone unless an option says otherwise
([../language.md](../language.md), *Deviations from the Definition*). The
systems were tried on 2026-10-10 on one machine: Poly/ML 5.9.2, SML/NJ
110.99.9 and 2026.2, MLton 20241230, MLKit 4.7.23 and Moscow ML 2.10.1, as
`make hosts` installs them.

## Poly/ML: `+`, `-` and the comparisons on `Time.time`

Poly/ML overloads the top-level `+`, `-`, `<`, `>`, `<=` and `>=` at
`Time.time`, so that

    val t = Time.fromSeconds 1 + Time.fromSeconds 2
    val b = Time.fromSeconds 1 < Time.fromSeconds 2

compiles and `t` is 3 seconds. Its `basis/Time.sml` adds them one by one
(`RunCall.addOverload Time.+ "+"`, and so on), and says why: "This is
actually non-standard. The basis library documentation does not include
Time.time among the types for which these operators are overloaded." `*`
is not among them: `Time.fromSeconds 1 * Time.fromSeconds 2` is a type
error there too.

**What the Definition says** (Appendix E). "Programmers cannot define their
own overloaded constants or operators." The overloaded identifiers are
the list of Figure 27, each over a class: `+`, `-` and `*` over `Num`,
`div` and `mod` over `WordInt`, `/` over `Real`, `abs` and `~` over
`RealInt`, the comparisons over `NumTxt`. The classes are made of five
basic ones, `Int ⊇ {int}`, `Real ⊇ {real}`, `Word ⊇ {word}`,
`String ⊇ {string}` and `Char ⊇ {char}`, and "libraries may extend each of
the basic overloading classes with further type names". A library can
therefore give a type all of a class or nothing: `Time.time` in `Int` would
have `*`, `div`, `mod`, `abs` and `~` as well, and, since "special constants
are overloaded within each of the basic overloading classes", `5` would be
a time. Overloading `+` alone, as Poly/ML does, is outside the scheme.

**What the Basis Library says.** Its top-level environment lists the types
of each class: `int` is `FixedInt`, `Int`, `IntN`, `IntInf`, `LargeInt` and
`Position`; `word` is `LargeWord`, `Word`, `Word8`, `WordN` and `SysWord`;
`real` is `LargeReal`, `Real` and `RealN`; `text` is `String`, `Char`,
`WideString` and `WideChar`. `Time.time` is in none. The `TIME` signature
declares `+`, `-`, `<`, `<=`, `>` and `>=` on `time` as values of the
structure, used as `Time.+` or after `open Time`, which rebinds them
(Appendix E.2: then they are not overloaded where the binding is in scope).

**What the others do.** All refuse the two lines above:

| | |
|---|---|
| SML/NJ 110.99.9 and 2026.2 | `overloaded variable not defined at type`, symbol `+`, type `Time.time` |
| MLton 20241230 | `Variable not overloaded at type: +.` |
| MLKit 4.7.23 | `Type clash`, operator `int * int -> int` |
| Moscow ML 2.10.1 | `Overloaded + cannot be applied to argument(s) of type time` |
| Rune | `overloaded operator not defined at type time` |

**Where Rune meets it.** HOL4's REPL, `tools-poly/holrepl.ML`, adds times
with `+`. Its copy for Rune, `tools-rune/holrepl.ML` on the local HOL4
branch `trindemossen-2-rune`, uses `Time.+` instead (`docs/plans/hol4.md`
on the `incremental` branch).

**Rune.** Refuses it, as the Definition and the Basis Library do. Its own
`_overload kind Strid` (the basis library's, behind `--allow-prim`) makes a
type an overloading type of a kind, constants included, as Appendix E's
classes do, so it cannot say what Poly/ML says either; a Poly/ML mode would
need overloads of single identifiers.

## SML/NJ: or-patterns

An or-pattern `(p1 | ... | pn)` matches what one of its alternatives
matches; every alternative binds the same variables. SML/NJ has them, and
so does Successor ML:

    datatype t = A of int | B of int | C
    fun f (A n | B n) = n
      | f C = 0

**What the Definition says.** Nothing: they are not in its grammar
(Appendix B), so Standard ML '97 has no or-patterns.

**What the others do.**

| | |
|---|---|
| SML/NJ 110.99.9 and 2026.2 | accepted, with no option |
| MLton 20241230 | refused unless annotated: `Or patterns disallowed, compile with -default-ann 'allowOrPats true'` (or `allowOrPats true` in an MLB file) |
| Poly/ML 5.9.2 | `End of pattern expected but \| was found` |
| MLKit 4.7.23 | `syntax error found at BAR` |
| Moscow ML 2.10.1 | `Syntax error.` |

**Where Rune meets it.** SML/NJ's own Basis Library uses a few, which the
xc2 configurations compile with Rune.

**Rune.** Accepts them with `--or-patterns` and refuses them without it,
naming the option (`8e873ddd`, 2026-09-28, on `master`; not yet on the
`incremental` branch). An or-pattern is in parentheses and may be nested
anywhere a pattern is; its alternatives are tried in order, have one type
and bind the same variables at the same types; a match with one is compiled
as a decision tree whose alternatives jump to the rule's body, which is not
copied ([../language.md](../language.md), `pat.or`; `tests/lang/pat.or_*`,
`tests/errors/err.orpat_*`).

## MLton: functor applications typed by the body

MLton elaborates a functor's body again at each application, with the
actual argument, and types the application by what that gives, not by the
functor's signature. So it accepts

    functor F (type t) = struct datatype d = D of t end
    structure S = F (type t = int)
    val b = S.D 1 = S.D 1

since `S.d`, a `D of int`, admits equality in the body elaborated with
`t = int`; and a body's value is as polymorphic as the argument makes it,
where a type of the argument drops a parameter (`type 'a t = int`).

**What the Definition says** (rules 54 and 86 to 89). A functor's body is
elaborated once, against the parameter's signature, each of whose type
names "acts like a constant in the functor body" (rule 86); that gives the
functor's signature `(T)(E, (T')E')`. An application instantiates it so
that the argument enriches the parameter's instance, and renames apart the
names the body made (rule 54); it never looks at the body again. Above,
`d` is made from `t`, a type of the parameter without equality, so `d` does
not admit equality in the signature, and `S.d` does not either, whatever
`t` the argument has. A functor whose result keeps a type variable that the
value restriction leaves free (`val r = ref []` in the body) puts that
variable in the basis, which rule 89 forbids; its commentary (Appendix G)
lets an implementation refuse the declaration or give the variable an
arbitrary monotype. Unlike the context of a flexible record, which Section
4.11 leaves to the implementation (*Rune: flexible records* below), the
typing of an application is fixed.

**What the others do** (E1 of [functors-units.md](functors-units.md),
2026-10-21; HaMLet 2.0.1, SML/NJ 110.99.9, Poly/ML 5.9.2, Moscow ML 2.10.1
with `-P full`, MLKit 4.7.25, MLton 20241230):

| program | Definition | HaMLet | SML/NJ | Poly/ML | Moscow ML | MLKit | MLton |
|---|---|---|---|---|---|---|---|
| the equality of `S.d` above | refused | refused | refused | refused | refused | refused | accepted |
| a value more polymorphic than the signature says (`tests/errors/err.functor_signature_types`) | refused | refused | refused | refused | refused | refused | accepted |
| a body's `val r = ref []`, its functor declared alone | either | refused | accepted, warning | accepted, warning | accepted | refused | accepted, warning |
| that `r` used at two types, after two applications | refused | refused | refused | refused | refused | refused | accepted, warning |
| `eqtype 'a t` realised by `'a ref`, the equality of `'a` lost | refused | refused | refused | refused | accepted | refused | accepted |
| an overloaded `+` of the body settled at `real` by its client | refused | refused | refused | accepted | accepted | refused | refused |

MLton's warning is "Type of variable was not inferred and could not be
generalized: r", with the type `??? list ref`. Poly/ML and Moscow ML settle
an overloaded operator of a body where the client's top-level declaration
ends, as MLton does not.

**Where Rune meets it.** Nowhere it was measured: performance M3, which
typed every application by the signature, compiled MLton's own sources,
HOL4, the xc2 configurations and every suite; E2 of
[functors-units.md](functors-units.md) found no functor whose result keeps
a free type variable in MLton's sources, the 510 benchmarks, the Basis,
the other libraries or Rune's own sources, nor a copy of a body whose
overloading its client settled otherwise than as the default.

**Rune.** Types every application by the functor's signature, as the
Definition does, since performance M3 (`a6d3f8108`, pull request #65,
2026-10-20; [functors.md](functors.md)); a functor whose result keeps a
type variable that its body leaves free is refused at its declaration, as
HaMLet and MLKit do (functors-units M3). A compile still elaborates a copy
of the body for each application whose code it makes, and in three corners
that copy decides what the signature should -- an overloaded constant or
operator of the body that its client settles, the equality of a type
variable lost through `'a ref`, and `--default-type` in a library's
functor -- until functors are compiled once (functors-units M7);
`--typecheck-only` and the language server follow the Definition there
already ([../language.md](../language.md), the deviation *Functors*). There
is no option for MLton's typing (functors-units D7, the owner's decision of
2026-10-21): its leniency is the copy's typing, and a body elaborated once
has no argument to type against, only its signature; of what MLton
accepts, only an equality that depends on the argument could be put into a
signature, and nothing measured relies on any of it.

## Rune: flexible records, by an option

A flexible record pattern (`{a, ...}`) or selector (`#a`) needs its record
type's labels, and Section 4.11 says only that "the program context must
determine uniquely the domain" of its row type. How large that context is,
the Definition leaves to the implementation (for overloading, Appendix E
bounds it by the smallest enclosing structure-level declaration; for
flexible records it says nothing). The implementations differ, and a
program one accepts another refuses. This is a choice the Definition
leaves open rather than an extension, but `program`, below, accepts
programs that none of the others does.

**Rune.** `--flex-records=MODE` (`57f66de0`, incremental M6, on the
`incremental` branch; the owner's decision of 2026-10-09) picks the context
of one of them:

| mode | the context | as |
|---|---|---|
| `binding` | the binding that would generalise the record | SML/NJ, Hamlet |
| `declaration` | the structure-level declaration it is in | MLKit |
| `topdec-monomorphic` | the top-level declaration, to a `;` or the end of the file, the record not generalised | Moscow ML |
| `topdec` (default) | the top-level declaration, a generalised record determined by each of its uses | Poly/ML, MLton |
| `program` | the whole program (the unit, with `--units`) | Rune before the option |

`tests/flexrec` holds each mode to what the implementation it follows did
with the same five programs (2026-10-09), compiled whole, in units and at
the REPL:

| program | `binding` | `declaration` | `topdec-monomorphic` | `topdec` | `program` |
|---|---|---|---|---|---|
| `same_let`: determined later in the same `let` | refused | accepted | accepted | accepted | accepted |
| `next_dec`: determined by the next declaration, no `;` between | refused | refused | accepted | accepted | accepted |
| `in_structure`: the same inside one structure | refused | refused | accepted | accepted | accepted |
| `two_types`: generalised and used at two record types | refused | refused | type mismatch | accepted | accepted |
| `after_semicolon`: determined only after a `;` | refused | refused | refused | refused | accepted |

"Refused" is "unresolved flexible record". In the modes of a top-level
declaration the free type variables of rules 87-89 are those left where the
top-level declaration ends, and the REPL compiles and runs a top-level
declaration at once (on the `incremental` branch: `docs/language.md`,
*Flexible records*, and `docs/plans/incremental-compilation.md`, M2; on
`master`, `docs/language.md` still describes the `program` behaviour).

## Sources

* *The Definition of Standard ML (Revised)*, Section 4.11, rules 54 and 86
  to 89, and Appendices E and G:
  <https://smlfamily.github.io/sml97-defn.pdf>
* The Basis Library, the top-level environment:
  <https://smlfamily.github.io/Basis/top-level-chapter.html>; `TIME`:
  <https://smlfamily.github.io/Basis/time.html>
* Poly/ML's `basis/Time.sml`:
  <https://github.com/polyml/polyml/blob/master/basis/Time.sml>
