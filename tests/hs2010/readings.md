# Readings of the Haskell 2010 Report

The readings of the 2010 table, `tests/hs2010/conformance.tsv` (the haskell2010 roadmap's D38 and M1): places where
the text of 2010 is wrong, contradictory, ambiguous or underspecified, or where rhc reads it with a correction the
Report's editors made and never published. A row names its readings in its column `reading`, and a program that pins
one names it on its first line (`-- rows: N22`), as 98's do with `tests/hs/readings.md`, whose readings R1 to R158 the
2010 table also uses on the rows whose text 2010 keeps. N1 to N21 are E1's (the roadmap's *The readings of 2010*,
which argues each and gives its probe); N22 to N25 are the four corrections of the Report's sources that the owner
had 2010's text read with (answer 4 of 2026-11-24; D38's record).

### N1. The FFI chapter is underspecified

When a pure import is called, a chname with digits, the spacing inside an entity, marshallable newtypes across
modules: chapter 8 leaves each open, and D27 to D33 decide them.

### N2. 10.6's algorithm against chapter 3's grammar

Chapter 3's grammar derives more than the language (`a + - b`, `- - a`), which 10.6, "an example algorithm", refuses
and so in effect defines; and with the meta-rule's two notes deleted, `let x = True in x == x == True` and `do a == b
== c` have no parse, so R1's and R9's deviations from 98 become the text.

### N3. Pattern guards: 3.13's prose against 3.17.3's rules

How a guard's bindings scope and what a failing qualifier falls through to, read from rules (c) and (s) with the
prose (D14).

### N4. 4.5.1's relaxed groups with the monomorphism restriction and defaulting

Which bindings form a group once explicit signatures cut dependencies, and how Rule 1 and defaulting meet the
smaller groups (D16).

### N5. Chapter 12: which pragmas, where, and "fail with an error"

Where a LANGUAGE pragma may stand, which names an implementation must know, and what refusing a combination means
(D6, D7).

### N6. `Int` under Data.Int: modulo 2^n against 6.4's "undefined"

18.1 says Int's arithmetic is modulo 2^n where 6.4 leaves overflow undefined; shifts by the width or more; Word's
size (D21, D22).

### N7. `isSpace` and "any Unicode space character"

16.1's `isSpace` against Unicode's categories and the White_Space property (D26).

### N8. Which Unicode

The version of Unicode the text means, which it does not name (D26).

### N9. Defaulting reaches Bits

4.3.4's standard classes now include those of the library's chapters, Bits among them (D20).

### N10. `0**y`

6.4.3 says what `0**y` is where 98 left it undefined, and as printed says it wrongly (N22 has the correction).

### N11. The code chapters' own defects

14.6's header `module Array (`, 22.1's Show instance short of a parenthesis, 17's export `Complex(:+)`, 19.1's
stray parenthesis, and Data.Maybe's second `maybe`: overlay entries of the 2010 library (D23).

### N12. Empty data declarations: deriving and kinds

What may be derived for a type with no constructors, and the kind of its variables (D15).

### N13. DoAndIfThenElse is silent and reaches beyond `do`

The optional semicolons before `then` and `else` are in the grammar of every expression, not only in `do` (D17).

### N14. Hierarchical names: lexing and export of `module M`

How `A.B.C` lexes where a constructor and a module name meet, and what `module M` exports (D18).

### N15. `approxRational`'s interval

22.1's code against the prose's closed or open interval, 98's erratum absorbed in effect.

### N16. Ix for tuples

19.2 requires Ix instances for tuples up to at least size 15; 19.1's list stops at 5. The sentence is the
requirement (D38's (c)).

### N17. Field order in a pattern

3.17.2 case 6 keeps the pre-erratum "in the order they are named in the field list"; rule (m) matches the pattern's
first field first, so the field list is the pattern's (R16, and N18).

### N18. 98's errata on 2010's unchanged text

Eight of 98's 18 errata are not in 2010's text, which is otherwise 98's at those places. They are read onto it, on the
ground that they are the editors' own corrections of the text 2010 copied (D38's (a)(i)), so 98's pinning programs
serve both tables: the field order and wording of 3.17.2, `=<<` in Table 4.1, the enumFrom family's strictness at
Float and Double, properFraction's wording, the do example's `putStr`, `lex` and the underscore, and the export
production's `var`.

### N19. "Simple pattern binding" is still defined twice

4.4.3.2's "p = e" and 4.5.5's single variable, unchanged from 98 (R18): rhc's reading of 4.5.5 stands.

### N20. Strict fields' order

4.2.1's translation, unchanged, forces the last strict field first (R24).

### N21. How a program ends

98's chapter 23 has no counterpart in 2010: chapter 40 keeps exitWith, exitFailure and exitSuccess alone. 98's
behaviour is kept as rhc's documented choice, output flushed and its exit statuses (D38's (d)(i)), and the five rows
E1 mapped from chapter 23 leave the table.

### N22. `0**y` as the sources correct it

Commit 2a78309 of the Report's sources (2011-04-15) makes 6.4.3's "0**y is 1 if y is 1, and 0 otherwise" read "1 if
y is 0, and 0 otherwise". The corrected sentence is the text; IEEE's answer at a negative y, Infinity, departs from
it, a deviation on the ground "wrong" (D13b), pinned by `lang/std.pow.undefined.h2010_ieee`.

### N23. 5.6.1's "Haskell"

Commit ea28a8e (2012-07-10) makes 5.6.1's "These modules are not part of Haskell 98" read "not part of Haskell".

### N24. Rule (s) without its side condition

Commit 554480a (2018-03-11, on the branch h2010) deletes Figure 3.3 rule (s)'s "where y is a new variable", which
names no y: the rule keeps its copies of e', as the editor meant (D14).

### N25. 8.4.2's arrow

Commit 14de79f (2010-11-17) typesets 8.4.2's `ftype -> fatype -> ftype` with the function arrow, not the grammar's
production arrow; the PDF of 2010-11-17 has it, the HTML of 2010-07-20 does not.
