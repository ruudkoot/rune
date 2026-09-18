# The Rune language

Rune compiles **Standard ML '97** (the full Core and Modules language of *The
Definition of Standard ML (Revised)*, and the Basis Library subset listed
below) to bytecode for the `runevm` interpreter. This document is the authoritative description of what Rune
accepts; `make check-docs` verifies that every feature marked *Supported* or
*Partial* has a test in `tests/lang/` named `<id>_<something>.sml`, and that
every test corresponds to a row here.

Status values: **Supported** (implemented, tested), **Partial** (implemented
with documented restrictions), **Planned** (not yet implemented; using it is a
compile-time error). The order in which the *Planned* rows and the deviations
below are to be closed is in [plans/sml97.md](plans/sml97.md).

## Deviations from the Definition

These are the choices the Definition leaves to an implementation, plus the
few places where Rune knowingly departs from it. They never make a well-typed
SML program behave differently; they only make Rune accept some programs that
SML rejects, or reject some that SML accepts.

| Topic | Rune behaviour |
|---|---|
| Integer literals | An integer constant is overloaded over the types of kind `int` and defaults to `int`; a word constant likewise over the kind `word`. Besides `int` and `word` these are the types the basis library registers with `_overload`: today `IntInf.int` (= `LargeInt.int`). A constant that its type cannot represent is a compile-time error (`int` and `word` have 64 bits). An `IntInf.int` constant is converted from its digits where it is evaluated, and compared structurally in a pattern. Real constants have the type `real` only. `Int` is 64-bit, `Word` is 64-bit, `Real` is IEEE double. |
| Strings | 8-bit byte strings; `\uXXXX` escapes above 255 are errors. |
| Functors | A functor body is specialised per application (the copy is type-checked against the actual argument, which cannot fail after the check against the parameter signature). This is not observable, but the bytecode contains one copy of the body per application. |
| Programs | Rune is a batch compiler: a static error in any top-level declaration rejects the whole program, and an uncaught exception terminates it. Chapter 8 regards programs as interactive and would skip the failing declaration and continue. |
| Overloading | Overloaded operators and literals are resolved (and defaulted) at the end of the enclosing top-level declaration. `~` is overloaded at `int`, `word` and `real`. |
| Flexible records | The labels of a flexible record pattern (`{a, ...}`) or selector (`#a`) must be determined by the end of the program (Section 4.11 leaves the granularity to the implementation). A generalised flexible record is resolved by any of its uses; the types of the labels it did not mention are then determined per use rather than shared. |
| `_prim "name" : ty` | Extension used by the basis library to access VM primitives. Only allowed with `--allow-prim`. |
| `_overload kind Strid [bits \| via f]` | Extension used by the basis library: a declaration that makes the type `Strid.kind` (`kind` is `int`, `word` or `real`) an overloading type. The overloaded operators at that type are the values `Strid.+`, `Strid.<`, ...; its constants are those of the builtin type restricted to `bits` bits (default 64), or `f digits` for a function `f : string -> Strid.kind`. Only allowed with `--allow-prim`. |
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
| dec.valrec | `val rec f = fn ...` (and mutually recursive with `and`); `rec` after `and` makes the remaining bindings recursive | Supported | Right-hand side must be a `fn`. |
| dec.fun | `fun f x y = ...` curried functions | Supported | |
| dec.fun.clauses | Multiple clauses `fun f 0 = ... \| f n = ...`, mutual recursion with `and` | Supported | All clauses must have the same name and arity. |
| dec.fun.infix | Infix function definitions `fun x ++ y = ...` and `fun (x ++ y) z = ...` | Supported | Requires a prior `infix` directive. |
| dec.type | `type` abbreviations with parameters | Supported | |
| dec.datatype | `datatype` with nullary and unary constructors | Supported | The syntactic restrictions of Section 2.9 are enforced: no duplicate type variables, type constructors, constructors or exception constructors in one declaration; `true`, `false`, `nil`, `::`, `ref` cannot be rebound, nor `it` as a constructor. |
| dec.datatype.poly | Parameterized datatypes `datatype ('a, 'b) t = ...` | Supported | |
| dec.datatype.mutual | Mutually recursive datatypes with `and` | Supported | |
| dec.datatype.withtype | `datatype ... withtype ...` | Supported | |
| dec.datatype.repl | Datatype replication `datatype t = datatype u` | Supported | Also copies the constructors. |
| dec.exception | `exception E`, `exception E of ty`, generative (fresh per evaluation) | Supported | |
| dec.exception.repl | `exception E = F` | Supported | |
| dec.local | `local dec in dec end` | Supported | |
| dec.infix | `infix`, `infixr`, `nonfix` with precedences 0–9, lexically scoped | Supported | Directives carry across the files of one program. |
| dec.structure | `structure S = struct ... end`, `structure S = T`, nested structures, long identifiers | Supported | See the *Modules* section for signatures, ascription and functors. |
| dec.open | `open S T` | Supported | |
| dec.toplevelexp | Top-level expression statements `exp ;` | Supported | Appendix A derived form: `val it = exp`; `it` can be used and rebound afterwards. |
| dec.abstype | `abstype datbind withtype typbind with dec end` | Supported | Outside the body the types are abstract: no constructors, no equality (rule 19). |

