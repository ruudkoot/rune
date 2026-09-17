infix 5 |>
fun x |> f = f x
val () = print (Int.toString (3 |> (fn x => x + 1) |> (fn x => x * 2)) ^ "\n")
infixr 5 ^^
fun a ^^ b = a ^ "." ^ b
val () = print ("a" ^^ "b" ^^ "c" ^ "\n")
nonfix +
val () = print (Int.toString (+ (1, 2)) ^ "\n")
infix 6 +
val () = print (Int.toString (1 + 2) ^ "\n")
val () = let infix 0 ## fun a ## b = a - b in print (Int.toString (10 ## 2 * 3) ^ "\n") end
