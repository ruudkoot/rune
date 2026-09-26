# structure SML90

[The Standard ML Basis Library](../README.md) &rsaquo; The language &rsaquo; [Structures](../structures.md) &rsaquo; **SML90**

|  |  |
| --- | --- |
| Signature | [`SML90`](../sig/SML90.md) |
| Status | optional |
| Members | 36 |
| Tests | 39 checks |
| Source | [lib/basis/sml90.sml](../../../../lib/basis/sml90.sml) |

## Synopsis

```sml
structure SML90 : SML90
```

SML90: the initial basis of the 1990 Definition, over Real.Math, String
and TextIO. As in MLton's (unexposed) SML90, which Poly/ML agrees with:
the arithmetic exceptions are Overflow and Mod is Div, which the Library
raises in their place; Sqrt, Ln, Ord, Io and Interrupt are new, and
sqrt, ln, ord and the functions on streams raise them.

## Members

What each means is on [`SML90`](../sig/SML90.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`instream`](../sig/SML90.md#type-instream) | *a type of its own* |
| type | [`outstream`](../sig/SML90.md#type-outstream) | *a type of its own* |
| exception | [`Abs`](../sig/SML90.md#exn-abs) |  |
| exception | [`Diff`](../sig/SML90.md#exn-diff) |  |
| exception | [`Exp`](../sig/SML90.md#exn-exp) |  |
| exception | [`Floor`](../sig/SML90.md#exn-floor) |  |
| exception | [`Interrupt`](../sig/SML90.md#exn-interrupt) |  |
| exception | [`Io`](../sig/SML90.md#exn-io) | `of string` |
| exception | [`Ln`](../sig/SML90.md#exn-ln) |  |
| exception | [`Mod`](../sig/SML90.md#exn-mod) |  |
| exception | [`Neg`](../sig/SML90.md#exn-neg) |  |
| exception | [`Ord`](../sig/SML90.md#exn-ord) |  |
| exception | [`Prod`](../sig/SML90.md#exn-prod) |  |
| exception | [`Quot`](../sig/SML90.md#exn-quot) |  |
| exception | [`Sqrt`](../sig/SML90.md#exn-sqrt) |  |
| exception | [`Sum`](../sig/SML90.md#exn-sum) |  |
| val | [`arctan`](../sig/SML90.md#val-arctan) | `real -> real` |
| val | [`chr`](../sig/SML90.md#val-chr) | `int -> string` |
| val | [`close_in`](../sig/SML90.md#val-close_in) | `instream -> unit` |
| val | [`close_out`](../sig/SML90.md#val-close_out) | `outstream -> unit` |
| val | [`cos`](../sig/SML90.md#val-cos) | `real -> real` |
| val | [`end_of_stream`](../sig/SML90.md#val-end_of_stream) | `instream -> bool` |
| val | [`exp`](../sig/SML90.md#val-exp) | `real -> real` |
| val | [`explode`](../sig/SML90.md#val-explode) | `string -> string list` |
| val | [`implode`](../sig/SML90.md#val-implode) | `string list -> string` |
| val | [`input`](../sig/SML90.md#val-input) | `instream * int -> string` |
| val | [`ln`](../sig/SML90.md#val-ln) | `real -> real` |
| val | [`lookahead`](../sig/SML90.md#val-lookahead) | `instream -> string` |
| val | [`open_in`](../sig/SML90.md#val-open_in) | `string -> instream` |
| val | [`open_out`](../sig/SML90.md#val-open_out) | `string -> outstream` |
| val | [`ord`](../sig/SML90.md#val-ord) | `string -> int` |
| val | [`output`](../sig/SML90.md#val-output) | `outstream * string -> unit` |
| val | [`sin`](../sig/SML90.md#val-sin) | `real -> real` |
| val | [`sqrt`](../sig/SML90.md#val-sqrt) | `real -> real` |
| val | [`std_in`](../sig/SML90.md#val-std_in) | `instream` |
| val | [`std_out`](../sig/SML90.md#val-std_out) | `outstream` |

## Notes

### 

> **Limitation** `SML90/is-history`. The page that defined this signature is no
> longer among the specification's pages; it is transcribed from MLton's
> library, which follows it, in the order the page had.

### Interrupt

> **Limitation** `SML90.Interrupt/never-raised`. It is declared and nothing
> raises it: the VM handles no signal, so an interrupt ends the program.

### Ln

> **Reading** `SML90.Ln/is-its-own-exception`. As [`Sqrt`](../sig/SML90.md#exn-sqrt): an exception of its
> own, not [`Overflow`](../sig/GENERAL.md#exn-overflow).

### Ord

> **Reading** `SML90.Ord/is-its-own-exception`. As [`Sqrt`](../sig/SML90.md#exn-sqrt): an exception of
> its own, not [`Overflow`](../sig/GENERAL.md#exn-overflow) and not [`Subscript`](../sig/GENERAL.md#exn-subscript).

### Sqrt

> **Reading** `SML90.Sqrt/is-its-own-exception`. [`Sqrt`](../sig/SML90.md#exn-sqrt), [`Ln`](../sig/SML90.md#exn-ln) and [`Ord`](../sig/SML90.md#exn-ord) are
> exceptions of their own, as MLton and SML/NJ have them. Poly/ML makes
> all three [`Overflow`](../sig/GENERAL.md#exn-overflow), which loses what went wrong.

### lookahead

> **Reading** `SML90.lookahead/closed-stream-is-empty`. A stream that has been
> closed is at its end, so it gives the empty string as well, and not [`Io`](../sig/SML90.md#exn-io).

<details><summary>Other implementations (6)</summary>

- **Poly/ML** &mdash; another reading of the specification: as SML90.Sqrt/new
- **Poly/ML** &mdash; another reading of the specification: Sqrt, Ln and Ord are Overflow; the test takes MLton's and SML/NJ's reading, exceptions of their own
- **SML/NJ** &mdash; Math.atan 0.0 is \~0.0
- **Poly/ML** &mdash; ln 0.0 is \~inf instead of raising Ln
- **SML/NJ** &mdash; lookahead raises Io at the end of the stream instead of returning ""
- **SML/NJ** &mdash; ord "" raises Subscript, not Ord

</details>

---

<sub>Generated by runedoc from lib/basis/sml90.sml; do not edit.</sub>
