(* The stack's watermark through its return barrier (docs/plans/native-frames.md,
   M5): a recursion that allocates, so that collections come at depth and the
   barrier sits deep; raises that unwind below it to a handler further down;
   returns through it, one frame at a time; and a loop of tail calls at it. Run
   with a small nursery, and in the suites under --gc-verify, which checks that
   the barrier is at the watermark. *)
exception Up of int
fun build 0 acc = acc
  | build n acc = build (n - 1) (n :: acc)
fun deep (0, k) = if k mod 3 = 0 then raise Up k else List.length (build 50 [])
  | deep (n, k) = let val xs = build 5 [] val r = deep (n - 1, k) in r + List.length xs end
fun catcher (n, k) = deep (n, k) handle Up j => j
fun loop (0, acc) = acc
  | loop (i, acc) = loop (i - 1, acc + catcher (200 + i mod 300, i))
fun tail (0, acc) = acc
  | tail (n, acc) = tail (n - 1, acc + length (build 3 []))
val () = print (Int.toString (loop (1000, 0)) ^ " " ^ Int.toString (tail (20000, 0)) ^ "\n")
