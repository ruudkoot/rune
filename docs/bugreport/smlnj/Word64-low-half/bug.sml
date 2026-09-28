(* SML/NJ 110.99.9 for 32 bits: a Word64.word loses bits 30 and 31 of its
   low half, both in a literal and in the result of arithmetic. Word64's
   fromLargeInt gets the same numbers right. Run: sml bug.sml *)
val literal : Word64.word = 0wx40000000
val sum : Word64.word = Word64.fromInt 1073741823 + 0w1
val converted : Word64.word = Word64.fromLargeInt 1073741824
val all : Word64.word = 0wxFFFFFFFFFFFFFFFF

fun show (name, w) = print (name ^ " = " ^ LargeInt.toString (Word64.toLargeInt w) ^ "\n")

val () = show ("0wx40000000", literal)
val () = show ("fromInt 1073741823 + 0w1", sum)
val () = show ("fromLargeInt 1073741824", converted)
val () = show ("0wxFFFFFFFFFFFFFFFF", all)
val () = OS.Process.exit OS.Process.success
