(* A loop of a million steps, each a tail call inside the let that makes a
   string. It runs in constant space on MLton, SML/NJ, Poly/ML and Rune; MLKit
   keeps the string's region and a frame for every step
   (docs/bugreport/mlkit/preserve-tail-calls). *)
fun go c =
  if c > 1000000 then true
  else
    let val s = Int.toString c
    in go (c + size s - size s + 1) end

val () = print (if go 0 then "PASS\n" else "FAIL\n")
