(* A CAF that the function of a closure of two parameters alone reaches
   (the haskell98 roadmap's item 24, option 1): ys, a list made as it is
   walked, is read only by count, a curried function of two parameters
   whose closure (Uncurry's twin: CLOSUREN) is put in a ref and called
   through it after collections. The register VM's closure of k >= 2
   parameters holds -2 - f in field 0, not its function f, so the
   collector's CAF tables take its function back from it (caf_code_due and
   caf_code, runtime/gc): else ys, which no other code that may still run
   reads, is made unit at a full collection, and the call through the ref
   forces unit. args: n
   tests/runner/thunks.sml runs it on every engine: its lowpause way
   (a cycle at every other allocation) found the collector taking it
   for no function. *)
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
val ys = D.delay (fn () => from (1, n))
fun count k (u : unit) = len (D.force ys, k)
val keep : (int -> unit -> int) ref = ref (fn k => fn _ => k)
val () = keep := count
(* allocation, so that collections come while ys is read by count alone *)
fun churn (0, acc) = acc
  | churn (k, acc) = churn (k - 1, List.length (List.tabulate (10, fn i => i + k)) + acc)
val c = churn (200, 0)
val a = !keep 5 ()
val c' = churn (200, 0)
val b = !keep 0 ()
val () = print ("cafnary " ^ Int.toString a ^ " " ^ Int.toString b ^ " " ^ Int.toString (c + c') ^ "\n")
