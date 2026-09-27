(* PackWord32Big.subVecX and subArrX, and those of PackWord32Little, "extend
   the sign bit (most significant bit) when converting the subvector to a
   word".  LargeWord.word has 64 bits, so an element whose bit 31 is set is
   0wxFFFFFFFF........ ; MLKit returns it without the sign extension. *)
val () = print ("LargeWord.wordSize = " ^ Int.toString LargeWord.wordSize ^ "\n")
val bytes = [0wxFF, 0wxFE, 0wxFD, 0wxFC] : Word8.word list
val vec = Word8Vector.fromList bytes
val arr = Word8Array.fromList bytes
fun show name w = print (name ^ " = 0wx" ^ LargeWord.toString w ^ "\n")
val () = show "PackWord32Big.subVec (vec, 0)    " (PackWord32Big.subVec (vec, 0))
val () = show "PackWord32Big.subVecX (vec, 0)   " (PackWord32Big.subVecX (vec, 0))     (* 0wxFFFFFFFFFFFEFDFC *)
val () = show "PackWord32Big.subArrX (arr, 0)   " (PackWord32Big.subArrX (arr, 0))     (* 0wxFFFFFFFFFFFEFDFC *)
val () = show "PackWord32Little.subVecX (vec, 0)" (PackWord32Little.subVecX (vec, 0))  (* 0wxFFFFFFFFFCFDFEFF *)
val () = show "PackWord32Little.subArrX (arr, 0)" (PackWord32Little.subArrX (arr, 0))  (* 0wxFFFFFFFFFCFDFEFF *)
(* for comparison: Word32.toLargeWordX extends the sign of the same 32 bits *)
val () = show "Word32.toLargeWordX 0wxFFFEFDFC  " (Word32.toLargeWordX 0wxFFFEFDFC)
