(* SML/NJ 2026.2: rotateL and rotateR of Word8, Word32 and Word -- the words
   the compiler keeps tagged -- fill the bits they rotate in with the top bit.
   Word64 is right. A line says what it should be where it is wrong. *)
fun show (what, got, want) =
  print (what ^ " = " ^ got ^ (if got = want then "" else "   (should be " ^ want ^ ")") ^ "\n")
fun ident x = x   (* an amount the compiler does not know *)
val () = show ("Word8.rotateL (0wx81, 0w1)", Word8.toString (Word8.rotateL (0wx81, 0w1)), "3")
val () = show ("Word8.rotateL (0wx81, ident 0w1)", Word8.toString (Word8.rotateL (0wx81, ident 0w1)), "3")
val () = show ("Word8.rotateR (0wx80, 0w1)", Word8.toString (Word8.rotateR (0wx80, 0w1)), "40")
val () = show ("Word32.rotateL (0wx80000001, 0w4)", Word32.toString (Word32.rotateL (0wx80000001, 0w4)), "18")
val () = show ("Word32.rotateR (0wx80000000, 0w4)", Word32.toString (Word32.rotateR (0wx80000000, 0w4)), "8000000")
val () = show ("Word.rotateL (0wx4000000000000001, 0w1)", Word.toString (Word.rotateL (0wx4000000000000001, 0w1)), "3")
val () = show ("Word64.rotateL (0wx8000000000000001, 0w1)", Word64.toString (Word64.rotateL (0wx8000000000000001, 0w1)), "3")
