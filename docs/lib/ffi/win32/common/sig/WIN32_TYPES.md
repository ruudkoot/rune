# signature WIN32_TYPES

[Shared Win32 GUI contracts](../README.md) &rsaquo; Foreign interfaces &rsaquo; **WIN32_TYPES**

|  |  |
| --- | --- |
| Status | required |
| Implementations | none |
| Documentation | 14 of 14 entries documented |
| Tests | not listed |
| Source | [lib/ffi/win32/common/types\_sig.sml](../../../../../../lib/ffi/win32/common/types_sig.sml) |

## Synopsis

```sml
signature WIN32_TYPES
```

Shared public identities and messages for the Win32 GUI subset.

## Interface

<pre>
signature WIN32_TYPES =
sig
  eqtype <a href="#type-window">window</a>
  eqtype <a href="#type-module">module</a>
  eqtype <a href="#type-atom">atom</a>
  eqtype <a href="#type-paint">paint</a>
  eqtype <a href="#type-object">object</a>
  eqtype <a href="#type-pen">pen</a>
  eqtype <a href="#type-brush">brush</a>
  type <a href="#type-rect">rect</a> = {<a href="#fld-rect.left">left</a> : Int32.int, <a href="#fld-rect.top">top</a> : Int32.int, <a href="#fld-rect.right">right</a> : Int32.int, <a href="#fld-rect.bottom">bottom</a> : Int32.int}
  datatype <a href="#type-message">message</a> = <a href="#con-nccreate">NcCreate</a> | <a href="#con-create">Create</a> | <a href="#con-size">Size</a> of {<a href="#fld-size.width">width</a> : int, <a href="#fld-size.height">height</a> : int}
    | <a href="#con-paint">Paint</a> | <a href="#con-close">Close</a> | <a href="#con-destroy">Destroy</a> | <a href="#con-ncdestroy">NcDestroy</a>
    | <a href="#con-keydown">KeyDown</a> of {<a href="#fld-keydown.key">key</a> : Word32.word, <a href="#fld-keydown.repeated">repeated</a> : bool}
    | <a href="#con-keyup">KeyUp</a> of Word32.word | <a href="#con-char">Char</a> of Word16.word
    | <a href="#con-mousemove">MouseMove</a> of {<a href="#fld-mousemove.x">x</a> : int, <a href="#fld-mousemove.y">y</a> : int, <a href="#fld-mousemove.buttons">buttons</a> : Word32.word}
    | <a href="#con-buttondown">ButtonDown</a> of {<a href="#fld-buttondown.button">button</a> : int, <a href="#fld-buttondown.x">x</a> : int, <a href="#fld-buttondown.y">y</a> : int}
    | <a href="#con-buttonup">ButtonUp</a> of {<a href="#fld-buttonup.button">button</a> : int, <a href="#fld-buttonup.x">x</a> : int, <a href="#fld-buttonup.y">y</a> : int}
    | <a href="#con-timer">Timer</a> of Word64.word
    | <a href="#con-application">Application</a> of {<a href="#fld-application.code">code</a> : Word32.word, <a href="#fld-application.w">w</a> : Word64.word, <a href="#fld-application.l">l</a> : Int64.int}
    | <a href="#con-unknown">Unknown</a> of Word32.word
  datatype <a href="#type-reply">reply</a> = <a href="#con-default">Default</a> | <a href="#con-result">Result</a> of Int64.int
  type <a href="#type-queued">queued</a>
  datatype <a href="#type-next">next</a> = <a href="#con-quit">Quit</a> of Int32.int | <a href="#con-message">Message</a> of queued
  exception <a href="#exn-error">Error</a> of {<a href="#fld-error.function">function</a> : string, <a href="#fld-error.code">code</a> : Word32.word}
  exception <a href="#exn-unsupported">Unsupported</a> of string
end
</pre>

### <a name="type-window"></a>`window`

```sml
eqtype window
```

An abstract window identity; operations validate its provider and lifetime.

### <a name="type-module"></a>`module`

```sml
eqtype module
```

An abstract process module identity.

### <a name="type-atom"></a>`atom`

```sml
eqtype atom
```

A registered window class owned by one implementation.

### <a name="type-paint"></a>`paint`

```sml
eqtype paint
```

An active BeginPaint scope, valid until its matching EndPaint.

### <a name="type-object"></a>`object`

```sml
eqtype object
```

A GDI object identity; selected and stock objects have distinct ownership.

### <a name="type-pen"></a>`pen`

```sml
eqtype pen
```

A pen identity sharing its object lifetime.

### <a name="type-brush"></a>`brush`

```sml
eqtype brush
```

