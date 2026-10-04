(* What the collector keeps of a frame that waits for a call
   (runtime/heap.c, stack_roots; scripts/check-register.sh runs this on
   runtime/register at every tier). A list of 100,000 cells, 2.4 MB, whose
   last use is before the call is dropped by the collection the callee makes;
   the same list used after the call is kept, and so is one that a handler
   alone needs, since the callee may raise. Every function here calls
   itself, so that the compiler keeps it a function with a frame of its own:
   the top level's has more registers than the 64 the liveness follows. *)
fun many (0, acc) = acc
  | many (n, acc) = many (n - 1, n :: acc)
fun liveNow 0 = (Runtime.collect (); #live (Runtime.stats ()))
  | liveNow n = liveNow (n - 1)
fun say l = if l < 1000000 then "dropped" else "kept"
fun deadBefore 0 = []
  | deadBefore k =
      let val xs = many (100000, [])
          val n = length xs
          val l = liveNow 3
      in (Int.toString n ^ " " ^ say l) :: deadBefore (k - 1) end
fun liveAfter 0 = []
  | liveAfter k =
      let val xs = many (100000, [])
          val l = liveNow 3
      in (Int.toString (length xs) ^ " " ^ say l) :: liveAfter (k - 1) end
fun forHandler 0 = []
  | forHandler k =
      let val xs = many (100000, [])
          val l = liveNow 3 handle Fail _ => length xs
      in say l :: forHandler (k - 1) end
val () = print (String.concatWith "\n" (deadBefore 1 @ liveAfter 1 @ forHandler 1) ^ "\n")
