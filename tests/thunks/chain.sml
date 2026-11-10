(* A chain of suspended additions, foldl (+) in suspensions, forced from
   its head: n forces nested in each other, a frame each (D18). args: n
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
val n = valOf (Int.fromString (hd (CommandLine.arguments ())))
fun go (i, acc) = if i > n then acc else go (i + 1, D.delay (fn () => D.force acc + i))
val r = D.force (go (1, D.delay (fn () => 0)))
val () = print ("chain " ^ Int.toString r ^ "\n")