## Expressions

| ID | Feature | Status | Notes |
|---|---|---|---|
| exp.literal | Integer, word, real, character and string constants | Supported | |
| exp.tuple | Tuples `(a, b)`, unit `()` | Supported | |
| exp.record | Records `{a = 1, b = "x"}`, structural equality, label order irrelevant | Supported | Fields are evaluated in source order. |
| exp.record.select | Selectors `#lab` (including numeric labels `#2`) | Supported | The record type must be determined by the end of the program. |
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
| pat.record.flex | Flexible record patterns `{a, ...}` | Supported | The full set of labels must be determined by the end of the program. |
| pat.list | List patterns `[]`, `[p1, p2]`, `p :: ps` | Supported | |
| pat.layered | Layered patterns `x as p`, `x : ty as p` | Supported | |
| pat.annot | Typed patterns `p : ty` | Supported | |
| pat.ref | `ref p` patterns | Supported | |

## Types and inference

| ID | Feature | Status | Notes |
|---|---|---|---|
| ty.infer.letpoly | Hindley–Milner inference with let-polymorphism | Supported | |
| ty.infer.valuerestriction | Value restriction (only non-expansive bindings generalize); a top-level declaration may not leave a type variable undetermined (rules 87–89, e.g. `val r = ref nil` is an error) | Supported | |
| ty.overload.default | Overloaded `+ - * div mod / ~ abs < <= > >=` at `int`, `word`, `real`, `char`, `string`; default `int` | Supported | `~` on `int`/`word`/`real`; `abs` on `int`/`real`; `div`/`mod` on `int`/`word`; `/` on `real`. |
| ty.overload.literal | Overloaded integer and word constants (in expressions and patterns) and operators at the types registered by the basis library: `IntInf.int` | Supported | Default `int`/`word`; out-of-range constants are compile-time errors (`tests/errors/err.literal_*`). |
| ty.record.flex | Flexible record types from `#lab` and `{..., ...}` | Supported | |
| ty.annot | Type annotations on expressions and patterns | Supported | |
| ty.tyvar.explicit | Explicit type variables `fun 'a f (x : 'a) = ...`, `''a`; implicit scoping at the outermost value declaration where the variable occurs unguarded (Section 4.6); the variables are rigid in their scope and must be generalised by it (rule 15) | Supported | Type variables in `type`, `datatype`, `exception` declarations and signatures must be bound (by the `tyvarseq`, an enclosing value declaration, or implicitly in `val` specifications). |
| ty.abbrev | Expansion of type abbreviations, arity checking | Supported | |
| ty.eqtype | Equality types: `=` and `<>` have type `''a * ''a -> bool`; `real`, `exn`, function types and abstract types do not admit equality, datatypes admit it when all constructor arguments do (maximised), `ref` and `array` always do | Supported | `eqtype` specifications, `where type` and `sharing` respect the attribute. Overloaded operators at an equality type exclude `real`. |
| ty.exhaustive | Warnings (Section 4.11): `fn`, `case` and `fun` matches that are not exhaustive, redundant rules in any match including `handle`, and non-exhaustive `val` bindings that are not top-level declarations | Supported | Reported on stderr after type checking with the missing case; `--no-warnings` silences them. A failed match still raises `Match` (or `Bind`) at runtime. |

