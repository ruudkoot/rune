infix 6 +++
fun a +++ b = a * 10 + b
infixr 5 ***
fun (a *** b) = a - b
infix 7 %%
fun (a %% b) c = a + b + c
val () = print (Int.toString (1 +++ 2) ^ " " ^ Int.toString (10 *** 4 *** 1) ^ " " ^ Int.toString ((1 %% 2) 3) ^ "\n")
val () = print (Int.toString (op+++ (3, 4)) ^ "\n")
