(* A dag of 2n edges that is a tree of 2^n leaves where a suspension's
   value is not shared: it ends for n = 50 only if each code runs once,
   which the count of evaluations says. args: n
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
val evals = ref 0
fun build 0 = D.delay (fn () => (evals := !evals + 1; 1))
  | build k = let val t = build (k - 1)
              in D.delay (fn () => (evals := !evals + 1; (D.force t + D.force t) mod 1000003)) end
val r = D.force (build n)
val () = print ("share " ^ Int.toString r ^ " evals " ^ Int.toString (!evals) ^ "\n")
