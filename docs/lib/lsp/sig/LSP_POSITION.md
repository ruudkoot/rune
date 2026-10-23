# signature LSP_POSITION

[Language Server Protocol](../README.md) &rsaquo; Protocols &rsaquo; **LSP_POSITION**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 11 of 11 entries documented |
| Tests | not listed |
| Source | [lib/lsp/position\_sig.sml](../../../../lib/lsp/position_sig.sml) |

## Synopsis

```sml
signature LSP_POSITION
structure LspPosition :> LSP_POSITION
```

| Implementation |  | Source |
| --- | --- | --- |
| [`LspPosition`](../str/LspPosition.md) | LSP coordinate conversion over immutable UTF-8 text. | [lib/lsp/position.sml](../../../../lib/lsp/position.sml) |

LSP positions over immutable UTF-8 document text.

## Interface

<pre>
signature LSP_POSITION =
sig
  type <a href="#type-t">t</a>
  exception <a href="#exn-invalid">Invalid</a>
  exception <a href="#exn-limit">Limit</a>
  val <a href="#val-make">make</a> : string -&gt; t
  val <a href="#val-bounded">bounded</a> : {<a href="#fld-bounded.text">text</a> : string, <a href="#fld-bounded.maxlines">maxLines</a> : int} -&gt; t
  val <a href="#val-text">text</a> : t -&gt; string
  val <a href="#val-linecount">lineCount</a> : t -&gt; int
  val <a href="#val-offset">offset</a> : t * LspProtocol.encoding * LspProtocol.position -&gt; int option
  val <a href="#val-position">position</a> : t * LspProtocol.encoding * int -&gt; LspProtocol.position option
  val <a href="#val-edit">edit</a> : t * int * int * string -&gt; t
  val <a href="#val-editbounded">editBounded</a> : {<a href="#fld-editbounded.document">document</a> : t, <a href="#fld-editbounded.start">start</a> : int, <a href="#fld-editbounded.stop">stop</a> : int, <a href="#fld-editbounded.text">text</a> : string,
                     <a href="#fld-editbounded.maxlines">maxLines</a> : int} -&gt; t
end
</pre>

### <a name="type-t"></a>`t`

```sml
type t
```

Text with a line index and sparse Unicode checkpoints.

### <a name="exn-invalid"></a>`Invalid`

```sml
exception Invalid
```

Malformed UTF-8 or an invalid byte edit boundary.

### <a name="exn-limit"></a>`Limit`

```sml
exception Limit
```

A requested line-count bound would be exceeded.

### <a name="val-make"></a>`make`

```sml
val make : string -> t
```

`make text` indexes well-formed UTF-8, preserving its BOM and exact
line endings. Empty text has one line.

**Raises** [`Invalid`](#exn-invalid) for malformed UTF-8, and [`Size`](../../basis/sig/GENERAL.md#exn-size) for an index larger
than the host's vectors permit.

### <a name="val-bounded"></a>`bounded`

```sml
val bounded : {text : string, maxLines : int} -> t
```

`bounded {text, maxLines}` indexes text with a line-count limit.

**Raises** [`Limit`](#exn-limit) before indexing more than maxLines lines; [`Domain`](../../basis/sig/GENERAL.md#exn-domain)
when maxLines is not positive; [`Invalid`](#exn-invalid) as make does.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-bounded.text"></a>`text` | `string` |  |
| <a name="fld-bounded.maxlines"></a>`maxLines` | `int` |  |

### <a name="val-text"></a>`text`

```sml
val text : t -> string
```

`text index` is the original UTF-8 text.

### <a name="val-linecount"></a>`lineCount`

```sml
val lineCount : t -> int
```

`lineCount index` counts LF, CRLF and CR as line endings. A trailing
line ending starts a final empty line.

**Example** `lineCount (make "a\r\nb\rc\n") = 4`

### <a name="val-offset"></a>`offset`

```sml
val offset : t * LspProtocol.encoding * LspProtocol.position -> int option
```

`offset (index, encoding, position)` converts a negotiated position
to a byte offset, or NONE for invalid coordinates or split scalars.

A character beyond its line clamps to that line's end. A line beyond
the document clamps to EOF. Negative or out-of-protocol coordinates
are invalid. UTF-16 positions inside a surrogate pair and UTF-8
positions inside a multibyte character are rejected.

### <a name="val-position"></a>`position`

```sml
val position : t * LspProtocol.encoding * int -> LspProtocol.position option
```

`position (index, encoding, offset)` converts a byte offset, or is
NONE for an out-of-bounds offset or one inside a multibyte character.

Offsets in line-ending bytes clamp to the line's end: LSP cannot
address the middle of CRLF. The BOM is a character when present.

### <a name="val-edit"></a>`edit`

```sml
val edit : t * int * int * string -> t
```

`edit (index, start, stop, text)` replaces a half-open byte range.

Unchanged Unicode checkpoints are reused. Line-ending changes
reconstruct the affected line region. The original index remains
valid for callers holding its document snapshot.

**Raises** [`Invalid`](#exn-invalid) for malformed inserted UTF-8, reversed/out-of-bounds
ranges or split scalar boundaries.

### <a name="val-editbounded"></a>`editBounded`

```sml
val editBounded : {document : t, start : int, stop : int, text : string,
                   maxLines : int} -> t
```

`editBounded edit` applies a byte edit with a maximum output line
count, preserving the input index when the edit fails.

**Raises** [`Limit`](#exn-limit) when the output exceeds maxLines, [`Domain`](../../basis/sig/GENERAL.md#exn-domain) for a
nonpositive limit, and [`Invalid`](#exn-invalid) as edit does.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-editbounded.document"></a>`document` | `t` |  |
| <a name="fld-editbounded.start"></a>`start` | `int` |  |
| <a name="fld-editbounded.stop"></a>`stop` | `int` |  |
| <a name="fld-editbounded.text"></a>`text` | `string` |  |
| <a name="fld-editbounded.maxlines"></a>`maxLines` | `int` |  |

---

<sub>Generated by runedoc from lib/lsp/position\_sig.sml; do not edit.</sub>
