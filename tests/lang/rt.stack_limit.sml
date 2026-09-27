(* a recursion without end: the VM stops at --stack-size, with status 2,
   rather than growing its stack until the machine has no memory left
   (rt.deeprec_stack is the depth a program may use) *)
fun forever n = 1 + forever (n + 1)
val () = print (Int.toString (forever 0) ^ "\n")
