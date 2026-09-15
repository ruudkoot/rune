# Rune language contract

## Current status

Rune now implements the M1 expression subset and emits version 1 bytecode for
the C VM. The support table records verification status; later M2–M5 features
remain planned or deferred. The [implementation plan](PLAN.md) defines the
milestones and acceptance checks. See [BUILD.md](BUILD.md) for working commands.

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
| bind-val | Sequential `val` declarations and lexical names | implemented | First slice | One identifier or wildcard binding; shadowing; no declaration `and` |
| expr-let | `let ... in ... end` and parentheses | implemented | First slice | Sequential local declarations and expression bodies |
| expr-if | `if ... then ... else ...` | implemented | First slice | Boolean condition; branches have the same type |
| expr-ops | Fixed integer, boolean, and string operators | implemented | First slice | Operator inventory below; no real/word overloading or user fixity |
| expr-sequence | Expression sequencing | implemented | First slice | Parenthesized or `let` body sequences; evaluate left to right |
| basis-output | `print`, `Int.toString`, `not`, `~` | implemented | First slice | Only the listed signatures; built-in values can be aliased, selected by if, and applied |
| type-static | Static type checking | implemented | First slice | Reject ill-typed programs before producing bytecode |
| fn-closures | `fn`, application, lexical closures, currying | planned | v0.1 / M2 | Irrefutable parameters, one match clause; functions are first-class |
| fn-recursion | Recursive `fun` declarations | planned | v0.1 / M2 | Single clause; one function per declaration; curried parameters; tail calls |
| data-tuples | Tuples and tuple destructuring | planned | v0.1 / M2 | Arity at least two; variable, wildcard, unit, and nested tuple patterns |
| type-poly | Let polymorphism and equality types | planned | v0.1 / M2 | Hindley–Milner inference, occurs check, SML value restriction, equality constraints |
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

## First-slice program model

A file is a sequence of `val` declarations, optionally separated by semicolons;
there is no implicit interactive `it` binding. Evaluate initializers in source
order. `val x = e` evaluates `e` using the preceding environment and then binds
`x`; `val _ = e` evaluates and discards its value. `let` introduces a lexical scope.
The program finishes after its last declaration. No `main` function is required.

Expressions include the listed literals, bound names, parentheses, `let`, `if`,
the fixed operators, sequencing, and the built-in calls listed below. Parse the
whole file; trailing unrecognized tokens are errors. Applications can call the
four built-in function values below, including aliases or values selected by `if`. User-defined functions arrive in M2.

Source syntax initially uses ASCII letters/digits and SML alphanumeric identifier
conventions, including underscores and primes after the first character. `_` is
a wildcard, not a value name. Other symbolic identifiers, leading underscores
in names, type variables, and Unicode identifiers are outside M1. Qualified alphanumeric names are lexed, but
only the predeclared `Int.toString` binding is available.

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
keywords cannot be names. M1 recognizes deferred keywords and rejects them with
an `unsupported` diagnostic. Unknown qualified names also report `unsupported`;
unknown unqualified names report `scope`.

