fun check name f =
  (ignore (f ()); print (name ^ ": UNEXPECTED no exception\n"))
  handle Subscript => print (name ^ ": Subscript (expected)\n")
       | Overflow => print (name ^ ": Overflow (WRONG: expected Subscript)\n")
       | e => print (name ^ ": UNEXPECTED " ^ General.exnName e ^ "\n")

val big = valOf Int.maxInt
val small = valOf Int.minInt

val () = check "Substring.substring (s, 1, big)"              (fn () => Substring.substring ("abcde", 1, big))
val () = check "Substring.substring (s, big, 1)"               (fn () => Substring.substring ("abcde", big, 1))
val () = check "Substring.substring (s, big, big)"             (fn () => Substring.substring ("abcde", big, big))
val () = check "Substring.extract (s, 1, SOME big)"            (fn () => Substring.extract ("abcde", 1, SOME big))
val () = check "Substring.extract (s, small, NONE)"            (fn () => Substring.extract ("abcde", small, NONE))
val () = check "String.substring (s, 1, big) (for contrast)"   (fn () => String.substring ("abcde", 1, big))
