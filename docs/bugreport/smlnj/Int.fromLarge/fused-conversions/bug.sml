(* Int.fromLarge (Word.toLargeInt w) and the like, for a w whose value does
   not fit the integer type: the Basis has Overflow. Run: sml bug.sml *)
fun show (name, f) =
      let val got = f () handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected Overflow: ",
                        if got = "Overflow" then "ok" else "WRONG", "\n"])
      end
fun fromWord (w : word) = Int.fromLarge (Word.toLargeInt w)
val () = show ("Int.fromLarge (Word.toLargeInt (Word.notb 0w0))",
               fn () => Int.toString (fromWord (Word.notb 0w0)))
fun fromWord32 (w : Word32.word) = Int32.fromLarge (Word32.toLargeInt w)
val () = show ("Int32.fromLarge (Word32.toLargeInt 0wxFFFFFFFF)",
               fn () => Int32.toString (fromWord32 0wxFFFFFFFF))
(* the same conversion in two steps, which the optimizer does not fuse *)
val big = Word32.toLargeInt 0wxFFFFFFFF;
val () = show ("Int32.fromLarge 4294967295",
               fn () => Int32.toString (Int32.fromLarge big))
val () = OS.Process.exit OS.Process.success
