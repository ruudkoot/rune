(* Trojan Source, the homoglyph function: a second sayHello with a Greek
   capital eta *)
fun sayHello () = "hello"
fun sayΗello () = "evil"
val () = print (sayHello () ^ " " ^ sayΗello () ^ "\n")
