# signature C_PARSE

[C declaration frontend](../README.md) &rsaquo; Languages &rsaquo; **C_PARSE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 9 of 9 entries documented |
| Tests | not listed |
| Source | [lib/language/c/parse\_sig.sml](../../../../../lib/language/c/parse_sig.sml) |

## Synopsis

```sml
signature C_PARSE
structure CParse : C_PARSE
```

| Implementation |  | Source |
| --- | --- | --- |
| [`CParse`](../str/CParse.md) |  | [lib/language/c/parse.sml](../../../../../lib/language/c/parse.sml) |

Target-neutral C declarations, retaining layout-affecting syntax.

## Interface

<pre>
signature C_PARSE =
sig
  datatype <a href="#type-recordkind">recordKind</a> = <a href="#con-struct">Struct</a> | <a href="#con-union">Union</a>
  type <a href="#type-attribute">attribute</a> = CLex.token list
  datatype <a href="#type-ctype">ctype</a> =
      <a href="#con-builtin">Builtin</a> of string
    | <a href="#con-named">Named</a> of string
    | <a href="#con-pointer">Pointer</a> of {<a href="#fld-pointer.target">target</a> : ctype, <a href="#fld-pointer.qualifiers">qualifiers</a> : string list}
    | <a href="#con-array">Array</a> of {<a href="#fld-array.element">element</a> : ctype, <a href="#fld-array.bound">bound</a> : CLex.token list}
    | <a href="#con-function">Function</a> of {<a href="#fld-function.result">result</a> : ctype, <a href="#fld-function.parameters">parameters</a> : parameter list,
                   <a href="#fld-function.variadic">variadic</a> : bool, <a href="#fld-function.prototype">prototype</a> : bool}
    | <a href="#con-record">Record</a> of {<a href="#fld-record.kind">kind</a> : recordKind, <a href="#fld-record.tag">tag</a> : string option, <a href="#fld-record.fields">fields</a> : field list option,
                 <a href="#fld-record.pack">pack</a> : int option}
    | <a href="#con-enum">Enum</a> of {<a href="#fld-enum.tag">tag</a> : string option, <a href="#fld-enum.values">values</a> : (string * CLex.token list) list option}
    | <a href="#con-attributed">Attributed</a> of ctype * attribute list
  and <a href="#type-parameter">parameter</a> = <a href="#con-parameter">Parameter</a> of {<a href="#fld-parameter.name">name</a> : string option, <a href="#fld-parameter.ctype">ctype</a> : ctype}
  and <a href="#type-field">field</a> = <a href="#con-field">Field</a> of {<a href="#fld-field.name">name</a> : string option, <a href="#fld-field.ctype">ctype</a> : ctype, <a href="#fld-field.bits">bits</a> : CLex.token list,
                        <a href="#fld-field.location">location</a> : CLex.location}
  datatype <a href="#type-declaration">declaration</a> = <a href="#con-declaration">Declaration</a> of
    {<a href="#fld-declaration.name">name</a> : string option, <a href="#fld-declaration.ctype">ctype</a> : ctype, <a href="#fld-declaration.storage">storage</a> : string list,
     <a href="#fld-declaration.initializer">initializer</a> : CLex.token list, <a href="#fld-declaration.body">body</a> : CLex.token list,
     <a href="#fld-declaration.location">location</a> : CLex.location}
    | <a href="#con-staticassert">StaticAssert</a> of {<a href="#fld-staticassert.condition">condition</a> : CLex.token list, <a href="#fld-staticassert.message">message</a> : CLex.token list,
                       <a href="#fld-staticassert.location">location</a> : CLex.location}
  exception <a href="#exn-error">Error</a> of CLex.location * string
  val <a href="#val-translationunit">translationUnit</a> : {<a href="#fld-translationunit.tokens">tokens</a> : CLex.token list, <a href="#fld-translationunit.predefinedtypes">predefinedTypes</a> : string list} -&gt;
                        {declarations : declaration list, pragmas : attribute list}
  val <a href="#val-typename">typeName</a> : {<a href="#fld-typename.tokens">tokens</a> : CLex.token list, <a href="#fld-typename.predefinedtypes">predefinedTypes</a> : string list} -&gt; ctype
end
</pre>

### <a name="type-recordkind"></a>`recordKind`

```sml
datatype recordKind = Struct | Union
```

Aggregate kind, kept distinct even when layouts happen to coincide.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-struct"></a>`Struct` |  |  |
| <a name="con-union"></a>`Union` |  |  |

### <a name="type-attribute"></a>`attribute`

```sml
type attribute = CLex.token list
```

Syntax attributes retain original tokens: calling conventions,
compiler attributes, qualifiers and alignment are not inferred away.

### <a name="type-ctype"></a>`ctype`

```sml
datatype ctype =
    Builtin of string
  | Named of string
  | Pointer of {target : ctype, qualifiers : string list}
  | Array of {element : ctype, bound : CLex.token list}
  | Function of {result : ctype, parameters : parameter list,
                 variadic : bool, prototype : bool}
  | Record of {kind : recordKind, tag : string option, fields : field list option,
               pack : int option}
  | Enum of {tag : string option, values : (string * CLex.token list) list option}
  | Attributed of ctype * attribute list
```

