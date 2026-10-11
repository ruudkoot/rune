(* "SOME(k) ... if a call to input would return immediately with at least k
   characters. Note that k = 0 corresponds to the stream being at
   end-of-stream." *)
fun opt NONE = "NONE" | opt (SOME k) = "SOME " ^ Int.toString k
fun show (what, f) = print (what ^ " = " ^ (f () handle e => "raised " ^ exnName e) ^ "\n")

(* 1. The functional stream alone, once input has read from it: the
      specification's noBlock. *)
val s = TextIO.getInstream (TextIO.openString "ab")
val (v, _) = TextIO.StreamIO.input s
val () = show ("1. StreamIO.input s gives \"" ^ v ^ "\"; StreamIO.canInput (s, 1)",
               fn () => opt (TextIO.StreamIO.canInput (s, 1)) ^ "   (expected SOME 1)")

(* 2. TextIO: the stream of getInstream f read to its end, then f itself. *)
val f = TextIO.openString "ab"
val _ = TextIO.StreamIO.inputAll (TextIO.getInstream f)
val () = show ("2. TextIO.canInput (f, 1)", fn () => opt (TextIO.canInput (f, 1)) ^ "   (expected SOME 1)")
val () = show ("2. TextIO.input f", fn () => "\"" ^ TextIO.input f ^ "\"")

(* 3. BinIO over a file of two bytes, likewise. *)
val name = OS.FileSys.tmpName ()
val () = let val out = BinIO.openOut name
         in BinIO.output (out, Word8Vector.fromList [0w1, 0w2]); BinIO.closeOut out end
val g = BinIO.openIn name
val _ = BinIO.StreamIO.inputAll (BinIO.getInstream g)
val () = show ("3. BinIO.canInput (g, 1)", fn () => opt (BinIO.canInput (g, 1)) ^ "   (expected SOME 1)")
val () = show ("3. Word8Vector.length (BinIO.input g)", fn () => Int.toString (Word8Vector.length (BinIO.input g)))
val () = (BinIO.closeIn g; OS.FileSys.remove name)

(* 4. BinIO over a reader of two bytes: canInput of the imperative stream reads
      ahead, and then the functional stream it is built on answers SOME 0. *)
val h = BinIO.mkInstream (BinIO.StreamIO.mkInstream
          (BinPrimIO.openVector (Word8Vector.fromList [0w1, 0w2]), Word8Vector.fromList []))
val () = show ("4. BinIO.canInput (h, 5)", fn () => opt (BinIO.canInput (h, 5)) ^ "   (expected SOME 2)")
val () = show ("4. BinIO.StreamIO.canInput (getInstream h, 5)",
               fn () => opt (BinIO.StreamIO.canInput (BinIO.getInstream h, 5)) ^ "   (expected SOME 2)")
val () = show ("4. Word8Vector.length (BinIO.input h)", fn () => Int.toString (Word8Vector.length (BinIO.input h)))
