(* let strdec in strexp end *)
structure S =
  let
    val base = 100
    structure Helper = struct fun add n = n + base end
  in
    struct
      val v = Helper.add 5
      structure H = Helper
    end
  end
val () = print (Int.toString S.v ^ " " ^ Int.toString (S.H.add 1) ^ "\n")
