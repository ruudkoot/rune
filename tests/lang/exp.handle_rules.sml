exception A of int
exception B
fun test f = (f (); "ok") handle A n => "A" ^ Int.toString n | B => "B" | Fail s => "Fail:" ^ s
val () = print (test (fn () => ()) ^ " " ^ test (fn () => raise A 1) ^ " " ^ test (fn () => raise B) ^ " " ^ test (fn () => raise Fail "f") ^ "\n")
(* unhandled exceptions propagate through handlers that don't match *)
val () = print ((test (fn () => raise Div) handle Div => "outer div") ^ "\n")
(* re-raise *)
val () = print (((raise B) handle A _ => "a") handle B => "reraised\n")
(* handler in tail position of a function *)
fun safeDiv a b = a div b handle Div => 0
val () = print (Int.toString (safeDiv 6 2) ^ Int.toString (safeDiv 1 0) ^ "\n")
(* nested handlers and stack unwinding through calls *)
fun deep 0 = raise A 0 | deep n = deep (n - 1) + 1
val () = print ((Int.toString (deep 1000)) handle A n => "deep " ^ Int.toString n ^ "\n")
