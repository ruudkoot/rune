(* Deterministic foreign cleanup on normal and exceptional SML returns.

   Area: Foreign interfaces *)
signature FOREIGN_SCOPE =
sig
  (* One dynamically scoped collection of cleanup actions. *)
  type scope
  (* An armed cleanup action, independent of a native address. *)
  type ticket
  (* Registration after cleanup has begun. *)
  exception Closed
  (* `withScope body` runs registered actions in reverse registration order.

     Every armed action is attempted once. A body exception takes priority
     over cleanup exceptions; otherwise the first cleanup exception escapes. *)
  val withScope : (scope -> 'a) -> 'a
  (* `defer (scope, action)` registers an action before its resource escapes.

     Raises: `Closed` when the scope is closing or closed. *)
  val defer : scope * (unit -> unit) -> ticket
  (* `run ticket` attempts its action now, at most once, even if it raises. *)
  val run : ticket -> unit
  (* `cancel ticket` transfers cleanup responsibility to the caller. *)
  val cancel : ticket -> unit
end
