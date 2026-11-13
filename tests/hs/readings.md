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

## The readings of rhc's clause programs (M19)

These come from the clause programs of `tests/hs/accept` and `tests/hs/errors`, put to the oracles before they landed:
GHC 9.4.7 with the strict shim (`-XHaskell98`, and for layout `-XNoNondecreasingIndentation`), Hugs `+98`, nhc98 `-98`.
In each the text is plain, so rhc follows it (D38), and the program pins the reading. A row's `reading` column names it.

### R57. Line ends: a lone return and a formfeed
> newline  |   ->  |  return linefeed | return | linefeed | formfeed (2.2)

**What the text says.** A return alone ends a line, and so does a formfeed: a line comment ends there, and the lexeme
after either begins a line, at column 1, for the layout rule. **GHC** ends a line at neither: a file of lone returns
is one line, its declarations one comment, and a formfeed is white space inside a line. **Hugs** ends a line at a lone
return and not at a formfeed. **nhc98** at neither. **rhc** follows 2.2. Rows: `lex.white.newline.cr`,
`lex.white.newline.ff`, `lay.col.newlinechars`.

### R58. No digit separator
> decimal  |   ->  |  digit{digit} (2.5)

**What the text says.** `1_000` is the literal `1` and the variable `_000`. **GHC** reads a literal with underscores,
then refuses it for want of `NumericUnderscores`, even under `-XHaskell98`. **Hugs** and **nhc98** read `1` and `_000`.
**rhc** follows 2.5. Rows: `lex.int.underscore`.

### R59. `@` and `~` are reserved alone
> reservedop  |   ->  |  .. | : | :: | = | \ | | | <- | -> | @ | ~ | => (2.4)

**What the text says.** Neither `@` nor `~` is a varsym, so `(@) a b = a` and `(~) a b = a` define nothing. **GHC**
9.4 takes both as operators where they are spaced as infix ones; **Hugs** and **nhc98** refuse them. **rhc** follows
2.4. Rows: `lex.reservedop.at`, `lex.reservedop.tilde`.

### R60. `:` is no constructor a program declares
> reservedop  |   ->  |  .. | : | :: | = | \ | | | <- | -> | @ | ~ | => (2.4)

**What the text says.** `:` is reserved for the list constructor, so `data T = Int : Int` is refused. **GHC** refuses
it; **Hugs** and **nhc98** accept it. **rhc** follows 2.4. Rows: `lex.reservedop.colon`.

### R61. No raw tab in a character or a string
> char  |   ->  |   ' (graphic<' | \> | space | escape<\&>) ' (2.6)

**What the text says.** Of the white characters only space stands raw in a character or a string literal. **GHC** and
**nhc98** refuse a raw tab; **Hugs** takes it. **rhc** follows 2.6. Rows: `lex.char.tab`, `lex.string.tab`.

### R62. `foreign` is a variable
> reservedid  |   ->  |  case | class | data | default | deriving | do | else (2.4)

**What the text says.** The reserved words are those of `reservedid`, and `foreign` is not one. **GHC** and **nhc98**
take it as a varid; **Hugs** reserves it even under `+98`. **rhc** follows 2.4. Rows: `lex.reserved.notspecial`.

### R63. A record's braces are an explicit context
> contexts, including labelled construction and update (Section 3.15). (9.3)

**What the text says.** Note 4: every pair of braces is an explicit layout context, so the lines of a record
construction, update, pattern or declaration may stand left of the block they are in, and get no `;`. **GHC** follows
it; **Hugs** and **nhc98** apply layout inside the braces and refuse the program. **rhc** follows 9.3. Rows:
`lay.note4.allbraces`.

### R64. The rest of a `\begin{code}` line
> Program code begins on the first line following a line that begins \begin{code}. (9.4)

**What the text says.** A line that *begins* `\begin{code}` opens the code on the next line, whatever follows on its
own; likewise `\end{code}`. **GHC**'s `unlit` fails on text after `\begin{code}`, and **Hugs** and **nhc98** do not see
the code begin. **rhc** follows 9.4. Rows: `lit.latex.restofline`.

### R65. A guard is an `exp0`
> gd  |   ->  |   | exp0 (3.13)
> end with a type signature --- indeed that is why a gd contains (3.13)

**What the text says.** A guard holds no signature at its top, which is what gives 3.13's note its single parse:
`case x of { (a,_) | let b = not a in b :: Bool -> a }` is `(let b = not a in b :: Bool) -> a`, the let's body being an
`exp`. **GHC**, **Hugs** and **nhc98** all read `Bool -> a` as the type and refuse the note's program, which the
Report warns parsers with limited lookahead do; and **GHC** accepts `f x | x :: Bool = 1`, a signature at a guard's top.
**rhc** follows 3.13: it accepts the first and refuses the second. Rows: `exp.case.note.letsig`, `syn.r.gd.exp0`.

### R66. `forall` is a type variable
> tyvar  |   ->  |  varid (4.1.2)