## Modules

| ID | Feature | Status | Notes |
|---|---|---|---|
| mod.strdec.and | Simultaneous structure bindings `structure A = ... and B = ...` | Supported | All right-hand sides see the environment before the declaration. |
| mod.strdec.local | `local strdec in strdec end` with structure declarations | Supported | |
| mod.let | `let strdec in strexp end` | Supported | |
| mod.signature | `signature S = sig ... end and T = ...`, signature identifiers in ascriptions and functor parameters | Supported | Every use of a signature identifier instantiates its flexible type names afresh (rule 65). |
| mod.spec | Specifications: `val`, `type`, `eqtype`, `type t = ty`, `datatype`, `datatype t = datatype u`, `exception`, `structure`, sequencing | Supported | An identifier may be specified only once in a signature (rule 77). `withtype` is not allowed in specifications. |
| mod.include | `include SIG`, `include A B ...`, `include sig ... end` | Supported | |
| mod.wheretype | `SIG where type tyvarseq t = ty and type ...`, also on types of substructures | Supported | The type must be a flexible type of the signature; arity and equality are checked. |
| mod.sharing | `sharing type t = u = ...` | Supported | All types must be flexible types of the signature with the same arity. |
| mod.sharing.structure | `sharing A = B` (derived form: shares all common type constructors) | Supported | Common types whose type functions are already equal are skipped. |
| mod.ascription | Transparent ascription `strexp : SIG`, `structure S : SIG = ...`, matching by instantiation and enrichment | Supported | Components not in the signature are hidden. A constructor or exception matched by a `val` specification becomes an ordinary value (5.9). |
| mod.ascription.opaque | Opaque ascription `strexp :> SIG`, `structure S :> SIG = ...` | Supported | The signature's types become fresh abstract types; `eqtype` and `datatype` specifications keep equality. |
| mod.functor | `functor F (X : SIG) = strexp`, `functor F (spec) = strexp`, application `F (strexp)` and `F (strdec)`, `and` | Supported | The body is type-checked once against the parameter signature; each application elaborates and compiles a copy of the body specialised to the argument (rule 54). |
| mod.functor.result | Result ascription `functor F (X : S) : R = ...` and `:> R` | Supported | |
| mod.functor.generative | Datatypes and exceptions declared in a functor body are fresh for every application | Supported | |
| mod.functor.nested | Functor application inside functor bodies, functor results as arguments | Supported | |

## Definition coverage

Where each part of the Definition is exercised. The rows are the ids above.

