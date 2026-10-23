(* Generated declarations and native layout for one Windows ABI.

   Area: Foreign interfaces *)
signature WIN32_NATIVE_CONFIG =
sig
  (* `prepare name` returns a generated, session-owned native descriptor. *)
  val prepare : string -> RuneForeign.resource
  (* `sizeOf name` returns the generated C object extent. *)
  val sizeOf : string -> int
  (* `offset (name, path)` returns the generated C member offset. *)
  val offset : string * string list -> int
  (* `constant name` returns an independently target-evaluated C constant. *)
  val constant : string -> IntInf.int
  (* `close ()` closes the generated session after dependents are released. *)
  val close : unit -> unit
end
