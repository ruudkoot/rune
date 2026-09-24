(* rt.save: the first object of the heap survives an image. It lies at the
   start of the heap, where its distance is 0, which was once read back as no
   object: here it is the string of the first constant, "Fail", which the
   constructor of Fail names, and the VM that carried the image on crashed. *)
val () =
  case Runtime.save "tests/out/rt.save_first.img" of
    Runtime.Saved => print "saved\n"
  | Runtime.Restored => print ("restored: " ^ exnName (Fail "x") ^ ", " ^ exnMessage (Fail "after") ^ "\n")
