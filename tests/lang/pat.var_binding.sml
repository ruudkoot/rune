fun swap (a, b) = (b, a)
val (x, y) = swap (1, 2)
val z = 3
val () = print (Int.toString x ^ Int.toString y ^ Int.toString z ^ "\n")
(* a variable pattern shadows even a constructor-like name that is not a constructor *)
val nil' = 5
val () = print (Int.toString nil' ^ "\n")
