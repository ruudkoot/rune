(* Poly/ML 5.9.2: IntInf.~>> of a negative number below Int.minInt.
   ~>> (i, n) is floor (i / 2^n), which is i div 2^n: it rounds down. *)
fun check (i, n) =
  let
    val got = IntInf.~>> (i, n)
    val floor = IntInf.div (i, IntInf.pow (2, Word.toInt n))
  in
    print (IntInf.toString i ^ " ~>> " ^ Int.toString (Word.toInt n) ^ " = "
           ^ IntInf.toString got
           ^ (if got = floor then "" else "    <- WRONG, should be " ^ IntInf.toString floor)
           ^ "\n")
  end

val p62 = IntInf.pow (2, 62)    (* Poly/ML's Int.minInt is ~p62 *)

val () = List.app check
  [(~p62, 0w1),                           (* Int.minInt: a short integer *)
   (~p62 + 1, 0w1),
   (~p62 - 1, 0w1),                       (* the first long one *)
   (~p62 - 1, 0w2),
   (~p62 - 2, 0w1),                       (* nothing shifted out but zeros *)
   (~p62 - 3, 0w1),
   (~(IntInf.pow (2, 63)) - 1, 0w1),
   (~9223372036854775792, 0w5),
   (~(IntInf.pow (2, 100)) - 1, 0w50),
   (~p62 - 1, 0w63),                      (* every bit shifted out *)
   (~(IntInf.pow (2, 100)), 0w101),
   (~5, 0w1),                             (* for contrast: short, and positive *)
   (~1, 0w100),
   (p62 + 1, 0w1)]
