(* Old suspensions given young values: an array of n suspensions made old
   by churn, each forced to a tuple made then, more churn, then every value
   read (D19's barrier). A store the barrier did not see is lost under
   --gc-verify, or a wrong sum. args: n rounds
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
val (n, rounds) = case List.map (valOf o Int.fromString) (CommandLine.arguments ()) of [n, r] => (n, r) | _ => raise Fail "args"
fun churn k = let fun go (0, acc) = acc | go (i, acc) = go (i - 1, if i mod 7 = 0 then [i] else i :: acc) in length (go (k, [])) end
fun round r =
  let
    val a = Array.tabulate (n, fn i => D.delay (fn () => (i + r, [i, r])))
    val c1 = churn (4 * n)
    val _ = Array.app (fn t => ignore (D.force t)) a
    val c2 = churn (4 * n)
    val s = Array.foldl (fn (t, acc) => let val (x, l) = D.force t in acc + x + hd l end) 0 a
  in s + c1 - c1 + c2 - c2 end
fun loop (0, acc) = acc | loop (r, acc) = loop (r - 1, acc + round r)
val () = print ("barrier " ^ Int.toString (loop (rounds, 0)) ^ "\n")
