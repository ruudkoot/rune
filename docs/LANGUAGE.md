# Rune language contract

## Current status

Rune implements the M1 expression subset and M2 functions, tuples, and polymorphic
typing, emitting version 2 bytecode for the C VM. M3 adds garbage collection and
bounded heap controls. Rune 0.1.0 completes the M0–M4 acceptance gates under all
three host-built compilers. Identical bytecode passes the corpus on native
x86-64 Linux and QEMU-emulated i386 (32-bit little-endian) and PowerPC64 (64-bit
big-endian) Linux VMs. M4 adds portability checks without changing the language
subset; M5 features remain deferred. The [implementation plan](PLAN.md) records
the results and remaining platform gaps. See [BUILD.md](BUILD.md) for commands.

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
| bind-val | Sequential `val` declarations and lexical names | implemented | First slice | Variable, wildcard, unit, and tuple patterns; shadowing; no declaration `and` |
| expr-let | `let ... in ... end` and parentheses | implemented | First slice | Sequential local declarations and expression bodies |
| expr-if | `if ... then ... else ...` | implemented | First slice | Boolean condition; branches have the same type |
| expr-ops | Fixed integer, boolean, and string operators | implemented | First slice | Operator inventory below; no real/word overloading or user fixity |
| expr-sequence | Expression sequencing | implemented | First slice | Parenthesized or `let` body sequences; evaluate left to right |
| basis-output | `print`, `Int.toString`, `not`, `~` | implemented | First slice | Only the listed signatures; built-in values can be aliased, selected by if, and applied |
| type-static | Static type checking | implemented | First slice | Reject ill-typed programs before producing bytecode |
| fn-closures | `fn`, application, lexical closures, currying | implemented | v0.1 / M2 | Irrefutable parameters, one match clause; functions are first-class |
| fn-recursion | Recursive `fun` declarations | implemented | v0.1 / M2 | Single clause; one function per declaration; curried parameters; tail calls |
| data-tuples | Tuples and tuple destructuring | implemented | v0.1 / M2 | Arity at least two; variable, wildcard, unit, and nested tuple patterns |
| type-poly | Let polymorphism and equality types | implemented | v0.1 / M2 | Hindley–Milner inference, occurs check, SML value restriction, equality constraints |
| runtime-gc | Garbage collection and bounded heap | implemented | v0.1 / M3 | Non-moving mark-and-sweep; 64 MiB default heap; active locals retain values until frame release or replacement |
| data-datatypes | Lists, datatypes, constructor patterns, `case` | deferred | Deferred / M5 | Includes user constructors, multi-clause matches, `Match`, and `Bind` |
| control-exceptions | `exception`, `raise`, `handle` | deferred | Deferred / M5 | Runtime arithmetic failures exist earlier; user exception handling does not |
| data-mutation | References, assignment, `while`, arrays, vectors | deferred | Deferred / M5 | No user-visible mutable storage in v0.1 |
| data-records | Records, selectors, flexible record patterns | deferred | Deferred / M5 | Tuples arrive earlier; other record syntax is rejected |
| decl-types | Type annotations and explicit type declarations | deferred | Deferred / M5 | Includes explicit type-variable syntax, `type`, `eqtype`, `abstype`, and `withtype` where applicable |
| decl-advanced | Remaining declaration and fixity forms | deferred | Deferred / M5 | `and`, explicit `val rec`, `local`, `open`, `infix`, `infixr`, `nonfix`, and `op` |
| modules | Structures, signatures, functors, sharing, ascription | deferred | Deferred / M5 | Built-in `Int.toString` is available without user-defined modules |
| numeric-more | Reals, words, chars, target `IntInf`, other literal forms | deferred | Deferred / M5 | Host `IntInf` may be used internally without exposing it in Rune |
| basis-more | Other Basis Library facilities | deferred | Deferred / M5 | No file I/O, OS interface, sockets, threads, or general library access in v0.1 |
<!-- features:end -->

## Program model

A file is a sequence of `val` and `fun` declarations, optionally separated by
semicolons; there is no implicit interactive `it` binding. Evaluate initializers in source
order. `val x = e` evaluates `e` using the preceding environment and then binds
`x`; `val _ = e` evaluates and discards its value. `let` introduces a lexical scope.
The program finishes after its last declaration. No `main` function is required.

Expressions include the listed literals, bound names, parentheses, `let`, `if`,
tuples, functions, the fixed operators, sequencing, and the built-in calls below. Parse the
whole file; trailing unrecognized tokens are errors. Applications can call the
four built-in function values below and user closures, including aliases or values
selected by `if`. Function application is unary and associates to the left;
`fun f x y = e` defines a curried function, so `f x` returns a closure.
A recursive `fun` binding is in scope within its own body. Plain `val` remains
non-recursive. Functions can escape their defining scope and retain captured values.

