(* Import an ordinary CLI unit without an API source companion. *)
val (input,output)=case CommandLine.arguments () of
  [input,output] => (input,output) | _ => raise Fail "expected input unit and output program"
val context=RuneCompiler.session {lib=NONE,flags=["--allow-prim"]}
val imported=RuneCompiler.readUnit (context,input)
val checked=RuneCompiler.compileText (context,{file="after-cli.sml",
  text="exception WrongImportedValue\nval print=_prim \"print\" : string -> unit\nval ()=if id answer=42 then print \"42 imported\\n\" else raise WrongImportedValue\n"})
val ()=RuneCompiler.writeProgram ([imported,checked],output)
val ()=RuneCompiler.close context
val ()=print "PASS CLI unit import\n"
