(* Suspensions of a closure that captures nothing, made in a loop: such a
   closure may be a constant the program shares, so each suspension is made
   beside it, of its function (runtime/prims.c, p_thunk_make; the JIT's in
   line since the haskell98 roadmap's M9b), and runs its code once, on its
   own, however often it is forced: the constant stays a closure. Were the
   closure made a suspension in place, the second loop's suspension would be
   the first's, and run no more. args: n
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
val runs = ref 0
fun go (0, acc) = acc
  | go (i, acc) =
      let val s = D.delay (fn () => (runs := !runs + 1; 1))
      in go (i - 1, acc + D.force s + D.force s) end
val n = valOf (Int.fromString (hd (CommandLine.arguments ())))
val r = go (n, 0)
val () = print ("nullary " ^ Int.toString r ^ " " ^ Int.toString (!runs) ^ "\n")
