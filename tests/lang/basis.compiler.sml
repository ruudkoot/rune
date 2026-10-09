(* basis.compiler: a program compiled by rune has no compiler beside it, so
   Compiler.use raises Fail; the REPL's controls are refs of their defaults,
   which a program may set (docs/repl.md) *)
val () = (Compiler.use "anything.sml"; print "used\n")
         handle Fail msg => print ("Fail: " ^ msg ^ "\n")
val () = print (Int.toString (!Compiler.printDepth) ^ " [" ^ !Compiler.prompt1 ^ "] [" ^ !Compiler.prompt2 ^ "]\n")
val () = (Compiler.printDepth := 3; Compiler.prompt1 := "> ")
val () = print (Int.toString (!Compiler.printDepth) ^ " [" ^ !Compiler.prompt1 ^ "]\n")
