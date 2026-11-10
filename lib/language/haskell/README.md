# Haskell 98 front end

Area: Languages

This library is the front end and the intermediate language of rhc, the
Haskell 98 compiler of the haskell98 roadmap. Rune alone builds it (the
roadmap's D42): the other SML systems may compile it, and nothing holds
them to it.

`Core` is rhc's typed lazy intermediate language (D2): System F with type
constructors applied to types, a lazy `let` and `letrec`, and a `case` that
is the only thing that forces. A binding of type `T` may hold a suspension
and one of `!T` an evaluated value, so a strictness result has a type to go
to. Its text, `CoreText`, is a contract between the front end, which writes
it, and Core to Mid, which reads it: a program in it runs before there is a
parser. `CoreLint` checks a program, `CoreInterp` runs it, `CorePrim` is
what it can do that is not Core, and `CoreGen` makes programs to test them
with. `CoreToMid` lowers a program to Mid's text, a lazy position a
suspension and an evaluated one its value, which rhc gives to the passes of
`lib/compiler` from Mid on.

The roadmap is `docs/plans/language/haskell98.md`.
