(* requires: Compiler *)
(* Compiler matches COMPILER, which is Rune's own signature and has no
   transcription under spec-sigs: a function and three refs, nothing
   abstract. *)
structure TestCompilerSig =
struct
  val () = T.check ("Compiler:COMPILER/a-use-and-three-refs",
                    fn () =>
                      let
                        val u : string -> unit = Compiler.use
                        val d : int ref = Compiler.printDepth
                        val p : string ref = Compiler.prompt1
                        val q : string ref = Compiler.prompt2
                      in !d > 0 andalso size (!p) > 0 andalso size (!q) > 0 andalso (ignore u; true) end)
end
