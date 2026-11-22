(* A suspension whose code forces it again: a loop, which ENTER finds at
   once, since the first entry said BLACKHOLE, and raises Loop, which
   nothing handles here: the program ends as an uncaught
   exception ends it, status 1 (D12; Haskell 98's <<loop>>; ruling 58).
   The suspension is Haskell's (docs/ir.md, Suspensions): its code says
   BLACKHOLE once it has read what it captured, and UPDATE with its value.
   tests/runner/thunks.sml runs it on every engine. *)
structure D =
struct
  type 'a susp = 'a _prim "susp"
  val make = _prim "thunk_make" : (unit -> 'a) -> 'a susp
  val force = _prim "thunk_force" : 'a susp -> 'a
  val blackhole = _prim "thunk_blackhole" : unit -> unit
  val update = _prim "thunk_self_update" : 'a -> unit
  fun delay f = make (fn () => let val () = blackhole () val v = f () val () = update v in v end)
end
val depth = ref 0
val c = ref NONE
val t = D.delay (fn () => (depth := !depth + 1; print ("entered " ^ Int.toString (!depth) ^ "\n");
                           if !depth < 3 then D.force (valOf (!c)) + 1 else 0))
val () = c := SOME t
val r = D.force t
val () = print ("reenter " ^ Int.toString r ^ "\n")
