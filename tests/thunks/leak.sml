(* A suspension running sum xs must not hold xs, a list made as it is
   summed, though its code does more after the loop (D12): as `last`, the
   most live is the same for every n where nothing keeps xs; its code
   written out, as `last`'s. args: n
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
fun sum (Nil, acc) = acc
  | sum (Cons (x, t), acc) = sum (D.force t, acc + x)
fun mk n =
  let val xs = D.delay (fn () => from (1, n))
  in D.make (fn () => let val () = D.blackhole () val v = 1 + sum (D.force xs, 0) val () = D.update v in v end) end
val n = valOf (Int.fromString (hd (CommandLine.arguments ())))
val t = mk n
val r = D.force t
val () = print ("leak " ^ Int.toString r ^ "\n")
