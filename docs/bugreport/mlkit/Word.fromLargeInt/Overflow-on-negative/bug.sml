(* Word.fromLargeInt, Word32.fromLargeInt and Word64.fromLargeInt (= LargeWord)
   raise Overflow for a negative argument below ~2^63.  The specification:
   "converts i of type LargeInt.int to a value of type word. This has the
   effect of taking the low-order wordSize bits of the 2's complement
   representation of i."  Every call below should return a word. *)
fun show name toString f =
  print (name ^ " = " ^ (toString (f ()) handle e => "raises " ^ exnName e) ^ "\n")

val two32 = IntInf.pow (2, 32)
val two63 = IntInf.pow (2, 63)
val two64 = IntInf.pow (2, 64)

val () = print ("Word.wordSize = " ^ Int.toString Word.wordSize ^ "\n")
(* expected results in the comments: the low-order wordSize bits *)
val () = show "Word64.fromLargeInt ~1           " Word64.toString (fn () => Word64.fromLargeInt (~1))          (* FFFFFFFFFFFFFFFF *)
val () = show "Word64.fromLargeInt (~2^63)      " Word64.toString (fn () => Word64.fromLargeInt (~two63))      (* 8000000000000000 *)
val () = show "Word64.fromLargeInt (~2^63 - 1)  " Word64.toString (fn () => Word64.fromLargeInt (~two63 - 1))  (* 7FFFFFFFFFFFFFFF *)
val () = show "Word64.fromLargeInt (~2^64 + 5)  " Word64.toString (fn () => Word64.fromLargeInt (~two64 + 5))  (* 5 *)
val () = show "Word64.fromLargeInt (2^64 + 5)   " Word64.toString (fn () => Word64.fromLargeInt (two64 + 5))   (* 5 *)
val () = show "Word.fromLargeInt (~2^63 - 3)    " Word.toString   (fn () => Word.fromLargeInt (~two63 - 3))    (* 7FFFFFFFFFFFFFFD *)
val () = show "Word.fromLargeInt (2^63 + 5)     " Word.toString   (fn () => Word.fromLargeInt (two63 + 5))     (* 5 *)
val () = show "Word32.fromLargeInt (~2^64 - 1)  " Word32.toString (fn () => Word32.fromLargeInt (~two64 - 1))  (* FFFFFFFF *)
val () = show "Word32.fromLargeInt (~2^32 - 3)  " Word32.toString (fn () => Word32.fromLargeInt (~two32 - 3))  (* FFFFFFFD *)
val () = show "Word8.fromLargeInt (~2^64 - 1)   " Word8.toString  (fn () => Word8.fromLargeInt (~two64 - 1))   (* FF *)
