(* Shared public identities and messages for the Win32 GUI subset.

   Area: Foreign interfaces *)
signature WIN32_TYPES =
sig
  (* An abstract window identity; operations validate its provider and lifetime. *)
  eqtype window
  (* An abstract process module identity. *)
  eqtype module
  (* A registered window class owned by one implementation. *)
  eqtype atom
  (* An active BeginPaint scope, valid until its matching EndPaint. *)
  eqtype paint
  (* A GDI object identity; selected and stock objects have distinct ownership. *)
  eqtype object
  (* A pen identity sharing its object lifetime. *)
  eqtype pen
  (* A brush identity sharing its object lifetime. *)
  eqtype brush
  (* Client coordinates; the right and bottom edges are exclusive. *)
  type rect = {left : Int32.int, top : Int32.int, right : Int32.int, bottom : Int32.int}
  (* Normalized GUI messages.

     Char carries one UTF-16 code unit, including lone
     surrogates. Application preserves the caller's integer payload. Native
     default processing retains the original message's complete ABI payload. *)
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
  (* Default asks the provider to perform its documented default behavior. *)
  datatype reply = Default | Result of Int64.int
  (* A copied message returned by GetMessage or PeekMessage. *)
  type queued
  (* A quit status or one copied queued message. *)
  datatype next = Quit of Int32.int | Message of queued
  (* A captured native-style error, before conversion or resource cleanup. *)
  exception Error of {function : string, code : Word32.word}
  (* An explicit operation outside the delivered provider's contract. *)
  exception Unsupported of string
end
