# signature HS_TOKEN

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_TOKEN**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 9 of 9 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/token\_sig.sml](../../../../../lib/language/haskell/token_sig.sml) |

## Synopsis

```sml
signature HS_TOKEN
structure HsToken :> HS_TOKEN
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsToken`](../str/HsToken.md) |  | [lib/language/haskell/token.sml](../../../../../lib/language/haskell/token.sml) |

The lexemes of Haskell 98 (the Report's chapter 2 and section 9.2), with
what lies between them.

Three tokens are the layout algorithm's (section 9.3) and never the
lexer's: [`VLBRACE`](#con-vlbrace), [`VSEMI`](#con-vsemi) and [`VRBRACE`](#con-vrbrace), the braces and semicolon it
puts in. They stay apart from the written ones, so that a trace shows
what layout did. Comments, pragmas and white space are not tokens: each
token keeps the trivia before it, so that a tree can be printed back as
its file (the haskell98 roadmap's D28).

## Interface

<pre>
signature HS_TOKEN =
sig
  datatype <a href="#type-token">token</a> =
      <a href="#con-varid">VARID</a> of string
    | <a href="#con-conid">CONID</a> of string
    | <a href="#con-qvarid">QVARID</a> of string * string
    | <a href="#con-qconid">QCONID</a> of string * string
    | <a href="#con-varsym">VARSYM</a> of string
    | <a href="#con-consym">CONSYM</a> of string
    | <a href="#con-qvarsym">QVARSYM</a> of string * string
    | <a href="#con-qconsym">QCONSYM</a> of string * string
    | <a href="#con-integer">INTEGER</a> of IntInf.int * string
    | <a href="#con-float">FLOAT</a> of string
    | <a href="#con-char">CHAR</a> of int * string
    | <a href="#con-string">STRING</a> of int list * string
    | <a href="#con-lparen">LPAREN</a> | <a href="#con-rparen">RPAREN</a> | <a href="#con-comma">COMMA</a> | <a href="#con-semi">SEMI</a> | <a href="#con-lbracket">LBRACKET</a> | <a href="#con-rbracket">RBRACKET</a> | <a href="#con-backquote">BACKQUOTE</a> | <a href="#con-lbrace">LBRACE</a>
    | <a href="#con-rbrace">RBRACE</a>
    | <a href="#con-dotdot">DOTDOT</a> | <a href="#con-colon">COLON</a> | <a href="#con-dcolon">DCOLON</a> | <a href="#con-equals">EQUALS</a> | <a href="#con-backslash">BACKSLASH</a> | <a href="#con-bar">BAR</a> | <a href="#con-larrow">LARROW</a> | <a href="#con-rarrow">RARROW</a> | <a href="#con-at">AT</a> | <a href="#con-tilde">TILDE</a>
    | <a href="#con-darrow">DARROW</a>
    | <a href="#con-case">CASE</a> | <a href="#con-class">CLASS</a> | <a href="#con-data">DATA</a> | <a href="#con-default">DEFAULT</a> | <a href="#con-deriving">DERIVING</a> | <a href="#con-do">DO</a> | <a href="#con-else">ELSE</a> | <a href="#con-if">IF</a> | <a href="#con-import">IMPORT</a> | <a href="#con-in">IN</a> | <a href="#con-infix">INFIX</a>
    | <a href="#con-infixl">INFIXL</a> | <a href="#con-infixr">INFIXR</a> | <a href="#con-instance">INSTANCE</a> | <a href="#con-let">LET</a> | <a href="#con-module">MODULE</a> | <a href="#con-newtype">NEWTYPE</a> | <a href="#con-of">OF</a> | <a href="#con-then">THEN</a> | <a href="#con-type">TYPE</a> | <a href="#con-where">WHERE</a>
    | <a href="#con-underscore">UNDERSCORE</a>
    | <a href="#con-vlbrace">VLBRACE</a>
    | <a href="#con-vsemi">VSEMI</a>
    | <a href="#con-vrbrace">VRBRACE</a>
    | <a href="#con-eof">EOF</a>
  datatype <a href="#type-trivia">trivia</a> =
      <a href="#con-whitespace">Whitespace</a>
    | <a href="#con-linecomment">LineComment</a>
    | <a href="#con-blockcomment">BlockComment</a>
    | <a href="#con-pragma">Pragma</a>
    | <a href="#con-byteordermark">ByteOrderMark</a>
  type <a href="#type-trivium">trivium</a> = {<a href="#fld-trivium.kind">kind</a> : trivia, <a href="#fld-trivium.start">start</a> : int, <a href="#fld-trivium.stop">stop</a> : int}
  type <a href="#type-item">item</a> = {<a href="#fld-item.token">token</a> : token, <a href="#fld-item.start">start</a> : int, <a href="#fld-item.stop">stop</a> : int, <a href="#fld-item.line">line</a> : int, <a href="#fld-item.column">column</a> : int, <a href="#fld-item.first">first</a> : bool,
               <a href="#fld-item.trivia">trivia</a> : trivium list}
  val <a href="#val-reservedid">reservedId</a> : string -&gt; token option
  val <a href="#val-reservedop">reservedOp</a> : string -&gt; token option
  val <a href="#val-show">show</a> : token -&gt; string
  val <a href="#val-describe">describe</a> : token -&gt; string
  val <a href="#val-plain">plain</a> : token -&gt; token
end
</pre>

### <a name="type-token"></a>`token`

```sml
datatype token =
    VARID of string
  | CONID of string
  | QVARID of string * string
  | QCONID of string * string
  | VARSYM of string
  | CONSYM of string
  | QVARSYM of string * string
  | QCONSYM of string * string
  | INTEGER of IntInf.int * string
  | FLOAT of string
  | CHAR of int * string
  | STRING of int list * string
  | LPAREN | RPAREN | COMMA | SEMI | LBRACKET | RBRACKET | BACKQUOTE | LBRACE
  | RBRACE
  | DOTDOT | COLON | DCOLON | EQUALS | BACKSLASH | BAR | LARROW | RARROW | AT | TILDE
  | DARROW
  | CASE | CLASS | DATA | DEFAULT | DERIVING | DO | ELSE | IF | IMPORT | IN | INFIX
  | INFIXL | INFIXR | INSTANCE | LET | MODULE | NEWTYPE | OF | THEN | TYPE | WHERE
  | UNDERSCORE
  | VLBRACE
  | VSEMI
  | VRBRACE
  | EOF
```

A lexeme. A qualified name is its qualifier and its name; a literal
keeps its value and its text as written.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-varid"></a>`VARID` | `string` | `varid` |
| <a name="con-conid"></a>`CONID` | `string` | `conid` |
| <a name="con-qvarid"></a>`QVARID` | `string * string` | `qvarid` with its qualifier |
| <a name="con-qconid"></a>`QCONID` | `string * string` | `qconid` with its qualifier |
| <a name="con-varsym"></a>`VARSYM` | `string` | `varsym` |
| <a name="con-consym"></a>`CONSYM` | `string` | `consym` |
| <a name="con-qvarsym"></a>`QVARSYM` | `string * string` | `qvarsym` with its qualifier |
| <a name="con-qconsym"></a>`QCONSYM` | `string * string` | `qconsym` with its qualifier |
| <a name="con-integer"></a>`INTEGER` | `IntInf.int * string` | `integer`: its value, its text |
| <a name="con-float"></a>`FLOAT` | `string` | `float`: its text |
| <a name="con-char"></a>`CHAR` | `int * string` | `char`: its code point, its text |
| <a name="con-string"></a>`STRING` | `int list * string` | `string`: its code points, its text |
| <a name="con-lparen"></a>`LPAREN` |  |  |
| <a name="con-rparen"></a>`RPAREN` |  |  |
| <a name="con-comma"></a>`COMMA` |  |  |
| <a name="con-semi"></a>`SEMI` |  |  |
| <a name="con-lbracket"></a>`LBRACKET` |  |  |
| <a name="con-rbracket"></a>`RBRACKET` |  |  |
| <a name="con-backquote"></a>`BACKQUOTE` |  |  |
| <a name="con-lbrace"></a>`LBRACE` |  |  |
| <a name="con-rbrace"></a>`RBRACE` |  | `special` |
| <a name="con-dotdot"></a>`DOTDOT` |  |  |
| <a name="con-colon"></a>`COLON` |  |  |
| <a name="con-dcolon"></a>`DCOLON` |  |  |
| <a name="con-equals"></a>`EQUALS` |  |  |
| <a name="con-backslash"></a>`BACKSLASH` |  |  |
| <a name="con-bar"></a>`BAR` |  |  |
| <a name="con-larrow"></a>`LARROW` |  |  |
| <a name="con-rarrow"></a>`RARROW` |  |  |
| <a name="con-at"></a>`AT` |  |  |
| <a name="con-tilde"></a>`TILDE` |  |  |
| <a name="con-darrow"></a>`DARROW` |  | `reservedop` |
| <a name="con-case"></a>`CASE` |  |  |
| <a name="con-class"></a>`CLASS` |  |  |
| <a name="con-data"></a>`DATA` |  |  |
| <a name="con-default"></a>`DEFAULT` |  |  |
| <a name="con-deriving"></a>`DERIVING` |  |  |
| <a name="con-do"></a>`DO` |  |  |
| <a name="con-else"></a>`ELSE` |  |  |
| <a name="con-if"></a>`IF` |  |  |
| <a name="con-import"></a>`IMPORT` |  |  |
| <a name="con-in"></a>`IN` |  |  |
| <a name="con-infix"></a>`INFIX` |  |  |
| <a name="con-infixl"></a>`INFIXL` |  |  |
| <a name="con-infixr"></a>`INFIXR` |  |  |
| <a name="con-instance"></a>`INSTANCE` |  |  |
| <a name="con-let"></a>`LET` |  |  |
| <a name="con-module"></a>`MODULE` |  |  |
| <a name="con-newtype"></a>`NEWTYPE` |  |  |
| <a name="con-of"></a>`OF` |  |  |
| <a name="con-then"></a>`THEN` |  |  |
| <a name="con-type"></a>`TYPE` |  |  |
| <a name="con-where"></a>`WHERE` |  |  |
| <a name="con-underscore"></a>`UNDERSCORE` |  | `reservedid` |
| <a name="con-vlbrace"></a>`VLBRACE` |  | layout's `{` |
| <a name="con-vsemi"></a>`VSEMI` |  | layout's `;` |
| <a name="con-vrbrace"></a>`VRBRACE` |  | layout's `}` |
| <a name="con-eof"></a>`EOF` |  | the end of the input |

### <a name="type-trivia"></a>`trivia`

```sml
datatype trivia =
    Whitespace
  | LineComment
  | BlockComment
  | Pragma
  | ByteOrderMark
```

What a stretch of trivia is.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-whitespace"></a>`Whitespace` |  | white space; in a literate file, its commentary too |
| <a name="con-linecomment"></a>`LineComment` |  | `--` to the end of the line |
| <a name="con-blockcomment"></a>`BlockComment` |  | `{-` to its `-}` |
| <a name="con-pragma"></a>`Pragma` |  | `{-#` to its `#-}`, which the Report's chapter 11 reads as a comment |
| <a name="con-byteordermark"></a>`ByteOrderMark` |  | the bytes EF BB BF at the head of the file |

### <a name="type-trivium"></a>`trivium`

```sml
type trivium = {kind : trivia, start : int, stop : int}
```

A stretch of trivia, by the bytes of the file it covers.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-trivium.kind"></a>`kind` | `trivia` |  |
| <a name="fld-trivium.start"></a>`start` | `int` |  |
| <a name="fld-trivium.stop"></a>`stop` | `int` |  |

### <a name="type-item"></a>`item`

```sml
type item = {token : token, start : int, stop : int, line : int, column : int, first : bool,
             trivia : trivium list}
```

A token as the lexer reads it, with where it is.

The bytes it covers, the line it is on, its column as layout counts
it (a tab to the next multiple of eight, plus one), whether it is the
first token of its line, and the trivia before it.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-item.token"></a>`token` | `token` |  |
| <a name="fld-item.start"></a>`start` | `int` |  |
| <a name="fld-item.stop"></a>`stop` | `int` |  |
| <a name="fld-item.line"></a>`line` | `int` |  |
| <a name="fld-item.column"></a>`column` | `int` |  |
| <a name="fld-item.first"></a>`first` | `bool` |  |
| <a name="fld-item.trivia"></a>`trivia` | `trivium list` |  |

### <a name="val-reservedid"></a>`reservedId`

```sml
val reservedId : string -> token option
```

`reservedId s` is the keyword `s` is, if it is one; `_` among them.

### <a name="val-reservedop"></a>`reservedOp`

```sml
val reservedOp : string -> token option
```

`reservedOp s` is the reserved operator `s` is, if it is one.

### <a name="val-show"></a>`show`

```sml
val show : token -> string
```

`show t` is the text `t` stands for, `{v`, `v;` and `v}` for layout's
tokens and `<eof>` for the end.

### <a name="val-describe"></a>`describe`

```sml
val describe : token -> string
```

`describe t` names `t` in a diagnostic: its text in backquotes, and
layout's tokens and the end by what they are.

### <a name="val-plain"></a>`plain`

```sml
val plain : token -> token
```

`plain t` is the written token that layout's `t` stands for, and `t`
when it is not layout's.

---

<sub>Generated by runedoc from lib/language/haskell/token\_sig.sml; do not edit.</sub>
