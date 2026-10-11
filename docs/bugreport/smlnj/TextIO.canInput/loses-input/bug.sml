(* canInput (f, n), then reading f. canInput "returns SOME k ... if a call to
   input would return immediately with at least k characters", and must not
   lose them. Run: sml bug.sml (it writes and removes bug.tmp in the current
   directory). *)
fun opt NONE = "NONE" | opt (SOME n) = "SOME " ^ Int.toString n
fun show (name, got, expected) =
      print (concat [name, " = ", got, ", expected ", expected, ": ",
                     if got = expected then "ok" else "WRONG", "\n"])
val () = let val f = TextIO.openString "ab"
             val a = TextIO.canInput (f, 2)
         in show ("openString \"ab\": canInput (f, 2), input f", opt a ^ ", \"" ^ TextIO.input f ^ "\"", "SOME 2, \"ab\"") end
val () = let val f = TextIO.openString "ab"
             val a = TextIO.canInput (f, 5)
         in show ("openString \"ab\": canInput (f, 5), input f", opt a ^ ", \"" ^ TextIO.input f ^ "\"", "SOME 2, \"ab\"") end
val () = let val f = TextIO.openString "ab"
             val a = TextIO.canInput (f, 3)
         in show ("openString \"ab\": canInput (f, 3), inputAll f", opt a ^ ", \"" ^ TextIO.inputAll f ^ "\"", "SOME 2, \"ab\"") end
(* a functional stream: s is a value, and canInput changes what it holds *)
val () = let val s = TextIO.getInstream (TextIO.openString "ab")
             val a = TextIO.StreamIO.canInput (s, 5)
         in show ("StreamIO: canInput (s, 5), input s", opt a ^ ", \"" ^ #1 (TextIO.StreamIO.input s) ^ "\"", "SOME 2, \"ab\"") end
val () = let val bytes = Byte.stringToBytes
             val g = BinIO.mkInstream (BinIO.StreamIO.mkInstream (BinPrimIO.openVector (bytes "ab"), bytes ""))
             val a = BinIO.canInput (g, 5)
         in show ("BinIO, 2 bytes: canInput (g, 5), input g", opt a ^ ", " ^ Int.toString (Word8Vector.length (BinIO.input g)) ^ " bytes", "SOME 2, 2 bytes") end
(* a file longer than a buffer *)
val text = CharVector.tabulate (10000, fn i => Char.chr (97 + i mod 26))
val () = let val out = TextIO.openOut "bug.tmp" in TextIO.output (out, text); TextIO.closeOut out end
val () = let val f = TextIO.openIn "bug.tmp"
             val a = TextIO.canInput (f, 6000)
             val s = TextIO.inputAll f
         in show ("file of 10000 characters: canInput (f, 6000), inputAll f", opt a ^ ", " ^ Int.toString (size s) ^ " characters",
                  "SOME 6000, 10000 characters");
            TextIO.closeIn f
         end
val () = OS.FileSys.remove "bug.tmp"
val () = OS.Process.exit OS.Process.success
