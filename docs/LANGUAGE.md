# Rune language contract

## Current status

**No language features are implemented yet.** This document specifies the proposed
first working subset and v0.1 target. It is not a claim that programs below can
currently be compiled by Rune. The [implementation plan](PLAN.md) defines the
milestones and acceptance checks.

Rune targets Standard ML ’97 syntax and semantics within an explicitly documented
subset. The conformance references are [The Definition of Standard ML, Revised](https://smlfamily.github.io/)
and the separate [Standard ML Basis Library](https://smlfamily.github.io/Basis/).
Omitted syntax must be rejected. Accepted constructs must retain their SML meaning;
implementation limits and any deviations must be documented explicitly.

## Proposed support matrix

Every row currently has status **planned** or **deferred**, never implemented.
`First slice` means M1; `v0.1` includes M1 through M4. Stable IDs will connect this
table to a feature manifest and tests when M0 is implemented.

| ID | Feature | Target | Planned boundary |
| --- | --- | --- | --- |
| lex-comments | Whitespace and nested `(* ... *)` comments | First slice | ASCII source syntax initially; diagnose unterminated comments |
| lex-names | Names and reserved tokens | First slice | Alphanumeric value names; fixed symbolic operators; recognize deferred keywords |
| lit-values | `int`, `bool`, `string`, and `unit` values | First slice | Signed decimal integers, `true`, `false`, quoted byte strings, `()` |
| bind-val | Sequential `val` declarations and lexical names | First slice | One identifier or wildcard binding; shadowing; no declaration `and` |
| expr-let | `let ... in ... end` and parentheses | First slice | Sequential local declarations and expression bodies |
| expr-if | `if ... then ... else ...` | First slice | Boolean condition; branches have the same type |
| expr-ops | Fixed integer, boolean, and string operators | First slice | Operator inventory below; no real/word overloading or user fixity |
| expr-sequence | Expression sequencing | First slice | Parenthesized or `let` body sequences; evaluate left to right |
| basis-output | `print`, `Int.toString`, `not` | First slice | Only the listed signatures; direct calls until general application arrives |
| type-static | Static type checking | First slice | Reject ill-typed programs before producing bytecode |
| fn-closures | `fn`, application, lexical closures, currying | v0.1 / M2 | Irrefutable parameters, one match clause; functions are first-class |
| fn-recursion | Recursive `fun` declarations | v0.1 / M2 | Single clause; one function per declaration; curried parameters; tail calls |
| data-tuples | Tuples and tuple destructuring | v0.1 / M2 | Arity at least two; variable, wildcard, unit, and nested tuple patterns |
| type-poly | Let polymorphism and equality types | v0.1 / M2 | Hindley–Milner inference, occurs check, SML value restriction, equality constraints |
| data-datatypes | Lists, datatypes, constructor patterns, `case` | Deferred / M5 | Includes user constructors, multi-clause matches, `Match`, and `Bind` |
| control-exceptions | `exception`, `raise`, `handle` | Deferred / M5 | Runtime arithmetic failures exist earlier; user exception handling does not |
| data-mutation | References, assignment, `while`, arrays, vectors | Deferred / M5 | No user-visible mutable storage in v0.1 |
| data-records | Records, selectors, flexible record patterns | Deferred / M5 | Tuples arrive earlier; other record syntax is rejected |
| decl-types | Type annotations and explicit type declarations | Deferred / M5 | Includes explicit type-variable syntax, `type`, `eqtype`, `abstype`, and `withtype` where applicable |
| decl-advanced | Remaining declaration and fixity forms | Deferred / M5 | `and`, explicit `val rec`, `local`, `open`, `infix`, `infixr`, `nonfix`, and `op` |
| modules | Structures, signatures, functors, sharing, ascription | Deferred / M5 | Built-in `Int.toString` is available without user-defined modules |
| numeric-more | Reals, words, chars, target `IntInf`, other literal forms | Deferred / M5 | Host `IntInf` may be used internally without exposing it in Rune |
| basis-more | Other Basis Library facilities | Deferred / M5 | No file I/O, OS interface, sockets, threads, or general library access in v0.1 |

## First-slice program model

A file is a sequence of `val` declarations, optionally separated by semicolons;
there is no implicit interactive `it` binding. Evaluate initializers in source
order. `val x = e` evaluates `e` using the preceding environment and then binds
`x`; `val _ = e` evaluates and discards its value. `let` introduces a lexical scope.
The program finishes after its last declaration. No `main` function is required.

Expressions include the listed literals, bound names, parentheses, `let`, `if`,
the fixed operators, sequencing, and the built-in calls listed below. Parse the
whole file; trailing unrecognized tokens are errors. User function application
becomes generally available in M2.

Source syntax initially uses ASCII letters/digits and SML alphanumeric identifier
conventions, including underscores and primes after the first character. `_` is
a wildcard, not a value name. Exact lexical productions and an EBNF grammar must
be added with the parser in M1, covering every implemented production.

String literals represent bytes. Plan to support SML escapes for backslash,
quote, named control characters (`\a`, `\b`, `\t`, `\n`, `\v`, `\f`, `\r`),
three-digit decimal byte escapes, control escapes, and whitespace gaps. Reject
malformed/out-of-range escapes, raw newlines, and unterminated strings. Any
initial escape omission must be marked partial with its exact boundary before
release. UTF-8 text can be carried as bytes; Unicode identifier processing is
outside the initial subset.

## Operators and built-ins

Planned precedence, highest first; parentheses override grouping:

| Form | Associativity / behavior | Types in the subset |
| --- | --- | --- |
| Application | Left-associative; full application in M2 | If `f : 'a -> 'b` and `x : 'a`, then `f x : 'b` |
| `*`, `div`, `mod` | Left-associative; SML precedence 7 | `int * int -> int` |
| `+`, `-`, `^` | Left-associative; SML precedence 6 | Integer arithmetic; string concatenation for `^` |
| `=`, `<>`, `<`, `<=`, `>`, `>=` | Left-associative; SML precedence 4 | Equality as below; ordering for integers only |
| `andalso` | Right-associative, short-circuit; binds more tightly than `orelse` | `bool` operands/result |
| `orelse` | Right-associative, short-circuit | `bool` operands/result |
| Type annotation, handlers, other operators | Deferred | Reject until documented as supported |

Negation `~` and `not` use prefix application syntax; a leading `~` is also part
of a signed integer literal. Short-circuit forms and sequencing are syntax, not
ordinary function calls. The grammar must specify their grouping with `if`, `fn`,
and `let`; do not implement them as eager primitive calls.

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
- **Limits:** bytecode size, function count, stack, heap, and string-length limits
  must be specified alongside the implementation and reported cleanly when
  exceeded. Do not claim unlimited recursion or memory.

## Planned examples

These examples are design targets. Move them into executable example files and
check their documentation inclusions when their milestones are implemented.

### First slice: expected output `42` followed by a newline

```sml
val answer = let val x = 6 in x * 7 end
val _ = if answer = 42
        then print (Int.toString answer ^ "\n")
        else print "unexpected\n"
```

### v0.1: expected output `42` followed by a newline

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

M2 must also reject function equality and self-application. Deferred forms such
as `datatype`, `case`, `handle`, `ref`, and `structure` need clear rejection
examples when the corresponding unsupported-feature checks are introduced.

## Maintenance

Update this document in the same change as any language behavior change. A feature
is implemented only when accepted examples and relevant rejection/boundary tests
pass using Rune built by SML/NJ, Poly/ML, and MLton. Partial support must list its
limits. See [the contributor rules](../AGENTS.md) and
[documentation checks in the plan](PLAN.md#8-keep-language-documentation-in-sync).
