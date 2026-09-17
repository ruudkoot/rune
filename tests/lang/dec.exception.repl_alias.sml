exception Orig of int
exception Alias = Orig
val () = print ((raise Alias 3) handle Orig n => Int.toString n ^ "\n")
val () = print ((raise Orig 4) handle Alias n => Int.toString n ^ "\n")
exception MyFail = Fail
val () = print ((raise Fail "x") handle MyFail s => s ^ "\n")
