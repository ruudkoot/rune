# Rune language contract

## Current status

Rune 0.2.0 adds the M5a datatype and pattern-matching increment to the M1–M3
functional subset and emits bytecode v3. It supports parameterized recursive
datatypes, constructor values, `case`, and refutable patterns in `val` and
single-clause functions. The working tree adds M5b polymorphic lists and list
patterns, and M5c multi-clause functions (acceptance checks in progress).
M5a and M5b pass the three-host,
native/emulated VM, and sanitizer acceptance gates. The
[implementation plan](PLAN.md) records validation and remaining platform gaps.
Rune 0.1.0 completed M0–M4 with bytecode v2;
v1/v2 files must be recompiled for the v3 VM. See [BUILD.md](BUILD.md) for commands.

Rune targets Standard ML ’97 syntax and semantics within an explicitly documented
subset. The conformance references are [The Definition of Standard ML, Revised](https://smlfamily.github.io/)
and the separate [Standard ML Basis Library](https://smlfamily.github.io/Basis/).
Omitted syntax must be rejected. Accepted constructs must retain their SML meaning;
implementation limits and any deviations must be documented explicitly.

## Support matrix

This table is generated from `docs/features.tsv`; tests map to the same stable IDs.
`First slice` means M1; `v0.1` includes M1 through M4. An implemented row has
passed its fixtures using Rune built by all three host compilers.

<!-- features:start -->
| ID | Feature | Status | Target | Boundary |
| --- | --- | --- | --- | --- |
| lex-comments | Whitespace and nested `(* ... *)` comments | implemented | First slice | ASCII source syntax initially; diagnose unterminated comments |
| lex-names | Names and reserved tokens | implemented | First slice | Alphanumeric value names; fixed symbolic operators; recognize deferred keywords |
| lit-values | `int`, `bool`, `string`, and `unit` values | implemented | First slice | Signed decimal integers, `true`, `false`, quoted byte strings, `()` |
| bind-val | Sequential `val` declarations and lexical names | implemented | First slice / M5a | Variable, wildcard, unit, tuple, literal, and constructor patterns; Bind on failure; no declaration and |
| expr-let | `let ... in ... end` and parentheses | implemented | First slice | Sequential local declarations and expression bodies |
| expr-if | `if ... then ... else ...` | implemented | First slice | Boolean condition; branches have the same type |
| expr-ops | Fixed integer, boolean, and string operators | implemented | First slice | Operator inventory below; no real/word overloading or user fixity |
| expr-sequence | Expression sequencing | implemented | First slice | Parenthesized or `let` body sequences; evaluate left to right |
| basis-output | `print`, `Int.toString`, `not`, `~` | implemented | First slice | Only the listed signatures; built-in values can be aliased, selected by if, and applied |
| type-static | Static type checking | implemented | First slice | Reject ill-typed programs before producing bytecode |
| fn-closures | `fn`, application, lexical closures, currying | partial | v0.1 / M2; M5a / M5c | Ordered match clauses; refutable parameters; first-class functions and constructors; M5c acceptance pending |
| fn-recursion | Recursive `fun` declarations | partial | v0.1 / M2; M5a / M5c | Ordered clauses with equal arity; one function per declaration; arguments gathered before matching; tail calls; M5c acceptance pending |
| data-tuples | Tuples and tuple destructuring | implemented | v0.1 / M2; M5a | Arity at least two; nested patterns including constructors and literals |
| type-poly | Let polymorphism and equality types | implemented | v0.1 / M2; M5a | Hindley–Milner inference, nominal datatypes, constructor value restriction, equality constraints |
| runtime-gc | Garbage collection and bounded heap | implemented | v0.1 / M3 | Non-moving mark-and-sweep; 64 MiB default heap; active locals retain values until frame release or replacement |
| data-datatypes | Lists, datatypes, constructor patterns, `case` | partial | M5a / M5b / M5c | Parameterized recursive datatypes, lists, constructors, case, multi-clause functions, Match/Bind, match warnings; mutual datatypes, replication, withtype deferred |
| control-exceptions | `exception`, `raise`, `handle` | deferred | Deferred / M5 | Runtime arithmetic failures exist earlier; user exception handling does not |
| data-mutation | References, assignment, `while`, arrays, vectors | deferred | Deferred / M5 | No user-visible mutable storage in v0.1 |
| data-records | Records, selectors, flexible record patterns | deferred | Deferred / M5 | Tuples arrive earlier; other record syntax is rejected |
| decl-types | Type annotations and explicit type declarations | partial | M5a | Type parameters and payload types in datatype declarations; annotations, type, eqtype, abstype, withtype deferred |
| decl-advanced | Remaining declaration and fixity forms | deferred | Deferred / M5 | `and`, explicit `val rec`, `local`, `open`, `infix`, `infixr`, `nonfix`, and `op` |
| modules | Structures, signatures, functors, sharing, ascription | deferred | Deferred / M5 | Built-in `Int.toString` is available without user-defined modules |
| numeric-more | Reals, words, chars, target `IntInf`, other literal forms | deferred | Deferred / M5 | Host `IntInf` may be used internally without exposing it in Rune |
| basis-more | Other Basis Library facilities | deferred | Deferred / M5 | No file I/O, OS interface, sockets, threads, or general library access in v0.1 |
<!-- features:end -->

## Program model

A file is a sequence of `val`, `fun`, and `datatype` declarations, optionally
separated by semicolons; there is no implicit interactive `it` binding. Evaluate
initializers in source order. `val x = e` evaluates `e` using the preceding environment and then binds
`x`; `val _ = e` evaluates and discards its value. `let` introduces a lexical scope.
The program finishes after its last declaration. No `main` function is required.

Expressions include the listed literals, bound names, parentheses, `let`, `if`,
tuples, lists, functions, `case`, the fixed operators, sequencing, and the built-in calls
below. Parse the whole file; trailing unrecognized tokens are errors. Applications can call the
four built-in function values below, user closures, and unary constructors,
including aliases or values selected by `if`. Function application is unary and associates to the left;
`fun f x y = e` defines a curried function, so `f x` returns a closure.
A recursive `fun` binding is in scope within its own body. Plain `val` remains
non-recursive. Functions can escape their defining scope and retain captured values.

Source syntax initially uses ASCII letters/digits and SML alphanumeric identifier
conventions, including underscores and primes after the first character. `_` is
a wildcard, not a value name. Other symbolic identifiers, leading underscores
in names and Unicode identifiers are unsupported. Explicit type variables are
accepted only in datatype parameters and payload types.
Qualified alphanumeric names are lexed, but only the predeclared `Int.toString` binding is available.

String literals represent bytes. Supported SML escapes include backslash,
quote, named control characters (`\a`, `\b`, `\t`, `\n`, `\v`, `\f`, `\r`),
three-digit decimal byte escapes, control escapes, and whitespace gaps. Reject
malformed/out-of-range escapes, raw control bytes, and unterminated strings.
UTF-8 text can be carried as bytes; Unicode identifier processing is
outside the initial subset.

## Datatypes and matching (M5a)

One `datatype` declaration introduces a fresh nominal type constructor and
nullary or unary value constructors. Parameters may be ordinary (`'a`) or
equality (`''a`) variables. Payload types support named types, parameters,
postfix type application, products, arrows, and parentheses. Declarations may
be recursive in their own type name, but declaration `and`, replication, and
`withtype` remain unsupported. A locally introduced type cannot escape its
`let`, including through an outer unification variable.

Constructor status belongs to the lexical value binding. A constructor name in
a pattern tests that constructor; a normal value name binds a variable. A `val`
alias of a constructor is an ordinary value, not another pattern constructor.
Direct constructor application to a non-expansive argument is non-expansive;
application through an ordinary alias remains expansive. Datatype equality is
nominal and structural: the type constructor must admit equality and all its
actual parameters must admit equality, including unused parameters. Recursive
datatype equality is the greatest solution consistent with its payloads.

`case e of p => e | ...` evaluates its scrutinee once and tries clauses in source
order. Patterns include constructors, integer/string/boolean literals, and the
existing variable, wildcard, unit, and tuple forms. Failed `val` patterns raise
uncaught `Bind`; exhausted `case`, `fn`, and `fun` matches raise uncaught `Match`.
Both terminate with VM status 3 and a source location. Curried
`fun` collects all arguments before matching its parameters. Match analysis
warns about redundant clauses and non-exhaustive matches while compiling them;
non-exhaustive `val` warns only inside `let`. Analysis is bounded by 1,000,000
steps and depth 512, with a `limit` diagnostic on exhaustion.

Predeclared option/order constructors, general
type annotations, and exception handlers remain deferred. These choices follow
the [SML Definition](https://smlfamily.github.io/sml97-defn.pdf), sections 4.7,
4.10–4.11 and Appendix A; the reference fixtures check the observable behavior.

Reference checks account for observed SML/NJ 110.79 differences: it accepts
escaping local datatypes (including through lists), ignores explicit equality
constraints on datatype parameters, and permits rebinding `nil` through `fun`
and `datatype` in the rejection probes. Poly/ML 5.7.1 and MLton 20210117 reject these
cases. They have explicit per-host reference coverage; Rune rejects them under
all three compiler builds. This does not weaken Rune's cross-host gate.

## Lists (M5b)

The initial environment contains the polymorphic type `'a list`, the nullary
constructor `nil : 'a list`, and the unary constructor
`:: : 'a * 'a list -> 'a list`. List expressions `[]`, `[e1, ..., en]`, and
`head :: tail` use these constructors. `::` is fixed right-associative infix
at precedence 5, between arithmetic/string concatenation and comparisons.
Elements evaluate left to right; constructing the tail follows evaluation of
the head. The empty list allocates no managed object. Nonempty lists use the
existing constructor payload and tuple representation and collector.

List patterns `[]`, `[p1, ..., pn]`, and `head :: tail` work in `case`, `val`,
`fn`, and parenthesized `fun` parameters. Bracket patterns match exactly their
stated length. Constructor application binds more tightly than infix `::`.
Matching, warnings, uncaught `Match`/`Bind`, and curried argument timing follow
the existing datatype rules. `val nil = e` tests for an empty list; it does not
bind a variable. `nil` and `::` cannot be rebound, including by a datatype or
`fun` declaration. The type name `list` can be shadowed by a fresh datatype,
but existing list constructors and bracket syntax retain their original type.

Lists are homogeneous and admit structural equality exactly when their element
type admits equality. Empty lists and lists whose elements are non-expansive
can be generalized; a list containing an expansive expression remains subject
to the value restriction. Lists nest, can contain functions, and can occur in
datatype payload types, including recursive payloads.

Bracket expressions and patterns contain at most 128 elements. They expand to
constructor applications and pairs, so the existing depth limits also apply to
the expanded trees; surrounding expressions or nested elements can reduce the
available depth. This is a source-syntax limit, not a runtime list-length limit.
`@`, `op`, fixity declarations, `List` members, and other list Basis functions
remain unsupported. These rules follow the
[SML Definition](https://smlfamily.github.io/sml97-defn.pdf), sections 2.9 and
Appendices A/C, and the [list datatype](https://smlfamily.github.io/Basis/list.html).

## Multi-clause functions (M5c)

`fn p => e | ...` and `fun f p ... = e | f p ... = e | ...` try their
clauses in source order. Each `fun` clause must repeat the same function name
and have the same positive number of parameters, at most 256. Different names
or parameter counts are syntax errors. `fun` still declares one function at a
time; mutual declarations with `and` are deferred.

Each clause has its own pattern bindings. Names may repeat across clauses, but
duplicates within a clause's pattern or complete parameter list are type errors.
Corresponding arguments have the same types across clauses, and all clause
results have the same type. The recursive function has one monomorphic type
shared by every clause; its completed binding may be generalized. Multi-clause
`fn` expressions are non-expansive, like single-clause functions.

An applied `fn` evaluates its argument once before selecting a clause. A curried
`fun` collects all arguments before testing any patterns: `f x` can return a
closure even when `x` will fail every clause after the remaining arguments arrive.
Nested `fn` expressions match at each application instead. A selected body runs
once; a failure inside it never retries a later clause. If no clause matches,
uncaught `Match` points to the first `fn` parameter pattern or the `fun`
declaration and terminates with status 3. Clause bodies preserve tail position.

Exhaustiveness and redundancy analysis checks complete rows of `fun` parameters,
including correlations between arguments. A non-exhaustive function produces
one warning for the whole match, including a single-clause `fun` with several
refutable parameters. Redundant clauses warn at their pattern (or parameter-row)
position. Both warnings permit compilation. The existing 1,000,000-step and
depth-512 match-analysis limits apply per complete function match. Clause counts
are bounded by the source/token and analysis limits rather than a separate cap.

Lowering reuses closures, tuples, and `case`. Fully applying a multi-clause
`fun` with two or more parameters allocates an argument tuple for matching.
Generated currying and that tuple do not count toward source-tree depth limits;
expanded list patterns still do. Generated patterns participate in the existing
match-analysis depth/work limits, and emitted code uses the existing resource
limits. Bytecode remains v3; the VM and instruction semantics are unchanged.
These rules follow the [SML Definition](https://smlfamily.github.io/sml97-defn.pdf),
sections 2.8 and 4.11 and Appendix A, Figure 17.

## Implemented grammar

The grammar below omits comments and whitespace. `name` is an alphanumeric name
starting with an ASCII letter and continuing with ASCII letters, digits, `_`, or
`'`. `qualified-name` consists of such names separated by dots. Reserved SML
keywords cannot be names. Rune recognizes deferred keywords and rejects them with
an `unsupported` diagnostic. Unknown qualified value names report `unsupported`;
unknown unqualified value names report `scope`. Unknown payload type names report
`type`.

Deferred predefined infix names (`o`, `before`) and constructors (`NONE`,
`SOME`, `LESS`, `EQUAL`, `GREATER`, `ref`, and the standard exception constructors)
from the [initial Basis](https://smlfamily.github.io/Basis/top-level-chapter.html)
are rejected as unsupported. They cannot be treated as ordinary variable patterns
without changing SML's binding semantics. `val nil = 1` is a type error.

```text
program      = { declaration | ";" } EOF
 declaration = "val" pattern "=" expression
             | "fun" fun-clause { "|" fun-clause }
             | "datatype" type-parameters name "=" constructor { "|" constructor }
 fun-clause  = name atomic-pattern { atomic-pattern } "=" expression
 type-parameters = [ type-variable | "(" type-variable { "," type-variable } ")" ]
 constructor = name [ "of" type ]
 type        = type-product [ "->" type ]
 type-product = type-application { "*" type-application }
 type-application = type-atom { name }
 type-atom   = type-variable | name | "(" type ")"
             | "(" type "," type { "," type } ")" name
 pattern     = constructor-pattern [ "::" pattern ]
 constructor-pattern = atomic-pattern | name atomic-pattern
 atomic-pattern = name | "_" | "()" | decimal-integer | string | "true" | "false"
             | "(" pattern ")" | "(" pattern "," pattern { "," pattern } ")"
             | "[" [ pattern { "," pattern } ] "]"
 match       = pattern "=>" expression { "|" pattern "=>" expression }
 expression  = "if" expression "then" expression "else" expression
             | "fn" match
             | "case" expression "of" match
             | boolean-or
 boolean-or  = boolean-and [ "orelse" expression ]
 boolean-and = infix-expression [ "andalso" boolean-rhs ]
 boolean-rhs = "if" expression "then" expression "else" expression
             | "fn" match
             | "case" expression "of" match
             | boolean-and
 infix-expression = application { infix-operator application }
 application = atom { atom }
 atom        = decimal-integer | string | "true" | "false" | "()"
             | name | qualified-name | "~"
             | "(" sequence ")"
             | "(" expression "," expression { "," expression } ")"
             | "[" [ expression { "," expression } ] "]"
             | "let" { declaration | ";" } "in" sequence "end"
 sequence    = expression { ";" expression }
 decimal-integer = [ "~" ] digit { digit }
```

Apply the precedence table below when grouping `infix-expression`; boolean
forms associate to the right. An `if`, `fn`, or `case` in a boolean right operand extends through its complete branches or body. Application arguments are
atoms: parenthesize an `if`, `fn`, or `case` argument. Empty `()` is a unit
expression and a unit pattern; `val () = e` requires a unit initializer. A sequence needs an
expression after each semicolon. The `let` declaration section may be empty.

Signed literals require `~` adjacent to digits; separated `~` uses ordinary
application. Symbolic tokens use maximal munch: `1 + ~2` is accepted; `1+~2`
contains the unsupported symbolic token `+~`. Symbolic identifier bindings,
`op`, expression annotations, and declaration `and` are deferred.
Each `fn` or `fun` has one or more clauses; `fun` declares one function at a time.
Duplicate names within a pattern or across one clause's `fun` parameter list are errors.
Nested `fn` expressions may shadow an earlier parameter. Constructor application
patterns in a `fun` parameter must be parenthesized, e.g. `fun f (C x) y = x`.
A match body extends to the right; an unparenthesized nested `case` or `fn` owns
following `|` clauses. Parenthesize a nested match/function when an outer
`case`, `fn`, or `fun` should consume the next `|`. Misplaced bars can therefore
cause syntax or type errors in the inner match.

In payload types, postfix type application binds more tightly than products,
which bind more tightly than right-associative arrows. Type applications must
have the declared arity. Parameters start with `'` or `''` and continue with
ASCII letters/digits, underscores or primes; a lone `'` or `''` is rejected.
Duplicate parameters, duplicate constructors, unbound parameters, and unknown
type names are errors. Names of deferred predefined constructors remain rejected
even in datatype declarations; qualified constructors and type names are deferred.

## Operators and built-ins

Implemented precedence, highest first; parentheses override grouping:

| Form | Associativity / behavior | Types in the subset |
| --- | --- | --- |
| Application | Left-associative; built-ins, user closures, and constructors | If `f : 'a -> 'b` and `x : 'a`, then `f x : 'b` |
| `*`, `div`, `mod` | Left-associative; SML precedence 7 | `int * int -> int` |
| `+`, `-`, `^` | Left-associative; SML precedence 6 | Integer arithmetic; string concatenation for `^` |
| `::` | Right-associative; SML precedence 5 | `'a * 'a list -> 'a list` |
| `=`, `<>`, `<`, `<=`, `>`, `>=` | Left-associative; SML precedence 4 | Equality as below; ordering for integers only |
| `andalso` | Right-associative, short-circuit; binds more tightly than `orelse` | `bool` operands/result |
| `orelse` | Right-associative, short-circuit | `bool` operands/result |
| Type annotation, handlers, other operators | Deferred | Reject until documented as supported |

Negation `~` and `not` use prefix application syntax; a leading `~` is also part
of a signed integer literal. Short-circuit forms and sequencing are syntax, not
ordinary function calls. Their grouping with `if` and `let` follows the grammar
above. A `fn` body extends as far to the right as the grammar permits.

Equality accepts matching scalar types (`int`, `bool`, `string`, `unit`),
structural tuples and datatypes, and polymorphic equality with equality-type
constraints.
Equality on functions is a static error. String ordering is deferred
even though string equality is included. Ordinary operators and built-ins obey
lexical binding/shadowing rules within accepted syntax; they are not unshadowable
magic names, except for the SML-protected constructors `nil` and `::`.
Infix operators need not be exposed through deferred `op` syntax.

Initial Basis inventory, in addition to the listed operators and literals:

| Binding | Type |
| --- | --- |
| `print` | `string -> unit` |
| `Int.toString` | `int -> string` |
| `not` | `bool -> bool` |
| `~` | `int -> int` |
| `nil` | `'a list` (constructor) |
| `::` | `'a * 'a list -> 'a list` (infix constructor) |

`Int.toString` is a predeclared qualified name; other `Int` members and general
structure declarations are not implied. There is no implicit access to the host
compiler's Basis from a compiled Rune program.

## Semantics that must stay consistent across hosts

- **Evaluation:** strict, left-to-right evaluation of accepted applications,
  tuples, list elements, sequences, and declaration initializers. `if` evaluates one branch;
  `andalso`/`orelse` evaluate their right operand only when required.
- **Integers:** signed 32-bit values, from `~2147483648` to `2147483647`, on every
  host and VM. Oversized literals are compile errors; arithmetic overflow raises
  the built-in `Overflow` failure. Decimal literals use `~`, not `-`, for their sign.
- **Division:** `div` rounds toward negative infinity; `mod` has the divisor's
  sign when nonzero. Zero divisors raise `Div`. The minimum integer divided by
  `~1` raises `Overflow`; its remainder is zero. These choices follow the
  [Basis integer operations](https://smlfamily.github.io/Basis/integer.html).
- **Runtime exceptions:** `Div`, `Overflow`, `Match`, and `Bind` terminate with an
  uncaught exception diagnostic and status 3. Source-level exception names,
  `raise`, and `handle` are deferred. Bytecode/resource errors are VM failures,
  not user-catchable SML exceptions.
- **Strings/output:** immutable byte strings, length-aware operations, embedded
  NUL preserved. `print` adds no newline and returns `()`. `Int.toString` uses `~`
  for negative values. Output errors are reported rather than silently ignored.
- **Sequences:** evaluate all expressions in order, discard intermediate values,
  and return the last expression's value; match SML typing for the accepted form.
- **Functions in M2:** lexical scope, first-class closures, curried application,
  and recursion through `fun`. A recursive function is monomorphic in its own
  body; its completed binding may be generalized. No polymorphic recursion.
  Tail-position calls replace the current VM frame, including calls through aliases
  and higher-order parameters. Calls in `if` branches, final sequence expressions,
  `case` clause bodies, and `let` bodies preserve tail position. Ordinary calls use
  explicit VM frames.
- **Inference in M2:** infer types; generalize eligible non-expansive bindings
  according to the SML ’97 value restriction. Literals, names, `fn`, and tuples
  of non-expansive expressions are eligible. List literals follow the same rule
  after expansion to `::` and `nil`. M5a also admits direct constructor
  applications to non-expansive arguments; other applications, conditionals, sequences,
  and `let` expressions are expansive. Expansive bindings keep shared monomorphic
  variables that later uses can constrain. An unresolved type at an expansive
  binding is not itself an error; later uses must agree on its monomorphic type.
  The [later-use regression](../tests/accept/value-restriction-later-use.sml) covers
  acceptance, and [conflicting uses](../tests/reject/value-restriction-later-conflict.sml)
  must be rejected. Variables shared with the surrounding scope are never
  generalized. Unification performs occurs checks and propagates
  equality constraints through tuples, datatype parameters, and type schemes.
- **Patterns:** variable, wildcard, unit, tuple, integer/string/boolean literal,
  constructor, and list patterns. Reject duplicate bound names; destructuring must
  agree with the inferred type. Refutable bindings and matches follow the M5a
  semantics above. Warnings go to stderr and do not change successful exit status.
  Failures point to the `case` expression, first `fn` parameter pattern, `fun`
  declaration, or failed `val` pattern respectively.
- **Limits:** source size 1 MiB; at most 65,536 non-EOF tokens; parser
  nesting, pattern nesting, checked expression/pattern-tree depth, and `fun` parameter
  count limited to 256; bracket list expressions/patterns have at most 128 elements,
  also subject to expanded-tree depth limits. Payload type parsing and checked type-expression depth
  are also limited to 256. At most 65,536 binding identities, datatype identities,
  constructors, and fresh type variables (including the initial list type and
  constructors); inference is limited to 1,000,000 type traversal steps per compilation. Each
  match analysis is limited to 1,000,000 steps and recursion depth 512.
  Functions, string constants, total instructions, locals/captures per function,
  tuple arity, active local slots, VM operands, and active frames are capped at
  65,536. Each string is at most 1 MiB; bytecode at most 16 MiB; the default managed
  heap is at most 64 MiB including object headers. Structural equality uses at
  most 65,536 pending comparisons and 1,000,000 comparison steps per operation. Limits fail with
  diagnostics. The heap ceiling does not include bytecode storage, VM stacks,
  or the C allocator's internal overhead.
- **Memory in M3:** non-moving mark-and-sweep collection reclaims unreachable
  strings, tuples, closures, and unary constructor payloads during execution.
  Tail-recursive programs can
  allocate more than the heap ceiling over time when their retained values fit.
  Constants and source metadata remain live; initialized local slots retain
  values until their frame is released, replaced by a tail call, or the slot is
  overwritten. This includes top-level bindings for the lifetime of the program;
  match temporaries and bindings in failed clauses also follow this rule. There
  is no last-use analysis. A retained graph or single allocation that
  cannot fit after collection fails with `heap limit exceeded` and status 3.
  The VM option `--heap-limit BYTES` lowers the ceiling (1 through 67,108,864
  bytes); `--gc-stress` collects before each managed allocation. These VM controls
  add no Rune syntax or built-ins. Exact heap consumption depends on C object
  sizes on the target platform; integer and bytecode semantics do not.

## Examples

These examples are included from `examples/` and executed by the test suite.
`make check-docs` verifies that their inclusions stay current.

### First slice: expected output `42` followed by a newline

<!-- example:examples/hello.sml:start -->
```sml
val answer = let val x = 6 in x * 7 end
val _ = if answer = 42
        then print (Int.toString answer ^ "\n")
        else print "unexpected\n"
```
<!-- example:examples/hello.sml:end -->

### M2 closures: expected output `42` followed by a newline

<!-- example:examples/closures.sml:start -->
```sml
fun makeAdder x = fn y => x + y
val addTwo = makeAdder 2
val _ = print (Int.toString (addTwo 40) ^ "\n")
```
<!-- example:examples/closures.sml:end -->

### M3 collection: expected output `1` followed by a newline

This tail-recursive program discards strings, tuples, and closures on each
iteration. The test suite runs it with a 16 KiB managed heap.

<!-- example:examples/collection.sml:start -->
```sml
fun loop (n, total) =
  if n = 0 then total
  else let
    val text = Int.toString n ^ "!"
    val next = fn x => if text = "1!" then x + 1 else x
  in loop (n - 1, next total) end
val _ = print (Int.toString (loop (100000, 0)) ^ "\n")
```
<!-- example:examples/collection.sml:end -->

### M5a datatypes: expected output `42` followed by a newline

<!-- example:examples/datatypes.sml:start -->
```sml
datatype 'a tree = Leaf of 'a | Node of 'a tree * 'a tree
fun sum tree =
  case tree of
    Leaf n => n
  | Node (left, right) => sum left + sum right
val _ = print (Int.toString (sum (Node (Leaf 20, Leaf 22))) ^ "\n")
```
<!-- example:examples/datatypes.sml:end -->

### M5b lists: expected output `42` followed by a newline

<!-- example:examples/lists.sml:start -->
```sml
fun map f xs = case xs of [] => [] | x :: rest => f x :: map f rest
fun sum xs = case xs of [] => 0 | x :: rest => x + sum rest
val _ = print (Int.toString (sum (map (fn x => x * 2) [5, 7, 9])) ^ "\n")
```
<!-- example:examples/lists.sml:end -->

### M5c multi-clause functions: expected output `42` followed by a newline

<!-- example:examples/multi-clause.sml:start -->
```sml
fun map f [] = []
  | map f (x :: xs) = f x :: map f xs
fun sum [] = 0
  | sum (x :: xs) = x + sum xs
val _ = print (Int.toString (sum (map (fn x => x * 2) [5,7,9])) ^ "\n")
```
<!-- example:examples/multi-clause.sml:end -->

### Required rejections

```sml
val x = 1 + true                 (* type error *)
val x = if 1 then 2 else 3       (* non-boolean condition *)
val x = missingName              (* unbound identifier *)
val x = 2147483648               (* Rune integer literal out of range *)
```

The test corpus covers these cases individually and rejects deferred forms such
as mutual function declarations, `handle`, `ref`, and `structure`. It also rejects function
equality (including functions inside tuples), self-application, polymorphic
recursion, duplicate pattern names, and invalid generalization of expansive values.

## Maintenance

Update this document in the same change as any language behavior change. A feature
is implemented only when accepted examples and relevant rejection/boundary tests
pass using Rune built by SML/NJ, Poly/ML, and MLton. Partial support must list its
limits. See [the contributor rules](../AGENTS.md) and
[documentation checks in the plan](PLAN.md#8-keep-language-documentation-in-sync).
