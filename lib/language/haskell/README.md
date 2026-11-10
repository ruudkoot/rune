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

The syntax (`syntax.build`, the roadmap's M11) reads a file of Haskell 98 to
a tree that keeps all of it. `HsLiterate` gives a literate file's program
text, the length of the file; `HsLexer` makes it tokens, each with the
comments, pragmas and white space before it; `HsLayout` is the Report's
layout algorithm, run a token at a time as `HsParser` pulls it, so that a
block the parser cannot go on with is closed there (`parse-error(t)`, D27).
`HsAst` keeps operators in flat sequences until fixity is known, a span on
every node and every node's own tokens; `HsPrint` prints a tree with every
block in braces, by layout, or exactly as its file was (D28), and `HsDump`
as text. `HsSource` holds spans and the front end's errors, `HsChar` the
Report's classes of characters.
