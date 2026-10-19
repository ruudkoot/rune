(* A frame's header in the value stack (docs/plans/native-frames.md, M4):
   compiled code writes its return word and, where it must, its closure, but
   not its info word, which holds what the slot held before -- here the lists
   in the registers of the wider frames that ran there -- and which a
   collection makes unit where it is a pointer (FrameRef.stale_slot). The
   recursion of small frames runs over the slots of the wide ones, and
   allocates at its depth; run with a small nursery, and in the suites under
   --gc-verify, which checks every slot of the stack. *)
fun build 0 acc = acc
  | build n acc = build (n - 1) (n :: acc)
fun wide n =
  let
    val a = build n []
    val b = build (n + 1) []
    val c = build (n + 2) []
    val d = build (n + 3) []
    val e = build 1 []
  in
    length a + length b + length c + length d + length e
  end
fun count 0 = length (build 20 [])
  | count n = 1 + count (n - 1)
fun spread 0 = 0
  | spread n = wide 3 + spread (n - 1)
fun round (0, acc) = acc
  | round (i, acc) = round (i - 1, acc + spread 20 + count 200)
val () = print (Int.toString (round (100, 0)) ^ "\n")
