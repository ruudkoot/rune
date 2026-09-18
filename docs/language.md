# The Rune language

Rune compiles **Standard ML '97** (the Core language, the Basis Library subset
listed below, and namespace-only structures) to bytecode for the `runevm`
interpreter. This document is the authoritative description of what Rune
accepts; `make check-docs` verifies that every feature marked *Supported* or
*Partial* has a test in `tests/lang/` named `<id>_<something>.sml`, and that
every test corresponds to a row here.

Status values: **Supported** (implemented, tested), **Partial** (implemented
with documented restrictions), **Planned** (not yet implemented; using it is a
compile-time error).

## Deviations from the Definition

These are intentional simplifications of the first release. They never make a
well-typed SML program behave differently; they only make Rune accept some
programs that SML rejects, or reject some that SML accepts.

| Topic | Rune behaviour |
|---|---|
| Equality types | `''a` type variables are accepted but equality is **not** restricted to equality types: `=` works on any type (reals compare by IEEE equality, functions never compare equal, refs/arrays compare by identity). |
| Exhaustiveness | No "match nonexhaustive" or "match redundant" warnings. A failed match raises `Match` (or `Bind` for `val`) at runtime as required. |
| Value restriction | Enforced (expansive bindings stay monomorphic), but an unresolved monomorphic type variable at top level is not reported as an error. |
| Integer literals | Integer, word and real literals have exactly one type each (`int`, `word`, `real`); there is no literal overloading over multiple precisions. `Int` is 64-bit, `Word` is 64-bit, `Real` is IEEE double. `IntInf.int` values are built with `IntInf.fromInt`/`fromString` or arithmetic, and the operators on them are not overloaded (`IntInf.+`). |
| Strings | 8-bit byte strings; `\uXXXX` escapes above 255 are errors. |
| Modules | Only `structure S = struct ... end`, `structure S = T`, `open`, and long identifiers. No signatures, ascription or functors (Planned). |
| `abstype` | Not supported (Planned). |
| Type variable scoping | Explicit type variables are scoped at the nearest enclosing `val`/`fun` declaration. A type variable that is unified with a concrete type is not reported. |
| Top-level expressions | `exp ;` at top level is accepted and treated as `val _ = exp`. |
| Flexible records | Must be resolved by the end of the enclosing top-level declaration (as in SML). |
| `_prim "name" : ty` | Extension used by the basis library to access VM primitives. Only allowed with `--allow-prim`. |
| I/O | `TextIO`/`BinIO` streams are concrete datatypes (so they admit equality); `BinIO` shares `TextIO`'s stream types; `Word8Vector.vector` is `string` and there is no `Word8`. |

## Lexical structure

| ID | Feature | Status | Notes |
|---|---|---|---|
| lex.comments | Nested comments `(* ... (* ... *) ... *)` | Supported | Unterminated comments are errors. |
| lex.int | Integer literals: decimal, `~` negative, `0x` hexadecimal | Supported | Range is 64-bit two's complement. |
| lex.word | Word literals `0w...`, `0wx...` | Supported | 64-bit. |
| lex.real | Real literals with `.`, `e`/`E` exponents and `~` signs | Supported | Not allowed in patterns. |
| lex.char | Character literals `#"c"` with all SML escapes | Supported | `\ddd`, `\uXXXX` (≤ 255), `\^C`, `\a\b\t\n\v\f\r\\\"`. |
| lex.string | String literals with escapes and `\ whitespace \` gaps | Supported | |
| lex.ident | Alphanumeric and symbolic identifiers, primes, `'a`/`''a` type variables, long identifiers `A.B.x` | Supported | All 50 reserved words including module keywords are reserved. |

## Declarations

