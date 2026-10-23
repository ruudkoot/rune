# signature WIN32_GUI_DRIVER

[Shared Win32 GUI contracts](../README.md) &rsaquo; Foreign interfaces &rsaquo; **WIN32_GUI_DRIVER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | none |
| Documentation | 19 of 19 entries documented |
| Tests | not listed |
| Source | [lib/ffi/win32/common/driver\_sig.sml](../../../../../../lib/ffi/win32/common/driver_sig.sml) |

## Synopsis

```sml
signature WIN32_GUI_DRIVER
```

Thin GUI driver used by the shared Win32 SDL and mock semantics.

## Interface

<pre>
signature WIN32_GUI_DRIVER =
sig
  eqtype <a href="#type-window">window</a>
  type <a href="#type-drawing">drawing</a>
  datatype <a href="#type-event">event</a> = <a href="#con-quit">Quit</a> | <a href="#con-message">Message</a> of window * Win32Common.Types.message
  val <a href="#val-externalevents">externalEvents</a> : bool
  val <a href="#val-create">create</a> : {<a href="#fld-create.title">title</a>:string,<a href="#fld-create.width">width</a>:int,<a href="#fld-create.height">height</a>:int,<a href="#fld-create.visible">visible</a>:bool,<a href="#fld-create.resizable">resizable</a>:bool} -&gt; window
  val <a href="#val-destroy">destroy</a> : window -&gt; unit
  val <a href="#val-show">show</a> : window * int -&gt; unit
  val <a href="#val-title">title</a> : window * string -&gt; unit
  val <a href="#val-client">client</a> : window -&gt; {<a href="#fld-client.width">width</a>:int,<a href="#fld-client.height">height</a>:int}
  val <a href="#val-begin">begin</a> : window -&gt; drawing
  val <a href="#val-finish">finish</a> : drawing -&gt; unit
  val <a href="#val-fill">fill</a> : {<a href="#fld-fill.drawing">drawing</a>:drawing,<a href="#fld-fill.rectangle">rectangle</a>:Win32Common.Types.rect,<a href="#fld-fill.colour">colour</a>:Word32.word} -&gt; unit
  val <a href="#val-line">line</a> : {<a href="#fld-line.drawing">drawing</a>:drawing,<a href="#fld-line.x1">x1</a>:int,<a href="#fld-line.y1">y1</a>:int,<a href="#fld-line.x2">x2</a>:int,<a href="#fld-line.y2">y2</a>:int,<a href="#fld-line.width">width</a>:int,<a href="#fld-line.colour">colour</a>:Word32.word} -&gt; unit
  val <a href="#val-text">text</a> : {<a href="#fld-text.drawing">drawing</a>:drawing,<a href="#fld-text.x">x</a>:int,<a href="#fld-text.y">y</a>:int,<a href="#fld-text.text">text</a>:string,<a href="#fld-text.colour">colour</a>:Word32.word,<a href="#fld-text.opaque">opaque</a>:bool,<a href="#fld-text.background">background</a>:Word32.word} -&gt; unit
  val <a href="#val-poll">poll</a> : unit -&gt; event option
  val <a href="#val-ticks">ticks</a> : unit -&gt; IntInf.int
  val <a href="#val-counter">counter</a> : unit -&gt; Int64.int
  val <a href="#val-frequency">frequency</a> : unit -&gt; Int64.int
  val <a href="#val-delay">delay</a> : Word32.word -&gt; unit
end
</pre>

### <a name="type-window"></a>`window`

```sml
eqtype window
```

A driver-owned window, separate from the portable public token.

### <a name="type-drawing"></a>`drawing`

```sml
type drawing
```

A drawing scope owned by this driver.

### <a name="type-event"></a>`event`

```sml
datatype event = Quit | Message of window * Win32Common.Types.message
```

A normalized external event; the model owns class procedure dispatch.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-quit"></a>`Quit` |  |  |
| <a name="con-message"></a>`Message` | `window * Win32Common.Types.message` |  |

### <a name="val-externalevents"></a>`externalEvents`

```sml
val externalEvents : bool
```

Whether events may arrive independently of deterministic model state.

### <a name="val-create"></a>`create`

```sml
val create : {title:string,width:int,height:int,visible:bool,resizable:bool} -> window
```

