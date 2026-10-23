(* Thin GUI driver used by the shared Win32 SDL and mock semantics.

   Area: Foreign interfaces *)
signature WIN32_GUI_DRIVER =
sig
  (* A driver-owned window, separate from the portable public token. *)
  eqtype window
  (* A drawing scope owned by this driver. *)
  type drawing
  (* A normalized external event; the model owns class procedure dispatch. *)
  datatype event = Quit | Message of window * Win32Common.Types.message
  (* Whether events may arrive independently of deterministic model state. *)
  val externalEvents : bool
  (* `create specification` creates a driver window without invoking SML procedures. *)
  val create : {title:string,x:int,y:int,width:int,height:int,visible:bool,resizable:bool} -> window
  (* `destroy window` releases a driver window and its drawing resources. *)
  val destroy : window -> unit
  (* `show (window, command)` applies a supported Win32 visibility command. *)
  val show : window * int -> unit
  (* `title (window, text)` changes the UTF-8 window title. *)
  val title : window * string -> unit
  (* `client window` reads its current client dimensions. *)
  val client : window -> {width:int,height:int}
  (* `begin window` acquires a drawing scope. *)
  val begin : window -> drawing
  (* `finish drawing` presents the completed drawing and releases its scope. *)
  val finish : drawing -> unit
  (* `fill specification` fills an exclusive-edge rectangle with RGB colour. *)
  val fill : {drawing:drawing,rectangle:Win32Common.Types.rect,colour:Word32.word} -> unit
  (* `line specification` draws a solid line with the requested positive width. *)
  val line : {drawing:drawing,x1:int,y1:int,x2:int,y2:int,width:int,colour:Word32.word} -> unit
  (* `text specification` draws fixed ASCII text with the declared background mode. *)
  val text : {drawing:drawing,x:int,y:int,text:string,colour:Word32.word,opaque:bool,background:Word32.word} -> unit
  (* `poll ()` copies the next available external event. *)
  val poll : unit -> event option
  (* `ticks ()` returns monotonic milliseconds as an unbounded integer. *)
  val ticks : unit -> IntInf.int
  (* `counter ()` returns the monotonic performance counter. *)
  val counter : unit -> Int64.int
  (* `frequency ()` returns performance counter ticks per second. *)
  val frequency : unit -> Int64.int
  (* `delay milliseconds` waits, or advances deterministic mock time. *)
  val delay : Word32.word -> unit
end
