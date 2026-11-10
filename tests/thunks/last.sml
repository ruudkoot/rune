(* Jones 1992's `last` (D12): a suspension whose code is last xs, a tail
   call of a loop over a list made as it is walked. Where the frame or the
   suspension keeps xs every cell stays live; the most live with a
   collection at every allocation (runevm --stats) is the same for every
   n where none does. The suspension's code is written out, as rhc makes
   it, so that -O0, which inlines nothing, has it too. args: n
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
datatype l = Nil | Cons of int * l D.susp
fun from (i, n) = if i > n then Nil else Cons (i, D.delay (fn () => from (i + 1, n)))
fun last (acc, Nil) = acc
  | last (_, Cons (x, t)) = last (x, D.force t)
fun mk n =
  let val xs = D.delay (fn () => from (1, n))
  in D.make (fn () => let val () = D.blackhole () val v = last (0, D.force xs) val () = D.update v in v end) end
val n = valOf (Int.fromString (hd (CommandLine.arguments ())))
val t = mk n
val r = D.force t
val () = print ("last " ^ Int.toString r ^ "\n")
