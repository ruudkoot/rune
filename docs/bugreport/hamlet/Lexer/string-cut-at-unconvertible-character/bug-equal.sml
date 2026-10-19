(* Two different literals, with E9 and E8 after "caf", are equal, and a
   pattern with E9 matches "caf". If the program were accepted, it
   should print false and "not matched". *)
val () = print (Bool.toString ("café" = "cafè") ^ "\n")
val () = print ((case "caf" of "café" => "matched" | _ => "not matched") ^ "\n")