**What the text says.** `forall` is no reserved word, so `f :: forall -> forall` is a function of a type variable.
**GHC** refuses `forall` in a type, wanting `RankNTypes`; **Hugs** and **nhc98** accept it. **rhc** follows 4.1.2.
Rows: `ty.quant.forall.isvar`.

### R67. A left section's operand may be an infix expression
> aexp  |   ->  |   ( expi+1 qop(a,i) )         |  (left section) (9.5)

**What the text says.** `(a * b +)`, `(a+b+)` and `(2 - 1 -)` are left sections, the second by `( lexpi qop(l,i) )`, as
3.5's own example `(a+b+)` says. **GHC** and **nhc98** accept them; **Hugs** refuses every left section whose operand
is an infix expression. **rhc** follows 3.5 and 9.5. Rows: `exp.sec.ex.aplusb`, `exp.sec.tighter`, `syn.aexp.10`.

### R68. An infix definition whose operand is an infix pattern
> funlhs  |   ->  |   var apat {apat } (4.4.3)

**What the text says.** `funlhs` has the forms `pati+1 varop(a,i) pati+1`, `lpati varop(l,i) pati+1` and
`pati+1 varop(r,i) rpati`, so with `infixl 6 +++` and `infixl 7 :*`, `a :* b +++ c = ...` defines `+++`. **GHC**
accepts it; **Hugs** refuses it ("Illegal pattern syntax"), and **nhc98** too. **rhc** follows 4.4.3. Rows:
`syn.funlhs.3`, `dec.fun.lhs.prec`.

### R69. No infix type constructor in a declaration
> simpletype  |   ->  |  tycon tyvar1 ... tyvark	  |  (k>=0) (4.2.1)

**What the text says.** A declared type is `tycon tyvar1 ... tyvark`, so ``data a `T` b = C`` is refused. **GHC**
accepts it; **Hugs** and **nhc98** refuse it. **rhc** follows 4.1.2 and 4.2.1. Rows: `ty.form.infix.none`.

### R70. No trailing comma in a list of constructors
> |  |  |   tycon [ (..) | ( cname1 , ... , cnamen )]  |   (n>=0) (5.3)

**What the text says.** An import list may end in a comma; the list of a type's constructors may not, so
`import Prelude (Maybe(Just,))` is refused. **GHC** and **nhc98** refuse it; **Hugs** accepts it. **rhc** follows 5.3
and 9.5. Rows: `syn.r.subordinate.trailing`.

### R71. The class or type declared is unqualified
> |  |  |   class [scontext =>] tycls tyvar [where cdecls] (4.3.1)

**What the text says.** A declaration names its class or type by an unqualified `tycls` or `tycon`, so `class M.C a`
and `class Main.C a` are refused. **GHC** and **nhc98** refuse them; **Hugs** accepts a qualified name there. **rhc**
follows 4.3.1 and 5.5.1. Rows: `cls.class.unqualified`, `mod.qual.def.type`.

### R72. A subordinate name of an export
> The constructor and field names ci in the second form are unqualified; (5.2)
> is in scope in the module body regardless of whether it is in scope (5.2)

**What the text says.** In `T(c1, ..., cn)` and `C(f1, ..., fn)` each name is unqualified, and is in scope in the
module. **GHC**, **Hugs** and **nhc98** all accept a qualified subordinate name (`T(Main.C)`, `Eq((Prelude.==))`), and
**Hugs** accepts one that is not in scope. **rhc** follows 5.2 (and 9.5 with the erratum of September 2004). Rows:
`mod.exp.sub.scope`, `mod.exp.class.sub.scope`, `syn.r.export.classqvar`, `mod.exp.sub.unqualified`.

### R73. A method's context does not constrain the class variable
> the cxi may not constrain u. (4.3.1)

**What the text says.** `class C a where m :: Eq a => a -> a` is refused. **GHC** and **nhc98** refuse it; **Hugs**
accepts it. **rhc** follows 4.3.1. Rows: `cls.method.ctx.notu`.

### R74. A derived instance has a simple context
> must, like any instance declaration, have a simple context; that is, (4.5.3)

**What the text says.** `data Apply a b = App (a b) deriving Show` would need `Show (a b)`, so it is refused. **GHC**
accepts it, inferring that context; **Hugs** and **nhc98** refuse it. **rhc** follows 4.5.3. Rows:
`cls.derive.restrictions`, `dec.ctx.derive.simple`.

### R75. `hiding (C)` hides every C
> any constructor, class, or type named C is excluded.  In contrast, (5.3.1)

**What the text says.** `import M hiding (C)` hides the type, the class and the constructor called `C`. **GHC** and
**nhc98** hide the constructor; **Hugs** does not. **rhc** follows 5.3.1. Rows: `mod.imp.hiding.c.all`.

### R76. Only what is in scope, and exported
> binding for a class method that is not in scope, but the name under (4.3.2)
> entities exported by the imported module. (5.3.1)

