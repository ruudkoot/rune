(* Shared Win32 GUI semantics with deterministic testing controls.

   Area: Foreign interfaces *)
signature WIN32_MODEL =
sig
  include WIN32
  (* `inject (window, message)` queues a copied supported input event. *)
  val inject : Types.window * Types.message -> unit
  (* `advance milliseconds` advances mock time, or waits in a real driver. *)
  val advance : Word32.word -> unit
  (* `trace ()` returns the deterministic normalized operation trace. *)
  val trace : unit -> string list
  (* `reset ()` clears observations after every owned resource has closed.

     Raises: `Win32Common.Types.Error` while windows, classes, paints or owned GDI objects remain. *)
  val reset : unit -> unit
end