| Definition | Rows |
|---|---|
| 2.2–2.5 special constants, comments, identifiers | lex.int, lex.word, lex.real, lex.char, lex.string, lex.comments, lex.ident |
| 2.6 infixed operators, `op` | dec.infix, exp.infix, exp.op, dec.fun.infix |
| 2.8 atomic expressions | exp.literal, exp.app, exp.record, exp.record.select, exp.tuple, exp.list, exp.seq, exp.let |
| 2.8 expressions and matches | exp.app, exp.infix, exp.annot, exp.boolops, exp.handle, exp.raise, exp.if, exp.while, exp.case, exp.fn |
| 2.8 declarations and bindings | dec.val, dec.valrec, dec.fun, dec.fun.clauses, dec.type, dec.datatype, dec.datatype.poly, dec.datatype.mutual, dec.datatype.withtype, dec.datatype.repl, dec.abstype, dec.exception, dec.exception.repl, dec.local, dec.open |
| 2.8 patterns | pat.wild, pat.const, pat.var, pat.con, pat.record, pat.record.flex, pat.tuple, pat.list, pat.layered, pat.annot, pat.ref |
| 2.8 type expressions | ty.tyvar.explicit, ty.abbrev, ty.annot, exp.record |
| 2.9 syntactic restrictions | dec.datatype (notes), dec.valrec, tests/errors/err.rebind_*, err.dup_* |
| 3.4 structure expressions and declarations | dec.structure, mod.strdec.and, mod.strdec.local, mod.let, mod.ascription, mod.ascription.opaque, mod.functor |
| 3.4 signature expressions and specifications | mod.signature, mod.spec, mod.include, mod.wheretype, mod.sharing |
| 3.4 functor and top-level declarations | mod.functor, mod.functor.result, mod.functor.generative, mod.functor.nested |
| 3.5 syntactic restrictions | tests/errors/err.spec_*, err.let_structure, err.let_functor |
| 4.6, rule 15 explicit type variables | ty.tyvar.explicit |
| 4.7–4.8 closure and value restriction | ty.infer.letpoly, ty.infer.valuerestriction |
| 4.9, 4.4 equality | ty.eqtype |
| 4.11 further restrictions | ty.exhaustive, ty.record.flex |
| Chapter 5 static semantics for Modules | mod.ascription, mod.ascription.opaque, mod.wheretype, mod.sharing, mod.sharing.structure, mod.functor.generative |
| Chapter 6 dynamic semantics for the Core | rt.tailcall, rt.deeprec, rt.exn.uncaught, rt.overflow, rt.div, rt.equality, rt.closure, exp.app (evaluation order), dec.exception (generativity) |
| Chapter 7 dynamic semantics for Modules | mod.functor.generative, mod.ascription (hidden components) |
| Chapter 8 programs, rules 87–89 | dec.toplevelexp, ty.infer.valuerestriction |
| Appendix A derived forms | exp.tuple, exp.record.select, exp.case, exp.if, exp.boolops, exp.seq, exp.let, exp.while, exp.list, pat.tuple, pat.list, dec.fun, dec.datatype.withtype, dec.abstype, dec.toplevelexp, mod.ascription, mod.functor, mod.functor.result, mod.spec, mod.include, mod.sharing.structure, mod.wheretype |
| Appendix C, D initial basis | basis.general, ty.eqtype |
| Appendix E overloading | ty.overload.default, ty.overload.literal, exp.literal |

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
| basis.general | Top-level `option`, `order`, `Fail`, `Option`, `Empty`, `Span`, `Unordered`, `not`, `ignore`, `o`, `before`, `getOpt`, `isSome`, `valOf`, `print`, `exnName`, `exnMessage`, `ref`, `!`, `:=`; structure `General` | Supported | |
| basis.bool | `Bool`: `not`, `toString`, `scan`, `fromString` | Supported | |
| basis.int | `Int`: `precision`, `minInt`, `maxInt`, `toInt`, `fromInt`, `toLarge`, `fromLarge`, arithmetic, `quot`, `rem`, `abs`, `min`, `max`, `sign`, `sameSign`, `compare`, comparisons, `fmt`, `toString`, `scan`, `fromString` | Supported | 64 bits. `toLarge`/`fromLarge` convert to/from `IntInf`. |
| basis.word | `Word`: `wordSize`, conversions (`toLarge`..., `toLargeInt`..., `toInt`...), arithmetic, comparisons, `andb`, `orb`, `xorb`, `notb`, `<<`, `>>`, `~>>`, `min`, `max`, `compare`, `fmt`, `toString`, `scan`, `fromString`; `LargeWord` = `Word` | Supported | 64 bits. |
| basis.real | `Real`: all of REAL (arithmetic, `rem`, `*+`, `*-`, comparisons, `==`, `!=`, `?=`, `unordered`, `compare`, `compareReal`, `isNan`, `isFinite`, `isNormal`, `class`, `sign`, `signBit`, `sameSign`, `copySign`, `min`, `max`, `toManExp`, `fromManExp`, `split`, `realMod`, `nextAfter`, `checkFloat`, `realFloor`..., `floor`..., `toInt`, `toLargeInt`, `fromInt`, `fromLargeInt`, `toLarge`, `fromLarge`, `fmt`, `toString`, `scan`, `fromString`, `toDecimal`, `fromDecimal`); `LargeReal` = `Real` | Supported | IEEE double. `toString` is `fmt (GEN NONE)`: `1.0` prints as `1`, `1000.0` as `1E3`. Conversions to and from text are correctly rounded (the C library does them). |
| basis.ieeereal | `IEEEReal`: `Unordered`, `real_order`, `float_class`, `rounding_mode`, `setRoundingMode`, `getRoundingMode`, `decimal_approx`, `toString`, `scan`, `fromString` | Supported | The rounding mode is that of the C library (`fesetround`). |
| basis.math | `Math`: `pi`, `e`, `sqrt`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `exp`, `ln`, `log10`, `pow`, `sinh`, `cosh`, `tanh` | Supported | Also available as `Real.Math`. `pow` follows the table of the specification where C differs (`pow (1.0, NaN)` and `pow (~1.0, inf)` are NaN). |
| basis.char | `Char`: `ord`, `chr`, `minChar`, `maxChar`, `maxOrd`, `succ`, `pred`, comparisons, `compare`, `contains`, `notContains`, `is*` predicates, `toLower`, `toUpper`, `toString`, `scan`, `fromString`, `toCString`, `fromCString` | Supported | An unescaped `"` converts to itself in `scan` and `fromString` (the specification does not say; Poly/ML does the same). `RuneEscape` holds the scanners that `Char` and `String` share. |
| basis.string | `String`: `maxSize`, `size`, `sub`, `extract`, `substring`, `^`, `concat`, `concatWith`, `str`, `implode`, `explode`, `map`, `translate`, `tokens`, `fields`, `isPrefix`, `isSuffix`, `isSubstring`, `compare`, `collate`, comparisons, `toString`, `scan`, `fromString`, `toCString`, `fromCString` | Supported | |
| basis.list | `List`: `null`, `hd`, `tl`, `last`, `getItem`, `nth`, `take`, `drop`, `length`, `rev`, `@`, `concat`, `revAppend`, `app`, `map`, `mapPartial`, `find`, `filter`, `partition`, `foldl`, `foldr`, `exists`, `all`, `tabulate`, `collate` | Supported | |
| basis.listpair | `ListPair`: `zip`, `zipEq`, `unzip`, `app`, `appEq`, `map`, `mapEq`, `foldl`, `foldr`, `foldlEq`, `foldrEq`, `all`, `exists`, `allEq`, `UnequalLengths` | Supported | |
| basis.option | `Option`: `getOpt`, `isSome`, `valOf`, `filter`, `join`, `app`, `map`, `mapPartial`, `compose`, `composePartial` | Supported | |
| basis.array | `Array`: `maxLen`, `array`, `fromList`, `tabulate`, `length`, `sub`, `update`, `vector`, `copy`, `copyVec`, `app`, `appi`, `modify`, `modifyi`, `foldl`, `foldli`, `foldr`, `foldri`, `find`, `findi`, `exists`, `all`, `collate` | Supported | At most 100000000 elements. |
| basis.vector | `Vector`: `fromList`, `tabulate`, `length`, `sub`, `update`, `app`, `appi`, `map`, `mapi`, `foldl`, `foldli`, `foldr`, `foldri`, `toList`, `concat`, `find`, `findi`, `exists`, `all`, `collate` | Supported | Vectors have structural equality. |
| basis.textio | `TextIO`: the imperative members of TEXT_IO (`input`, `input1`, `inputN`, `inputAll`, `canInput`, `lookahead`, `closeIn`, `endOfStream`, `inputLine`, `output`, `output1`, `outputSubstr`, `flushOut`, `closeOut`, `openIn`, `openOut`, `openAppend`, `openString`, `scanStream`, `stdIn`, `stdOut`, `stdErr`, `print`), the conversions to and from `StreamIO`, and `structure StreamIO` | Supported | Built on `TextPrimIO` and the functional streams; `getPosOut`/`setPosOut` and the reader positions need `OS.FileSys`, so they raise `IO.RandomAccessNotSupported` for now. |
| basis.commandline | `CommandLine`: `name`, `arguments` | Supported | |
| basis.toplevel | Top-level aliases: `@ ^ app map foldl foldr rev length null hd tl size str concat implode explode substring ord chr real floor ceil round trunc vector exnName exnMessage` | Supported | They are the values of `lib/basis/pervasive.sml`, which `List`, `String`, `Char`, `Real` and `Vector` take their members of the same name from. |
| basis.time | `Time`: `time`, `Time`, `zeroTime`, `now`, the conversions to and from seconds, milliseconds, microseconds, nanoseconds and `real`, `+`, `-`, `compare`, the comparisons, `fmt`, `toString`, `scan`, `fromString` | Supported | A time is microseconds in an `int`, so about 292,000 years either way. |
| basis.timer | `Timer`: `cpu_timer`, `real_timer`, `startCPUTimer`, `checkCPUTimer`, `checkCPUTimes`, `checkGCTime`, `totalCPUTimer`, `startRealTimer`, `checkRealTimer`, `totalRealTimer` | Partial | The collector's time is not measured on its own, so `checkGCTime` is zero and `checkCPUTimes` reports it all as `nongc`. |
| basis.date | `Date`: `weekday`, `month`, `date`, `Date`, `date`, `year`, `month`, `day`, `hour`, `minute`, `second`, `weekDay`, `yearDay`, `isDst`, `offset`, `localOffset`, `fromTimeLocal`, `fromTimeUniv`, `toTime`, `fmt`, `toString`, `scan`, `fromString`, `compare` | Supported | The calendar of the C library: `fmt` is `strftime`, local time is what the time zone of the system says, and UTC is worked out from the proleptic Gregorian calendar. |
| basis.os.process | `OS.Process`: `status`, `success`, `failure`, `isSuccess`, `system`, `atExit`, `exit`, `terminate`, `getEnv`, `sleep`; `OS.SysErr`, `OS.syserror`, `OS.errorMsg`, `OS.errorName`, `OS.syserror`; `OS.IO.iodesc` | Supported | A `syserror` is an `errno` value. `system` reports what the command exited with, or 128 plus the signal that ended it. The actions of `atExit` run when the program ends or calls `exit`, not when it calls `terminate` and not after an uncaught exception; `RuneExit` holds them and `lib/basis/epilogue.sml`, compiled after a program that uses `OS`, runs them. |
| basis.textio.files | File streams: `TextIO.openIn`, `openOut`, `openAppend`, reading and writing files; errors raise `IO.Io {name, function, cause}` with `cause` `OS.SysErr` or `IO.ClosedStream` | Supported | A stream that has reached the end of a file reads what the file gains afterwards, as the specification's stream model prescribes. |
| basis.binio | `BinIO`: the imperative members of BIN_IO and `structure StreamIO`, over `Word8Vector` | Supported | Built on `BinPrimIO` in the same way as `TextIO`. |
| basis.byte | `Byte`: `byteToChar`, `charToByte`, `bytesToString`, `stringToBytes`, `unpackStringVec`, `unpackString`, `packString` | Supported | |
| basis.io | `IO`: exceptions `Io {name, function, cause}`, `BlockingNotSupported`, `NonblockingNotSupported`, `RandomAccessNotSupported`, `ClosedStream`; datatype `buffer_mode`; signatures `PRIM_IO`, `STREAM_IO`; `TextPrimIO`, `BinPrimIO`; `Position`; the functors `RunePrimIOFn`, `RuneStreamIOFn`, `RuneImperativeIOFn` and `RuneFile`, which holds the VM's file handles | Supported | A writer writes through, so a stream buffers nothing unless `setBufferMode` asks for it; what `BLOCK_BUF` holds is lost if a program ends without flushing (the at-exit actions come with `OS.Process.atExit`). |
| basis.substring | `Substring`: all of SUBSTRING (`base`, `string`, `extract`, `substring`, `full`, `getc`, `first`, `triml`, `trimr`, `slice`, `sub`, `size`, `concat`, `concatWith`, `explode`, `isPrefix`, `isSubstring`, `isSuffix`, `compare`, `collate`, `splitl`, `splitr`, `splitAt`, `dropl`, `dropr`, `takel`, `taker`, `position`, `span`, `translate`, `tokens`, `fields`, `app`, `foldl`, `foldr`) | Supported | `Substring.substring` is `CharVectorSlice.slice`; the top-level type `substring` exists. |
| basis.stringcvt | `StringCvt`: `radix`, `realfmt`, `reader`, `cs`, `padLeft`, `padRight`, `splitl`, `takel`, `dropl`, `skipWS`, `scanString` | Supported | |
| basis.word8 | `Word8`: all of WORD at 8 bits; word constants and the overloaded operators work at `Word8.word`; signature `WORD` | Supported | A minimal instance, there because the byte-oriented structures need it: a `word` whose upper bits are kept zero. |
| basis.vectorslice | `VectorSlice`: all of VECTOR_SLICE | Supported | The `-i` functions pass the index in the slice. |
| basis.arrayslice | `ArraySlice`: all of ARRAY_SLICE | Supported | `copy` is right for overlapping ranges of one array. |
| basis.array2 | `Array2`: all of ARRAY2 (`array`, `fromList`, `tabulate`, `sub`, `update`, `dimensions`, `nCols`, `nRows`, `row`, `column`, `copy`, `appi`, `app`, `foldi`, `fold`, `modifyi`, `modify`; `region`, `traversal`) | Supported | Stored row by row in one array of at most 100000000 elements. |
| basis.word8vector | `Word8Vector`: all of MONO_VECTOR; signatures `MONO_VECTOR`, `MONO_ARRAY`, `MONO_VECTOR_SLICE`, `MONO_ARRAY_SLICE` | Supported | A `Word8Vector.vector` is a `string` (the type is not abstract), which makes `Byte` free and lets `BinIO` share `TextIO`'s streams. The functors `RuneStringVectorFn`, `RuneMonoArrayFn`, `RuneMonoVectorSliceFn`, `RuneMonoArraySliceFn` build the family; each instance has a file of its own. |
| basis.word8vectorslice | `Word8VectorSlice`: all of MONO_VECTOR_SLICE | Supported | |
| basis.word8array | `Word8Array`: all of MONO_ARRAY | Supported | An array of `Word8.word` values, one VM value per byte; a compact byte array is planned. |
| basis.word8arrayslice | `Word8ArraySlice`: all of MONO_ARRAY_SLICE | Supported | |
| basis.charvector | `CharVector`: all of MONO_VECTOR; `CharVector.vector` is `string` | Supported | |
| basis.charvectorslice | `CharVectorSlice`: all of MONO_VECTOR_SLICE; `CharVectorSlice.slice` is `Substring.substring` | Supported | |
| basis.chararray | `CharArray`: all of MONO_ARRAY | Supported | |
| basis.chararrayslice | `CharArraySlice`: all of MONO_ARRAY_SLICE | Supported | |
| basis.text | `Text`: `Char`, `String`, `Substring`, `CharVector`, `CharArray`, `CharVectorSlice`, `CharArraySlice` | Supported | |
| basis.intn | `Int8`, `Int16`, `Int32`, `Int64`, `Word16`, `Word32`, `Word64` | Planned | Omitted for now; see `docs/plans/basis.md`. `Int` and `Word` have 64 bits, `LargeWord` is `Word`, `LargeInt` is `IntInf`. |
| basis.intinf | `IntInf`: `int`, `precision`, `minInt`, `maxInt`, `fromInt`, `toInt`, `toLarge`, `fromLarge`, `~`, `+`, `-`, `*`, `div`, `mod`, `quot`, `rem`, `divMod`, `quotRem`, `abs`, `min`, `max`, `sign`, `sameSign`, `compare`, comparisons, `pow`, `log2`, `andb`, `orb`, `xorb`, `notb`, `<<`, `~>>`, `fmt`, `toString`, `scan`, `fromString`; `LargeInt` = `IntInf` | Supported | Implemented in SML with base-2^30 limbs. Integer constants and the overloaded operators work at `IntInf.int` (`ty.overload.literal`; `RuneIntInf.fromLit` converts the constants). |

Tags of `option` (`NONE` = 0, `SOME` = 1) and `order` are fixed by the basis
because VM primitives construct these values directly.
