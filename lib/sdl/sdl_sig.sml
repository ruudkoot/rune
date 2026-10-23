(* Core SDL3 GUI, input and software rendering, with explicit lifetimes.

   Area: Foreign interfaces *)
signature SDL =
sig
  (* A window owned until `destroyWindow`; dependent renderers prevent release. *)
  eqtype window
  (* An owned software pixel surface. *)
  eqtype surface
  (* An owned renderer retaining its window or software surface. *)
  eqtype renderer
  (* An owned texture retaining its renderer. *)
  eqtype texture
  (* Integer coordinates and dimensions in native pixels. *)
  type rect = {x : int, y : int, width : int, height : int}
  (* Floating point coordinates and dimensions in native pixels. *)
  type frect = {x : real, y : real, width : real, height : real}
  (* Copied event values; text survives subsequent SDL operations. *)
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
  (* Native failure; the error text is captured before cleanup. *)
  exception Error of {function : string, message : string}
  (* A request outside the declared portable core behavior. *)
  exception Unsupported of string
  (* A closed resource or an operation before loading its native library. *)
  exception Closed
  (* A release with live children, locks or borrowers. *)
  exception Busy
  (* `load paths` names SDL3 and its generated adapter library; call before initialization.

     The generated target must match the runtime width and byte order. *)
  val load : string list -> unit
  (* `unload ()` closes a quiescent library after `quit` and all resources. *)
  val unload : unit -> unit
  (* `constant name` looks up one generated SDL core integer constant. *)
  val constant : string -> IntInf.int
  (* `setMainReady ()` declares that Rune owns application startup on the VM thread. *)
  val setMainReady : unit -> unit
  (* `init flags` initializes SDL subsystems after declaring main readiness. *)
  val init : Word32.word -> unit
  (* `initSubSystem flags` adds a reference to the named subsystems. *)
  val initSubSystem : Word32.word -> unit
  (* `quitSubSystem flags` releases subsystem references after all owned resources close. *)
  val quitSubSystem : Word32.word -> unit
  (* `quit ()` shuts down SDL and releases retained pushed-event text; live resources raise `Busy`. *)
  val quit : unit -> unit
  (* `getError ()` copies the current SDL UTF-8 error text immediately. *)
  val getError : unit -> string
  (* `clearError ()` clears the current SDL error text. *)
  val clearError : unit -> unit
  (* `createWindow options` creates an owned window with a copied UTF-8 title. *)
  val createWindow : {title : string, width : int, height : int,
                      flags : Word64.word} -> window
  (* `destroyWindow window` destroys a window after its renderers close. *)
  val destroyWindow : window -> unit
  (* `getWindowID window` returns its nonzero SDL event identity. *)
  val getWindowID : window -> Word32.word
  (* `setWindowTitle (window, title)` copies a UTF-8 title into SDL. *)
  val setWindowTitle : window * string -> unit
  (* `getWindowSize window` returns both native output dimensions. *)
  val getWindowSize : window -> {width : int, height : int}
  (* `setWindowSize (window, width, height)` requests a size change; OS events remain asynchronous. *)
  val setWindowSize : window * int * int -> unit
  (* `setWindowPosition (window, x, y)` requests a supported native position.

     `SDL_WINDOWPOS_UNDEFINED` lets SDL choose an axis. Compositors may reject
     explicit positioning; native failure propagates rather than being ignored. *)
  val setWindowPosition : window * int * int -> unit
  (* `setHint (name, value)` sets an SDL policy hint before initialization.

     This support operation is selected for the Win32-over-SDL provider. *)
  val setHint : string * string -> unit
  (* `showWindow window` requests that the native window become visible. *)
  val showWindow : window -> unit
  (* `hideWindow window` requests that the native window become hidden. *)
  val hideWindow : window -> unit
  (* `pollEvent ()` copies one available event; `NONE` means no event was returned. *)
  val pollEvent : unit -> event option
  (* `waitEvent ()` blocks for one event and copies its payload. *)
  val waitEvent : unit -> event
  (* `waitEventTimeout milliseconds` waits up to the given duration; `NONE` preserves the native timeout-or-error result through raw access. *)
  val waitEventTimeout : int -> event option
  (* `pushEvent event` queues a supported event; input-state snapshots are unaffected.

     Text storage is retained until consumption or `quit`; `Unknown` requires raw access. *)
  val pushEvent : event -> unit
  (* `getKeyboardState ()` copies the complete current SDL keyboard snapshot. *)
  val getKeyboardState : unit -> bool vector
  (* `getMouseState ()` returns buttons and both native float output coordinates. *)
  val getMouseState : unit -> {buttons : Word32.word, x : real, y : real}
  (* `startTextInput window` enables UTF-8 text input events for that window. *)
  val startTextInput : window -> unit
  (* `stopTextInput window` disables text input for that window. *)
  val stopTextInput : window -> unit
  (* `createSurface options` allocates an owned, zero-initialized pixel surface. *)
  val createSurface : {width : int, height : int, format : Word32.word} -> surface
  (* `destroySurface surface` releases it after software renderers and locks close. *)
  val destroySurface : surface -> unit
  (* `lockSurface surface` acquires a counted pixel lock; balance it with `unlockSurface`. *)
  val lockSurface : surface -> unit
  (* `unlockSurface surface` releases one lock; an unmatched call raises `Busy`. *)
  val unlockSurface : surface -> unit
  (* `withSurfacePixels surface body` locks an uncompressed surface and supplies a copied byte array.

     Writes copy back on every returning path, including exceptions, before unlocking. FourCC and compressed formats raise `Unsupported`. *)
  val withSurfacePixels : surface ->
    ({bytes : Word8Array.array, pitch : int, width : int, height : int,
      format : Word32.word} -> 'a) -> 'a
  (* `fillSurfaceRect (surface, rect, color)` fills a rectangle or the entire surface; color is encoded in its pixel format. *)
  val fillSurfaceRect : surface * rect option * Word32.word -> unit
  (* `blitSurface options` copies and clips between surfaces using optional integer rectangles. *)
  val blitSurface : {source : surface, sourceRect : rect option,
                     destination : surface, destinationRect : rect option} -> unit
  (* `createRenderer (window, driver)` creates a renderer retaining the window; `NONE` lets SDL choose a driver. *)
  val createRenderer : window * string option -> renderer
  (* `createSoftwareRenderer surface` creates a renderer retaining the target surface. *)
  val createSoftwareRenderer : surface -> renderer
  (* `destroyRenderer renderer` destroys it after its textures close. *)
  val destroyRenderer : renderer -> unit
  (* `setRenderDrawColor (renderer, color)` sets channels from zero through 255; other values raise `Domain`. *)
  val setRenderDrawColor : renderer * {red : int, green : int, blue : int, alpha : int} -> unit
  (* `setRenderClipRect (renderer, rectangle)` sets an integer drawing clip.

     `NONE` resets clipping; a zero-area rectangle clips every pixel. *)
  val setRenderClipRect : renderer * rect option -> unit
  (* `renderClear renderer` clears the render target with the current draw color. *)
  val renderClear : renderer -> unit
  (* `renderPoint (renderer, x, y)` draws one floating point position. *)
  val renderPoint : renderer * real * real -> unit
  (* `renderLine (renderer, x1, y1, x2, y2)` draws a line in renderer coordinates. *)
  val renderLine : renderer * real * real * real * real -> unit
  (* `renderRect (renderer, rect)` outlines the optional rectangle or complete target. *)
  val renderRect : renderer * frect option -> unit
  (* `renderFillRect (renderer, rect)` fills the optional rectangle or complete target. *)
  val renderFillRect : renderer * frect option -> unit
  (* `renderPresent renderer` presents accumulated drawing on the owning VM thread. *)
  val renderPresent : renderer -> unit
  (* `renderReadPixels (renderer, rect)` copies pixels into a new owned surface. *)
  val renderReadPixels : renderer * rect option -> surface
  (* `createTextureFromSurface (renderer, surface)` copies pixels into a texture retaining its renderer. *)
  val createTextureFromSurface : renderer * surface -> texture
  (* `destroyTexture texture` destroys the texture and releases its renderer dependency. *)
  val destroyTexture : texture -> unit
  (* `renderTexture (renderer, texture, source, destination)` copies a texture using optional floating rectangles. *)
  val renderTexture : renderer * texture * frect option * frect option -> unit
  (* `renderDebugText (renderer, x, y, text)` draws SDL debug text. SDL documents its built-in font as ASCII; UTF-8 is validated at the boundary. *)
  val renderDebugText : renderer * real * real * string -> unit
  (* `hasClipboardText ()` reports whether SDL exposes clipboard text. *)
  val hasClipboardText : unit -> bool
  (* `getClipboardText ()` copies UTF-8 clipboard text and calls `SDL_free` before returning. *)
  val getClipboardText : unit -> string
  (* `setClipboardText text` copies UTF-8 text to the clipboard. *)
  val setClipboardText : string -> unit
  (* `getTicks ()` returns elapsed SDL milliseconds as an unsigned 64-bit value. *)
  val getTicks : unit -> Word64.word
  (* `getTicksNS ()` returns elapsed SDL nanoseconds as an unsigned 64-bit value. *)
  val getTicksNS : unit -> Word64.word
  (* `getPerformanceCounter ()` returns the current unsigned high-resolution counter. *)
  val getPerformanceCounter : unit -> Word64.word
  (* `getPerformanceFrequency ()` returns high-resolution counter ticks per second. *)
  val getPerformanceFrequency : unit -> Word64.word
  (* `delay milliseconds` requests a native delay; scheduling can extend it. *)
  val delay : Word32.word -> unit
end
