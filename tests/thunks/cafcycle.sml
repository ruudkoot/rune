(* A CAF that only the code of a suspension reads, the suspension forced
   while the low-pause collector's cycle marks and before the cycle has
   marked it (the haskell98 roadmap's D19, B; runtime/gc/caf.c): zs is read
   by s's code alone, and s goes under evaluation (BLACKHOLE) with big
   still to be marked before it, then allocates until the cycle ends, then
   reads zs. The cycle's snapshot reached s as a suspension whose code may
   run, so the globals that code reads are the snapshot's too: BLACKHOLE
   and UPDATE take them while a cycle marks (gc_barrier_code, runtime/vm.h),
   as marking s would have; else the cycle's end makes zs unit, and s's
   read of it stops the program. args: n
   tests/runner/thunks.sml runs it on every engine: its lowpause ways (a
   cycle at every other allocation, both VMs, the default tier and tier 2)
   found the cycle letting zs go, as rhc's programs under --gc low-pause
   did ("primitive thunk_make: wrong argument type"). *)
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
fun churn (0, acc) = acc
  | churn (k, acc) = churn (k - 1, List.length (List.tabulate (10, fn i => i + k)) + acc)
val n = valOf (Int.fromString (hd (CommandLine.arguments ())))
val zs = D.delay (fn () => from (1, 100))
(* s reads zs only after allocating enough for the cycle it was forced in
   to end *)
val s = D.delay (fn () => let val c = churn (4 * n, 0) in len (D.force zs, 0) + c - c end)
(* big, on the stack, marked before s: the cycle's gray objects are taken
   last first, and the stack's are pushed after the globals' *)
fun go big = let val c = churn (20, 0) val r = D.force s in r + c - c + length big - length big end
val r = go (List.tabulate (n, fn i => i))
val () = print ("cafcycle " ^ Int.toString r ^ "\n")
