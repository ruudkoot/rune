structure Ints = Set (IntOrd)
structure Names = Set (StringOrd)
val s = List.foldl (fn (x, s) => Ints.add (s, x)) Ints.empty [5, 3, 8, 3, 1]
val n = Names.add (Names.add (Names.empty, "b"), "a")
val () = print (String.concatWith " " (List.map IntOrd.show (Ints.elems s)) ^ " " ^ Int.toString (Ints.size s) ^ "\n")
val () = print (String.concatWith " " (Names.elems n) ^ "\n")
val () = (ignore (Ints.remove (s, 7)); print "removed\n") handle Ints.Absent k => print ("absent " ^ IntOrd.show k ^ "\n")
