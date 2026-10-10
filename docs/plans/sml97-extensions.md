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

* *The Definition of Standard ML (Revised)*, Section 4.11 and Appendix E:
  <https://smlfamily.github.io/sml97-defn.pdf>
* The Basis Library, the top-level environment:
  <https://smlfamily.github.io/Basis/top-level-chapter.html>; `TIME`:
  <https://smlfamily.github.io/Basis/time.html>
* Poly/ML's `basis/Time.sml`:
  <https://github.com/polyml/polyml/blob/master/basis/Time.sml>
