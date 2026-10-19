# signature COMPILER

[The Standard ML Basis Library](../README.md) &rsaquo; The runtime &rsaquo; **COMPILER**

|  |  |
| --- | --- |
| Status | extension |
| Implementations | 1 |
| Documentation | 14 of 14 entries documented |
| Tests | 16 checks of 11 entries |
| Source | [lib/basis/compiler\_sig.sml](../../../../lib/basis/compiler_sig.sml) |

## Synopsis

```sml
signature COMPILER
structure Compiler : COMPILER  (* extension *)
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Compiler`](../str/Compiler.md) | Compiler: what a program can ask of the compiler it runs beside. | [lib/basis/compiler.sml](../../../../lib/basis/compiler.sml) |

What a program can ask of the compiler it runs beside: in the REPL
(`rune-repl`, docs/repl.md) the compiler is in the same program as the
code it compiled, and a program compiles more of itself with [`use`](#val-use).

A program compiled by `rune` and run by `runevm` has no compiler beside
it: there [`use`](#val-use) raises [`Fail`](../sig/GENERAL.md#exn-fail), and the rest is there to be set and read
with nothing reading it.

This signature is Rune's own. Poly/ML keeps the same things in its
structure PolyML.Compiler, and SML/NJ in Compiler.Control.

> **Deviation** `COMPILER/not-in-the-specification`. The specification
> regards a program as interactive (Chapter 8 of the Definition) and says
> nothing of how one is fed to the compiler, so the REPL's controls are
> every implementation's own.

## Contents

[Printers of one's own](#printers-of-ones-own)

## Interface

<pre>
signature COMPILER =
sig
  val <a href="#val-use">use</a> : string -&gt; unit
  val <a href="#val-compile">compile</a> : {<a href="#fld-compile.read">read</a> : unit -&gt; char option, <a href="#fld-compile.file">file</a> : string, <a href="#fld-compile.line">line</a> : int} -&gt; unit -&gt; unit
  val <a href="#val-compilein">compileIn</a> : string -&gt; {<a href="#fld-compilein.read">read</a> : unit -&gt; char option, <a href="#fld-compilein.file">file</a> : string, <a href="#fld-compilein.line">line</a> : int} -&gt; unit -&gt; unit
  val <a href="#val-printdepth">printDepth</a> : int ref
  val <a href="#val-printlength">printLength</a> : int ref
  val <a href="#val-stringlength">stringLength</a> : int ref
  val <a href="#val-prompt1">prompt1</a> : string ref
  val <a href="#val-prompt2">prompt2</a> : string ref
  type <a href="#type-location">location</a> = {<a href="#fld-location.file">file</a> : string, <a href="#fld-location.startline">startLine</a> : int, <a href="#fld-location.startposition">startPosition</a> : int, <a href="#fld-location.endline">endLine</a> : int, <a href="#fld-location.endposition">endPosition</a> : int}
  datatype <a href="#type-context">context</a> = <a href="#con-contextlocation">ContextLocation</a> of location | <a href="#con-contextproperty">ContextProperty</a> of string * string
  datatype <a href="#type-pretty">pretty</a> =
      <a href="#con-prettyblock">PrettyBlock</a> of int * bool * context list * pretty list
    | <a href="#con-prettybreak">PrettyBreak</a> of int * int
    | <a href="#con-prettylinebreak">PrettyLineBreak</a>
    | <a href="#con-prettystring">PrettyString</a> of string
    | <a href="#con-prettystringwithwidth">PrettyStringWithWidth</a> of string * int
  val <a href="#val-prettyprint">prettyPrint</a> : (string -&gt; unit) * int -&gt; pretty -&gt; unit
  val <a href="#val-linelength">lineLength</a> : int ref
  val <a href="#val-addprettyprinter">addPrettyPrinter</a> : (int -&gt; 'a -&gt; 'b -&gt; pretty) -&gt; unit
end
</pre>

### <a name="val-use"></a>`use`

```sml
val use : string -> unit
```

`use file` compiles the top-level declarations of `file` and runs
them, one after another, as if they had been typed at the REPL.

Each extends the declarations before it, and those after it see them.
A declaration that does not compile stops the file there: its error is
reported, and the declarations before it are kept. One whose running
raises an exception stops the file too, and the exception goes on to
the caller of [`use`](#val-use), its effects and the declarations before it kept.
[`use`](#val-use) may be called by a declaration that [`use`](#val-use) is running.

**Raises** [`Fail`](../sig/GENERAL.md#exn-fail) in a program that has no compiler beside it, or when a
declaration of the file does not compile; [`IO.Io`](../sig/IO.md#exn-io) if the file cannot
be read.

<details><summary>Tests (1)</summary>

For `Compiler`, in [tests/basis/compiler.sml](../../../../tests/basis/compiler.sml): `no-compiler-beside-the-program` (raises)

</details>

### <a name="val-compile"></a>`compile`

```sml
val compile : {read : unit -> char option, file : string, line : int} -> unit -> unit
```

`compile {read, file, line}` reads top-level declarations from `read`
and is the function that runs them, as if they had been typed at the
REPL.

It reads up to a `;` that ends a declaration at the top level, or to
the end of what `read` gives (`NONE`); a caller that wants all of a
reader compiles from it until it is at its end. `file` and `line` say
where the characters are from, for the positions of errors and
traces. The declarations are compiled and run one after another when
the function is called, each extending those before it, as with
[`use`](#val-use): a declaration that does not compile stops them, its error
reported, and one that raises stops them, the exception going on to
the caller. Poly/ML's PolyML.compiler is the same, a reader and its
parameters in, a function that runs what it read out.

**Raises** [`Fail`](../sig/GENERAL.md#exn-fail) in a program that has no compiler beside it; the
function raises [`Fail`](../sig/GENERAL.md#exn-fail) where a declaration does not compile.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-compile.read"></a>`read` | `unit -> char option` |  |
| <a name="fld-compile.file"></a>`file` | `string` |  |
| <a name="fld-compile.line"></a>`line` | `int` |  |

<details><summary>Tests (1)</summary>

For `Compiler`, in [tests/basis/compiler.sml](../../../../tests/basis/compiler.sml): `no-compiler-beside-the-program` (raises)

</details>

### <a name="val-compilein"></a>`compileIn`

```sml
val compileIn : string -> {read : unit -> char option, file : string, line : int} -> unit -> unit
```

`compileIn mode {read, file, line}` is `compile {read, file, line}`
with the characters read in the mode that `mode` names.

The names are those of a build file's annotations: `"ascii"`, the
default, which [`compile`](#val-compile) reads in; `"unicode"` (or `"unicode=utf8"`);
and `"unicode=latin1"`. A mode is how `rune --unicode=ENC` reads its
inputs (docs/units.md, Source modes).

**Raises** [`Fail`](../sig/GENERAL.md#exn-fail) in a program that has no compiler beside it, or for a
mode of another name; the function raises [`Fail`](../sig/GENERAL.md#exn-fail) where a declaration
does not compile.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-compilein.read"></a>`read` | `unit -> char option` |  |
| <a name="fld-compilein.file"></a>`file` | `string` |  |
| <a name="fld-compilein.line"></a>`line` | `int` |  |

<details><summary>Tests (1)</summary>

For `Compiler`, in [tests/basis/compiler.sml](../../../../tests/basis/compiler.sml): `no-compiler-beside-the-program` (raises)

</details>

### <a name="val-printdepth"></a>`printDepth`

```sml
val printDepth : int ref
```

How deep the REPL prints a value, from the outside in.

The levels it counts are those of a list, a tuple, a record, a
constructor's argument and a `ref`'s content; past them it writes
`...` for the rest. At 0 or below the REPL says nothing of what a
declaration declared.

<details><summary>Tests (1)</summary>

For `Compiler`, in [tests/basis/compiler.sml](../../../../tests/basis/compiler.sml): `is-twenty`

</details>

### <a name="val-printlength"></a>`printLength`

```sml
val printLength : int ref
```

How many items of a list, an array or a vector the REPL prints (100);
the rest print as one `...`.

<details><summary>Tests (1)</summary>

For `Compiler`, in [tests/basis/compiler.sml](../../../../tests/basis/compiler.sml): `is-a-hundred`

</details>

### <a name="val-stringlength"></a>`stringLength`

```sml
val stringLength : int ref
```

How many characters of a string the REPL prints (1,000); the rest
print as `...` after the closing quote.

<details><summary>Tests (1)</summary>

For `Compiler`, in [tests/basis/compiler.sml](../../../../tests/basis/compiler.sml): `is-a-thousand`

</details>

### <a name="val-prompt1"></a>`prompt1`

```sml
val prompt1 : string ref
```

What the REPL writes before it reads a declaration.

<details><summary>Tests (1)</summary>

For `Compiler`, in [tests/basis/compiler.sml](../../../../tests/basis/compiler.sml): `is-a-dash`

</details>

### <a name="val-prompt2"></a>`prompt2`

```sml
val prompt2 : string ref
```

What the REPL writes before each line that continues a declaration.

<details><summary>Tests (1)</summary>

For `Compiler`, in [tests/basis/compiler.sml](../../../../tests/basis/compiler.sml): `is-an-equals-sign`

</details>

## Printers of one's own

### <a name="type-location"></a>`location`

```sml
type location = {file : string, startLine : int, startPosition : int, endLine : int, endPosition : int}
```

Where in a source what a printer shows came from: the file, and the
line and position it begins and ends at.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-location.file"></a>`file` | `string` |  |
| <a name="fld-location.startline"></a>`startLine` | `int` |  |
| <a name="fld-location.startposition"></a>`startPosition` | `int` |  |
| <a name="fld-location.endline"></a>`endLine` | `int` |  |
| <a name="fld-location.endposition"></a>`endPosition` | `int` |  |

### <a name="type-context"></a>`context`

```sml
datatype context = ContextLocation of location | ContextProperty of string * string
```

What a block of a printer's output says beside its text: where it came
from, or a property by name. Rune's REPL lays out the text alone.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-contextlocation"></a>`ContextLocation` | `location` |  |
| <a name="con-contextproperty"></a>`ContextProperty` | `string * string` |  |

### <a name="type-pretty"></a>`pretty`

```sml
datatype pretty =
    PrettyBlock of int * bool * context list * pretty list
  | PrettyBreak of int * int
  | PrettyLineBreak
  | PrettyString of string
  | PrettyStringWithWidth of string * int
```

A document for [`prettyPrint`](#val-prettyprint) to lay out, in Poly/ML's shape: text,
places where a line may break, and blocks of them.

`PrettyBlock (indent, consistent, context, items)` lays its items
on one line where they fit; where they do not, a break of the block
starts a new line `indent` further in than the block began, every
break of the block where `consistent` and only those it needs where
not. `PrettyBreak (blanks, offset)` is `blanks` spaces where the line
does not break there, and where it does, the new line is `offset`
further in. [`PrettyLineBreak`](#con-prettylinebreak) always breaks the line,
`PrettyString s` is `s`, and `PrettyStringWithWidth (s, w)` is `s`
laid out as if it were `w` characters wide.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-prettyblock"></a>`PrettyBlock` | `int * bool * context list * pretty list` |  |
| <a name="con-prettybreak"></a>`PrettyBreak` | `int * int` |  |
| <a name="con-prettylinebreak"></a>`PrettyLineBreak` |  |  |
| <a name="con-prettystring"></a>`PrettyString` | `string` |  |
| <a name="con-prettystringwithwidth"></a>`PrettyStringWithWidth` | `string * int` |  |

### <a name="val-prettyprint"></a>`prettyPrint`

```sml
val prettyPrint : (string -> unit) * int -> pretty -> unit
```

`prettyPrint (out, width) p` lays `p` out in lines of `width`
characters where it can, and gives `out` the text, piece by piece.

**Example** `let val b = ref "" in prettyPrint (fn s => b := !b ^ s, 3) (PrettyBlock (2, false, [], [PrettyString "ab", PrettyBreak (1, 0), PrettyString "cd"])); !b end = "ab\n  cd"`

<details><summary>Tests (6)</summary>

For `Compiler`, in [tests/basis/compiler.sml](../../../../tests/basis/compiler.sml): `a-block-that-fits-is-one-line` &middot; `consistent-breaks-every-break` &middot; `inconsistent-breaks-where-it-must` &middot; `a-break-adds-its-offset` &middot; `a-line-break-always-breaks` &middot; `a-string-with-a-width-counts-that`

</details>

### <a name="val-linelength"></a>`lineLength`

```sml
val lineLength : int ref
```

How wide the REPL lays out a value where its output is not a terminal.

It is the width of what the REPL's own printers make and what those of
[`addPrettyPrinter`](#val-addprettyprinter) make; on a terminal, the terminal's width is.

<details><summary>Tests (1)</summary>

For `Compiler`, in [tests/basis/compiler.sml](../../../../tests/basis/compiler.sml): `is-eighty`

</details>

### <a name="val-addprettyprinter"></a>`addPrettyPrinter`

```sml
val addPrettyPrinter : (int -> 'a -> 'b -> pretty) -> unit
```

`addPrettyPrinter f` makes `f` the REPL's printer of the values of a
type, as Poly/ML's PolyML.addPrettyPrinter does.

The type is the one `f`'s third argument has where [`addPrettyPrinter`](#val-addprettyprinter)
is applied, which the compiler sees there: a datatype or an abstract
type, at any arguments. `f depth args v` is what `v` shows as,
`depth` the levels the REPL still shows, and `args` how to show the
type's arguments: `()` for a type of none, for one a function of a
value and a depth, and for more a tuple of them. A later printer of
the same type takes the place of an earlier one.

Where the type is not known where it is applied -- a type variable,
in a function that installs printers -- or is declared by the same
top-level declaration, nothing is installed; nor is anything in a
program that has no compiler beside it, where nothing prints.

<details><summary>Tests (1)</summary>

For `Compiler`, in [tests/basis/compiler.sml](../../../../tests/basis/compiler.sml): `no-compiler-beside-the-program`

</details>

## See also

[`RUNTIME`](../sig/RUNTIME.md)

---

<sub>Generated by runedoc from lib/basis/compiler\_sig.sml; do not edit.</sub>
