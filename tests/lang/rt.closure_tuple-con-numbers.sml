(* As rt.closure_tuple-con, in a closure with variables of its own at the
   numbers the parts of the tuple had in mk: Lower once made the constructor
   of those, and the program printed other numbers, with every lint
   satisfied, at every level. *)
datatype t = A of int * int | B

fun mk (x, y) =
  let val p = (x + 1, y + 2)
  in
    fn (z : int) =>
      let
        val a = z * 7
        val b = a + 3
        val c = b - z
        val d = c * c
      in (d, A p) end
  end

fun show (d, A (a, b)) = Int.toString d ^ " " ^ Int.toString a ^ " " ^ Int.toString b
  | show (d, B) = Int.toString d ^ " B"

val fs = List.map mk [(10, 20), (30, 40), (50, 60)]
val () = List.app (fn f => print (show (f 5) ^ "\n")) fs