C types before target layout and FFI policy. Bounds, bit widths and
enum values retain constant-expression tokens for target evaluation.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-builtin"></a>`Builtin` | `string` |  |
| <a name="con-named"></a>`Named` | `string` |  |
| <a name="con-pointer"></a>`Pointer` | `{target : ctype, qualifiers : string list}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-pointer.target"></a>`target` | `ctype` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-pointer.qualifiers"></a>`qualifiers` | `string list` |  |
| <a name="con-array"></a>`Array` | `{element : ctype, bound : CLex.token list}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-array.element"></a>`element` | `ctype` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-array.bound"></a>`bound` | `CLex.token list` |  |
| <a name="con-function"></a>`Function` | `{result : ctype, parameters : parameter list, variadic : bool, prototype : bool}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-function.result"></a>`result` | `ctype` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-function.parameters"></a>`parameters` | `parameter list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-function.variadic"></a>`variadic` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-function.prototype"></a>`prototype` | `bool` |  |
| <a name="con-record"></a>`Record` | `{kind : recordKind, tag : string option, fields : field list option, pack : int option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-record.kind"></a>`kind` | `recordKind` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-record.tag"></a>`tag` | `string option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-record.fields"></a>`fields` | `field list option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-record.pack"></a>`pack` | `int option` |  |
| <a name="con-enum"></a>`Enum` | `{tag : string option, values : (string * CLex.token list) list option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-enum.tag"></a>`tag` | `string option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-enum.values"></a>`values` | `(string * CLex.token list) list option` |  |
| <a name="con-attributed"></a>`Attributed` | `ctype * attribute list` |  |

### <a name="type-parameter"></a>`parameter`

```sml
datatype parameter = Parameter of {name : string option, ctype : ctype}
```

A function parameter, including abstract declarators without a name.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-parameter"></a>`Parameter` | `{name : string option, ctype : ctype}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-parameter.name"></a>`name` | `string option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-parameter.ctype"></a>`ctype` | `ctype` |  |

### <a name="type-field"></a>`field`

```sml
datatype field = Field of {name : string option, ctype : ctype, bits : CLex.token list,
                      location : CLex.location}
```

An aggregate member, including anonymous members and bitfields.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-field"></a>`Field` | `{name : string option, ctype : ctype, bits : CLex.token list, location : CLex.location}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-field.name"></a>`name` | `string option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-field.ctype"></a>`ctype` | `ctype` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-field.bits"></a>`bits` | `CLex.token list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-field.location"></a>`location` | `CLex.location` |  |

### <a name="type-declaration"></a>`declaration`

```sml
datatype declaration = Declaration of
  {name : string option, ctype : ctype, storage : string list,
   initializer : CLex.token list, body : CLex.token list,
   location : CLex.location}
  | StaticAssert of {condition : CLex.token list, message : CLex.token list,
                     location : CLex.location}
```

A declaration or definition; inline bodies remain balanced syntax,
not a claim that the frontend implements C statement semantics.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-declaration"></a>`Declaration` | `{name : string option, ctype : ctype, storage : string list, initializer : CLex.token list, body : CLex.token list, location : CLex.location}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-declaration.name"></a>`name` | `string option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-declaration.ctype"></a>`ctype` | `ctype` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-declaration.storage"></a>`storage` | `string list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-declaration.initializer"></a>`initializer` | `CLex.token list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-declaration.body"></a>`body` | `CLex.token list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-declaration.location"></a>`location` | `CLex.location` |  |
| <a name="con-staticassert"></a>`StaticAssert` | `{condition : CLex.token list, message : CLex.token list, location : CLex.location}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-staticassert.condition"></a>`condition` | `CLex.token list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-staticassert.message"></a>`message` | `CLex.token list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-staticassert.location"></a>`location` | `CLex.location` |  |

### <a name="exn-error"></a>`Error`

```sml
exception Error of CLex.location * string
```

A source-located syntactic error or unsupported extension.

### <a name="val-translationunit"></a>`translationUnit`

```sml
val translationUnit : {tokens : CLex.token list, predefinedTypes : string list} ->
                      {declarations : declaration list, pragmas : attribute list}
```

`translationUnit {tokens, predefinedTypes}` parses preprocessed input
with typedef-sensitive declarators.

It preserves pragmas and applies
`pack` push/pop state to aggregate definitions. Unmatched packing and
unterminated syntax fail explicitly.

**Raises** [`Error`](#exn-error) for malformed declarations or unsupported syntax.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-translationunit.tokens"></a>`tokens` | `CLex.token list` |  |
| <a name="fld-translationunit.predefinedtypes"></a>`predefinedTypes` | `string list` |  |

### <a name="val-typename"></a>`typeName`

```sml
val typeName : {tokens : CLex.token list, predefinedTypes : string list} -> ctype
```

`typeName {tokens, predefinedTypes}` parses one abstract C type name.

It accepts array and function declarators without changing their shape.

**Raises** [`Error`](#exn-error) for named declarators, storage classes or trailing syntax.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-typename.tokens"></a>`tokens` | `CLex.token list` |  |
| <a name="fld-typename.predefinedtypes"></a>`predefinedTypes` | `string list` |  |

---

<sub>Generated by runedoc from lib/language/c/parse\_sig.sml; do not edit.</sub>