A brush identity sharing its object lifetime.

### <a name="type-rect"></a>`rect`

```sml
type rect = {left : Int32.int, top : Int32.int, right : Int32.int, bottom : Int32.int}
```

Client coordinates; the right and bottom edges are exclusive.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-rect.left"></a>`left` | `Int32.int` |  |
| <a name="fld-rect.top"></a>`top` | `Int32.int` |  |
| <a name="fld-rect.right"></a>`right` | `Int32.int` |  |
| <a name="fld-rect.bottom"></a>`bottom` | `Int32.int` |  |

### <a name="type-message"></a>`message`

```sml
datatype message = NcCreate | Create | Size of {width : int, height : int}
  | Paint | Close | Destroy | NcDestroy
  | KeyDown of {key : Word32.word, repeated : bool}
  | KeyUp of Word32.word | Char of Word16.word
  | MouseMove of {x : int, y : int, buttons : Word32.word}
  | ButtonDown of {button : int, x : int, y : int}
  | ButtonUp of {button : int, x : int, y : int}
  | Timer of Word64.word
  | Application of {code : Word32.word, w : Word64.word, l : Int64.int}
  | Unknown of Word32.word
```

Normalized GUI messages.

Char carries one UTF-16 code unit, including lone
surrogates. Application preserves the caller's integer payload. Native
default processing retains the original message's complete ABI payload.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-nccreate"></a>`NcCreate` |  |  |
| <a name="con-create"></a>`Create` |  |  |
| <a name="con-size"></a>`Size` | `{width : int, height : int}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-size.width"></a>`width` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-size.height"></a>`height` | `int` |  |
| <a name="con-paint"></a>`Paint` |  |  |
| <a name="con-close"></a>`Close` |  |  |
| <a name="con-destroy"></a>`Destroy` |  |  |
| <a name="con-ncdestroy"></a>`NcDestroy` |  |  |
| <a name="con-keydown"></a>`KeyDown` | `{key : Word32.word, repeated : bool}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-keydown.key"></a>`key` | `Word32.word` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-keydown.repeated"></a>`repeated` | `bool` |  |
| <a name="con-keyup"></a>`KeyUp` | `Word32.word` |  |
| <a name="con-char"></a>`Char` | `Word16.word` |  |
| <a name="con-mousemove"></a>`MouseMove` | `{x : int, y : int, buttons : Word32.word}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousemove.x"></a>`x` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousemove.y"></a>`y` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousemove.buttons"></a>`buttons` | `Word32.word` |  |
| <a name="con-buttondown"></a>`ButtonDown` | `{button : int, x : int, y : int}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-buttondown.button"></a>`button` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-buttondown.x"></a>`x` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-buttondown.y"></a>`y` | `int` |  |
| <a name="con-buttonup"></a>`ButtonUp` | `{button : int, x : int, y : int}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-buttonup.button"></a>`button` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-buttonup.x"></a>`x` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-buttonup.y"></a>`y` | `int` |  |
| <a name="con-timer"></a>`Timer` | `Word64.word` |  |
| <a name="con-application"></a>`Application` | `{code : Word32.word, w : Word64.word, l : Int64.int}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-application.code"></a>`code` | `Word32.word` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-application.w"></a>`w` | `Word64.word` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-application.l"></a>`l` | `Int64.int` |  |
| <a name="con-unknown"></a>`Unknown` | `Word32.word` |  |

### <a name="type-reply"></a>`reply`

```sml
datatype reply = Default | Result of Int64.int
```

Default asks the provider to perform its documented default behavior.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-default"></a>`Default` |  |  |
| <a name="con-result"></a>`Result` | `Int64.int` |  |

### <a name="type-queued"></a>`queued`

```sml
type queued
```

A copied message returned by GetMessage or PeekMessage.

Dispatch or discard each copy; both end its lifetime.

### <a name="type-next"></a>`next`

```sml
datatype next = Quit of Int32.int | Message of queued
```

A quit status or one copied queued message.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-quit"></a>`Quit` | `Int32.int` |  |
| <a name="con-message"></a>`Message` | `queued` |  |

### <a name="exn-error"></a>`Error`

```sml
exception Error of {function : string, code : Word32.word}
```

A captured native-style error, before conversion or resource cleanup.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-error.function"></a>`function` | `string` |  |
| <a name="fld-error.code"></a>`code` | `Word32.word` |  |

### <a name="exn-unsupported"></a>`Unsupported`

```sml
exception Unsupported of string
```

An explicit operation outside the delivered provider's contract.

---

<sub>Generated by runedoc from lib/ffi/win32/common/types\_sig.sml; do not edit.</sub>
