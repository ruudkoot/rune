# Readings of the Report from rhc's oracles

Where the oracles disagree on a test, or agree against the Report, the disagreement yields a reading: what the text
says, what each oracle does, and what rhc follows (D52, D38). E9 wrote R1 to R54 from the text (`results/E9/readings.md`
in the drafts); these are the ones E7's hard cases yielded that had none, numbered after them. Every `>` line quotes the
December 2002 text; none of the 18 errata touches these clauses. The oracles' verdicts are in `oracles.txt` beside this
file, under the reading's number.

### R55. `show` of `Float` and `Double`: the Report's code fixes the digits and the form
> instance Show Float where showsPrec p = showFloat (8, PreludeText)
> showGFloat uses standard decimal notation for arguments whose absolute value lies between 0.1 and 9,999,999, and scientific notation otherwise. (14.1)
> FFGeneric -> doFmt (if e < 0 || e > 7 then FFExponent else FFFixed) (is, e) (14.4, Numeric)

**What the text says.** `show` at `Float` and `Double` is `showFloat`, which is `showGFloat Nothing`: the digits of
`floatToDigits`, the shortest that identify the number ("Based on Printing Floating-Point Numbers Quickly and
Accurately", Burger and Dybvig, the code's own comment), in fixed form from 0.1 to 9,999,999 and otherwise as `d.ddde`
with the exponent unsigned when it is positive. So `show 1.0e20` is `1.0e20`, `show (123456789 :: Double)` is
`1.23456789e8`, `show (1.0e12 :: Double)` is `1.0e12`, and `show (0.123456789 :: Float)` is `0.12345679`. The text is
not ambiguous here: the code is normative for the digits, and 14.1 agrees with it on the form.
**GHC** and **nhc98** print the Report's form. **Hugs** prints with C's `%.7g` for a `Float` and `%.15g` for a
`Double` (`Hugs/src/prelude.h:451,463`, `src/machdep.c:1724,1791`): 7 and 15 significant digits, the fixed form for
`123456789.0` and `1000000000000.0`, and `1.0e+20` (E7: `Enum/succ` in both suites,
`numbers/floatdouble`, `numbers/integerdouble`, `numbers/subtract`, `parsing/rational_lits`). **MicroHs** prints a
`Double` to 16 digits (`numbers/floatdouble`). So Hugs is no judge of a printed floating number, nor MicroHs of a
`Double`: their lines are `HOST-BUG`.
**rhc** follows the Report's code: `floatToDigits` and the `FFGeneric` rule, as R42 leaves them but for the
parentheses of a negative number. Rows: `pre.text.inst.showfloat`, `lib.numeric.showfloat`, `lib.numeric.showgfloat`,
`lib.r.numeric.showgfloat.mid`, `lib.r.numeric.showgfloat.out`, `lib.r.numeric.floattodigits.shortest`.

### R56. `do {e}` is `e`, at any type
> Do expressions satisfy these identities, which may be used as a translation into the kernel, after eliminating empty stmts: do {e} = e (3.14)
> the functions >>, >>=, and fail are operations in the class Monad (3.14)

**What the text says.** A `do` with one statement, an expression, translates to that expression, and only `>>`,
`>>=` and `fail` bring `Monad` in. So `f a b = do a == b` is `f a b = a == b`, of type `Eq a => a -> a -> Bool`,
and `main = print (f () ())` prints `True` (`conformance98/layout/do`, whose expected output that is). Nothing in the
translation asks the last statement for a monadic type.
**GHC**, **nhc98** and **MicroHs** accept it and print `True`. **Hugs** refuses it, "Type error in final generator ...
Type : Bool": it types `do` by a rule of its own that wants a monad. Its line is `HOST-BUG`.
**rhc** follows the translation: `do {e}` is `e`, typed as `e` is. Rows: `tr.do.last`, `tr.do.last.nomonad`.
