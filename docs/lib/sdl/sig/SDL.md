# signature SDL

[SDL3](../README.md) &rsaquo; Foreign interfaces &rsaquo; **SDL**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 69 of 69 entries documented |
| Tests | not listed |
| Source | [lib/sdl/sdl\_sig.sml](../../../../lib/sdl/sdl_sig.sml) |

## Synopsis

```sml
signature SDL
functor SDLFn (...) :> SDL
```

| Implementation |  | Source |
| --- | --- | --- |
| `SDLFn` |  | [lib/sdl/sdl.sml](../../../../lib/sdl/sdl.sml) |

Core SDL3 GUI, input and software rendering, with explicit lifetimes.

## Interface

<pre>
signature SDL =
sig
  eqtype <a href="#type-window">window</a>
  eqtype <a href="#type-surface">surface</a>
  eqtype <a href="#type-renderer">renderer</a>
  eqtype <a href="#type-texture">texture</a>
  type <a href="#type-rect">rect</a> = {<a href="#fld-rect.x">x</a> : int, <a href="#fld-rect.y">y</a> : int, <a href="#fld-rect.width">width</a> : int, <a href="#fld-rect.height">height</a> : int}
  type <a href="#type-frect">frect</a> = {<a href="#fld-frect.x">x</a> : real, <a href="#fld-frect.y">y</a> : real, <a href="#fld-frect.width">width</a> : real, <a href="#fld-frect.height">height</a> : real}
  datatype <a href="#type-event">event</a> =
      <a href="#con-quit">Quit</a>
    | <a href="#con-window">Window</a> of {<a href="#fld-window.window">window</a> : Word32.word, <a href="#fld-window.kind">kind</a> : Word32.word, <a href="#fld-window.data1">data1</a> : int, <a href="#fld-window.data2">data2</a> : int}
    | <a href="#con-key">Key</a> of {<a href="#fld-key.window">window</a> : Word32.word, <a href="#fld-key.down">down</a> : bool, <a href="#fld-key.repeated">repeated</a> : bool,
              <a href="#fld-key.key">key</a> : Word32.word, <a href="#fld-key.scan">scan</a> : int, <a href="#fld-key.modifiers">modifiers</a> : Word16.word}
    | <a href="#con-text">Text</a> of {<a href="#fld-text.window">window</a> : Word32.word, <a href="#fld-text.text">text</a> : string}
    | <a href="#con-mousemotion">MouseMotion</a> of {<a href="#fld-mousemotion.window">window</a> : Word32.word, <a href="#fld-mousemotion.x">x</a> : real, <a href="#fld-mousemotion.y">y</a> : real,
                       <a href="#fld-mousemotion.buttons">buttons</a> : Word32.word}
    | <a href="#con-mousebutton">MouseButton</a> of {<a href="#fld-mousebutton.window">window</a> : Word32.word, <a href="#fld-mousebutton.down">down</a> : bool,
                       <a href="#fld-mousebutton.button">button</a> : int, <a href="#fld-mousebutton.clicks">clicks</a> : int, <a href="#fld-mousebutton.x">x</a> : real, <a href="#fld-mousebutton.y">y</a> : real}
    | <a href="#con-unknown">Unknown</a> of Word32.word
  exception <a href="#exn-error">Error</a> of {<a href="#fld-error.function">function</a> : string, <a href="#fld-error.message">message</a> : string}
  exception <a href="#exn-unsupported">Unsupported</a> of string
  exception <a href="#exn-closed">Closed</a>
  exception <a href="#exn-busy">Busy</a>
  val <a href="#val-load">load</a> : string list -&gt; unit
  val <a href="#val-unload">unload</a> : unit -&gt; unit
  val <a href="#val-constant">constant</a> : string -&gt; IntInf.int
  val <a href="#val-setmainready">setMainReady</a> : unit -&gt; unit
  val <a href="#val-init">init</a> : Word32.word -&gt; unit
  val <a href="#val-initsubsystem">initSubSystem</a> : Word32.word -&gt; unit
  val <a href="#val-quitsubsystem">quitSubSystem</a> : Word32.word -&gt; unit
  val <a href="#val-quit">quit</a> : unit -&gt; unit
  val <a href="#val-geterror">getError</a> : unit -&gt; string
  val <a href="#val-clearerror">clearError</a> : unit -&gt; unit
  val <a href="#val-createwindow">createWindow</a> : {<a href="#fld-createwindow.title">title</a> : string, <a href="#fld-createwindow.width">width</a> : int, <a href="#fld-createwindow.height">height</a> : int,
                      <a href="#fld-createwindow.flags">flags</a> : Word64.word} -&gt; window
  val <a href="#val-destroywindow">destroyWindow</a> : window -&gt; unit
  val <a href="#val-getwindowid">getWindowID</a> : window -&gt; Word32.word
  val <a href="#val-setwindowtitle">setWindowTitle</a> : window * string -&gt; unit
  val <a href="#val-getwindowsize">getWindowSize</a> : window -&gt; {<a href="#fld-getwindowsize.width">width</a> : int, <a href="#fld-getwindowsize.height">height</a> : int}
  val <a href="#val-setwindowsize">setWindowSize</a> : window * int * int -&gt; unit
  val <a href="#val-setwindowposition">setWindowPosition</a> : window * int * int -&gt; unit
  val <a href="#val-sethint">setHint</a> : string * string -&gt; unit
  val <a href="#val-showwindow">showWindow</a> : window -&gt; unit
  val <a href="#val-hidewindow">hideWindow</a> : window -&gt; unit
  val <a href="#val-pollevent">pollEvent</a> : unit -&gt; event option
  val <a href="#val-waitevent">waitEvent</a> : unit -&gt; event
  val <a href="#val-waiteventtimeout">waitEventTimeout</a> : int -&gt; event option
  val <a href="#val-pushevent">pushEvent</a> : event -&gt; unit
  val <a href="#val-getkeyboardstate">getKeyboardState</a> : unit -&gt; bool vector
  val <a href="#val-getmousestate">getMouseState</a> : unit -&gt; {<a href="#fld-getmousestate.buttons">buttons</a> : Word32.word, <a href="#fld-getmousestate.x">x</a> : real, <a href="#fld-getmousestate.y">y</a> : real}
  val <a href="#val-starttextinput">startTextInput</a> : window -&gt; unit
  val <a href="#val-stoptextinput">stopTextInput</a> : window -&gt; unit
  val <a href="#val-createsurface">createSurface</a> : {<a href="#fld-createsurface.width">width</a> : int, <a href="#fld-createsurface.height">height</a> : int, <a href="#fld-createsurface.format">format</a> : Word32.word} -&gt; surface
  val <a href="#val-destroysurface">destroySurface</a> : surface -&gt; unit
  val <a href="#val-locksurface">lockSurface</a> : surface -&gt; unit
  val <a href="#val-unlocksurface">unlockSurface</a> : surface -&gt; unit
  val <a href="#val-withsurfacepixels">withSurfacePixels</a> : surface -&gt;
    ({<a href="#fld-withsurfacepixels.bytes">bytes</a> : Word8Array.array, <a href="#fld-withsurfacepixels.pitch">pitch</a> : int, <a href="#fld-withsurfacepixels.width">width</a> : int, <a href="#fld-withsurfacepixels.height">height</a> : int,
      <a href="#fld-withsurfacepixels.format">format</a> : Word32.word} -&gt; 'a) -&gt; 'a
  val <a href="#val-fillsurfacerect">fillSurfaceRect</a> : surface * rect option * Word32.word -&gt; unit
  val <a href="#val-blitsurface">blitSurface</a> : {<a href="#fld-blitsurface.source">source</a> : surface, <a href="#fld-blitsurface.sourcerect">sourceRect</a> : rect option,
                     <a href="#fld-blitsurface.destination">destination</a> : surface, <a href="#fld-blitsurface.destinationrect">destinationRect</a> : rect option} -&gt; unit
  val <a href="#val-createrenderer">createRenderer</a> : window * string option -&gt; renderer
  val <a href="#val-createsoftwarerenderer">createSoftwareRenderer</a> : surface -&gt; renderer
  val <a href="#val-destroyrenderer">destroyRenderer</a> : renderer -&gt; unit
  val <a href="#val-setrenderdrawcolor">setRenderDrawColor</a> : renderer * {<a href="#fld-setrenderdrawcolor.red">red</a> : int, <a href="#fld-setrenderdrawcolor.green">green</a> : int, <a href="#fld-setrenderdrawcolor.blue">blue</a> : int, <a href="#fld-setrenderdrawcolor.alpha">alpha</a> : int} -&gt; unit
  val <a href="#val-renderclear">renderClear</a> : renderer -&gt; unit
  val <a href="#val-renderpoint">renderPoint</a> : renderer * real * real -&gt; unit
  val <a href="#val-renderline">renderLine</a> : renderer * real * real * real * real -&gt; unit
  val <a href="#val-renderrect">renderRect</a> : renderer * frect option -&gt; unit
  val <a href="#val-renderfillrect">renderFillRect</a> : renderer * frect option -&gt; unit
  val <a href="#val-renderpresent">renderPresent</a> : renderer -&gt; unit
  val <a href="#val-renderreadpixels">renderReadPixels</a> : renderer * rect option -&gt; surface
  val <a href="#val-createtexturefromsurface">createTextureFromSurface</a> : renderer * surface -&gt; texture
  val <a href="#val-destroytexture">destroyTexture</a> : texture -&gt; unit
  val <a href="#val-rendertexture">renderTexture</a> : renderer * texture * frect option * frect option -&gt; unit
  val <a href="#val-renderdebugtext">renderDebugText</a> : renderer * real * real * string -&gt; unit
  val <a href="#val-hasclipboardtext">hasClipboardText</a> : unit -&gt; bool
  val <a href="#val-getclipboardtext">getClipboardText</a> : unit -&gt; string
  val <a href="#val-setclipboardtext">setClipboardText</a> : string -&gt; unit
  val <a href="#val-getticks">getTicks</a> : unit -&gt; Word64.word
  val <a href="#val-getticksns">getTicksNS</a> : unit -&gt; Word64.word
  val <a href="#val-getperformancecounter">getPerformanceCounter</a> : unit -&gt; Word64.word
  val <a href="#val-getperformancefrequency">getPerformanceFrequency</a> : unit -&gt; Word64.word
  val <a href="#val-delay">delay</a> : Word32.word -&gt; unit
end
</pre>

### <a name="type-window"></a>`window`

```sml
eqtype window
```

A window owned until [`destroyWindow`](#val-destroywindow); dependent renderers prevent release.

### <a name="type-surface"></a>`surface`

```sml
eqtype surface
```

An owned software pixel surface.

### <a name="type-renderer"></a>`renderer`

```sml
eqtype renderer
```

An owned renderer retaining its window or software surface.

### <a name="type-texture"></a>`texture`

```sml
eqtype texture
```

An owned texture retaining its renderer.

### <a name="type-rect"></a>`rect`

```sml
type rect = {x : int, y : int, width : int, height : int}
```

Integer coordinates and dimensions in native pixels.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-rect.x"></a>`x` | `int` |  |
| <a name="fld-rect.y"></a>`y` | `int` |  |
| <a name="fld-rect.width"></a>`width` | `int` |  |
| <a name="fld-rect.height"></a>`height` | `int` |  |

### <a name="type-frect"></a>`frect`

```sml
type frect = {x : real, y : real, width : real, height : real}
```

Floating point coordinates and dimensions in native pixels.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-frect.x"></a>`x` | `real` |  |
| <a name="fld-frect.y"></a>`y` | `real` |  |
| <a name="fld-frect.width"></a>`width` | `real` |  |
| <a name="fld-frect.height"></a>`height` | `real` |  |

### <a name="type-event"></a>`event`

```sml
datatype event =
    Quit
  | Window of {window : Word32.word, kind : Word32.word, data1 : int, data2 : int}
  | Key of {window : Word32.word, down : bool, repeated : bool,
            key : Word32.word, scan : int, modifiers : Word16.word}
  | Text of {window : Word32.word, text : string}
  | MouseMotion of {window : Word32.word, x : real, y : real,
                     buttons : Word32.word}
  | MouseButton of {window : Word32.word, down : bool,
                     button : int, clicks : int, x : real, y : real}
  | Unknown of Word32.word
```

Copied event values; text survives subsequent SDL operations.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-quit"></a>`Quit` |  |  |
| <a name="con-window"></a>`Window` | `{window : Word32.word, kind : Word32.word, data1 : int, data2 : int}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-window.window"></a>`window` | `Word32.word` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-window.kind"></a>`kind` | `Word32.word` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-window.data1"></a>`data1` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-window.data2"></a>`data2` | `int` |  |
| <a name="con-key"></a>`Key` | `{window : Word32.word, down : bool, repeated : bool, key : Word32.word, scan : int, modifiers : Word16.word}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-key.window"></a>`window` | `Word32.word` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-key.down"></a>`down` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-key.repeated"></a>`repeated` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-key.key"></a>`key` | `Word32.word` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-key.scan"></a>`scan` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-key.modifiers"></a>`modifiers` | `Word16.word` |  |
| <a name="con-text"></a>`Text` | `{window : Word32.word, text : string}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-text.window"></a>`window` | `Word32.word` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-text.text"></a>`text` | `string` |  |
| <a name="con-mousemotion"></a>`MouseMotion` | `{window : Word32.word, x : real, y : real, buttons : Word32.word}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousemotion.window"></a>`window` | `Word32.word` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousemotion.x"></a>`x` | `real` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousemotion.y"></a>`y` | `real` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousemotion.buttons"></a>`buttons` | `Word32.word` |  |
| <a name="con-mousebutton"></a>`MouseButton` | `{window : Word32.word, down : bool, button : int, clicks : int, x : real, y : real}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousebutton.window"></a>`window` | `Word32.word` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousebutton.down"></a>`down` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousebutton.button"></a>`button` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousebutton.clicks"></a>`clicks` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousebutton.x"></a>`x` | `real` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-mousebutton.y"></a>`y` | `real` |  |
| <a name="con-unknown"></a>`Unknown` | `Word32.word` |  |

### <a name="exn-error"></a>`Error`

```sml
exception Error of {function : string, message : string}
```

Native failure; the error text is captured before cleanup.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-error.function"></a>`function` | `string` |  |
| <a name="fld-error.message"></a>`message` | `string` |  |

### <a name="exn-unsupported"></a>`Unsupported`

```sml
exception Unsupported of string
```

A request outside the declared portable core behavior.

### <a name="exn-closed"></a>`Closed`

```sml
exception Closed
```

A closed resource or an operation before loading its native library.

### <a name="exn-busy"></a>`Busy`

```sml
exception Busy
```

A release with live children, locks or borrowers.

### <a name="val-load"></a>`load`

```sml
val load : string list -> unit
```

`load paths` names SDL3 and its generated adapter library; call before initialization.

The generated target must match the runtime width and byte order.

### <a name="val-unload"></a>`unload`

```sml
val unload : unit -> unit
```

`unload ()` closes a quiescent library after [`quit`](#val-quit) and all resources.

### <a name="val-constant"></a>`constant`

```sml
val constant : string -> IntInf.int
```

`constant name` looks up one generated SDL core integer constant.

### <a name="val-setmainready"></a>`setMainReady`

```sml
val setMainReady : unit -> unit
```

`setMainReady ()` declares that Rune owns application startup on the VM thread.

### <a name="val-init"></a>`init`

```sml
val init : Word32.word -> unit
```

`init flags` initializes SDL subsystems after declaring main readiness.

### <a name="val-initsubsystem"></a>`initSubSystem`

```sml
val initSubSystem : Word32.word -> unit
```

`initSubSystem flags` adds a reference to the named subsystems.

### <a name="val-quitsubsystem"></a>`quitSubSystem`

```sml
val quitSubSystem : Word32.word -> unit
```

`quitSubSystem flags` releases subsystem references after all owned resources close.

### <a name="val-quit"></a>`quit`

```sml
val quit : unit -> unit
```

`quit ()` shuts down SDL and releases retained pushed-event text; live resources raise [`Busy`](#exn-busy).

### <a name="val-geterror"></a>`getError`

```sml
val getError : unit -> string
```

`getError ()` copies the current SDL UTF-8 error text immediately.

### <a name="val-clearerror"></a>`clearError`

```sml
val clearError : unit -> unit
```

`clearError ()` clears the current SDL error text.

### <a name="val-createwindow"></a>`createWindow`

```sml
val createWindow : {title : string, width : int, height : int,
                    flags : Word64.word} -> window
```

`createWindow options` creates an owned window with a copied UTF-8 title.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-createwindow.title"></a>`title` | `string` |  |
| <a name="fld-createwindow.width"></a>`width` | `int` |  |
| <a name="fld-createwindow.height"></a>`height` | `int` |  |
| <a name="fld-createwindow.flags"></a>`flags` | `Word64.word` |  |

### <a name="val-destroywindow"></a>`destroyWindow`

```sml
val destroyWindow : window -> unit
```

`destroyWindow window` destroys a window after its renderers close.

### <a name="val-getwindowid"></a>`getWindowID`

```sml
val getWindowID : window -> Word32.word
```

`getWindowID window` returns its nonzero SDL event identity.

### <a name="val-setwindowtitle"></a>`setWindowTitle`

```sml
val setWindowTitle : window * string -> unit
```

`setWindowTitle (window, title)` copies a UTF-8 title into SDL.

### <a name="val-getwindowsize"></a>`getWindowSize`

```sml
val getWindowSize : window -> {width : int, height : int}
```

`getWindowSize window` returns both native output dimensions.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-getwindowsize.width"></a>`width` | `int` |  |
| <a name="fld-getwindowsize.height"></a>`height` | `int` |  |

### <a name="val-setwindowsize"></a>`setWindowSize`

```sml
val setWindowSize : window * int * int -> unit
```

`setWindowSize (window, width, height)` requests a size change; OS events remain asynchronous.

### <a name="val-setwindowposition"></a>`setWindowPosition`

```sml
val setWindowPosition : window * int * int -> unit
```

`setWindowPosition (window, x, y)` requests a supported native position.

`SDL_WINDOWPOS_UNDEFINED` lets SDL choose an axis. Compositors may reject
explicit positioning; native failure propagates rather than being ignored.

### <a name="val-sethint"></a>`setHint`

```sml
val setHint : string * string -> unit
```

`setHint (name, value)` sets an SDL policy hint before initialization.

This support operation is selected for the Win32-over-SDL provider.

### <a name="val-showwindow"></a>`showWindow`

```sml
val showWindow : window -> unit
```

`showWindow window` requests that the native window become visible.

### <a name="val-hidewindow"></a>`hideWindow`

```sml
val hideWindow : window -> unit
```

`hideWindow window` requests that the native window become hidden.

### <a name="val-pollevent"></a>`pollEvent`

```sml
val pollEvent : unit -> event option
```

`pollEvent ()` copies one available event; `NONE` means no event was returned.

### <a name="val-waitevent"></a>`waitEvent`

```sml
val waitEvent : unit -> event
```

`waitEvent ()` blocks for one event and copies its payload.

### <a name="val-waiteventtimeout"></a>`waitEventTimeout`

```sml
val waitEventTimeout : int -> event option
```

`waitEventTimeout milliseconds` waits up to the given duration; `NONE` preserves the native timeout-or-error result through raw access.

### <a name="val-pushevent"></a>`pushEvent`

```sml
val pushEvent : event -> unit
```

`pushEvent event` queues a supported event; input-state snapshots are unaffected.

Text storage is retained until consumption or [`quit`](#val-quit); [`Unknown`](#con-unknown) requires raw access.

### <a name="val-getkeyboardstate"></a>`getKeyboardState`

```sml
val getKeyboardState : unit -> bool vector
```

`getKeyboardState ()` copies the complete current SDL keyboard snapshot.

### <a name="val-getmousestate"></a>`getMouseState`

```sml
val getMouseState : unit -> {buttons : Word32.word, x : real, y : real}
```

`getMouseState ()` returns buttons and both native float output coordinates.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-getmousestate.buttons"></a>`buttons` | `Word32.word` |  |
| <a name="fld-getmousestate.x"></a>`x` | `real` |  |
| <a name="fld-getmousestate.y"></a>`y` | `real` |  |

### <a name="val-starttextinput"></a>`startTextInput`

```sml
val startTextInput : window -> unit
```

`startTextInput window` enables UTF-8 text input events for that window.

### <a name="val-stoptextinput"></a>`stopTextInput`

```sml
val stopTextInput : window -> unit
```

`stopTextInput window` disables text input for that window.

### <a name="val-createsurface"></a>`createSurface`

```sml
val createSurface : {width : int, height : int, format : Word32.word} -> surface
```

`createSurface options` allocates an owned, zero-initialized pixel surface.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-createsurface.width"></a>`width` | `int` |  |
| <a name="fld-createsurface.height"></a>`height` | `int` |  |
| <a name="fld-createsurface.format"></a>`format` | `Word32.word` |  |

### <a name="val-destroysurface"></a>`destroySurface`

```sml
val destroySurface : surface -> unit
```

`destroySurface surface` releases it after software renderers and locks close.

### <a name="val-locksurface"></a>`lockSurface`

```sml
val lockSurface : surface -> unit
```

`lockSurface surface` acquires a counted pixel lock; balance it with [`unlockSurface`](#val-unlocksurface).

### <a name="val-unlocksurface"></a>`unlockSurface`

```sml
val unlockSurface : surface -> unit
```

`unlockSurface surface` releases one lock; an unmatched call raises [`Busy`](#exn-busy).

### <a name="val-withsurfacepixels"></a>`withSurfacePixels`

```sml
val withSurfacePixels : surface ->
  ({bytes : Word8Array.array, pitch : int, width : int, height : int,
    format : Word32.word} -> 'a) -> 'a
```

`withSurfacePixels surface body` locks an uncompressed surface and supplies a copied byte array.

Writes copy back on every returning path, including exceptions, before unlocking. FourCC and compressed formats raise [`Unsupported`](#exn-unsupported).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-withsurfacepixels.bytes"></a>`bytes` | `Word8Array.array` |  |
| <a name="fld-withsurfacepixels.pitch"></a>`pitch` | `int` |  |
| <a name="fld-withsurfacepixels.width"></a>`width` | `int` |  |
| <a name="fld-withsurfacepixels.height"></a>`height` | `int` |  |
| <a name="fld-withsurfacepixels.format"></a>`format` | `Word32.word` |  |

### <a name="val-fillsurfacerect"></a>`fillSurfaceRect`

```sml
val fillSurfaceRect : surface * rect option * Word32.word -> unit
```

`fillSurfaceRect (surface, rect, color)` fills a rectangle or the entire surface; color is encoded in its pixel format.

### <a name="val-blitsurface"></a>`blitSurface`

```sml
val blitSurface : {source : surface, sourceRect : rect option,
                   destination : surface, destinationRect : rect option} -> unit
```

`blitSurface options` copies and clips between surfaces using optional integer rectangles.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-blitsurface.source"></a>`source` | `surface` |  |
| <a name="fld-blitsurface.sourcerect"></a>`sourceRect` | `rect option` |  |
| <a name="fld-blitsurface.destination"></a>`destination` | `surface` |  |
| <a name="fld-blitsurface.destinationrect"></a>`destinationRect` | `rect option` |  |

### <a name="val-createrenderer"></a>`createRenderer`

```sml
val createRenderer : window * string option -> renderer
```

`createRenderer (window, driver)` creates a renderer retaining the window; `NONE` lets SDL choose a driver.

### <a name="val-createsoftwarerenderer"></a>`createSoftwareRenderer`

```sml
val createSoftwareRenderer : surface -> renderer
```

`createSoftwareRenderer surface` creates a renderer retaining the target surface.

### <a name="val-destroyrenderer"></a>`destroyRenderer`

```sml
val destroyRenderer : renderer -> unit
```

`destroyRenderer renderer` destroys it after its textures close.

### <a name="val-setrenderdrawcolor"></a>`setRenderDrawColor`

```sml
val setRenderDrawColor : renderer * {red : int, green : int, blue : int, alpha : int} -> unit
```

`setRenderDrawColor (renderer, color)` sets channels from zero through 255; other values raise [`Domain`](../../basis/sig/GENERAL.md#exn-domain).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-setrenderdrawcolor.red"></a>`red` | `int` |  |
| <a name="fld-setrenderdrawcolor.green"></a>`green` | `int` |  |
| <a name="fld-setrenderdrawcolor.blue"></a>`blue` | `int` |  |
| <a name="fld-setrenderdrawcolor.alpha"></a>`alpha` | `int` |  |

### <a name="val-renderclear"></a>`renderClear`

```sml
val renderClear : renderer -> unit
```

`renderClear renderer` clears the render target with the current draw color.

### <a name="val-renderpoint"></a>`renderPoint`

```sml
val renderPoint : renderer * real * real -> unit
```

`renderPoint (renderer, x, y)` draws one floating point position.

### <a name="val-renderline"></a>`renderLine`

```sml
val renderLine : renderer * real * real * real * real -> unit
```

`renderLine (renderer, x1, y1, x2, y2)` draws a line in renderer coordinates.

### <a name="val-renderrect"></a>`renderRect`

```sml
val renderRect : renderer * frect option -> unit
```

`renderRect (renderer, rect)` outlines the optional rectangle or complete target.

### <a name="val-renderfillrect"></a>`renderFillRect`

```sml
val renderFillRect : renderer * frect option -> unit
```

`renderFillRect (renderer, rect)` fills the optional rectangle or complete target.

### <a name="val-renderpresent"></a>`renderPresent`

```sml
val renderPresent : renderer -> unit
```

`renderPresent renderer` presents accumulated drawing on the owning VM thread.

### <a name="val-renderreadpixels"></a>`renderReadPixels`

```sml
val renderReadPixels : renderer * rect option -> surface
```

`renderReadPixels (renderer, rect)` copies pixels into a new owned surface.

### <a name="val-createtexturefromsurface"></a>`createTextureFromSurface`

```sml
val createTextureFromSurface : renderer * surface -> texture
```

`createTextureFromSurface (renderer, surface)` copies pixels into a texture retaining its renderer.

### <a name="val-destroytexture"></a>`destroyTexture`

```sml
val destroyTexture : texture -> unit
```

`destroyTexture texture` destroys the texture and releases its renderer dependency.

### <a name="val-rendertexture"></a>`renderTexture`

```sml
val renderTexture : renderer * texture * frect option * frect option -> unit
```

`renderTexture (renderer, texture, source, destination)` copies a texture using optional floating rectangles.

### <a name="val-renderdebugtext"></a>`renderDebugText`

```sml
val renderDebugText : renderer * real * real * string -> unit
```

`renderDebugText (renderer, x, y, text)` draws SDL debug text. SDL documents its built-in font as ASCII; UTF-8 is validated at the boundary.

### <a name="val-hasclipboardtext"></a>`hasClipboardText`

```sml
val hasClipboardText : unit -> bool
```

`hasClipboardText ()` reports whether SDL exposes clipboard text.

### <a name="val-getclipboardtext"></a>`getClipboardText`

```sml
val getClipboardText : unit -> string
```

`getClipboardText ()` copies UTF-8 clipboard text and calls `SDL_free` before returning.

### <a name="val-setclipboardtext"></a>`setClipboardText`

```sml
val setClipboardText : string -> unit
```

`setClipboardText text` copies UTF-8 text to the clipboard.

### <a name="val-getticks"></a>`getTicks`

```sml
val getTicks : unit -> Word64.word
```

`getTicks ()` returns elapsed SDL milliseconds as an unsigned 64-bit value.

### <a name="val-getticksns"></a>`getTicksNS`

```sml
val getTicksNS : unit -> Word64.word
```

`getTicksNS ()` returns elapsed SDL nanoseconds as an unsigned 64-bit value.

### <a name="val-getperformancecounter"></a>`getPerformanceCounter`

```sml
val getPerformanceCounter : unit -> Word64.word
```

`getPerformanceCounter ()` returns the current unsigned high-resolution counter.

### <a name="val-getperformancefrequency"></a>`getPerformanceFrequency`

```sml
val getPerformanceFrequency : unit -> Word64.word
```

`getPerformanceFrequency ()` returns high-resolution counter ticks per second.

### <a name="val-delay"></a>`delay`

```sml
val delay : Word32.word -> unit
```

`delay milliseconds` requests a native delay; scheduling can extend it.

---

<sub>Generated by runedoc from lib/sdl/sdl\_sig.sml; do not edit.</sub>
