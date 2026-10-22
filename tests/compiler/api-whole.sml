(* A whole-program host cannot share its Basis identities. Refuse before
   linking a second library instance with separate process-exit hooks. *)
val context=RuneCompiler.session {lib=SOME "lib",flags=[]}
val unit=RuneCompiler.compileText (context,{file="whole-client.sml",text="val ()=print \"MUST NOT EXECUTE\\n\"\n"})
val rejected=((RuneCompiler.run unit;false) handle Fail message =>
  message="compiler-library execution with libraries requires a host built with --units")
val ()=if rejected then print "PASS whole host execution refusal\n" else raise Fail "whole host executed a second Basis"