| ID | Feature | Status | Notes |
|---|---|---|---|
| dec.val | `val pat = exp`, `val ... and ...`, explicit type variables `val 'a x = ...` | Supported | Refutable patterns raise `Bind`. |
| dec.valrec | `val rec f = fn ...` (and mutually recursive with `and`) | Supported | Right-hand side must be a `fn`. |
| dec.fun | `fun f x y = ...` curried functions | Supported | |
| dec.fun.clauses | Multiple clauses `fun f 0 = ... \| f n = ...`, mutual recursion with `and` | Supported | All clauses must have the same name and arity. |
| dec.fun.infix | Infix function definitions `fun x ++ y = ...` and `fun (x ++ y) z = ...` | Supported | Requires a prior `infix` directive. |
| dec.type | `type` abbreviations with parameters | Supported | |
| dec.datatype | `datatype` with nullary and unary constructors | Supported | |
| dec.datatype.poly | Parameterized datatypes `datatype ('a, 'b) t = ...` | Supported | |
| dec.datatype.mutual | Mutually recursive datatypes with `and` | Supported | |
| dec.datatype.withtype | `datatype ... withtype ...` | Supported | |
| dec.datatype.repl | Datatype replication `datatype t = datatype u` | Supported | Also copies the constructors. |
| dec.exception | `exception E`, `exception E of ty`, generative (fresh per evaluation) | Supported | |
| dec.exception.repl | `exception E = F` | Supported | |
| dec.local | `local dec in dec end` | Supported | |
| dec.infix | `infix`, `infixr`, `nonfix` with precedences 0–9, lexically scoped | Supported | Directives carry across the files of one program. |
| dec.structure | `structure S = struct ... end`, `structure S = T`, nested structures, long identifiers | Partial | Namespaces only: no signatures, ascription or functors. |
| dec.open | `open S T` | Supported | |
| dec.toplevelexp | Top-level expression statements `exp;` | Supported | Extension: treated as `val _ = exp`. |
| dec.abstype | `abstype` | Planned | |

## Expressions

| ID | Feature | Status | Notes |
|---|---|---|---|
| exp.literal | Integer, word, real, character and string constants | Supported | |
| exp.tuple | Tuples `(a, b)`, unit `()` | Supported | |
| exp.record | Records `{a = 1, b = "x"}`, structural equality, label order irrelevant | Supported | Fields are evaluated in source order. |
| exp.record.select | Selectors `#lab` (including numeric labels `#2`) | Supported | The record type must be determined within the enclosing top-level declaration. |
| exp.list | List syntax `[a, b, c]` | Supported | |
| exp.seq | Sequencing `(e1; e2; e3)` | Supported | |
| exp.let | `let dec in exp; exp end` | Supported | |
| exp.fn | `fn pat => exp \| ...` | Supported | |
| exp.app | Function application, left-to-right evaluation (function, then argument) | Supported | |
| exp.infix | Infix application respecting precedence and associativity, `o`, `before`, `:=`, `^`, `@`, `::` | Supported | |
| exp.boolops | `andalso`, `orelse` (short-circuit) | Supported | |
| exp.if | `if ... then ... else` | Supported | |
| exp.case | `case exp of match` | Supported | Non-exhaustive matches raise `Match`. |
| exp.while | `while exp do exp` | Supported | Compiled to a tail-recursive loop. |
| exp.raise | `raise exp` | Supported | |
| exp.handle | `exp handle match`, re-raising when no rule matches | Supported | |
| exp.annot | Type annotations `exp : ty` | Supported | |
| exp.op | `op` prefix for infix identifiers (`op+`, `op::`, `op=`) | Supported | |

## Patterns

| ID | Feature | Status | Notes |
|---|---|---|---|
| pat.wild | Wildcard `_` | Supported | |
| pat.var | Variable patterns | Supported | Identifiers bound as constructors in scope are constructors, otherwise variables. |
| pat.const | Constant patterns: int, word, string, char | Supported | Real constants are rejected. |
| pat.con | Constructor patterns, nullary and with arguments, nested | Supported | |
| pat.tuple | Tuple patterns and `()` | Supported | |
| pat.record | Record patterns `{a, b = p, c : ty}` | Supported | |
| pat.record.flex | Flexible record patterns `{a, ...}` | Supported | Full type must be known within the declaration. |
| pat.list | List patterns `[]`, `[p1, p2]`, `p :: ps` | Supported | |
| pat.layered | Layered patterns `x as p`, `x : ty as p` | Supported | |
| pat.annot | Typed patterns `p : ty` | Supported | |
| pat.ref | `ref p` patterns | Supported | |

## Types and inference