`create specification` creates a driver window without invoking SML procedures.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-create.title"></a>`title` | `string` |  |
| <a name="fld-create.width"></a>`width` | `int` |  |
| <a name="fld-create.height"></a>`height` | `int` |  |
| <a name="fld-create.visible"></a>`visible` | `bool` |  |
| <a name="fld-create.resizable"></a>`resizable` | `bool` |  |

### <a name="val-destroy"></a>`destroy`

```sml
val destroy : window -> unit
```

`destroy window` releases a driver window and its drawing resources.

### <a name="val-show"></a>`show`

```sml
val show : window * int -> unit
```

`show (window, command)` applies a supported Win32 visibility command.

### <a name="val-title"></a>`title`

```sml
val title : window * string -> unit
```

`title (window, text)` changes the UTF-8 window title.

### <a name="val-client"></a>`client`

```sml
val client : window -> {width:int,height:int}
```

`client window` reads its current client dimensions.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-client.width"></a>`width` | `int` |  |
| <a name="fld-client.height"></a>`height` | `int` |  |

### <a name="val-begin"></a>`begin`

```sml
val begin : window -> drawing
```

`begin window` acquires a drawing scope.

### <a name="val-finish"></a>`finish`

```sml
val finish : drawing -> unit
```

`finish drawing` presents the completed drawing and releases its scope.

### <a name="val-fill"></a>`fill`

```sml
val fill : {drawing:drawing,rectangle:Win32Common.Types.rect,colour:Word32.word} -> unit
```

`fill specification` fills an exclusive-edge rectangle with RGB colour.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-fill.drawing"></a>`drawing` | `drawing` |  |
| <a name="fld-fill.rectangle"></a>`rectangle` | `Win32Common.Types.rect` |  |
| <a name="fld-fill.colour"></a>`colour` | `Word32.word` |  |

### <a name="val-line"></a>`line`

```sml
val line : {drawing:drawing,x1:int,y1:int,x2:int,y2:int,width:int,colour:Word32.word} -> unit
```

`line specification` draws a solid line with the requested positive width.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-line.drawing"></a>`drawing` | `drawing` |  |
| <a name="fld-line.x1"></a>`x1` | `int` |  |
| <a name="fld-line.y1"></a>`y1` | `int` |  |
| <a name="fld-line.x2"></a>`x2` | `int` |  |
| <a name="fld-line.y2"></a>`y2` | `int` |  |
| <a name="fld-line.width"></a>`width` | `int` |  |
| <a name="fld-line.colour"></a>`colour` | `Word32.word` |  |

### <a name="val-text"></a>`text`

```sml
val text : {drawing:drawing,x:int,y:int,text:string,colour:Word32.word,opaque:bool,background:Word32.word} -> unit
```

`text specification` draws fixed ASCII text with the declared background mode.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-text.drawing"></a>`drawing` | `drawing` |  |
| <a name="fld-text.x"></a>`x` | `int` |  |
| <a name="fld-text.y"></a>`y` | `int` |  |
| <a name="fld-text.text"></a>`text` | `string` |  |
| <a name="fld-text.colour"></a>`colour` | `Word32.word` |  |
| <a name="fld-text.opaque"></a>`opaque` | `bool` |  |
| <a name="fld-text.background"></a>`background` | `Word32.word` |  |

### <a name="val-poll"></a>`poll`

```sml
val poll : unit -> event option
```

`poll ()` copies the next available external event.

### <a name="val-ticks"></a>`ticks`

```sml
val ticks : unit -> IntInf.int
```

`ticks ()` returns monotonic milliseconds as an unbounded integer.

### <a name="val-counter"></a>`counter`

```sml
val counter : unit -> Int64.int
```

`counter ()` returns the monotonic performance counter.

### <a name="val-frequency"></a>`frequency`

```sml
val frequency : unit -> Int64.int
```

`frequency ()` returns performance counter ticks per second.

### <a name="val-delay"></a>`delay`

```sml
val delay : Word32.word -> unit
```

`delay milliseconds` waits, or advances deterministic mock time.

---

<sub>Generated by runedoc from lib/ffi/win32/common/driver\_sig.sml; do not edit.</sub>