**What the text says.** An instance cannot bind a method that is not in scope, and an import list names only what the
module exports, subordinate names too. **GHC** refuses both; **Hugs** accepts both. **rhc** follows 4.3.2 and 5.3.1.
Rows: `cls.inst.body.notinscope`, `mod.imp.list.sub.exported`.

### R77. `F.--` by maximal munch
> varsym  |   ->  |  ( symbol {symbol | :})<reservedop | dashes> (2.4)

**What the text says.** `dashes` is two or more `-`, so `-` alone is a varsym and `F.-` a qvarsym, while `F.--` is
none. At `F` the longest lexeme is therefore `F.-`, then `-`: `F.--1` is `F.- - 1`, which 10.6's rule on negation
refuses. The row's first reading, `F` then the varsym `.--`, overlooks the shorter qualified operator. **GHC**, **Hugs**
and **nhc98** all read one qualified symbol `F.--` and refuse it as out of scope. **rhc** follows 2.4; the row needs a
refused program, and stays without one until its test is read again. Rows: `lex.qual.dashes`.

## The lead's rulings on rows the text leaves open (impl/rulings.md, 2026-11-10)

Each applies the seed of a reading of E9's (the roadmap's *What the Report says*) where the text stops. Where the choice
is the implementation's (D53), it says so, and the program pins rhc's choice; an oracle that chose otherwise is recorded
in tests/hs/oracles.txt, not followed.

### R78. `abs` and `signum` at IEEE's negative zero and NaN
The Report's instances for `Float` and `Double` are primitive, and 6.4.4 says only that `abs x * signum x == x`.
**Ruling.** IEEE, as R45's seed has it where Rune's real is: `abs` clears the sign, so `abs (-0.0)` is `0.0` and
`abs` of NaN is NaN; `signum (-0.0)` is `-0.0` and `signum` of NaN is NaN, so that the law holds at `-0.0` too.
Implementation-defined. Rows: `std.sign.abs`, `std.sign.signum`.

### R79. Complex's branch cuts are its code's
6.4.5 defines the branch cuts by reference to Common Lisp. **Ruling.** The Report's own `Complex` code (chapter 11) is
the text: the cuts are what that code computes, signed zeros and all. Rows: `std.trig.cl`.

### R80. `Enum Int` and `Enum Integer` are strict once forced
The Report omits these instances. **Ruling.** As the erratum of May 2003 makes the `Float` family (R39): an enumeration
is strict in its arguments once the list is forced to weak head normal form, not before. Implementation-defined.
Rows: `std.enum.strict.int`, `std.enum.strict.integer`.

### R81. `fromEnum` beyond `Int`
A user type wider than `Int` meets the default `enumFrom` through `fromEnum`. **Ruling.** 6.4's exceptional condition on
a fixed-precision type, by D22's checked primitives: `fromInteger` out of `Int`'s range is an error, so `fromEnum` and
the default `enumFrom` of such a value are bottom, ending the program as `error` does. Implementation-defined.
Rows: `std.enum.bounded.fromenum`, `pre.r.default.enumfrom`.

### R82. `lex` is the code, with the erratum of February 2003
**Ruling.** R43's seed: the Prelude's `lex`, with `isIdInit`, decides what `read` accepts: `lex "_a"` is
`[("_a","")]`, and `read "0x10" :: Int` fails, `lex` reading `0` and leaving `x10`. Rows: `pre.r.lex.limits`,
`pre.r.lex.idinit`.

### R83. Laziness of standard input, and its buffering
**Ruling.** A test that feeds standard input in steps and checks the output between them waits for a runner that can
(about 150 lines of tests/runner, or held). Buffering is implementation-defined; rhc's choice is written when M17's I/O
lands. Rows: `io.getcontents.lazy`, `pre.r.interact.buffering`.

### R84. `readFile`'s laziness is a cost
**Ruling.** Reading the head of a large file costs a bounded count: held for a `--count` budget, as `tr.sec.sharing`.
Rows: `io.readfile.lazy`.

### R85. `interact`'s example on ASCII input
The example needs `import Char`, which the text omits. **Ruling.** The ASCII form now; non-ASCII standard input is held
until M17 states the encoding of I/O (R5 covers the source alone). Rows: `io.interact.example`.

