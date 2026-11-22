(* A CAF -- a global that holds a suspension -- that no code that may
   still run reads is let go at a full collection (the haskell98 roadmap's
   D19, B; runtime/gc/caf.c): xs, a list of n elements made as it is
   walked, is walked by total, which nothing calls after, so the live at
   the end does not grow with n; ys, read again at the end, is kept, and
   its walk there finds it whole. args: n
   The suspensions are Haskell's (docs/ir.md, Suspensions).
   tests/runner/thunks.sml runs it on every engine, and its live at the
   end at n = 1000 and 2000 under each collector, and with every global a
   root (--caf-tables off), where it grows. *)
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
fun len (Nil, k) = k
  | len (Cons (_, t), k) = len (D.force t, k + 1)
val n = valOf (Int.fromString (hd (CommandLine.arguments ())))
val xs = D.delay (fn () => from (1, n))
val ys = D.delay (fn () => from (1, 100))
fun total () = len (D.force xs, 0)
val a = total ()
val b = len (D.force ys, 0)
(* allocation after xs is read for the last time, so that collections
   come with it dead *)
fun churn (0, acc) = acc
  | churn (k, acc) = churn (k - 1, List.length (List.tabulate (10, fn i => i + k)) + acc)
val c = churn (200, 0)
val d = len (D.force ys, 0)
val () = print ("caf " ^ Int.toString a ^ " " ^ Int.toString b ^ " " ^ Int.toString c ^ " " ^ Int.toString d ^ "\n")
