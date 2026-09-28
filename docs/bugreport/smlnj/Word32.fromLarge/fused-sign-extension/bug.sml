(* Conversions through a sign extension that the optimizer fuses: a word made
   from a signed value, and an unsigned test of a sign-extended word. The
   arguments are read at run time. Run: sml bug.sml *)
fun show (name, got, expected) =
      print (concat [name, " = ", got, ", expected ", expected, ": ",
                     if got = expected then "ok" else "WRONG", "\n"])
fun r f = f () handle Overflow => "Overflow"
val m1 = valOf (Int32.fromString "~1")
val ff = valOf (Word8.fromString "FF")
fun a (i : Int32.int) = Word32.fromLargeInt (Int32.toLarge i)
val () = show ("Word32.fromLargeInt (Int32.toLarge ~1)", Word32.toString (a m1), "FFFFFFFF")
val () = show ("Word32.toLargeInt (Word32.fromLargeInt (Int32.toLarge ~1))",
               IntInf.toString (Word32.toLargeInt (a m1)), "4294967295")
fun b (w : Word8.word) = Word32.fromLarge (Word8.toLargeX w)
val () = show ("Word32.fromLarge (Word8.toLargeX 0wxFF)", Word32.toString (b ff), "FFFFFFFF")
fun c (w : Word8.word) = Word64.toInt (Word8.toLargeX w)
val () = show ("Word64.toInt (Word8.toLargeX 0wxFF)", r (fn () => Int.toString (c ff)), "Overflow")
fun d (w : Word8.word) = Word32.toInt (Word32.fromLarge (Word8.toLargeX w))
val () = show ("Word32.toInt (Word32.fromLarge (Word8.toLargeX 0wxFF))", r (fn () => Int.toString (d ff)),
               if Word.wordSize > 32 then "4294967295" else "Overflow")
val () = OS.Process.exit OS.Process.success
