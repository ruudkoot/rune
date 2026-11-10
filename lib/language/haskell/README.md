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
`lib/compiler` from Mid on. A program may be in units (M21): a unit takes a
value of another by an import, `(import x TYPE)`, and a type by a copy of
its declaration, and `CoreUnits` joins units into one program, which the
interpreter runs.

`CoreRuntime` is rhc's runtime, written in Core over `CorePrim` (M17, D26's
A: no SML below Haskell), so that the interpreter and the VM run one text:
the unit and the list, which are the Report's built-in syntax, and the
modules the Report imports and never defines, PreludeBuiltin and
UnicodePrims, each `prim*` of `share/rhc/haskell98` a value of it of the
same name. An action passes the state token (D25), and `getContents` and
`readFile` read through `interleave`, the one interleaving primitive; a
string literal is unpacked as its list is read (D24); a `Char` is a code
point, classed and mapped by `lib/unicode`'s tables (D21); a `Float` is
rounded to binary32 after each operation (D23). rhc links into a program
what it reaches of the runtime. A family of primitives (`CorePrimFamily`) is
a file of its own, each primitive with what the interpreter does and the Mid
function it is lowered to: `CorePrimIo` gives the IO library's positions of
files and errors of the system's, over `CoreFiles`, the interpreter's files;
`CorePrimSys` the operating system's file system, process, environment,
clock, time zone and randomness, which Directory, System, Time, CPUTime and
Random read (the roadmap's M18), each over a primitive of Mid's.

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

The roadmap is `docs/plans/language/haskell98.md`.
