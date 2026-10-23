# signature WIN32

[Shared Win32 GUI contracts](../README.md) &rsaquo; Foreign interfaces &rsaquo; **WIN32**

|  |  |
| --- | --- |
| Status | required |
| Implementations | none |
| Documentation | 46 of 46 entries documented |
| Tests | not listed |
| Source | [lib/ffi/win32/common/win32\_sig.sml](../../../../../../lib/ffi/win32/common/win32_sig.sml) |

## Synopsis

```sml
signature WIN32
```

Stable GUI subset implemented by native Windows, SDL3 and mocks.

## Interface

<pre>
signature WIN32 =
sig
  structure <a href="#str-types">Types</a> : WIN32_TYPES
  structure <a href="#str-kernel">Kernel</a> :
  sig
    val <a href="#val-kernel.getmodulehandle">getModuleHandle</a> : string option -&gt; Types.module
    val <a href="#val-kernel.getlasterror">getLastError</a> : unit -&gt; Word32.word
    val <a href="#val-kernel.setlasterror">setLastError</a> : Word32.word -&gt; unit
    val <a href="#val-kernel.queryperformancecounter">queryPerformanceCounter</a> : unit -&gt; Int64.int
    val <a href="#val-kernel.queryperformancefrequency">queryPerformanceFrequency</a> : unit -&gt; Int64.int
  end
  structure <a href="#str-user">User</a> :
  sig
    val <a href="#val-user.registerclassex">registerClassEx</a> : {<a href="#fld-user.registerclassex.name">name</a> : string, <a href="#fld-user.registerclassex.instance">instance</a> : Types.module,
                          <a href="#fld-user.registerclassex.style">style</a> : Word32.word,
                          <a href="#fld-user.registerclassex.procedure">procedure</a> : Types.window * Types.message -&gt; Types.reply} -&gt; Types.atom
    val <a href="#val-user.unregisterclass">unregisterClass</a> : Types.atom * Types.module -&gt; unit
    val <a href="#val-user.createwindowex">createWindowEx</a> : {<a href="#fld-user.createwindowex.class">class</a> : Types.atom, <a href="#fld-user.createwindowex.instance">instance</a> : Types.module,
                          <a href="#fld-user.createwindowex.title">title</a> : string, <a href="#fld-user.createwindowex.style">style</a> : Word32.word, <a href="#fld-user.createwindowex.extendedstyle">extendedStyle</a> : Word32.word,
                          <a href="#fld-user.createwindowex.x">x</a> : int, <a href="#fld-user.createwindowex.y">y</a> : int, <a href="#fld-user.createwindowex.width">width</a> : int, <a href="#fld-user.createwindowex.height">height</a> : int,
                          <a href="#fld-user.createwindowex.parent">parent</a> : Types.window option} -&gt; Types.window
    val <a href="#val-user.destroywindow">destroyWindow</a> : Types.window -&gt; unit
    val <a href="#val-user.showwindow">showWindow</a> : Types.window * int -&gt; bool
    val <a href="#val-user.updatewindow">updateWindow</a> : Types.window -&gt; unit
    val <a href="#val-user.defwindowproc">defWindowProc</a> : Types.window * Types.message -&gt; Int64.int
    val <a href="#val-user.getclientrect">getClientRect</a> : Types.window -&gt; Types.rect
    val <a href="#val-user.setwindowtext">setWindowText</a> : Types.window * string -&gt; unit
    val <a href="#val-user.getmessage">getMessage</a> : {<a href="#fld-user.getmessage.window">window</a> : Types.window option, <a href="#fld-user.getmessage.minimum">minimum</a> : Word32.word,
                      <a href="#fld-user.getmessage.maximum">maximum</a> : Word32.word} -&gt; Types.next
    val <a href="#val-user.peekmessage">peekMessage</a> : {<a href="#fld-user.peekmessage.window">window</a> : Types.window option, <a href="#fld-user.peekmessage.minimum">minimum</a> : Word32.word,
                       <a href="#fld-user.peekmessage.maximum">maximum</a> : Word32.word, <a href="#fld-user.peekmessage.remove">remove</a> : bool} -&gt; Types.queued option
    val <a href="#val-user.translatemessage">translateMessage</a> : Types.queued -&gt; bool
    val <a href="#val-user.dispatchmessage">dispatchMessage</a> : Types.queued -&gt; Int64.int
    val <a href="#val-user.postquitmessage">postQuitMessage</a> : Int32.int -&gt; unit
    val <a href="#val-user.postmessage">postMessage</a> : Types.window * Types.message -&gt; unit
    val <a href="#val-user.sendmessage">sendMessage</a> : Types.window * Types.message -&gt; Int64.int
    val <a href="#val-user.invalidaterect">invalidateRect</a> : Types.window * Types.rect option * bool -&gt; unit
    val <a href="#val-user.beginpaint">beginPaint</a> : Types.window -&gt; Types.paint * Types.rect
    val <a href="#val-user.endpaint">endPaint</a> : Types.window * Types.paint -&gt; unit
    val <a href="#val-user.withpaint">withPaint</a> : Types.window -&gt; (Types.paint * Types.rect -&gt; 'a) -&gt; 'a
    val <a href="#val-user.fillrect">fillRect</a> : Types.paint * Types.rect * Types.brush -&gt; unit
    val <a href="#val-user.settimer">setTimer</a> : Types.window * Word64.word * Word32.word -&gt; Word64.word
    val <a href="#val-user.killtimer">killTimer</a> : Types.window * Word64.word -&gt; unit
  end
  structure <a href="#str-gdi">Gdi</a> :
  sig
    val <a href="#val-gdi.createpen">createPen</a> : {<a href="#fld-gdi.createpen.style">style</a> : int, <a href="#fld-gdi.createpen.width">width</a> : int, <a href="#fld-gdi.createpen.colour">colour</a> : Word32.word} -&gt; Types.pen
    val <a href="#val-gdi.createsolidbrush">createSolidBrush</a> : Word32.word -&gt; Types.brush
    val <a href="#val-gdi.penobject">penObject</a> : Types.pen -&gt; Types.object
    val <a href="#val-gdi.brushobject">brushObject</a> : Types.brush -&gt; Types.object
    val <a href="#val-gdi.objectbrush">objectBrush</a> : Types.object -&gt; Types.brush
    val <a href="#val-gdi.selectobject">selectObject</a> : Types.paint * Types.object -&gt; Types.object
    val <a href="#val-gdi.deleteobject">deleteObject</a> : Types.object -&gt; unit
    val <a href="#val-gdi.getstockobject">getStockObject</a> : int -&gt; Types.object
    val <a href="#val-gdi.movetoex">moveToEx</a> : Types.paint * int * int -&gt; {<a href="#fld-gdi.movetoex.x">x</a> : int, <a href="#fld-gdi.movetoex.y">y</a> : int}
    val <a href="#val-gdi.lineto">lineTo</a> : Types.paint * int * int -&gt; unit
    val <a href="#val-gdi.rectangle">rectangle</a> : Types.paint * Types.rect -&gt; unit
    val <a href="#val-gdi.settextcolor">setTextColor</a> : Types.paint * Word32.word -&gt; Word32.word
    val <a href="#val-gdi.setbkmode">setBkMode</a> : Types.paint * int -&gt; int
    val <a href="#val-gdi.textout">textOut</a> : Types.paint * int * int * string -&gt; unit
  end
end
</pre>

### <a name="str-types"></a>`Types`

```sml
structure Types : WIN32_TYPES
```

A substructure: its members are described on the page of [`WIN32_TYPES`](../sig/WIN32_TYPES.md).

Shared identities, copied messages and provider exceptions.

### <a name="str-kernel"></a>`Kernel`

Module, native error and monotonic clock support.

#### <a name="val-kernel.getmodulehandle"></a>`getModuleHandle`

```sml
val getModuleHandle : string option -> Types.module
```

`getModuleHandle name` looks up a process module; NONE selects the application module.

#### <a name="val-kernel.getlasterror"></a>`getLastError`

```sml
val getLastError : unit -> Word32.word
```

`getLastError ()` returns the last captured provider error.

#### <a name="val-kernel.setlasterror"></a>`setLastError`

```sml
val setLastError : Word32.word -> unit
```

`setLastError code` sets the provider error value.

#### <a name="val-kernel.queryperformancecounter"></a>`queryPerformanceCounter`

```sml
val queryPerformanceCounter : unit -> Int64.int
```

`queryPerformanceCounter ()` reads the monotonic performance counter.

#### <a name="val-kernel.queryperformancefrequency"></a>`queryPerformanceFrequency`

```sml
val queryPerformanceFrequency : unit -> Int64.int
```

`queryPerformanceFrequency ()` returns the counter ticks per second.

### <a name="str-user"></a>`User`

Owning-thread windows, message dispatch, timers and painting.

#### <a name="val-user.registerclassex"></a>`registerClassEx`

```sml
val registerClassEx : {name : string, instance : Types.module,
                      style : Word32.word,
                      procedure : Types.window * Types.message -> Types.reply} -> Types.atom
```

`registerClassEx specification` registers a named class and a same-thread window procedure.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-user.registerclassex.name"></a>`name` | `string` |  |
| <a name="fld-user.registerclassex.instance"></a>`instance` | `Types.module` |  |
| <a name="fld-user.registerclassex.style"></a>`style` | `Word32.word` |  |
| <a name="fld-user.registerclassex.procedure"></a>`procedure` | `Types.window * Types.message -> Types.reply` |  |

#### <a name="val-user.unregisterclass"></a>`unregisterClass`

```sml
val unregisterClass : Types.atom * Types.module -> unit
```

`unregisterClass (atom, instance)` unregisters a class after every associated window has ended.

#### <a name="val-user.createwindowex"></a>`createWindowEx`

```sml
val createWindowEx : {class : Types.atom, instance : Types.module,
                      title : string, style : Word32.word, extendedStyle : Word32.word,
                      x : int, y : int, width : int, height : int,
                      parent : Types.window option} -> Types.window
```

`createWindowEx specification` creates a window, delivering NcCreate and Create before returning its identity.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-user.createwindowex.class"></a>`class` | `Types.atom` |  |
| <a name="fld-user.createwindowex.instance"></a>`instance` | `Types.module` |  |
| <a name="fld-user.createwindowex.title"></a>`title` | `string` |  |
| <a name="fld-user.createwindowex.style"></a>`style` | `Word32.word` |  |
| <a name="fld-user.createwindowex.extendedstyle"></a>`extendedStyle` | `Word32.word` |  |
| <a name="fld-user.createwindowex.x"></a>`x` | `int` |  |
| <a name="fld-user.createwindowex.y"></a>`y` | `int` |  |
| <a name="fld-user.createwindowex.width"></a>`width` | `int` |  |
| <a name="fld-user.createwindowex.height"></a>`height` | `int` |  |
| <a name="fld-user.createwindowex.parent"></a>`parent` | `Types.window option` |  |

#### <a name="val-user.destroywindow"></a>`destroyWindow`

```sml
val destroyWindow : Types.window -> unit
```

`destroyWindow window` destroys the window, delivering Destroy and NcDestroy before closing its identity.

#### <a name="val-user.showwindow"></a>`showWindow`

```sml
val showWindow : Types.window * int -> bool
```

`showWindow (window, command)` changes visibility and returns the previous visibility.

#### <a name="val-user.updatewindow"></a>`updateWindow`

```sml
val updateWindow : Types.window -> unit
```

`updateWindow window` processes the pending paint region synchronously.

#### <a name="val-user.defwindowproc"></a>`defWindowProc`

```sml
val defWindowProc : Types.window * Types.message -> Int64.int
```

`defWindowProc (window, message)` performs the provider default action; Close destroys a live window.

#### <a name="val-user.getclientrect"></a>`getClientRect`

```sml
val getClientRect : Types.window -> Types.rect
```

`getClientRect window` returns its client rectangle.

#### <a name="val-user.setwindowtext"></a>`setWindowText`

```sml
val setWindowText : Types.window * string -> unit
```

`setWindowText (window, text)` sets the title using WTF-8 at native Windows boundaries.

#### <a name="val-user.getmessage"></a>`getMessage`

```sml
val getMessage : {window : Types.window option, minimum : Word32.word,
                  maximum : Word32.word} -> Types.next
```

`getMessage filter` waits for a matching queued message or a posted quit status.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-user.getmessage.window"></a>`window` | `Types.window option` |  |
| <a name="fld-user.getmessage.minimum"></a>`minimum` | `Word32.word` |  |
| <a name="fld-user.getmessage.maximum"></a>`maximum` | `Word32.word` |  |

#### <a name="val-user.peekmessage"></a>`peekMessage`

```sml
val peekMessage : {window : Types.window option, minimum : Word32.word,
                   maximum : Word32.word, remove : bool} -> Types.queued option
```

`peekMessage filter` returns a matching copied message when available, optionally removing it.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-user.peekmessage.window"></a>`window` | `Types.window option` |  |
| <a name="fld-user.peekmessage.minimum"></a>`minimum` | `Word32.word` |  |
| <a name="fld-user.peekmessage.maximum"></a>`maximum` | `Word32.word` |  |
| <a name="fld-user.peekmessage.remove"></a>`remove` | `bool` |  |

#### <a name="val-user.translatemessage"></a>`translateMessage`

```sml
val translateMessage : Types.queued -> bool
```

`translateMessage message` requests keyboard text translation and reports whether translation occurred.

#### <a name="val-user.dispatchmessage"></a>`dispatchMessage`

```sml
val dispatchMessage : Types.queued -> Int64.int
```

`dispatchMessage message` dispatches a copied message to its window procedure.

#### <a name="val-user.postquitmessage"></a>`postQuitMessage`

```sml
val postQuitMessage : Int32.int -> unit
```

`postQuitMessage status` queues the application quit status.

#### <a name="val-user.postmessage"></a>`postMessage`

```sml
val postMessage : Types.window * Types.message -> unit
```

`postMessage (window, message)` queues a supported message for later dispatch.

#### <a name="val-user.sendmessage"></a>`sendMessage`

```sml
val sendMessage : Types.window * Types.message -> Int64.int
```

`sendMessage (window, message)` dispatches synchronously, permitting nested same-thread sends.

#### <a name="val-user.invalidaterect"></a>`invalidateRect`

```sml
val invalidateRect : Types.window * Types.rect option * bool -> unit
```

`invalidateRect (window, rectangle, erase)` adds a client rectangle to the pending paint region.

#### <a name="val-user.beginpaint"></a>`beginPaint`

```sml
val beginPaint : Types.window -> Types.paint * Types.rect
```

`beginPaint window` begins a paint scope and returns its invalid rectangle.

#### <a name="val-user.endpaint"></a>`endPaint`

```sml
val endPaint : Types.window * Types.paint -> unit
```

`endPaint (window, paint)` ends the matching paint scope and invalidates its drawing capability.

#### <a name="val-user.withpaint"></a>`withPaint`

```sml
val withPaint : Types.window -> (Types.paint * Types.rect -> 'a) -> 'a
```

`withPaint window body` runs body inside a paint scope and ends it on every returning path.

#### <a name="val-user.fillrect"></a>`fillRect`

```sml
val fillRect : Types.paint * Types.rect * Types.brush -> unit
```

`fillRect (paint, rectangle, brush)` fills a rectangle with a live brush.

#### <a name="val-user.settimer"></a>`setTimer`

```sml
val setTimer : Types.window * Word64.word * Word32.word -> Word64.word
```

`setTimer (window, requested, milliseconds)` creates or replaces an owning-thread message timer and returns its identity.

#### <a name="val-user.killtimer"></a>`killTimer`

```sml
val killTimer : Types.window * Word64.word -> unit
```

`killTimer (window, identity)` cancels the associated message timer.

### <a name="str-gdi"></a>`Gdi`

Owned and borrowed drawing objects, geometry and text.

#### <a name="val-gdi.createpen"></a>`createPen`

```sml
val createPen : {style : int, width : int, colour : Word32.word} -> Types.pen
```

`createPen specification` creates an owned drawing pen.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-gdi.createpen.style"></a>`style` | `int` |  |
| <a name="fld-gdi.createpen.width"></a>`width` | `int` |  |
| <a name="fld-gdi.createpen.colour"></a>`colour` | `Word32.word` |  |

#### <a name="val-gdi.createsolidbrush"></a>`createSolidBrush`

```sml
val createSolidBrush : Word32.word -> Types.brush
```

`createSolidBrush colour` creates an owned solid colour brush.

#### <a name="val-gdi.penobject"></a>`penObject`

```sml
val penObject : Types.pen -> Types.object
```

`penObject pen` returns its generic object identity.

#### <a name="val-gdi.brushobject"></a>`brushObject`

```sml
val brushObject : Types.brush -> Types.object
```

`brushObject brush` returns its generic object identity.

#### <a name="val-gdi.objectbrush"></a>`objectBrush`

```sml
val objectBrush : Types.object -> Types.brush
```

`objectBrush object` returns a brush view after validating the object kind.

#### <a name="val-gdi.selectobject"></a>`selectObject`

```sml
val selectObject : Types.paint * Types.object -> Types.object
```

`selectObject (paint, object)` selects a live drawing object and returns the previous selection of that kind.

#### <a name="val-gdi.deleteobject"></a>`deleteObject`

```sml
val deleteObject : Types.object -> unit
```

`deleteObject object` deletes an owned, unselected object; borrowed stock objects are rejected.

#### <a name="val-gdi.getstockobject"></a>`getStockObject`

```sml
val getStockObject : int -> Types.object
```

`getStockObject index` returns a borrowed stock drawing object.

#### <a name="val-gdi.movetoex"></a>`moveToEx`

```sml
val moveToEx : Types.paint * int * int -> {x : int, y : int}
```

`moveToEx (paint, x, y)` sets the current drawing point and returns its previous coordinates.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-gdi.movetoex.x"></a>`x` | `int` |  |
| <a name="fld-gdi.movetoex.y"></a>`y` | `int` |  |

#### <a name="val-gdi.lineto"></a>`lineTo`

```sml
val lineTo : Types.paint * int * int -> unit
```

`lineTo (paint, x, y)` draws from the current point and updates that point.

#### <a name="val-gdi.rectangle"></a>`rectangle`

```sml
val rectangle : Types.paint * Types.rect -> unit
```

`rectangle (paint, rectangle)` draws an outline and fills the interior using the selected pen and brush.

#### <a name="val-gdi.settextcolor"></a>`setTextColor`

```sml
val setTextColor : Types.paint * Word32.word -> Word32.word
```

`setTextColor (paint, colour)` sets text colour and returns the previous colour.

#### <a name="val-gdi.setbkmode"></a>`setBkMode`

```sml
val setBkMode : Types.paint * int -> int
```

`setBkMode (paint, mode)` sets transparent or opaque text background mode and returns the previous mode.

#### <a name="val-gdi.textout"></a>`textOut`

```sml
val textOut : Types.paint * int * int * string -> unit
```

`textOut (paint, x, y, text)` draws text through the provider with explicit text and rendering limitations.

---

<sub>Generated by runedoc from lib/ffi/win32/common/win32\_sig.sml; do not edit.</sub>
