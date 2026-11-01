(* The program that loads the dynamic module, built in units: its slots
   cast from the record the runtime gives (dynamic_cast), its datatype
   matched and its exception handled. *)
structure S = _dynamic "impl.rbu" : SHAPE
fun kind k = case k of S.Round => "round" | S.Square n => "square " ^ Int.toString n
val () = print (S.name ^ " " ^ Int.toString (S.area (S.make 3)) ^ " " ^ kind (S.kindOf (S.make 3)) ^ " "
                ^ kind (S.kindOf (S.make 7)) ^ "\n")
val () = print (#1 (S.twice "poly") ^ "\n")
val () = (ignore (S.make ~4); print "no raise\n") handle S.Bad n => print ("Bad " ^ Int.toString n ^ "\n")
