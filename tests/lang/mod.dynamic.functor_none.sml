(* A virtual functor that the program does not implement compiles, and its
   declaration raises Dynamic.Mismatch when it runs, as a virtual
   structure's does (docs/build.md, Virtual modules) *)
signature S = sig val x : int end
val () = print "before\n"
functor F = _virtual (X : S) : S
structure A = F (struct val x = 1 end)
val () = print (Int.toString A.x ^ "\n")
