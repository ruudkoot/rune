# The top-level environment

[The Standard ML Basis Library](README.md)

What a program can name without a structure in front. The types `int`, `word`, `real`, `char`,
`string`, `bool`, `list`, `ref`, `array`, `vector`, `exn` and `unit`, the constructors of `bool`,
`list` and `ref`, the arithmetic and comparison operators and the exceptions of the language are
built into the compiler; the rest is declared by the files of the library that every program
loads, and is listed here. A value that is also a member of a structure is described on the page
of that structure's signature.

## Types

|  | Also |  |
| --- | --- | --- |
| `option` | [`Option.option`](sig/OPTION.md#type-option) | The type of optional values, the one of the top-level environment. |
| `order` | [`General.order`](sig/GENERAL.md#type-order) | What a comparison answers: the result of [`Int.compare`](sig/INTEGER.md#val-compare), [`String.compare`](sig/STRING.md#val-compare) and every other `compare` and `collate` of the library. It is the top-level [`order`](sig/GENERAL.md#type-order). |

## Exceptions

|  | Also |  |
| --- | --- | --- |
| `Fail` | [`General.Fail`](sig/GENERAL.md#exn-fail) | Raised where a program has nothing better to raise; its argument says what went wrong. |
| `Option` | [`Option.Option`](sig/OPTION.md#exn-option) | Raised by [`valOf`](sig/OPTION.md#val-valof) when there is no value. It is the top-level [`Option`](sig/OPTION.md). |
| `Empty` | [`List.Empty`](sig/LIST.md#exn-empty) | Raised by [`hd`](sig/LIST.md#val-hd), [`tl`](sig/LIST.md#val-tl) and `last` when they are given the empty list. It is the same exception as the top-level [`Empty`](sig/LIST.md#exn-empty). |
| `Span` | [`General.Span`](sig/GENERAL.md#exn-span) | Raised by [`Substring.span`](sig/SUBSTRING.md#val-span) when its two arguments are not substrings of one string, or lie the wrong way round. |
| `Unordered` |  |  |

## Values

|  | Also |  |
| --- | --- | --- |
| `not` | [`Bool.not`](sig/BOOL.md#val-not) | `not b` is the negation of `b`. |
| `ignore` | [`General.ignore`](sig/GENERAL.md#val-ignore) | `ignore e` is `()`: it throws the value of `e` away. |
| `o` | [`General.o`](sig/GENERAL.md#val-o) | `(f o g) x` is `f (g x)`: the composition of two functions. |
| `before` | [`General.before`](sig/GENERAL.md#val-before) | `e before e'` is `e`, after `e'` has been evaluated for its effect. |
| `getOpt` | [`Option.getOpt`](sig/OPTION.md#val-getopt) | `getOpt (opt, a)` is the value that `opt` carries, or the default `a` if it carries none. |
| `isSome` | [`Option.isSome`](sig/OPTION.md#val-issome) | `isSome opt` is `true` when `opt` carries a value. |
| `valOf` | [`Option.valOf`](sig/OPTION.md#val-valof) | `valOf opt` is the value that `opt` carries. |
| `print` |  |  |
| `null` | [`List.null`](sig/LIST.md#val-null) | `null l` is `true` exactly when `l` is empty. |
| `hd` | [`List.hd`](sig/LIST.md#val-hd) | `hd l` is the first element of `l`. |
| `tl` | [`List.tl`](sig/LIST.md#val-tl) | `tl l` is `l` without its first element. |
| `length` | [`List.length`](sig/LIST.md#val-length) | `length l` is the number of elements of `l`. |
| `rev` | [`List.rev`](sig/LIST.md#val-rev) | `rev l` is the list of the elements of `l` in the opposite order. |
| `@` | [`List.@`](sig/LIST.md#val-op-at) | `l @ m` is the list of the elements of `l` followed by those of `m`. |
| `app` | [`List.app`](sig/LIST.md#val-app) | `app f l` applies `f` to every element of `l`, from left to right, for its effect. |
| `map` | [`List.map`](sig/LIST.md#val-map) | `map f l` is the list of the results of applying `f` to each element of `l`, from left to right. |
| `foldl` | [`List.foldl`](sig/LIST.md#val-foldl) | `foldl f init l` combines the elements of `l` from the left: `f (xn, ... f (x2, f (x1, init)) ...)`. |
| `foldr` | [`List.foldr`](sig/LIST.md#val-foldr) | `foldr f init l` combines the elements of `l` from the right: `f (x1, f (x2, ... f (xn, init) ...))`. |
| `size` | [`String.size`](sig/STRING.md#val-size) | `size s` is the number of characters of `s`. |
| `^` | [`String.^`](sig/STRING.md#val-op-caret) | `s ^ t` is the characters of `s` followed by those of `t`. |
| `str` | [`String.str`](sig/STRING.md#val-str) | `str c` is the string of the one character `c`. |
| `concat` | [`String.concat`](sig/STRING.md#val-concat) | `concat l` is the strings of `l` one after another. |
| `implode` | [`String.implode`](sig/STRING.md#val-implode) | `implode l` is the string of the characters of `l`, in order. |
| `explode` | [`String.explode`](sig/STRING.md#val-explode) | `explode s` is the list of the characters of `s`, in order. |
| `substring` | [`String.substring`](sig/STRING.md#val-substring) | `substring (s, i, n)` is the `n` characters of `s` from position `i`. |
| `ord` | [`Char.ord`](sig/CHAR.md#val-ord) | `ord c` is the code of `c`, between 0 and `maxOrd`. |
| `chr` | [`Char.chr`](sig/CHAR.md#val-chr) | `chr i` is the character whose code is `i`. |
| `real` | [`Real.fromInt`](sig/REAL.md#val-fromint) |  |
| `floor` | [`Real.floor`](sig/REAL.md#val-floor) |  |
| `ceil` | [`Real.ceil`](sig/REAL.md#val-ceil) |  |
| `round` | [`Real.round`](sig/REAL.md#val-round) |  |
| `trunc` | [`Real.trunc`](sig/REAL.md#val-trunc) |  |
| `vector` | [`Vector.fromList`](sig/VECTOR.md#val-fromlist) |  |
| `exnName` | [`General.exnName`](sig/GENERAL.md#val-exnname) | `exnName ex` is the name of the constructor of `ex`, without a structure in front and without its argument. |
| `exnMessage` | [`General.exnMessage`](sig/GENERAL.md#val-exnmessage) | `exnMessage ex` is a message that describes `ex`, for a program that reports an exception it cannot handle. |

## Infix identifiers

| Identifiers | Status |
| --- | --- |
| `*` `/` `div` `mod` | infix 7 |
| `+` `-` `^` | infix 6 |
| `::` `@` | infixr 5 |
| `=` `<>` `>` `>=` `<` `<=` | infix 4 |
| `:=` `o` | infix 3 |
| `before` | infix 0 |

---

<sub>Generated by runedoc; do not edit.</sub>
