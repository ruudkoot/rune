# signature MARKDOWN

[Markdown](../README.md) &rsaquo; Text &rsaquo; **MARKDOWN**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 8 of 8 entries documented |
| Tests | not listed |
| Source | [lib/markdown/markdown\_sig.sml](../../../../lib/markdown/markdown_sig.sml) |

## Synopsis

```sml
signature MARKDOWN
structure Markdown :> MARKDOWN
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Markdown`](../str/Markdown.md) | Markdown: CommonMark's blocks and inlines, GitHub's tables, HTML and documents. | [lib/markdown/markdown.sml](../../../../lib/markdown/markdown.sml) |

Markdown: CommonMark's (0.31.2) blocks and inlines, with GitHub's
tables, parsed into a tree; written back as the HTML of CommonMark's
reference implementation, or laid out as a document of `Pretty` whose
annotations say what each piece is, for a terminal or plain text.

It reads what runedoc writes -- headings, paragraphs, fenced code,
tables, lists, links, emphasis, code spans, entities and the HTML of
its interface blocks -- and the rest of CommonMark well enough that
tests/lib/markdown checks it on CommonMark's own examples for those
constructs.

## Interface

<pre>
signature MARKDOWN =
sig
  datatype <a href="#type-inline">inline</a> =
      <a href="#con-text">Text</a> of string
    | <a href="#con-code">Code</a> of string
    | <a href="#con-emphasis">Emphasis</a> of inline list
    | <a href="#con-strong">Strong</a> of inline list
    | <a href="#con-link">Link</a> of {<a href="#fld-link.target">target</a> : string, <a href="#fld-link.title">title</a> : string option, <a href="#fld-link.text">text</a> : inline list}
    | <a href="#con-image">Image</a> of {<a href="#fld-image.source">source</a> : string, <a href="#fld-image.title">title</a> : string option, <a href="#fld-image.alt">alt</a> : inline list}
    | <a href="#con-html">Html</a> of string
    | <a href="#con-softbreak">SoftBreak</a>
    | <a href="#con-hardbreak">HardBreak</a>
  datatype <a href="#type-alignment">alignment</a> = <a href="#con-default">Default</a> | <a href="#con-left">Left</a> | <a href="#con-center">Center</a> | <a href="#con-right">Right</a>
  datatype <a href="#type-block">block</a> =
      <a href="#con-heading">Heading</a> of int * inline list
    | <a href="#con-paragraph">Paragraph</a> of inline list
    | <a href="#con-codeblock">CodeBlock</a> of {<a href="#fld-codeblock.info">info</a> : string, <a href="#fld-codeblock.text">text</a> : string}
    | <a href="#con-htmlblock">HtmlBlock</a> of string
    | <a href="#con-quote">Quote</a> of block list
    | <a href="#con-list">List</a> of {<a href="#fld-list.ordered">ordered</a> : bool, <a href="#fld-list.start">start</a> : int, <a href="#fld-list.tight">tight</a> : bool, <a href="#fld-list.items">items</a> : block list list}
    | <a href="#con-table">Table</a> of {<a href="#fld-table.align">align</a> : alignment list, <a href="#fld-table.header">header</a> : inline list list, <a href="#fld-table.rows">rows</a> : inline list list list}
    | <a href="#con-rule">Rule</a>
  val <a href="#val-parse">parse</a> : string -&gt; block list
  val <a href="#val-tohtml">toHtml</a> : block list -&gt; string
  datatype <a href="#type-role">role</a> = <a href="#con-head">Head</a> of int | <a href="#con-mono">Mono</a> | <a href="#con-italic">Italic</a> | <a href="#con-bold">Bold</a> | <a href="#con-anchor">Anchor</a> of string | <a href="#con-quoted">Quoted</a> | <a href="#con-marker">Marker</a> | <a href="#con-ruler">Ruler</a>
  val <a href="#val-todoc">toDoc</a> : block list -&gt; role Pretty.doc
  val <a href="#val-totext">toText</a> : int -&gt; block list -&gt; string
end
</pre>

### <a name="type-inline"></a>`inline`

```sml
datatype inline =
    Text of string
  | Code of string
  | Emphasis of inline list
  | Strong of inline list
  | Link of {target : string, title : string option, text : inline list}
  | Image of {source : string, title : string option, alt : inline list}
  | Html of string
  | SoftBreak
  | HardBreak
```

