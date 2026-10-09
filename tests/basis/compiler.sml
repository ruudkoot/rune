(* requires: Compiler Int *)
(* Compiler (signature COMPILER, Rune's own): what a program can ask of the
   compiler beside it. The suite's programs are compiled by rune, with no
   compiler beside them, so what is checked is that: use raises Fail, and
   the controls are refs of the defaults the REPL starts from
   (docs/repl.md). The REPL itself is checked by tests/repl. *)
structure TestCompiler =
struct
  val () = T.raises ("Compiler.use/no-compiler-beside-the-program",
                     fn Fail _ => true | _ => false,
                     fn () => Compiler.use "no-such-file.sml")
  val () = T.check ("Compiler.printDepth/is-twenty", fn () => !Compiler.printDepth = 20)
  val () = T.check ("Compiler.prompt1/is-a-dash", fn () => !Compiler.prompt1 = "- ")
  val () = T.check ("Compiler.prompt2/is-an-equals-sign", fn () => !Compiler.prompt2 = "= ")
end
