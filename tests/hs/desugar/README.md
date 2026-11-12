# tests/hs/desugar

rhc's desugaring to Core (the haskell98 roadmap's M15; `tests/runner/hsdesugar.sml`, docs/testing.md, *rhc's
desugaring*). Each `NAME.hs` is a program whose matches and translations run on Core's interpreter in the Report's
order (`hs/desugar/report/NAME`) and in Sestoft's (`hs/desugar/sestoft/NAME`), and on the VM
(`hs/desugar/vm/NAME`), printing `NAME.expected` and ending with `NAME.exitcode` (0 where there is none); printed with
explicit braces it desugars to the same Core text (`hs/desugar/braces/NAME`); desugared a unit at a time
(`--desugar-units`) it prints the same (`hs/desugar/units/NAME`). `relations/NAME.hs` and
`relations/NAME.parens.hs` are one program, the second with every application of an operator in parentheses, which
desugar to the same Core text (`hs/desugar/parens/NAME`).

Each expected output is GHC 9.4.7's (`runghc`, with `-XNPlusKPatterns` for `patterns.hs`, and for `control.hs` the
Functor and Applicative instances GHC's Monad wants). The programs but `strictnew.hs` (a strict field of a newtype's
type, its Show derived, M14) keep clear of derived instances and of `show` of a character, a string or a floating
number, which rhc did not have when they were written.
