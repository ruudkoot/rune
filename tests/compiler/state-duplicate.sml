(* Registration stays cheap for batch clients; ownership still refuses an
   ambiguous registry before any session can observe it. *)
structure CompilerStateDuplicateTest =
struct
  val first = ref 0
  val second = ref 0
  val () = CompilerState.cellRoot ("duplicate", first)
  val () = CompilerState.cellRoot ("duplicate", second)
  fun main () =
    if ((CompilerState.seal (); false)
        handle Fail message => String.isPrefix "duplicate compiler root:" message)
    then print "PASS compiler-state: duplicate root refused at sealing\n"
    else raise Fail "duplicate compiler roots were accepted"
end
val () = CompilerStateDuplicateTest.main ()
