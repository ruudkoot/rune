(* Link inventory records success, including empty units, and says nothing
   about running the returned initializer. The loader scenario supplies
   the Basis prefix and the two units of the counter fixture. *)
fun need (true,_) = () | need (false,message) = raise Fail message
val files=CommandLine.arguments ()
val n=length files
val basis=List.take (files,n-2)
val a=List.nth (files,n-2)
val b=List.nth (files,n-1)
val initial=Runtime.linkedUnits ()
val ()=need (null initial,"whole program unexpectedly has a unit inventory")
val rejected=((ignore (Runtime.load b);false) handle Fail _ => true)
val ()=need (rejected andalso Runtime.linkedUnits ()=initial,"failed link published a unit")
val ()=List.app (fn file => Runtime.load file ()) basis
val prefix=Runtime.linkedUnits ()
val ()=need (length prefix=length basis,"empty library units were omitted")
val first=Runtime.load a
val afterFirst=Runtime.linkedUnits ()
val ()=need (length afterFirst=length prefix+1 andalso List.take (afterFirst,length prefix)=prefix,"first-link order changed")
val ()=first ()
val second=Runtime.load b
val linked=Runtime.linkedUnits ()
val ()=need (length linked=length afterFirst+1,"linked but unexecuted unit missing")
val ()=print "linked before executing\n"
val ()=second ()
val again=Runtime.load b
val ()=need (Runtime.linkedUnits ()=linked,"relink duplicated an identity")
val ()=again ()
val ()=Runtime.collect ()
val ()=need (Runtime.linkedUnits ()=linked,"collection changed inventory")
val ()=print "PASS linked unit inventory\n"