| ID | Feature | Status | Notes |
|---|---|---|---|
| ty.infer.letpoly | Hindley–Milner inference with let-polymorphism | Supported | |
| ty.infer.valuerestriction | Value restriction (only non-expansive bindings generalize) | Supported | See deviations. |
| ty.overload.default | Overloaded `+ - * div mod / ~ abs < <= > >=` at `int`, `word`, `real`, `char`, `string`; default `int` | Supported | `~`/`abs` on `int`/`real`; `div`/`mod` on `int`/`word`; `/` on `real`. |
| ty.record.flex | Flexible record types from `#lab` and `{..., ...}` | Supported | |
| ty.annot | Type annotations on expressions and patterns | Supported | |
| ty.tyvar.explicit | Explicit type variables `fun 'a f (x : 'a) = ...`, `''a` | Supported | Equality attribute not enforced. |
| ty.abbrev | Expansion of type abbreviations, arity checking | Supported | |
| ty.eqtype | Equality type checking | Planned | |
| ty.exhaustive | Exhaustiveness and redundancy warnings | Planned | |

## Modules

| ID | Feature | Status | Notes |
|---|---|---|---|
| mod.signature | `signature`, `sig ... end` | Planned | |
| mod.ascription | `structure S : SIG`, `:>` | Planned | |
| mod.functor | `functor` | Planned | |

## Runtime behaviour

| ID | Feature | Status | Notes |
|---|---|---|---|
| rt.tailcall | Proper tail calls (constant stack for tail recursion) | Supported | Not in the body of a `handle`. |
| rt.deeprec | Deep non-tail recursion (the VM stack grows on demand) | Supported | |
| rt.gc | Garbage collection (copying collector, heap grows as needed) | Supported | `runevm --heap-size N` sets the initial semispace. |
| rt.exn.uncaught | Uncaught exceptions print `runevm: uncaught exception Name payload` to stderr and exit with status 1 | Supported | |
| rt.exit | `OS.Process.exit` terminates with the given status | Supported | |
| rt.overflow | `int` arithmetic raises `Overflow`; `word` arithmetic wraps | Supported | |
| rt.div | `div`/`mod` floor semantics, `quot`/`rem` truncate, `Div` on zero, IEEE reals | Supported | |
| rt.equality | Structural equality on immutable data, identity on `ref`/`array` | Supported | |
| rt.closure | Closures capture variables by value (refs for mutation), mutual recursion | Supported | |
| rt.args | Command line arguments after the bytecode file | Supported | |
| rt.stdin | Reading standard input | Supported | |

## Basis library

Structures are listed with the members implemented. Members of the SML Basis
Library that are not listed are not available.

