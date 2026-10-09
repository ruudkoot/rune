(* SML/NJ: String.extract (s, i, SOME j) checks the region with an
   unchecked i + j, which wraps round near Int.maxInt *)
fun check name f =
  (ignore (f ()); print (name ^ ": UNEXPECTED no exception\n"))
  handle Subscript => print (name ^ ": Subscript (expected)\n")
       | e => print (name ^ ": " ^ General.exnName e ^ " (WRONG: expected Subscript)\n")

val big = valOf Int.maxInt
val () = check "String.substring (\"abcde\", 1, big) (for contrast)" (fn () => String.substring ("abcde", 1, big))
val () = check "String.extract (\"abcde\", big, SOME 1)" (fn () => String.extract ("abcde", big, SOME 1))
val () = check "String.extract (\"abcde\", big, SOME big)" (fn () => String.extract ("abcde", big, SOME big))
val () = check "String.extract (\"abcde\", 1, SOME big)" (fn () => String.extract ("abcde", 1, SOME big))
