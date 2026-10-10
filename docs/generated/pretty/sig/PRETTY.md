# signature PRETTY

[Pretty printing](../README.md) &rsaquo; Text &rsaquo; **PRETTY**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 18 of 18 entries documented |
| Tests | not listed |
| Source | [lib/pretty/pretty\_sig.sml](../../../../lib/pretty/pretty_sig.sml) |

## Synopsis

```sml
signature PRETTY
structure Pretty :> PRETTY
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Pretty`](../str/Pretty.md) | Pretty: documents laid out strictly (Lindig, "Strictly Pretty", 2000). | [lib/pretty/pretty.sml](../../../../lib/pretty/pretty.sml) |

Documents laid out at a width: Wadler's prettier printer, strictly, as
Lindig wrote it, with annotations that a renderer turns into styles, and
budgets that cut a document of a deep or long value short.

A document is text, line breaks that become a blank (or nothing) when
the group around them fits the rest of the line, nesting, groups and
annotations. [`sequence`](#val-sequence) is the document of a list, a tuple or a record:
its items aligned after the opening bracket and separated, all on one
line when they fit and one to a line when not; [`bound`](#val-bound) cuts sequences
deeper, longer or more numerous than its budgets with `...`, as a
REPL does with `printDepth` and `printLength`. Text is measured in
display columns (`DisplayWidth`), so a CJK character takes two.

## Interface

<pre>
signature PRETTY =
sig
  type 'a <a href="#type-doc">doc</a>
  val <a href="#val-empty">empty</a> : 'a doc
  val <a href="#val-text">text</a> : string -&gt; 'a doc
  val <a href="#val-line">line</a> : 'a doc
  val <a href="#val-cut">cut</a> : 'a doc
  val <a href="#val-hardline">hardline</a> : 'a doc
  val <a href="#val-concat">concat</a> : 'a doc list -&gt; 'a doc
  val <a href="#val-nest">nest</a> : int -&gt; 'a doc -&gt; 'a doc
  val <a href="#val-group">group</a> : 'a doc -&gt; 'a doc
  val <a href="#val-annotate">annotate</a> : 'a * 'a doc -&gt; 'a doc
  val <a href="#val-sequence">sequence</a> : {<a href="#fld-sequence.opening">opening</a> : string, <a href="#fld-sequence.closing">closing</a> : string, <a href="#fld-sequence.separator">separator</a> : string} -&gt; 'a doc list -&gt; 'a doc
  val <a href="#val-ellipsis">ellipsis</a> : 'a doc
  val <a href="#val-bound">bound</a> : {<a href="#fld-bound.depth">depth</a> : int option, <a href="#fld-bound.length">length</a> : int option, <a href="#fld-bound.nodes">nodes</a> : int option} -&gt; 'a doc -&gt; 'a doc
  datatype 'a <a href="#type-piece">piece</a> = <a href="#con-text">Text</a> of string | <a href="#con-newline">Newline</a> of int | <a href="#con-begin">Begin</a> of 'a | <a href="#con-end">End</a>
  val <a href="#val-layout">layout</a> : int -&gt; 'a doc -&gt; 'a piece list
  val <a href="#val-render">render</a> : int -&gt; 'a doc -&gt; string
  val <a href="#val-renderwith">renderWith</a> : {<a href="#fld-renderwith.width">width</a> : int, <a href="#fld-renderwith.start">start</a> : 'a -&gt; string, <a href="#fld-renderwith.finish">finish</a> : 'a -&gt; string} -&gt; 'a doc -&gt; string
  val <a href="#val-flat">flat</a> : 'a doc -&gt; string
end
</pre>

### <a name="type-doc"></a>`doc`

```sml
type 'a doc
```

A document whose annotations are of type `'a`.

### <a name="val-empty"></a>`empty`

```sml
val empty : 'a doc
```

Nothing.

### <a name="val-text"></a>`text`

```sml
val text : string -> 'a doc
```

`text s` is `s`, which should have no newline.

**Example** `render 80 (text "abc") = "abc"`

### <a name="val-line"></a>`line`

```sml
val line : 'a doc
```

A newline and the indentation, or one blank when its group fits on
the line.

### <a name="val-cut"></a>`cut`

```sml
val cut : 'a doc
```

A newline and the indentation, or nothing when its group fits.

### <a name="val-hardline"></a>`hardline`

```sml
val hardline : 'a doc
```

A newline always, which keeps the groups around it from fitting.

### <a name="val-concat"></a>`concat`

```sml
val concat : 'a doc list -> 'a doc
```

`concat ds` is the documents one after the other.

**Example** `render 80 (concat [text "a", line, text "b"]) = "a\nb"`

### <a name="val-nest"></a>`nest`

```sml
val nest : int -> 'a doc -> 'a doc
```

`nest n d` is `d` with every newline in it indented by `n` more.

### <a name="val-group"></a>`group`

```sml
val group : 'a doc -> 'a doc
```

`group d` is `d` on one line, its breaks blanks or nothing, when that
fits the width, and `d` with its breaks as newlines otherwise.

**Example** `render 80 (group (concat [text "a", line, text "b"])) = "a b"`

### <a name="val-annotate"></a>`annotate`

```sml
val annotate : 'a * 'a doc -> 'a doc
```

`annotate (a, d)` is `d` marked with `a`, which a renderer may show
(a colour, a link) and layout passes on.

### <a name="val-sequence"></a>`sequence`

```sml
val sequence : {opening : string, closing : string, separator : string} -> 'a doc list -> 'a doc
```

`sequence {opening, closing, separator} ds` is the items `ds` between
the brackets, separated.

It is `[1, 2, 3]` when that fits, and one item to a line, each aligned
after the opening bracket, when it does not.

**Example** `render 6 (sequence {opening = "[", closing = "]", separator = ","} [text "1", text "22", text "333"]) = "[1,\n 22,\n 333]"`

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-sequence.opening"></a>`opening` | `string` |  |
| <a name="fld-sequence.closing"></a>`closing` | `string` |  |
| <a name="fld-sequence.separator"></a>`separator` | `string` |  |

### <a name="val-ellipsis"></a>`ellipsis`

```sml
val ellipsis : 'a doc
```

The text `...`, which stands for what a budget left out.

### <a name="val-bound"></a>`bound`

```sml
val bound : {depth : int option, length : int option, nodes : int option} -> 'a doc -> 'a doc
```

`bound {depth, length, nodes} d` is `d` with what is past the budgets
made `...`.

A sequence nested more than `depth` deep is `...`; the items of a
sequence after the first `length` are one `...`; the items after the
first `nodes` of the whole document, counted depth first, are `...`.
`NONE` is no limit.

**Example** `render 80 (bound {depth = NONE, length = SOME 2, nodes = NONE} (sequence {opening = "[", closing = "]", separator = ","} [text "1", text "2", text "3"])) = "[1, 2, ...]"`

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-bound.depth"></a>`depth` | `int option` |  |
| <a name="fld-bound.length"></a>`length` | `int option` |  |
| <a name="fld-bound.nodes"></a>`nodes` | `int option` |  |

### <a name="type-piece"></a>`piece`

```sml
datatype 'a piece = Text of string | Newline of int | Begin of 'a | End
```

What a layout is made of: text, a newline and its indentation, and
the beginning and end of an annotation.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-text"></a>`Text` | `string` |  |
| <a name="con-newline"></a>`Newline` | `int` |  |
| <a name="con-begin"></a>`Begin` | `'a` |  |
| <a name="con-end"></a>`End` |  |  |

### <a name="val-layout"></a>`layout`

```sml
val layout : int -> 'a doc -> 'a piece list
```

`layout w d` is `d` laid out at width `w`: as many groups on one line
as fit, the outermost first. A line is wider than `w` only where a
piece of text alone is.

### <a name="val-render"></a>`render`

```sml
val render : int -> 'a doc -> string
```

`render w d` is the layout of `d` as text, its annotations left out.

### <a name="val-renderwith"></a>`renderWith`

```sml
val renderWith : {width : int, start : 'a -> string, finish : 'a -> string} -> 'a doc -> string
```

`renderWith {width, start, finish} d` is the layout as text, with
`start a` before what `a` annotates and `finish a` after it.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-renderwith.width"></a>`width` | `int` |  |
| <a name="fld-renderwith.start"></a>`start` | `'a -> string` |  |
| <a name="fld-renderwith.finish"></a>`finish` | `'a -> string` |  |

### <a name="val-flat"></a>`flat`

```sml
val flat : 'a doc -> string
```

`flat d` is `d` with every group on one line.

**Example** `flat (concat [text "a", line, text "b"]) = "a b"`

---

<sub>Generated by runedoc from lib/pretty/pretty\_sig.sml; do not edit.</sub>
