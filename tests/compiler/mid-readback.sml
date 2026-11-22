(* A program whose Mid, the Basis Library's with it, is printed as text
   (--dump-after=mid) and read back (--read-mid) at each level
   (tests/runner/tools.sml, compiler/mid-readback; the haskell98 roadmap's
   M5). What it uses of the Basis is made of functors compiled once --
   TextIO's streams, the arrays and their slices, the words -- whose
   functions are known by their labels: read back without them, it failed a
   lint at -O1 (the roadmap's E1). *)
fun pow (_, 0) = IntInf.fromInt 1
  | pow (b, n) = IntInf.* (b, pow (b, n - 1))
val () = TextIO.print (IntInf.toString (pow (IntInf.fromInt 2, 100)) ^ "\n")
val () = TextIO.output (TextIO.stdOut, CharVector.map Char.toUpper "functor" ^ "\n")
val () = print (String.concatWith "," (List.map Int.toString [1, 2, 3]) ^ "\n")
val a = Word8Array.tabulate (4, fn i => Word8.fromInt (i + 1))
val s = Word8ArraySlice.slice (a, 1, SOME 2)
val () = print (Int.toString (Word8ArraySlice.foldl (fn (w, n) => n + Word8.toInt w) 0 s) ^ "\n")
val () = print (Word32.toString (Word32.<< (0w1, 0w31)) ^ "\n")
val () = print (Real.toString (Math.sqrt 2.0) ^ "\n")
val () = TextIO.flushOut TextIO.stdOut