Inline content: text, code spans, emphasis, links and images, raw
HTML, and the breaks between lines.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-text"></a>`Text` | `string` |  |
| <a name="con-code"></a>`Code` | `string` |  |
| <a name="con-emphasis"></a>`Emphasis` | `inline list` |  |
| <a name="con-strong"></a>`Strong` | `inline list` |  |
| <a name="con-link"></a>`Link` | `{target : string, title : string option, text : inline list}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-link.target"></a>`target` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-link.title"></a>`title` | `string option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-link.text"></a>`text` | `inline list` |  |
| <a name="con-image"></a>`Image` | `{source : string, title : string option, alt : inline list}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-image.source"></a>`source` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-image.title"></a>`title` | `string option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-image.alt"></a>`alt` | `inline list` |  |
| <a name="con-html"></a>`Html` | `string` |  |
| <a name="con-softbreak"></a>`SoftBreak` |  |  |
| <a name="con-hardbreak"></a>`HardBreak` |  |  |

### <a name="type-alignment"></a>`alignment`

```sml
datatype alignment = Default | Left | Center | Right
```

How a table's column is aligned.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-default"></a>`Default` |  |  |
| <a name="con-left"></a>`Left` |  |  |
| <a name="con-center"></a>`Center` |  |  |
| <a name="con-right"></a>`Right` |  |  |

### <a name="type-block"></a>`block`

```sml
datatype block =
    Heading of int * inline list
  | Paragraph of inline list
  | CodeBlock of {info : string, text : string}
  | HtmlBlock of string
  | Quote of block list
  | List of {ordered : bool, start : int, tight : bool, items : block list list}
  | Table of {align : alignment list, header : inline list list, rows : inline list list list}
  | Rule
```

A block. A list is tight when no blank line separates its items or
the blocks of one; its paragraphs are then written without `<p>`.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-heading"></a>`Heading` | `int * inline list` |  |
| <a name="con-paragraph"></a>`Paragraph` | `inline list` |  |
| <a name="con-codeblock"></a>`CodeBlock` | `{info : string, text : string}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-codeblock.info"></a>`info` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-codeblock.text"></a>`text` | `string` |  |
| <a name="con-htmlblock"></a>`HtmlBlock` | `string` |  |
| <a name="con-quote"></a>`Quote` | `block list` |  |
| <a name="con-list"></a>`List` | `{ordered : bool, start : int, tight : bool, items : block list list}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-list.ordered"></a>`ordered` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-list.start"></a>`start` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-list.tight"></a>`tight` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-list.items"></a>`items` | `block list list` |  |
| <a name="con-table"></a>`Table` | `{align : alignment list, header : inline list list, rows : inline list list list}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-table.align"></a>`align` | `alignment list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-table.header"></a>`header` | `inline list list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-table.rows"></a>`rows` | `inline list list list` |  |
| <a name="con-rule"></a>`Rule` |  |  |

### <a name="val-parse"></a>`parse`

```sml
val parse : string -> block list
```

`parse s` is the blocks of the Markdown text `s`.

**Example** `parse "# A *b*" = [Heading (1, [Text "A ", Emphasis [Text "b"]])]`

### <a name="val-tohtml"></a>`toHtml`

```sml
val toHtml : block list -> string
```

`toHtml bs` is the blocks as HTML, as CommonMark's reference
implementation writes it.

**Example** `toHtml (parse "a *b*") = "<p>a <em>b</em></p>\n"`

### <a name="type-role"></a>`role`

```sml
datatype role = Head of int | Mono | Italic | Bold | Anchor of string | Quoted | Marker | Ruler
```

What a piece of a laid-out document is, for its style.

A heading of a level, code, emphasis, strong emphasis, a link to a
target, a quote, a list's marker, or a table's rule.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-head"></a>`Head` | `int` |  |
| <a name="con-mono"></a>`Mono` |  |  |
| <a name="con-italic"></a>`Italic` |  |  |
| <a name="con-bold"></a>`Bold` |  |  |
| <a name="con-anchor"></a>`Anchor` | `string` |  |
| <a name="con-quoted"></a>`Quoted` |  |  |
| <a name="con-marker"></a>`Marker` |  |  |
| <a name="con-ruler"></a>`Ruler` |  |  |

### <a name="val-todoc"></a>`toDoc`

```sml
val toDoc : block list -> role Pretty.doc
```

`toDoc bs` is the blocks as a document, annotated with their roles.

Paragraphs are filled to the width they are laid out at, code is as it
is, tables are in columns, lists have their markers, and a blank line
is between blocks.

### <a name="val-totext"></a>`toText`

```sml
val toText : int -> block list -> string
```

`toText w bs` is the blocks as plain text at width `w`.

**Example** `toText 80 (parse "# Title\n\nSome *text*.") = "Title\n\nSome text."`

---

<sub>Generated by runedoc from lib/markdown/markdown\_sig.sml; do not edit.</sub>
