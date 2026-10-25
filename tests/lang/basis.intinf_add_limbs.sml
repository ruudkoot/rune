(* IntInf's addition of two magnitudes of as many bytes and different
   lengths in limbs (30 bits each, where the machine int has 63): the SML
   arithmetic (the stack VM's, and --intinf=sml) took the first for the
   longer by bytes and dropped the other's top limb, so that
   (2^210 - 1) + 2^210 lost 2^210 (found by pidigits under --intinf=sml).
   Each sum is checked both ways round against 2^(k+1) - 1, and then
   against its parts. *)
val i = IntInf.fromInt
val two = i 2
fun pow k = IntInf.pow (two, k)
val wrong = ref 0
fun check (x : IntInf.int, y, want) =
  (if x + y = want then () else wrong := !wrong + 1;
   if y + x = want then () else wrong := !wrong + 1)
(* 2^k - 1 and 2^k: k bits and k + 1, of one byte length unless k is a
   multiple of 8, of two limb lengths where k is a multiple of 30 *)
val () = List.app (fn k => check (pow k - i 1, pow k, pow (k + 1) - i 1)) (List.tabulate (400, fn k => k + 1))
(* a sum that carries out of the top limb, of operands of one byte length *)
val () = List.app (fn k => check (pow k - i 1, pow k + i 12345, pow (k + 1) + i 12344)) [60, 90, 120, 210, 240, 300]
val () = print ("wrong sums: " ^ Int.toString (!wrong) ^ "\n")
val () = print (IntInf.toString ((pow 210 - i 1) + pow 210) ^ "\n")
