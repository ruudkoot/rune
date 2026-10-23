(* The generated dynamic calls required by the core SDL projection.

   Area: Foreign interfaces *)
signature SDL_NATIVE_RAW =
sig
  (* One explicitly loaded collection of libraries and prepare calls. *)
  type session
  (* `openSession {libraries}` loads the named native SDL and adapter files. *)
  val openSession : {libraries : string list} -> session
  (* `closeSession session` closes an idle session after its resources close. *)
  val closeSession : session -> unit
  (* `call session name arguments` invokes one selected original or generated helper. *)
  val call : session -> string -> RuneForeign.argument list -> RuneForeign.result
  (* `prepare session name` exposes the selected prepare call for guarded destruction. *)
  val prepare : session -> string -> RuneForeign.resource
end
