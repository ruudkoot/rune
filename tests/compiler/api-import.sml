(* Import an ordinary CLI unit without an API source companion. *)
val (input,output)=case CommandLine.arguments () of
  [input,output] => (input,output) | _ => raise Fail "expected input unit and output program"
val context=CompilerApi.session {lib=NONE,flags=["--allow-prim"]}
val imported=CompilerApi.readUnit (context,input)
val checked=CompilerApi.compileText (context,{file="after-cli.sml",
  text="exception WrongImportedValue\nval print=_prim \"print\" : string -> unit\nval ()=if id answer=42 then print \"42 imported\\n\" else raise WrongImportedValue\n"})
val ()=CompilerApi.writeProgram ([imported,checked],output)
val ()=CompilerApi.close context
val ()=print "PASS CLI unit import\n"
