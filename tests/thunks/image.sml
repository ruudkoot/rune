(* Suspensions in an image: evaluated, unevaluated, and the one under
   evaluation that saves it (D11; runtime/image.c), made one with their
   equals first (Runtime.share). The run saves and stops; the image
   restored goes on inside the suspension. args: path
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
val path = hd (CommandLine.arguments ())
fun count (0, acc) = acc | count (n, acc) = count (n - 1, D.delay (fn () => n * 2) :: acc)
val ts = count (1000, [])
val forced = List.filter (fn t => D.force t mod 4 = 0) ts
val fresh = count (1000, [])
val under = D.delay (fn () =>
  let val keep = List.foldl (fn (t, a) => a + D.force t) 0 (List.take (fresh, 10))
      val _ = Runtime.share ()
  in case Runtime.save path of
       Runtime.Saved => (print "saved\n"; OS.Process.exit OS.Process.success)
     | Runtime.Restored => (print "restored inside the suspension\n"; keep + 1)
  end)
val r = D.force under
val s = List.foldl (fn (t, a) => a + D.force t) 0 fresh
val f = List.foldl (fn (t, a) => a + D.force t) 0 forced
val () = print ("image " ^ Int.toString r ^ " " ^ Int.toString s ^ " " ^ Int.toString f ^ " again " ^ Int.toString (D.force under) ^ "\n")
