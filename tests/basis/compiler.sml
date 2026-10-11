(* requires: Compiler Int String *)
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
  val () = T.raises ("Compiler.compile/no-compiler-beside-the-program",
                     fn Fail _ => true | _ => false,
                     fn () => Compiler.compile {read = fn () => NONE, file = "none", line = 1})
  val () = T.check ("Compiler.printDepth/is-twenty", fn () => !Compiler.printDepth = 20)
  val () = T.check ("Compiler.prompt1/is-a-dash", fn () => !Compiler.prompt1 = "- ")
  val () = T.check ("Compiler.prompt2/is-an-equals-sign", fn () => !Compiler.prompt2 = "= ")

  (* prettyPrint, into a string *)
  fun laid (width, p) =
    let val parts = ref []
    in Compiler.prettyPrint (fn s => parts := s :: !parts, width) p; String.concat (List.rev (!parts)) end
  open Compiler
  val three = [PrettyString "aa", PrettyBreak (1, 0), PrettyString "bb", PrettyBreak (1, 0), PrettyString "cc"]
  val () = T.check ("Compiler.prettyPrint/a-block-that-fits-is-one-line",
                    fn () => laid (80, PrettyBlock (2, true, [], three)) = "aa bb cc")
  val () = T.check ("Compiler.prettyPrint/consistent-breaks-every-break",
                    fn () => laid (6, PrettyBlock (2, true, [], three)) = "aa\n  bb\n  cc")
  val () = T.check ("Compiler.prettyPrint/inconsistent-breaks-where-it-must",
                    fn () => laid (6, PrettyBlock (2, false, [], three)) = "aa bb\n  cc")
  val () = T.check ("Compiler.prettyPrint/a-break-adds-its-offset",
                    fn () => laid (3, PrettyBlock (1, true, [], [PrettyString "aa", PrettyBreak (1, 2), PrettyString "b"]))
                             = "aa\n   b")
  val () = T.check ("Compiler.prettyPrint/a-line-break-always-breaks",
                    fn () => laid (80, PrettyBlock (0, false, [], [PrettyString "a", PrettyLineBreak, PrettyString "b"]))
                             = "a\nb")
  val () = T.check ("Compiler.prettyPrint/a-string-with-a-width-counts-that",
                    fn () => laid (4, PrettyBlock (0, false, [], [PrettyStringWithWidth ("x", 4), PrettyBreak (1, 0),
                                                                  PrettyString "y"])) = "x\ny")
  val () = T.check ("Compiler.lineLength/is-eighty", fn () => !Compiler.lineLength = 80)
  (* with no compiler beside the program, there is nothing to install a
     printer in, and nothing happens *)
  val () = T.check ("Compiler.addPrettyPrinter/no-compiler-beside-the-program",
                    fn () => (Compiler.addPrettyPrinter (fn _ => fn () => fn (_ : bool) => PrettyString "b"); true))
end
