(* IntInf: multiplication, division and printing of large numbers. *)
fun fact (0 : IntInf.int) = 1
  | fact n = n * fact (n - 1)
val f = fact 300
val digits = String.size (IntInf.toString f)
val (q, r) = IntInf.divMod (f, fact 150)
val () = print (Int.toString digits ^ " " ^ Int.toString (String.size (IntInf.toString q)) ^ " "
                ^ IntInf.toString r ^ " " ^ IntInf.toString (IntInf.pow (3, 200) mod 1000007) ^ "\n")
