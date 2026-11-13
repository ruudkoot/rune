(* A loop handled (D12; ruling 58): a suspension forced while its code runs
   raises Loop from ENTER, which a handler takes; the
   suspension, left under evaluation by the raise, raises it again at each
   force after. args: n, the forces after the first.
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
val c = ref NONE
val t = D.delay (fn () => D.force (valOf (!c)) + 1)
val () = c := SOME t
fun try () = (Int.toString (D.force t)) handle e => exnName e
val first = try ()
fun go (0, acc) = acc
  | go (k, acc) = go (k - 1, if try () = "Loop" then acc + 1 else acc)
val () = print ("loopcatch " ^ first ^ " " ^ Int.toString (go (n, 0)) ^ "\n")
