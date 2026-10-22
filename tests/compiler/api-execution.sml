(* Public execution must share the host Basis, avoid unrelated effects,
   preserve initializer state on retry, and place finalizers last. *)
structure Ast = struct val clientOwned=42 end
structure CompilerApiExecutionTests =
struct
  structure C=RuneCompiler
  fun need (true,_) = () | need (false,message) = raise Fail message
  fun main (directory,foreignLibrary,hostUnit) =
    let
      val context=C.session {lib=SOME "lib",flags=[]}
      fun text (file,source) = C.compileText (context,{file=file,text=source})
      fun runtimeContexts () =
        let fun fresh () = C.session {lib=NONE,flags=[]}
            val a=fresh ()
            val b=fresh ()
            fun input session (file,source) = C.compileText (session,{file=file,text=source})
            val firstA=input a ("same-state.sml","val counter=ref 0\n")
            val firstB=input b ("same-state.sml","val counter=ref 0\n")
            val step="exception Collision\nval ()=if !counter=0 then counter:=1 else raise Collision\n"
            val stepA=input a ("same-step.sml",step)
            val stepB=input b ("same-step.sml",step)
            val ()=List.app C.run [firstA,firstB,stepA,stepB]
        in C.close a;C.close b end
      val ()=runtimeContexts ()
      val ()=OS.Process.atExit (fn () => print "host finalizer\n")
      val state=text ("api-state.sml","val counter=ref 0\n")
      val _=text ("api-unrelated.sml","val ()=print \"UNRELATED MUST NOT RUN\\n\"\n")
      val effect=text ("api-effect.sml",
        "val ()=counter:= !counter+1\n"
        ^ "val ()=if !counter=1 then raise Fail \"initializer retry\" else print (Int.toString (!counter) ^ \"\\n\")\n")
      val ()=print "before explicit run\n"
      val ()=need (((C.run effect;false) handle Fail message => message="initializer retry"),"user exception changed")
      val ()=C.run effect
      val ()=C.run effect
      val exit=text ("api-exit.sml","val ()=OS.Process.atExit (fn () => print \"compiled finalizer\\n\")\n")
      val ()=C.run exit
      val ()=C.writeProgram ([state,exit],directory ^ "/program.rbc")
      val ()=C.close context
      val ()=need (((C.run exit;false) handle C.Closed => true),"closed context executed")
      val ()=need (Ast.clientOwned=42,"client namespace changed")
      val foreign=C.session {lib=SOME foreignLibrary,flags=[]}
      val foreignUnit=C.compileText (foreign,{file="foreign-client.sml",
        text="val ()=OS.Process.atExit (fn () => print \"FOREIGN MUST NOT RUN\\n\")\n"})
      val ()=need (((C.run foreignUnit;false) handle Fail message => String.isPrefix "host library source differs:" message),
        "host library with different source was silently reused")
      val ()=C.close foreign
      val shared=C.session {lib=SOME "lib",flags=[]}
      val sharedUnit=C.compileText (shared,{file="shared-client.sml",
        text="val ()=OS.Process.atExit (fn () => print \"STALE LINK MUST NOT RUN\\n\")\n"})
      val _=Runtime.load hostUnit
      val ()=need (((C.run sharedUnit;false) handle Fail message => String.isPrefix "host unit linkage changed:" message),
        "replaced host unit was reused with stale provenance")
      val ()=C.close shared
    in print "PASS compiler API execution\n" end
end
val ()=(case CommandLine.arguments () of
  [directory,foreignLibrary,hostUnit] => CompilerApiExecutionTests.main (directory,foreignLibrary,hostUnit)
| _ => raise Fail "compiler API execution requires an artifact directory")
  handle RuneCompiler.Failed diagnostics =>
    (List.app (fn d : RuneCompiler.diagnostic => TextIO.output (TextIO.stdErr,#file d ^ ": " ^ #message d ^ "\n")) diagnostics;
     OS.Process.exit OS.Process.failure)
