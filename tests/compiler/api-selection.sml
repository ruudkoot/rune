(* The API selects as a batch compile does (D7): by the names a file uses.
   The library m provides E, and its one file does not elaborate, so that a
   selection that takes it fails. Alpha-renaming a bound variable is nothing
   to a session, a query or an analysis; naming E is. *)
structure C=RuneCompiler
fun need (true,_) = () | need (false,message) = raise Fail message
val root=case CommandLine.arguments () of [root] => root | _ => raise Fail "expected the fixture's library root"
fun session () = C.session {lib=SOME root,flags=["--library","m"]}
val renamed="val f = fn F => F + 1\n"
val alpha="val f = fn E => E + 1\n"
val label="val r = {E = 1}\n"
val named="val v = E.v\n"
val file="selected.sml"
(* the session's compile, and a query of what it compiled *)
fun compiled text =
  let val context=session ()
      val outcome=
        (ignore (C.compileText (context,{file=file,text=text}));
         SOME (C.typeAt (context,{file=file,offset=4})))
        handle C.Failed _ => NONE
  in C.close context;outcome end
(* whether an analysis finds no error, and whether it took the library's file *)
fun analysed text =
  let val context=session ()
      val analysis=C.Analysis.create (context,{context="selection"})
      val snapshot=C.Analysis.check (analysis,{project=NONE,cancelled=fn () => false,
        inputs=[{file=file,text=text,mode="",annotations=[],revision="1"}]})
      val clean=null (C.Analysis.diagnostics snapshot)
      val loaded=List.exists (fn ({file,...} : C.Analysis.input) => String.isSuffix "/e.sml" file) (C.Analysis.dependencies snapshot)
  in C.Analysis.close analysis;C.close context;(clean,loaded) end
val ()=need (compiled renamed=compiled alpha,"a session or a query selected by a bound variable")
val ()=need (isSome (compiled alpha),"a session took the library for a bound variable")
val ()=need (isSome (compiled label),"a session took the library for a record's label")
val ()=need (not (isSome (compiled named)),"a session did not take the library for a name used")
val ()=need (analysed renamed=(true,false),"an analysis took the library for no name")
val ()=need (analysed alpha=(true,false),"an analysis took the library for a bound variable")
val ()=need (analysed label=(true,false),"an analysis took the library for a record's label")
val ()=need (analysed named=(false,true),"an analysis did not take the library for a name used")
val ()=print "PASS API selection\n"
