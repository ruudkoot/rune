(* M0 public contract. Native, SDL and mock implementations share this type
   module. Native pointers and exact ABI buffers belong to Win32Raw. *)
signature WIN32_TYPES =
sig
  eqtype window
  eqtype module
  eqtype atom
  eqtype paint
  eqtype object
  eqtype pen
  eqtype brush
  type rect = {left : Int32.int, top : Int32.int,
               right : Int32.int, bottom : Int32.int}
  datatype message =
      NcCreate | Create | Size of {width : int, height : int}
    | Paint | Close | Destroy | NcDestroy
    | KeyDown of {key : Word32.word, repeated : bool}
    | KeyUp of Word32.word | Char of Word16.word
    | MouseMove of {x : int, y : int, buttons : Word32.word}
    | ButtonDown of {button : int, x : int, y : int}
    | ButtonUp of {button : int, x : int, y : int}
    | Timer of Word64.word
    | Application of {code : Word32.word, w : Word64.word, l : Int64.int}
    | Unknown of Word32.word
  datatype reply = Default | Result of Int64.int
  type queued
  datatype next = Quit of Int32.int | Message of queued
  exception Error of {function : string, code : Word32.word}
  exception Unsupported of string
end

signature WIN32 =
sig
  structure Types : WIN32_TYPES
  structure Kernel :
  sig
    val getModuleHandle : string option -> Types.module
    val getLastError : unit -> Word32.word
    val setLastError : Word32.word -> unit
    val queryPerformanceCounter : unit -> Int64.int
    val queryPerformanceFrequency : unit -> Int64.int
  end
  structure User :
  sig
    val registerClassEx : {name : string, instance : Types.module,
                          style : Word32.word,
                          procedure : Types.window * Types.message -> Types.reply} -> Types.atom
    val unregisterClass : Types.atom * Types.module -> unit
    val createWindowEx : {class : Types.atom, instance : Types.module,
                          title : string, style : Word32.word, extendedStyle : Word32.word,
                          x : int, y : int, width : int, height : int,
                          parent : Types.window option} -> Types.window
    val destroyWindow : Types.window -> unit
    val showWindow : Types.window * int -> bool
    val updateWindow : Types.window -> unit
    val defWindowProc : Types.window * Types.message -> Int64.int
    val getClientRect : Types.window -> Types.rect
    val setWindowText : Types.window * string -> unit
    val getMessage : {window : Types.window option, minimum : Word32.word,
                      maximum : Word32.word} -> Types.next
    val peekMessage : {window : Types.window option, minimum : Word32.word,
                       maximum : Word32.word, remove : bool} -> Types.queued option
    val translateMessage : Types.queued -> bool
    val dispatchMessage : Types.queued -> Int64.int
    val postQuitMessage : Int32.int -> unit
    val postMessage : Types.window * Types.message -> unit
    val sendMessage : Types.window * Types.message -> Int64.int
    val invalidateRect : Types.window * Types.rect option * bool -> unit
    val beginPaint : Types.window -> Types.paint * Types.rect
    val endPaint : Types.window * Types.paint -> unit
    val withPaint : Types.window -> (Types.paint * Types.rect -> 'a) -> 'a
    val fillRect : Types.paint * Types.rect * Types.brush -> unit
    val setTimer : Types.window * Word64.word * Word32.word -> Word64.word
    val killTimer : Types.window * Word64.word -> unit
  end
  structure Gdi :
  sig
    val createPen : {style : int, width : int, colour : Word32.word} -> Types.pen
    val createSolidBrush : Word32.word -> Types.brush
    val penObject : Types.pen -> Types.object
    val brushObject : Types.brush -> Types.object
    val objectBrush : Types.object -> Types.brush
    val selectObject : Types.paint * Types.object -> Types.object
    val deleteObject : Types.object -> unit
    val getStockObject : int -> Types.object
    val moveToEx : Types.paint * int * int -> {x : int, y : int}
    val lineTo : Types.paint * int * int -> unit
    val rectangle : Types.paint * Types.rect -> unit
    val setTextColor : Types.paint * Word32.word -> Word32.word
    val setBkMode : Types.paint * int -> int
    val textOut : Types.paint * int * int * string -> unit
  end
end

(* A unit compiled against this functor cannot distinguish the resource
   representations used by the implementations. Sharing is a type equation,
   not a conversion through native pointers. *)
functor Win32SharedContract (X : sig
  structure Native : WIN32
  structure Sdl : WIN32
  structure Mock : WIN32
  sharing type Native.Types.window = Sdl.Types.window = Mock.Types.window
  sharing type Native.Types.paint = Sdl.Types.paint = Mock.Types.paint
  sharing type Native.Types.message = Sdl.Types.message = Mock.Types.message
  sharing type Native.Types.module = Sdl.Types.module = Mock.Types.module
  sharing type Native.Types.atom = Sdl.Types.atom = Mock.Types.atom
  sharing type Native.Types.object = Sdl.Types.object = Mock.Types.object
  sharing type Native.Types.pen = Sdl.Types.pen = Mock.Types.pen
  sharing type Native.Types.brush = Sdl.Types.brush = Mock.Types.brush
  sharing type Native.Types.reply = Sdl.Types.reply = Mock.Types.reply
  sharing type Native.Types.queued = Sdl.Types.queued = Mock.Types.queued
  sharing type Native.Types.next = Sdl.Types.next = Mock.Types.next
end) =
struct
  fun roundTrip window =
    (X.Native.User.getClientRect window,
     X.Sdl.User.getClientRect window,
     X.Mock.User.getClientRect window)
end
