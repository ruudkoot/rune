(* M0 public core SDL3 surface; resource ownership is explicit. Events are
   copied out of SDL_Event, including borrowed UTF-8 strings. *)
signature SDL =
sig
  eqtype window
  eqtype surface
  eqtype renderer
  eqtype texture
  type rect = {x : int, y : int, width : int, height : int}
  type frect = {x : real, y : real, width : real, height : real}
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
  exception Error of {function : string, message : string}
  exception Unsupported of string
  val setMainReady : unit -> unit
  val init : Word32.word -> unit
  val initSubSystem : Word32.word -> unit
  val quitSubSystem : Word32.word -> unit
  val quit : unit -> unit
  val getError : unit -> string
  val clearError : unit -> unit
  val createWindow : {title : string, width : int, height : int,
                      flags : Word64.word} -> window
  val destroyWindow : window -> unit
  val getWindowID : window -> Word32.word
  val setWindowTitle : window * string -> unit
  val getWindowSize : window -> {width : int, height : int}
  val setWindowSize : window * int * int -> unit
  val showWindow : window -> unit
  val hideWindow : window -> unit
  val pollEvent : unit -> event option
  val waitEvent : unit -> event
  val waitEventTimeout : int -> event option
  val pushEvent : event -> unit
  val getKeyboardState : unit -> bool vector
  val getMouseState : unit -> {buttons : Word32.word, x : real, y : real}
  val startTextInput : window -> unit
  val stopTextInput : window -> unit
  val createSurface : {width : int, height : int, format : Word32.word} -> surface
  val destroySurface : surface -> unit
  val lockSurface : surface -> unit
  val unlockSurface : surface -> unit
  val withSurfacePixels : surface ->
    ({bytes : Word8Array.array, pitch : int, width : int, height : int,
      format : Word32.word} -> 'a) -> 'a
  val fillSurfaceRect : surface * rect option * Word32.word -> unit
  val blitSurface : {source : surface, sourceRect : rect option,
                     destination : surface, destinationRect : rect option} -> unit
  val createRenderer : window * string option -> renderer
  val createSoftwareRenderer : surface -> renderer
  val destroyRenderer : renderer -> unit
  val setRenderDrawColor : renderer * {red : int, green : int, blue : int, alpha : int} -> unit
  val renderClear : renderer -> unit
  val renderPoint : renderer * real * real -> unit
  val renderLine : renderer * real * real * real * real -> unit
  val renderRect : renderer * frect option -> unit
  val renderFillRect : renderer * frect option -> unit
  val renderPresent : renderer -> unit
  val renderReadPixels : renderer * rect option -> surface
  val createTextureFromSurface : renderer * surface -> texture
  val destroyTexture : texture -> unit
  val renderTexture : renderer * texture * frect option * frect option -> unit
  val renderDebugText : renderer * real * real * string -> unit
  val hasClipboardText : unit -> bool
  val getClipboardText : unit -> string
  val setClipboardText : string -> unit
  val getTicks : unit -> Word64.word
  val getTicksNS : unit -> Word64.word
  val getPerformanceCounter : unit -> Word64.word
  val getPerformanceFrequency : unit -> Word64.word
  val delay : Word32.word -> unit
end