Deferred predefined infix names (`o`, `before`) and constructors (`nil`, `NONE`,
`SOME`, `LESS`, `EQUAL`, `GREATER`, `ref`, and the standard exception constructors)
from the [initial Basis](https://smlfamily.github.io/Basis/top-level-chapter.html)
are rejected as unsupported. They cannot be treated as ordinary variable patterns
without changing SML's binding semantics. In particular, `val nil = 1` is rejected.

```text
program      = { declaration | ";" } EOF
 declaration = "val" (name | "_") "=" expression
 expression  = "if" expression "then" expression "else" expression
             | boolean-or
 boolean-or  = boolean-and [ "orelse" expression ]
 boolean-and = infix-expression [ "andalso" boolean-rhs ]
 boolean-rhs = "if" expression "then" expression "else" expression
             | boolean-and
 infix-expression = application { infix-operator application }
 application = atom { atom }
 atom        = decimal-integer | string | "true" | "false" | "()"
             | name | qualified-name | "~"
             | "(" sequence ")"
             | "let" { declaration | ";" } "in" sequence "end"
 sequence    = expression { ";" expression }
 decimal-integer = [ "~" ] digit { digit }
```

Apply the precedence table below when grouping `infix-expression`; boolean
forms associate to the right. An `if` in the right operand of a boolean form
extends through its complete branches. Application arguments are atoms: use
parentheses around an `if` argument. Empty `()` is a unit expression; `val () = e`
is not yet an accepted binding pattern. A sequence needs an expression after each
semicolon. The `let` declaration section may be empty.

Signed literals require `~` adjacent to digits; separated `~` uses ordinary
application. Symbolic tokens use maximal munch: `1 + ~2` is accepted; `1+~2`
contains the unsupported symbolic token `+~`. Symbolic identifier bindings,
`op`, general patterns, tuples, annotations, and declaration `and` are deferred.

## Operators and built-ins

Implemented precedence, highest first; parentheses override grouping:

| Form | Associativity / behavior | Types in the subset |
| --- | --- | --- |
| Application | Left-associative; built-in function values in M1 | If `f : 'a -> 'b` and `x : 'a`, then `f x : 'b` |
| `*`, `div`, `mod` | Left-associative; SML precedence 7 | `int * int -> int` |
| `+`, `-`, `^` | Left-associative; SML precedence 6 | Integer arithmetic; string concatenation for `^` |
| `=`, `<>`, `<`, `<=`, `>`, `>=` | Left-associative; SML precedence 4 | Equality as below; ordering for integers only |
| `andalso` | Right-associative, short-circuit; binds more tightly than `orelse` | `bool` operands/result |
| `orelse` | Right-associative, short-circuit | `bool` operands/result |
| Type annotation, handlers, other operators | Deferred | Reject until documented as supported |

Negation `~` and `not` use prefix application syntax; a leading `~` is also part
of a signed integer literal. Short-circuit forms and sequencing are syntax, not
ordinary function calls. Their grouping with `if` and `let` follows the grammar
above. `fn` remains deferred.

M1 equality accepts matching scalar types (`int`, `bool`, `string`, `unit`). M2
adds structural tuple equality and polymorphic equality with equality-type
constraints. Equality on functions is a static error. String ordering is deferred
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
- **Inference in M2:** infer types; generalize eligible non-expansive bindings
  according to the SML ’97 value restriction. Unification must perform occurs
  checks and propagate equality constraints. Do not generalize every `val` merely
  because this subset has no references yet.
- **Patterns in M2:** only irrefutable variable, wildcard, unit, and tuple patterns.
  Reject duplicate bound names; destructuring must agree with the inferred type.
  Literal/constructor patterns and match failure semantics arrive with M5.
- **Limits in M1:** source size 1 MiB; at most 65,536 non-EOF tokens; parser
  nesting and checked expression-tree depth 256; local slots, string constants,
  instructions, and VM operand stack at most 65,536; each string at most 1 MiB;
  bytecode at most 16 MiB; VM arena at most 64 MiB including metadata. Limits
  fail with diagnostics. Memory is reclaimed at process exit; GC is deferred.

## Examples

The first example is included from `examples/hello.sml` and executed by the test
suite. `make check-docs` verifies that its inclusion stays current.

### First slice: expected output `42` followed by a newline

<!-- example:examples/hello.sml:start -->
```sml
val answer = let val x = 6 in x * 7 end
val _ = if answer = 42
        then print (Int.toString answer ^ "\n")
        else print "unexpected\n"
```
<!-- example:examples/hello.sml:end -->

### Planned M2 example: expected output `42` followed by a newline

This example requires user-defined functions and is not accepted by M1.

```sml
fun makeAdder x = fn y => x + y
val addTwo = makeAdder 2
val _ = print (Int.toString (addTwo 40) ^ "\n")
```

### Required rejections

```sml
val x = 1 + true                 (* type error *)
val x = if 1 then 2 else 3       (* non-boolean condition *)
val x = missingName              (* unbound identifier *)
val x = 2147483648               (* Rune integer literal out of range *)
```

The test corpus covers these cases individually and rejects deferred forms such
as `fn`, `fun`, `datatype`, `case`, `handle`, `ref`, and `structure`. Function
equality is already rejected for built-in functions; polymorphic self-application
checks arrive in M2.

## Maintenance

Update this document in the same change as any language behavior change. A feature
is implemented only when accepted examples and relevant rejection/boundary tests
pass using Rune built by SML/NJ, Poly/ML, and MLton. Partial support must list its
limits. See [the contributor rules](../AGENTS.md) and
[documentation checks in the plan](PLAN.md#8-keep-language-documentation-in-sync).
