(* basis.compiler: a program compiled by rune has no compiler beside it, so
   Compiler.use, Compiler.compile and Compiler.compileIn raise Fail; the
   REPL's controls are refs of their defaults, which a program may set
   (docs/repl.md) *)
val () = (Compiler.use "anything.sml"; print "used\n")
         handle Fail msg => print ("Fail: " ^ msg ^ "\n")
val () = (ignore (Compiler.compile {read = fn () => NONE, file = "none", line = 1}); print "compiled\n")
         handle Fail msg => print ("Fail: " ^ msg ^ "\n")
(* compileIn, which is given the mode of what it reads, as well *)
val () = (ignore (Compiler.compileIn "unicode" {read = fn () => NONE, file = "none", line = 1}); print "compiled\n")
         handle Fail msg => print ("Fail: " ^ msg ^ "\n")
val () = print (Int.toString (!Compiler.printDepth) ^ " [" ^ !Compiler.prompt1 ^ "] [" ^ !Compiler.prompt2 ^ "]\n")
val () = (Compiler.printDepth := 3; Compiler.prompt1 := "> ")
val () = print (Int.toString (!Compiler.printDepth) ^ " [" ^ !Compiler.prompt1 ^ "]\n")
