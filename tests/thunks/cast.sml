(* Casts at the boundary of suspensions (D4, D5): a value cast into a
   suspension's slot, which Lower makes no instruction, and forced, which
   Lower makes the value itself; and a value cast from a polymorphic slot
   to int, an Any's cast, which --check-casts makes any_check, and which
   prints the same with it. The suspension is Haskell's (docs/ir.md,
   Suspensions); tests/runner/thunks.sml runs it on every engine. *)
structure D =
struct
  type 'a susp = 'a _prim "susp"
  val make = _prim "thunk_make" : (unit -> 'a) -> 'a susp
  val force = _prim "thunk_force" : 'a susp -> 'a
  val blackhole = _prim "thunk_blackhole" : unit -> unit
  val update = _prim "thunk_self_update" : 'a -> unit
  fun delay f = make (fn () => let val () = blackhole () val v = f () val () = update v in v end)
end
val toSusp = _prim "unsafe_cast" : int -> int D.susp
val toInt = _prim "unsafe_cast" : 'a -> int
fun anyOf x = toInt x
val s = toSusp 41
val a = D.force s + 1
val b = anyOf a + anyOf (D.force (D.delay (fn () => a + 1)))
val () = print ("cast " ^ Int.toString a ^ " " ^ Int.toString b ^ "\n")
