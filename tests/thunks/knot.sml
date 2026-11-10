(* A stream tied to itself through a cell, fibs = 0 : 1 : zipWith (+) fibs
   (tail fibs), mod a prime (D6's A): linear in n only if every cell of
   the stream is shared, which the count of evaluations says. args: n reps
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
datatype s = C of int * s D.susp
val evals = ref 0
fun knot build =
  let val c = ref NONE
      val t = D.delay (fn () => build (valOf (!c)))
  in c := SOME t; t end
fun hd' (C (a, _)) = a
fun tl' (C (_, t)) = t
fun zip (s, t) =
  let val C (a, s') = D.force s
      val C (b, t') = D.force t
  in evals := !evals + 1;
     C ((a + b) mod 1000003, D.delay (fn () => zip (s', t')))
  end
fun fibs () = knot (fn self => C (0, D.delay (fn () => C (1, D.delay (fn () => zip (self, tl' (D.force self)))))))
fun nth (t, 0) = hd' (D.force t)
  | nth (t, k) = nth (tl' (D.force t), k - 1)
val (n, reps) = case List.map (valOf o Int.fromString) (CommandLine.arguments ()) of [n, r] => (n, r) | _ => raise Fail "args"
fun loop (0, acc) = acc | loop (r, acc) = loop (r - 1, (acc + nth (fibs (), n)) mod 1000003)
val r = loop (reps, 0)
val () = print ("knot " ^ Int.toString r ^ " evals " ^ Int.toString (!evals) ^ "\n")
