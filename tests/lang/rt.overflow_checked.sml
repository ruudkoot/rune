val big = valOf Int.maxInt
fun try f = (Int.toString (f ()) ^ "\n") handle Overflow => "Overflow\n"
val () = print (try (fn () => big + 1))
val () = print (try (fn () => big * 2))
val () = print (try (fn () => valOf Int.minInt - 1))
val () = print (try (fn () => ~(valOf Int.minInt)))
val () = print (try (fn () => abs (valOf Int.minInt)))
val () = print (try (fn () => valOf Int.minInt div ~1))
val () = print (try (fn () => big - 1 + 1))
val () = print (Word.toString (0wxFFFFFFFFFFFFFFFF + 0w1) ^ "\n")