### R86. The pattern-match obligation is a corpus difference
**Ruling.** `-O0`'s literal rules against decision trees over the corpus and generated programs. Since rhc compiles
them: `hs/desugar/orders` holds the Report's order against Sestoft's trees on every program of `tests/hs/lang`
(`lang/tr.case.obligation_held` among them), `hs/generated/@orders` (nightly) the generated programs compiled with
Sestoft's trees against the Report's meaning, `hs-corpus-run/sestoft/ID` (nightly) the corpus's 178 programs that
run on Sestoft's trees against E8's output, and `hs/interp-vm` the literal translation against the compiled form (the
lead's ruling 59). Rows: `tr.case.obligation`.


## The lead's rulings on T's M19h list (impl/rulings.md, 2026-11-10, items 14 to 27)

### R87. Derived Show and Read of records
10.4 says only "the record-syntax form". **Ruling.** R41's seed, Haskell 2010's form, as GHC writes it:
`C {f = 1, g = 2}`, a field at precedence 0, a record constructor parenthesised at 11, an operator field or constructor
in parentheses, and derived Read reading that form, every field present and in order. Implementation-defined.
Rows: `der.show.record.chars`, `.form`, `.prec`, `.neg`, `.opfield`, `.opcon`, `.empty`, `der.show.infix.backtick`,
`der.show.prefix.opcon`, `der.read.prec.range`, `der.read.record.all`, `der.read.record.prec`.

### R88. Negative floats in derived Show and Read
**Ruling.** R42's seed, 10.4's text over chapter 8's code: a negative `Float` or `Double` is parenthesised above
precedence 6, as `showSigned showFloat`, and derived Read takes the parenthesised form, so `read . show` holds.
Rows: `der.show.neg.float`, `der.show.readable`, `der.read.neg`.

### R89. Comments in read's input
**Ruling.** R43's seed, the code with the erratum: the Prelude's `lex` skips white space only, so a comment in what
`read` reads is not skipped, and the read fails. Rows: `der.read.space`.

### R90. Derived Ord over NaN
**Ruling.** `Double`'s `compare` is Ord's default over IEEE's `==` and `<=`, so `compare NaN x` is `GT`; a derived
Ord compares fields by `compare`, left to right, and its `<` and the rest by `compare`. Implementation-defined.
Rows: `der.ord.partial`.

### R91. A derived and an explicit instance in two modules
**Ruling.** R26's seed: one class-type pair has one instance in a program, checked at link: a derived instance in one
module and an explicit one in another are refused, an errors program held until rhc links (M21).
Rows: `der.cond.noexplicit.module`.

### R92. The Report's misprints are not copied
**Ruling.** R52's: `der.tree.fixity` uses Figure 10.1's `infixr 5 :^:`; `prag.inline`'s program uses
`factorial 0 = 1`, testing the pragma only. `lit.example.factorial` stays the owner's. Rows: `der.tree.fixity`,
`prag.inline`.

### R93. `default (Int, Double)` shows Int by its overflow
**Ruling.** `2^70` at the first type of `default (Int, Double)` is an error by D22's checked `Int` (R81), which shows
that Int was picked, where Integer would print the value. Implementation-defined; the oracles' wrapping is recorded.
Rows: `def.pick.first`.

### R94. Recursive modules have no oracle
**Ruling.** A program whose modules import each other is written by hand, its output from the text alone (D52): none
of GHC (without its boot files), Hugs or nhc98 compiles it as written. Rows: `mod.inst.recursive`.

## The lead's rulings of 2026-11-11 (impl/rulings.md, 56 to 58)

### R95. A bottom rhc determines, and the stack's limit
> If a program terminates as a result of calling error or because its value is otherwise determined to be _|_, then
> it is treated identically to the computation exitFailure. (23)

**Ruling 58.** A loop rhc determines, the re-entry of a suspension blackholed while it is evaluated (form C), is
"determined to be _|_": it ends as exitFailure does, status 1, on Core's interpreter and on the VM alike, what was
written first flushed. Running out of the stack is D18's limit, an implementation's resource and not a determination
of _|_ (GHC's own stack overflow exits 2): outside the clause, so the VM's status 2 there stands. **GHC**, **Hugs**
and **nhc98** give status 1 on the blackholed loop. Rows: `lib.r.system.term.loop` (`lang/lib.r.system.term.loop`,
which the VM fails today, R's), `std.eq.neither` (`lang/std.eq.neither_loops`, a loop to the stack's limit).

## The owner's calls on E9's readings (2026-11-10)

E9 left these three to the owner (its readings.md in the drafts; the roadmap records the calls). Each is written here
with the programs that pin it.

### R4. Texts that are not in the grammar: a comment at end of file, white space in a line comment, an empty file
> comment  |   ->  |  dashes [ any<symbol>  {any}] newline (2.2)
> any  |   ->  |  graphic  |  space  |  tab (2.2)

**The owner's call.** As E9's seed reads it, each acceptance a deviation from the grammar taken literally, pinned by a
program (`tests/hs/deviations.tsv`): a line comment that ends the file without a newline is accepted, the end of the
file ending it (`accept/lex.comment.line.eof_noeol`); a vertical tab and the other Unicode white space in a line
comment are accepted, and a vertical tab moves the column by one, as nothing else is stated
(`accept/lex.any.linecomment_uniwhite`, which pins both); a file with no lexeme is the module `Main` with no `main`,
5.1's abbreviation, refused by chapter 5's rule and not by the grammar (`errors/lay.first.empty_nomain`, a file of
comment only, which L sees as it sees an empty one). **GHC**, **Hugs** and **nhc98** accept the comment at end of
file; **nhc98** and **MicroHs** refuse the second program; **Hugs** loads the third, asking for no `main`.
Rows: `lex.comment.line.eof`, `lex.any.linecomment`, `lay.col.vt`, `lay.first.empty`.

### R15. `n+0`
> Matching an n+k pattern (where n is a variable and k is a positive integer literal) against a value v succeeds if x >= k (3.17.2)
> pat  |   ->  |   var + integer  |  (successor pattern) (3.17.1)

**The owner's call.** `n+0` is refused, by 3.17.2's "positive integer literal" over the grammar's `integer`, as
**Hugs** refuses it ("Integer k in (n+k) pattern must be > 0"); **GHC** and **nhc98** accept it. 3.17.3's rule (s)
is read with that `k`. Not a deviation: the prose is followed. Rows: `pat.m.npk.positive` (`errors/pat.m.npk.positive`),
`tr.case.s`.

### R52. 9.4's `readLine`
**The owner's call.** A mistake in the Report, recorded as such and not copied: no module of the Report defines
`readLine`, and the factorial example is tested with `getLine`, its likely meaning (`lang/lit.example.factorial`, the
example as the HTML Report prints it, its blank lines kept, run on the input 5). R92 applies the same to the other
misprints. Rows: `lit.example.factorial`.

## rhc's choices on E9's readings, for the rows of test `none` (ruling 49)

Where E9's row says rhc must pick, ruling 49 makes it a test whose program pins rhc's choice; E9's reading (its
readings.md in the drafts) is the problem, and its entry here says what rhc does and which program shows it.

### R5. The source's encoding and Unicode's version
**rhc's choice.** Source text is UTF-8: `"é"` is one character, 233 (a byte that begins no UTF-8 sequence is read
as its Latin-1 character, unpinned). The version of Unicode is 18.0.0, lib/unicode's, for the lexer's classes and
for Char: letters new in Unicode 16.0 (Garay) are letters. **GHC** 9.4 (Unicode 14.0) and **nhc98** (8-bit) refuse
the identifier; **Hugs** lexes it, and its Char calls neither letter upper nor lower. Rows: `lex.unicode.encoding`,
`lex.unicode.newversions` (`lang/lex.unicode.encoding`).