Source syntax initially uses ASCII letters/digits and SML alphanumeric identifier
conventions, including underscores and primes after the first character. `_` is
a wildcard, not a value name. Other symbolic identifiers, leading underscores
in names, explicit type variables, and Unicode identifiers are unsupported.
Qualified alphanumeric names are lexed, but only the predeclared `Int.toString` binding is available.

String literals represent bytes. Supported SML escapes include backslash,
quote, named control characters (`\a`, `\b`, `\t`, `\n`, `\v`, `\f`, `\r`),
three-digit decimal byte escapes, control escapes, and whitespace gaps. Reject
malformed/out-of-range escapes, raw control bytes, and unterminated strings.
UTF-8 text can be carried as bytes; Unicode identifier processing is
outside the initial subset.

## Implemented grammar

The grammar below omits comments and whitespace. `name` is an alphanumeric name
starting with an ASCII letter and continuing with ASCII letters, digits, `_`, or
`'`. `qualified-name` consists of such names separated by dots. Reserved SML
keywords cannot be names. Rune recognizes deferred keywords and rejects them with
an `unsupported` diagnostic. Unknown qualified names also report `unsupported`;
unknown unqualified names report `scope`.

Deferred predefined infix names (`o`, `before`) and constructors (`nil`, `NONE`,
`SOME`, `LESS`, `EQUAL`, `GREATER`, `ref`, and the standard exception constructors)
from the [initial Basis](https://smlfamily.github.io/Basis/top-level-chapter.html)
are rejected as unsupported. They cannot be treated as ordinary variable patterns
without changing SML's binding semantics. In particular, `val nil = 1` is rejected.

```text
program      = { declaration | ";" } EOF
 declaration = "val" pattern "=" expression
             | "fun" name pattern { pattern } "=" expression
 pattern     = name | "_" | "()" | "(" pattern ")"
             | "(" pattern "," pattern { "," pattern } ")"
 expression  = "if" expression "then" expression "else" expression
             | "fn" pattern "=>" expression
             | boolean-or
 boolean-or  = boolean-and [ "orelse" expression ]
 boolean-and = infix-expression [ "andalso" boolean-rhs ]
 boolean-rhs = "if" expression "then" expression "else" expression
             | "fn" pattern "=>" expression
             | boolean-and
 infix-expression = application { infix-operator application }
 application = atom { atom }
 atom        = decimal-integer | string | "true" | "false" | "()"
             | name | qualified-name | "~"
             | "(" sequence ")"
             | "(" expression "," expression { "," expression } ")"
             | "let" { declaration | ";" } "in" sequence "end"
 sequence    = expression { ";" expression }
 decimal-integer = [ "~" ] digit { digit }
```

Apply the precedence table below when grouping `infix-expression`; boolean
forms associate to the right. An `if` or `fn` in the right operand of a boolean
form extends through its complete branches or body. Application arguments are
atoms: parenthesize an `if` or `fn` argument. Empty `()` is a unit expression and
a unit pattern; `val () = e` requires a unit initializer. A sequence needs an
expression after each semicolon. The `let` declaration section may be empty.

Signed literals require `~` adjacent to digits; separated `~` uses ordinary
application. Symbolic tokens use maximal munch: `1 + ~2` is accepted; `1+~2`
contains the unsupported symbolic token `+~`. Symbolic identifier bindings,
`op`, literal/constructor patterns, annotations, and declaration `and` are deferred.
Each `fn` or `fun` has one clause; `fun` declares one function at a time.
Duplicate names within a pattern or across one `fun` parameter list are errors.
Nested `fn` expressions may shadow an earlier parameter.

## Operators and built-ins

Implemented precedence, highest first; parentheses override grouping:

| Form | Associativity / behavior | Types in the subset |
| --- | --- | --- |
| Application | Left-associative; built-ins and user closures | If `f : 'a -> 'b` and `x : 'a`, then `f x : 'b` |
| `*`, `div`, `mod` | Left-associative; SML precedence 7 | `int * int -> int` |
| `+`, `-`, `^` | Left-associative; SML precedence 6 | Integer arithmetic; string concatenation for `^` |
| `=`, `<>`, `<`, `<=`, `>`, `>=` | Left-associative; SML precedence 4 | Equality as below; ordering for integers only |
| `andalso` | Right-associative, short-circuit; binds more tightly than `orelse` | `bool` operands/result |
| `orelse` | Right-associative, short-circuit | `bool` operands/result |
| Type annotation, handlers, other operators | Deferred | Reject until documented as supported |

Negation `~` and `not` use prefix application syntax; a leading `~` is also part
of a signed integer literal. Short-circuit forms and sequencing are syntax, not
ordinary function calls. Their grouping with `if` and `let` follows the grammar
above. A `fn` body extends as far to the right as the grammar permits.

Equality accepts matching scalar types (`int`, `bool`, `string`, `unit`),
structural tuples, and polymorphic equality with equality-type constraints.
Equality on functions is a static error. String ordering is deferred
even though string equality is included. Ordinary operators and built-ins obey
lexical binding/shadowing rules within accepted syntax; they are not unshadowable
magic names. Infix operators need not be exposed through deferred `op` syntax.

Initial Basis inventory, in addition to the listed operators and literals:

| Binding | Type |
| --- | --- |
| `print` | `string -> unit` |
| `Int.toString` | `int -> string` |
| `not` | `bool -> bool` |
| `~` | `int -> int` |

`Int.toString` is a predeclared qualified name; other `Int` members and general
structure declarations are not implied. There is no implicit access to the host
compiler's Basis from a compiled Rune program.

## Semantics that must stay consistent across hosts

- **Evaluation:** strict, left-to-right evaluation of accepted applications,
  tuples, sequences, and declaration initializers. `if` evaluates one branch;
  `andalso`/`orelse` evaluate their right operand only when required.
- **Integers:** signed 32-bit values, from `~2147483648` to `2147483647`, on every
  host and VM. Oversized literals are compile errors; arithmetic overflow raises
  the built-in `Overflow` failure. Decimal literals use `~`, not `-`, for their sign.
- **Division:** `div` rounds toward negative infinity; `mod` has the divisor's
  sign when nonzero. Zero divisors raise `Div`. The minimum integer divided by
  `~1` raises `Overflow`; its remainder is zero. These choices follow the
  [Basis integer operations](https://smlfamily.github.io/Basis/integer.html).
- **Runtime exceptions in v0.1:** `Div` and `Overflow` terminate with an uncaught
  exception diagnostic and a nonzero exit status. Source-level exception names,
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
  and `let` bodies preserve tail position. Ordinary calls use explicit VM frames.
- **Inference in M2:** infer types; generalize eligible non-expansive bindings
  according to the SML ’97 value restriction. Literals, names, `fn`, and tuples
  of non-expansive expressions are eligible; applications, conditionals, sequences,
  and `let` expressions are expansive. Expansive bindings keep shared monomorphic
  variables that later uses can constrain. Variables shared with the surrounding
  scope are never generalized. Unification performs occurs checks and propagates
  equality constraints through tuples and type schemes.
- **Patterns in M2:** only irrefutable variable, wildcard, unit, and tuple patterns.
  Reject duplicate bound names; destructuring must agree with the inferred type.
  Literal/constructor patterns and match failure semantics arrive with M5.
- **Limits:** source size 1 MiB; at most 65,536 non-EOF tokens; parser
  nesting, pattern nesting, checked expression-tree depth, and `fun` parameter
  count limited to 256. At most 65,536 binding identities and fresh type variables;
  inference is limited to 1,000,000 type traversal steps per compilation.
  Functions, string constants, total instructions, locals/captures per function,
  tuple arity, active local slots, VM operands, and active frames are capped at
  65,536. Each string is at most 1 MiB; bytecode at most 16 MiB; the default managed
  heap is at most 64 MiB including object headers. Structural equality uses at
  most 65,536 pending comparisons and 1,000,000 comparison steps per operation. Limits fail with
  diagnostics. The heap ceiling does not include bytecode storage, VM stacks,
  or the C allocator's internal overhead.
- **Memory in M3:** non-moving mark-and-sweep collection reclaims unreachable
  strings, tuples, and closures during execution. Tail-recursive programs can
  allocate more than the heap ceiling over time when their retained values fit.
  Constants and source metadata remain live; initialized local slots retain
  values until their frame is released, replaced by a tail call, or the slot is
  overwritten. This includes top-level bindings for the lifetime of the program;
  there is no last-use analysis. A retained graph or single allocation that
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

### Required rejections

```sml
val x = 1 + true                 (* type error *)
val x = if 1 then 2 else 3       (* non-boolean condition *)
val x = missingName              (* unbound identifier *)
val x = 2147483648               (* Rune integer literal out of range *)
```

The test corpus covers these cases individually and rejects deferred forms such
as `datatype`, `case`, `handle`, `ref`, and `structure`. It also rejects function
equality (including functions inside tuples), self-application, polymorphic
recursion, duplicate pattern names, and invalid generalization of expansive values.

## Maintenance

Update this document in the same change as any language behavior change. A feature
is implemented only when accepted examples and relevant rejection/boundary tests
pass using Rune built by SML/NJ, Poly/ML, and MLton. Partial support must list its
limits. See [the contributor rules](../AGENTS.md) and
[documentation checks in the plan](PLAN.md#8-keep-language-documentation-in-sync).
