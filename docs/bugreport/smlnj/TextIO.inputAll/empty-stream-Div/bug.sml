(* inputAll of a stream over no characters or bytes. inputAll "returns the
   vector of the rest of the elements in the stream", here an empty one.
   The last line is the same empty reader with chunkSize 1 instead of 0.
   Run: sml bug.sml *)
fun show (name, f, expected) =
      let val got = (f ()) handle IO.Io {function, cause, ...} =>
                      "Io {function = \"" ^ function ^ "\", cause = " ^ exnName cause ^ "}"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
fun q s = "\"" ^ s ^ "\""
val bytes = Byte.stringToBytes
fun len v = Int.toString (Word8Vector.length v) ^ " bytes"
val () = show ("TextIO.inputAll (openString \"\")", fn () => q (TextIO.inputAll (TextIO.openString "")), q "")
val () = show ("TextIO.StreamIO.inputAll (getInstream (openString \"\"))",
               fn () => q (#1 (TextIO.StreamIO.inputAll (TextIO.getInstream (TextIO.openString "")))), q "")
val () = show ("TextIO.StreamIO.inputAll over TextPrimIO.openVector \"\"",
               fn () => q (#1 (TextIO.StreamIO.inputAll (TextIO.StreamIO.mkInstream (TextPrimIO.openVector "", "")))), q "")
val () = show ("BinIO.StreamIO.inputAll over BinPrimIO.openVector of no bytes",
               fn () => len (#1 (BinIO.StreamIO.inputAll (BinIO.StreamIO.mkInstream (BinPrimIO.openVector (bytes ""), bytes "")))), "0 bytes")
val () = show ("BinIO.inputAll over BinPrimIO.openVector of no bytes",
               fn () => len (BinIO.inputAll (BinIO.mkInstream (BinIO.StreamIO.mkInstream (BinPrimIO.openVector (bytes ""), bytes "")))), "0 bytes")
val () = show ("TextIO.inputAll (openString \"ab\")", fn () => q (TextIO.inputAll (TextIO.openString "ab")), q "ab")
val () = show ("TextIO.input (openString \"\")", fn () => q (TextIO.input (TextIO.openString "")), q "")
val () = let val TextPrimIO.RD r = TextPrimIO.openVector ""
             val rd = TextPrimIO.RD {name = #name r, chunkSize = 1, readVec = #readVec r, readArr = #readArr r,
                                     readVecNB = #readVecNB r, readArrNB = #readArrNB r, block = #block r,
                                     canInput = #canInput r, avail = #avail r, getPos = #getPos r,
                                     setPos = #setPos r, endPos = #endPos r, verifyPos = #verifyPos r,
                                     close = #close r, ioDesc = #ioDesc r}
         in print ("chunkSize of TextPrimIO.openVector \"\" = " ^ Int.toString (#chunkSize r) ^ "\n");
            show ("the same reader with chunkSize 1, inputAll",
                  fn () => q (#1 (TextIO.StreamIO.inputAll (TextIO.StreamIO.mkInstream (rd, "")))), q "")
         end
val () = OS.Process.exit OS.Process.success