### R6. Unicode digits in a numeric literal
**rhc's choice.** Chapter 19's side, as R6's seed has it: a numeric literal holds ASCII digits, and `١٢` is refused
("a digit above ASCII"), though a Unicode digit may stand in an identifier. A deviation from 2.5's grammar, on the
ground that the text contradicts itself (the lead's ruling 56, `tests/hs/deviations.tsv`): 2.5 admits the digit and
no clause gives it a value. **GHC**, **Hugs**, **nhc98** and **MicroHs** all refuse it. Rows: `lex.int.unidigit`
(`errors/lex.int.unidigit`, the deviation's pin).

### R8. A numeric escape's bound
**rhc's choice.** R8's seed: an escape above `maxBound :: Char`, 0x10FFFF, is a static error, as **GHC** and **Hugs**
refuse it; **nhc98** accepts it. Rows: `lex.esc.range` (`errors/lex.esc.range`).

### R1. `do` against a non-associative operator, and the parse-error rule
**rhc's choice.** 9.3 gives `do a == b == c` the single parse `(do { a == b }) == c`, and concedes it: "The
parse-error rule is hard to implement in its full generality, because doing so involves fixities ... Programmers are
therefore advised to avoid writing code that requires the parser to insert a closing brace in such situations". rhc
closes blocks by the grammar with operators flat (D27), and fixity resolution refuses the block, as all four oracles
do: a deviation conceded by the Report (D38's ground, the owner's decision of 2026-11-13), pinned. Rows:
`lay.parseerror.fixity` (`errors/lay.parseerror.fixity_refused`).

### R9. `let` against a non-associative operator
**rhc's choice.** As R1 for `do` (D27, D38): the parser takes the meta-rule, the `let` extending as far right as it
can, with operators flat, and fixity resolution refuses `x == x == True`; the parse 3 states, `(let x = True in (x ==
x)) == True`, needs fixities while parsing, and chapter 3 concedes it ("implementations may well use a post-parsing
pass to deal with fixities ... Programmers are advised to avoid constructs whose parsing involves an interaction of
(lack of) associativity with the let/lambda meta-rule"): a deviation conceded by the Report (D38's ground, the
owner's decision of 2026-11-13), pinned. **GHC**,
**Hugs**, **nhc98** and **MicroHs** all refuse it. Rows: `exp.parse.letnonassoc` (`errors/exp.parse.letnonassoc_refused`).

### R14. The kernel's literals, and the translations' claim
**rhc's choice.** R14's seed: an integer literal is the Prelude's `fromInteger` of an Integer, a floating one its
`fromRational` of a reduced Rational, whatever else is in scope, and a string a list of characters; so the
translations keep a program's meaning, the claim of chapter 3 (but for `let`), each identity held by its own row.
Rows: `exp.trans.preserve` (`lang/tr.lit.int`, which pins R14 for the literals' rows too).

### R20. Rule 2 across a cycle of modules
**rhc's choice.** D30's (owner, 2026-11-09): "an entire module" is the module, `--cycle-default=module` by default,
so a monomorphic variable is closed at the end of its own module, and a use at another type in a module of its cycle
is refused; `--cycle-default=scc`, an extension off by default, closes it at the end of the cycle. No oracle compiles
a cycle as written (R94). Rows: `mr.rule2.mutual` (`errors/mr.rule2.mutual`), `mod.sep.sigs` (`accept/mod.sep.sigs`).

### R29. Separate compilation of a cycle
**rhc's choice.** R29's seed: rhc compiles a cycle of modules whole, with no annotation, and needs no signature for
a function exported across it; what D30 asks is only that a restricted variable's type be fixed in its own module.
Rows: `mod.sep.recursive` (`accept/mod.recursive`), `mod.sep.sigs` (`accept/mod.sep.sigs`).

### R32. The Prelude's parts
**rhc's choice.** R32's seed: the modules chapter 8 shows the Prelude in "cannot be imported separately", so
`import PreludeList` is refused; the implicit `import Prelude` is as 5.6.1 says (`mod.prel.*`). Rows:
`mod.prel.primitive` (`errors/mod.prel.primitive`).

### R37. What an error does
**rhc's choice.** R37's seed, chapter 23 over 3.1's "immediate": an error ends the program at once, with status 1 as
`exitFailure`, its message on standard error, after the handles are flushed and closed, so what was written before
it is kept. And `exitWith (ExitFailure 0)` (the lead's ruling 57): chapter 23 lets a system prohibit 0, as POSIX
does, and says nothing of what follows; rhc prohibits it, so it raises an IOError, `isIllegalOperation`, which
`catch` sees and which, uncaught, ends the program as a failure, status 1. **GHC** ("exitWith: invalid argument") and
**Hugs** (a pattern-match failure) stop with status 1; **nhc98** and **MicroHs** exit 0. Rows: `exp.err.behaviour`
(`lang/exp.err.terminate_stop`), `lib.r.system.exitcode.prohibited` (`lang/lib.r.system.exitcode.prohibited`).

### R38. Binary I/O, and what a character is on a handle
**rhc's choice.** A `Char` is any code point (R5's version), and the standard handles carry UTF-8 on every host,
binary-mode (no newline is translated): `putStrLn ['\233', '\8364']` writes the bytes C3 A9 E2 82 AC and a newline.
**GHC** and **Hugs** do the same in a UTF-8 locale; **nhc98**'s 8-bit Char writes Latin-1. Rows: `io.binary`
(`lang/io.binary`).

### R45. Numeric corners: division by zero, `0 ** y`, coercions of NaN and infinities, Ord's totality
**rhc's choice.** R45's seed: integral division by zero is an error, at `Int` and `Integer` (**GHC** and **Hugs**
alike; **nhc98** gives -1); IEEE where Rune's real is, so `0 ** y` is IEEE's pow, 0, 1 or an infinity by `y`'s sign
(**GHC** alike; **Hugs** errs at a negative `y`, **nhc98** gives the largest finite number); `truncate`, `round`,
`ceiling`, `floor`, `properFraction` and `toRational` of a NaN or an infinity are errors (Domain or Overflow), as the
Report's code leaves them undefined (**Hugs** errs too; **GHC** and **nhc98** give a number); and Double's `Ord` is
not total over NaN (R90). Rows: `std.arith.zero` (`lang/std.arith.zero`), `std.pow.undefined`
(`lang/std.pow.undefined`), `std.coerce.nan` (`lang/std.coerce.nan`), `std.ord.total` (`lang/der.ord.partial_nan`).

### R47. The Prelude's code where it does not compile
**rhc's choice.** R47's seed: the overlay (`share/rhc/haskell98/overlay.tsv`, `ov.preludeio.interact` for
`interact`'s names) makes chapter 8's code compile as it means. Rows: `pre.r.interact.scope`
(`lang/io.interact.example_ascii`).

### R53. An unterminated `\begin{code}`
**rhc's choice.** R53's seed: an error ("a `\begin{code}` that no `\end{code}` closes"), as **GHC**'s unlit refuses
it; **Hugs** and **nhc98** read to the end of the file. A file that mixes the two styles, which R53's seed would also
refuse, rhc reads line by line, each line by its own style (`lit.mixed`'s how; no reading names that row). Rows:
`lit.latex.unterminated` (`errors/lit.latex.unterminated`).

## The readings of the libraries' clause programs (M19, chapters 12 to 27)

These come from the clause programs of the Report's libraries, `tests/hs/lang` and `tests/hs/accept` from `lib.`, put to
GHC 9.4.7 with the strict shim, Hugs `+98`, nhc98 `-98` and MicroHs before they landed. Where the library's prose and its
code part, the code is the text (D38, as the lead's ruling on R39 takes chapter 8's code), and rhc follows it.

### R150. `showFFloat Nothing 245000` is `245000.0`
> showFFloat uses standard decimal notation (e.g. 245000, 0.0015). (14.1)
> Nothing -- Always prints a decimal point (14.4, Numeric, formatRealFloat)

**What the text says.** The prose's example drops the point that the code always prints: by the code,
`showFFloat Nothing 245000 ""` is `245000.0`, and `0.0015` stays `0.0015`. The code defines the function; the example
illustrates "standard decimal notation", which both forms are. E9's R49 lists this among the library's prose against its
code. **GHC**, **Hugs**, **nhc98** and **MicroHs** all print `245000.0`. **rhc** follows the code.
Rows: `lib.r.numeric.showffloat`.

### R151. `floatToDigits`: `r = 0.d1...dn * b^e` exactly only where `b` is a power of the radix
> if floatToDigits b r = ([d_1, d_2, ... d_n], e) then the following properties hold: r = 0.d1 d2 ..., dn * be (14.1)
> Based on "Printing Floating-Point Numbers Quickly and Accurately" by R.G. Burger and R. K. Dybvig (14.4, Numeric)

**What the text says.** The code generates the shortest digits that identify `r` among the numbers of its type, its
citation's algorithm, so `floatToDigits 10 0.1` is `([1], 0)`, while `0.1 :: Double` is not one tenth. The first
property holds exactly in bases 2 and 16, where the digits are `r`'s own, and in base 10 only as the digits read back to
`r`: `fromRational` of `0.d1...dn * 10^e` is `r`. The other properties hold as written. **GHC**, **Hugs**, **nhc98** and
**MicroHs** agree with the code. **rhc** follows the code; the program checks the property exactly in bases 2 and 16
and to the nearest float in base 10. Rows: `lib.r.numeric.floattodigits.value`.

### R152. `Functor (Array a)` has the context `(Ix a)`
> instance Functor (Array a) where ... (16, the synopsis)
> instance (Ix a) => Functor (Array a) where (16.4, Array)

**What the text says.** The synopsis gives the instance no context and the code gives it `(Ix a)`; E9's R49 lists the
pair among the library's prose against its code. The code is the text, so `fmap` on an `Array a b` needs `Ix a`:
`g :: Array a Int -> Array a Int; g = fmap (+ 1)` is refused, and with `(Ix a) =>` in its signature accepted. **Hugs**,
**nhc98** and **MicroHs** refuse the first form, as the code does; **GHC**'s instance has no context and takes it.
**rhc** follows the code; the accepted program uses the form with the context, which both readings take.
Rows: `lib.r.array.functor.context`.

### R153. `Char`'s classes beyond Latin-1: the table and its rule, on characters that have kept their category
> For the purposes of Haskell, any alphabetic character which is not lower case is treated as upper case (19)
> isAlpha c = isUpper c || isLower c (19.1, Char)

**What the text says.** The primitives `isPrint`, `isUpper`, `isLower`, `isAlphaNum`, `toUpper` and `toLower` take
their meaning from 19's table: lower-case alphabetic; other alphabetic, upper case, title case and letters of no case
alike, all `isUpper`; digits; other printable; non-printing. `isAlpha` is `isUpper || isLower` by the code, at every
character, and `isSpace` is true of the seven Latin-1 white characters only. Which version of Unicode is E9's R38, the
owner's call (2.1 opens the text to any version after 3.0), as is whether `Char` holds the surrogates: the programs use
only characters whose category and case mapping have stood since Unicode 3.0 (not U+00AA, U+00BA, U+00AD or U+200B,
which have moved), so that they do not depend on it. **GHC**, **Hugs** and **MicroHs** take a letter of no case as
neither upper nor lower case, so `isAlpha` is not `isUpper || isLower` (R38 found no oracle that follows the rule);
GHC and MicroHs take U+2003 and U+3000 as spaces; **nhc98**'s `Char` stops at `'\255'`. **rhc** follows the text.
Implementation-defined (D53): the Unicode version, on which no program depends. Rows: `lib.r.char.table.other.upper`,
`lib.r.char.isalpha`, `lib.r.char.isspace`, `lib.r.char.toupper.unicode`.

### R154. `lexLitChar` returns exactly the characters `readLitChar` reads
> The function lexLitChar does the reverse, returning the sequence of characters that encode the character. The
> function readLitChar does the same, but in addition converts the to the character that it encodes. (19)
> -- Very crude approximation to \XYZ. (19.1, Char, lexLitChar)

**What the text says.** The code's clause for a named escape, `span isCharName`, takes every upper-case letter and
digit that follows: `lexLitChar "\\NUL1"` is `[("\\NUL1","")]`, `lexLitChar "\\Q"` is `[("\\Q","")]` though `\Q`
encodes nothing, and its numeric clauses take `\o` or `\x` with no digit (`lexLitChar "\\o8"` is `[("\\o","8")]`),
which `readLitChar` refuses. The code calls its own clause a crude approximation, so it does not claim to define the
function; the prose does: `lexLitChar` returns the characters that encode the character, those `readLitChar` reads. So
`lexLitChar s` is `[(the prefix that readLitChar s reads, the rest)]`, and `[]` where `readLitChar s` is `[]`:
`"\\NUL"` before `"1"`, `"\\SOH"` before `"H"`, nothing for `\Q`, `\o8` or `\x`. **GHC**, **Hugs** and **nhc98** all give
`"\\NUL"` before `"1"` and nothing for `\Q`; for `\o8` GHC gives nothing and Hugs and nhc98 the code's `"\\o"`. Taken
as the lead's ruling on R42 took 10.4's text over a code every oracle departs from; the lead's ruling 36 confirms it. **rhc**
follows the prose; where the code and the prose agree, the differential holds rhc to the code. Rows:
`lib.r.char.lexlitchar`, `lib.char.lexlitchar`.

### R155. `array` is strict in its bounds, with or without associations
> array is strict in the bounds argument and in the indices of the association list, but nonstrict in the values. (16.1)
> array b ivs = if and [inRange b i | (i,_) <- ivs] then MkArray b ... (16.4, Array)

**What the text says.** The prose makes `array` strict in its bounds; the code reaches the bounds only through `inRange`
over the associations, so with none it builds `MkArray b f` without looking at `b`, and `array undefined [] `seq` ()`
is `()`. With an association to check, both give bottom. D52's judges and third, **GHC**, **Hugs** and **nhc98**, give
bottom for the empty list, as the prose; **MicroHs**, the smoke oracle, gives `()`, as the code. By R42's precedent the
prose decides (the lead's ruling 35, correcting 28): an overlay entry (L) makes `array` force its bounds. **rhc**
follows the prose: both programs exit as error. Rows: `lib.r.array.strict.bounds`.

### R156. A semi-closed handle is neither open nor closed
> A handle is semi-closed after hGetContents... In this state, hdl is effectively closed, but items are read from hdl on
> demand (21.2.2)
> Computation hIsOpen hdl returns True if hdl is open ... hIsClosed hdl returns True if hdl is closed (21.8)

**What the text says.** The text gives no predicate for the semi-closed state and does not say what `hIsOpen` and
`hIsClosed` answer of a semi-closed handle (E9's R49). The lead's ruling 37: neither, so both are `False`, as **GHC**
does. Implementation-defined (D53); rhc implements it with M18's IO, and the program that pins it is held until then.
Rows: `lib.r.io.semi.state`.

### R157. `floatToDigits` at a power of the radix keeps the code's low margin
> -- Based on "Printing Floating-Point Numbers Quickly and Accurately" by R.G. Burger and R. K. Dybvig (14.4, Numeric)
> if e >= 0 then let be = b^e in if f == b^(p-1) then (f*be*b*2, 2*b, be*b, b) (14.4, Numeric, floatToDigits)

**What the text says.** At a mantissa that is a power of the radix with `e >= 0`, the code takes the low margin `mDn`
as `b`, where Burger and Dybvig take `b^e`. Its digits still read back to the number, but they are not always the
shortest or the closest: `floatToDigits 10 (2^70 :: Double)` ends `...4114`, so `show (2^70 :: Double)` is
`1.1805916207174114e21`, and `show (2^70 :: Float)` is `1.18059163e21`, nine digits. 14.1 promises only
`r = 0.d1...dn * b^e` (R151), not the shortest or the closest digits, so the code contradicts no text, and by D38 the
printed code stands (the lead's ruling, on L's finding). **GHC** and **MicroHs** follow Burger and Dybvig
(`1.1805916207174113e21`, `1.1805916e21`); **nhc98** keeps the Report's line. Expected output written from GHC at
such numbers differs from rhc's: a program's expected `show` of a power of two from `2^p` up comes from the code.
**rhc** follows the code. Rows: `lib.r.numeric.floattodigits.shortest`.

### R158. Changing an input handle to NoBuffering discards the input it has read ahead
> If the buffer mode is changed from BlockBuffering or LineBuffering to NoBuffering, then if hdl is writable, the
> buffer is flushed as for hFlush; if hdl is not writable, the contents of the buffer is discarded. (21.6)

**What the text says.** The characters an input handle has read ahead of the program and not yet given are lost at
the change, so that the next read skips them (E9's `how`). **GHC**, **Hugs**, **nhc98** and **MicroHs** all keep
them: after one `hGetChar` of "abcdef" and the change, `hGetContents` gives "bcdef" (oracles.txt). **rhc** follows
the text, the lead's ruling 61 (D38: the text is clear and implementable, and unanimity is no ground): the change
discards what a file's handle has read ahead (its bytes and any character `hLookAhead` or `hIsEOF` put back), and
under NoBuffering such a handle reads a byte at a time, so that nothing is ahead; the runtime's buffer of the
standard input, which `getChar` and `getContents` share, is the runtime's and not discarded. On the owner's list
(15). Rows: `lib.r.io.hsetbuffering.discard` (`lang/lib.r.io.hsetbuffering.discard_lost`).
