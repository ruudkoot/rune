(* A force forgotten behind a cast (D4, D5): a suspension given to a
   cast from a polymorphic slot to int, an Any's, where nothing forced it.
   Compiled with --check-casts, any_check stops it on every engine; at -O0
   the lint cannot see it, through a type variable, and at -O2, where
   Simplify has specialised the cast to its suspension, it refuses it.
   tests/runner/thunks.sml compiles it without the lint but where it wants
   that refusal. *)
structure D =
struct
  type 'a susp = 'a _prim "susp"
  val make = _prim "thunk_make" : (unit -> 'a) -> 'a susp
  val force = _prim "thunk_force" : 'a susp -> 'a
  val blackhole = _prim "thunk_blackhole" : unit -> unit
  val update = _prim "thunk_self_update" : 'a -> unit
  fun delay f = make (fn () => let val () = blackhole () val v = f () val () = update v in v end)
end
val toInt = _prim "unsafe_cast" : 'a -> int
fun anyOf x = toInt x
val c = anyOf (D.delay (fn () => 7))
val () = print ("forget " ^ Int.toString c ^ "\n")
