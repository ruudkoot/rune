(* each application creates new exceptions and new datatypes *)
functor F () = struct exception E datatype t = C fun raiseIt () = raise E end
structure A = F ()
structure B = F ()
val () = (A.raiseIt ()) handle B.E => print "wrong\n" | A.E => print "A.E\n"
val () = (B.raiseIt ()) handle A.E => print "wrong\n" | B.E => print "B.E\n"
val () = case A.C of A.C => print "A.C\n"
