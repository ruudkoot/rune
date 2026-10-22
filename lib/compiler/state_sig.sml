(* Ownership of the compiler's persistent mutable roots. Drivers execute
   compiler operations serially in an owning session. *)
signature COMPILER_STATE =
sig
  (* A compiler owner. Values retained by that owner's roots keep their
     identities while another owner uses the compiler. *)
  type session
  (* An operation attempted to enter a closed session. *)
  exception Closed
  (* An operation attempted to close a session on the active call stack. *)
  exception Active

  (* Register a ref whose value is immutable or belongs to its session.
     Register roots during module initialization, before sealing. *)
  val cellRoot : string * 'a ref -> unit
  (* Register a ref with a copy for its mutable container. The initialized
     baseline and new owners receive copies; switching between existing
     owners preserves the container's identity. *)
  val refRoot : string * 'a ref * ('a -> 'a) -> unit
  (* Copy an array's cells; the elements retain their identities. *)
  val copyArray : 'a array -> 'a array
  (* Register an array whose identity remains fixed. *)
  val arrayRoot : string * 'a array -> unit
  (* Register an integer table whose identity remains fixed. Bucket and
     binding cells are copied; stored values retain their identities. *)
  val tableRoot : string * 'a IntTable.table -> unit
  (* Register a fixed vector of independently owned integer tables. *)
  val tableVectorRoot : string * 'a IntTable.table vector -> unit
  (* The registered root names, in initialization order. *)
  val names : unit -> string list

  (* Validate unique root names and seal the initialized baseline once all
     compiler modules have loaded. Further calls preserve that baseline.
     Duplicate names and later registration raise Fail. *)
  val seal : unit -> unit
  (* Make an owner from the sealed baseline, sealing it first if necessary. *)
  val session : unit -> session
  (* Release an owner's saved roots. Closing it again is harmless. *)
  val close : session -> unit
  (* Execute with the owner's roots, retain its updates and restore the
     caller's roots on return or exception. Calls can nest and re-enter
     owners; re-entered owners retain their updates. These ownership saves do not roll back mutable
     type or AST graphs within a session. *)
  val withSession : session * (unit -> 'a) -> 'a
end