| ID | Structure | Status | Notes |
|---|---|---|---|
| basis.general | Top-level `option`, `order`, `Fail`, `Option`, `Empty`, `Span`, `Unordered`, `not`, `ignore`, `o`, `before`, `getOpt`, `isSome`, `valOf`, `print`, `ref`, `!`, `:=`; structure `General` | Supported | |
| basis.bool | `Bool`: `not`, `toString`, `fromString` | Supported | |
| basis.int | `Int`: `precision`, `minInt`, `maxInt`, `toInt`, `fromInt`, `toLarge`, `fromLarge`, arithmetic, `quot`, `rem`, `abs`, `min`, `max`, `sign`, `sameSign`, `compare`, comparisons, `toString`, `fromString` | Partial | `fromString` parses decimal only; no `fmt`/`scan`. `toLarge`/`fromLarge` convert to/from `IntInf`. |
| basis.word | `Word`: `wordSize`, conversions, arithmetic, comparisons, `andb`, `orb`, `xorb`, `notb`, `<<`, `>>`, `~>>`, `min`, `max`, `compare`, `toString`, `fromString` | Partial | `toString`/`fromString` are hexadecimal; no `fmt`/`scan`. `toLargeInt`/`toLargeIntX`/`fromLargeInt` go through `IntInf`. |
| basis.real | `Real`: arithmetic, comparisons, `==`, `!=`, `isNan`, `isFinite`, `isNormal`, `posInf`, `negInf`, `maxFinite`, `minPos`, `sign`, `signBit`, `copySign`, `min`, `max`, `compare`, `fromInt`, `floor`, `ceil`, `round`, `trunc`, `realFloor`..., `toInt`, `toString`, `fromString`, `checkFloat` | Partial | `toString` uses 12 significant digits; no `fmt`/`toDecimal`. |
| basis.math | `Math`: `pi`, `e`, `sqrt`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `exp`, `ln`, `log10`, `pow`, `sinh`, `cosh`, `tanh` | Supported | Also available as `Real.Math`. |
| basis.char | `Char`: `ord`, `chr`, `minChar`, `maxChar`, `maxOrd`, `succ`, `pred`, comparisons, `compare`, `contains`, `notContains`, `is*` predicates, `toLower`, `toUpper`, `toString`, `fromString` | Supported | |
| basis.string | `String`: `maxSize`, `size`, `sub`, `extract`, `substring`, `^`, `concat`, `concatWith`, `str`, `implode`, `explode`, `map`, `translate`, `tokens`, `fields`, `isPrefix`, `isSuffix`, `isSubstring`, `compare`, `collate`, comparisons, `toString`, `fromString` | Partial | No `Substring` structure; no `scan`. |
| basis.list | `List`: `null`, `hd`, `tl`, `last`, `getItem`, `nth`, `take`, `drop`, `length`, `rev`, `@`, `concat`, `revAppend`, `app`, `map`, `mapPartial`, `find`, `filter`, `partition`, `foldl`, `foldr`, `exists`, `all`, `tabulate`, `collate` | Supported | |
| basis.listpair | `ListPair`: `zip`, `zipEq`, `unzip`, `app`, `appEq`, `map`, `mapEq`, `foldl`, `foldr`, `foldlEq`, `foldrEq`, `all`, `exists`, `allEq`, `UnequalLengths` | Supported | |
| basis.option | `Option`: `getOpt`, `isSome`, `valOf`, `filter`, `join`, `app`, `map`, `mapPartial`, `compose`, `composePartial` | Supported | |
| basis.array | `Array`: `array`, `fromList`, `tabulate`, `length`, `sub`, `update`, `app`, `appi`, `modify`, `modifyi`, `foldl`, `foldli`, `foldr`, `foldri`, `toList`, `vector`, `find`, `findi`, `exists`, `all`, `copy`, `collate` | Partial | `copy` takes `{src, dst, di}`; no slices. |
| basis.vector | `Vector`: `fromList`, `tabulate`, `length`, `sub`, `update`, `app`, `appi`, `map`, `mapi`, `foldl`, `foldli`, `foldr`, `foldri`, `toList`, `concat`, `find`, `findi`, `exists`, `all`, `collate` | Supported | Vectors have structural equality. |
| basis.textio | `TextIO`: `stdIn`, `stdOut`, `stdErr`, `openIn`, `openOut`, `openAppend`, `output`, `output1`, `outputSubstr`, `flushOut`, `print`, `inputLine`, `inputAll`, `closeIn`, `closeOut` | Partial | No `input1`, `inputN`, `endOfStream`, `lookahead` or `StreamIO`. |
| basis.commandline | `CommandLine`: `name`, `arguments` | Supported | |
| basis.os.process | `OS.Process`: `status`, `success`, `failure`, `isSuccess`, `exit`, `terminate`; `OS.SysErr`, `OS.syserror` | Supported | |
| basis.toplevel | Top-level aliases: `@ ^ app map foldl foldr rev length null hd tl size str concat implode explode substring ord chr real floor ceil round trunc vector` | Supported | |
| basis.textio.files | File streams: `TextIO.openIn`, `openOut`, `openAppend`, reading and writing files; errors raise `IO.Io {name, function, cause}` with `cause` `OS.SysErr` or `IO.ClosedStream` | Supported | Streams are concrete datatypes carrying a VM file handle. |
| basis.binio | `BinIO`: `openIn`, `openOut`, `openAppend`, `closeIn`, `closeOut`, `output`, `inputAll`, `flushOut`; `Byte`: `bytesToString`, `stringToBytes`; `Word8Vector`: `vector`, `length` | Partial | `Word8Vector.vector` is `string`; no `Word8`, no element access. |
| basis.substring | `Substring` | Planned | |
| basis.intinf | `IntInf`: `int`, `precision`, `minInt`, `maxInt`, `fromInt`, `toInt`, `toLarge`, `fromLarge`, `~`, `+`, `-`, `*`, `div`, `mod`, `quot`, `rem`, `divMod`, `quotRem`, `abs`, `min`, `max`, `sign`, `sameSign`, `compare`, comparisons, `pow`, `toString`, `fromString`; `LargeInt` = `IntInf` | Partial | Implemented in SML with base-2^30 limbs. No `IntInf` literals or overloading: write `IntInf.fromInt n`, `IntInf.+ (a, b)`. No bit operations, `log2`, `fmt` or `scan`. |

Tags of `option` (`NONE` = 0, `SOME` = 1) and `order` are fixed by the basis
because VM primitives construct these values directly.
