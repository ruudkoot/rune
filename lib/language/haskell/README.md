# Haskell 98 front end

Area: Languages

This library is the front end and the intermediate language of rhc, the
Haskell 98 compiler of the haskell98 roadmap
([docs/plans/language/haskell98.md](../../../docs/plans/language/haskell98.md)).
Rune alone builds it (the roadmap's D42): the other SML systems may compile
it, and nothing holds them to it.

`Core` is rhc's typed lazy intermediate language (D2): System F with type
constructors applied to types, a lazy `let` and `letrec`, and a `case` that
is the only thing that forces. A binding of type `T` may hold a suspension
and one of `!T` an evaluated value, so a strictness result has a type to go
to. Its text is a contract between the front end, which writes it, and
Core to Mid, which reads it: a program in it runs before there is a parser.
