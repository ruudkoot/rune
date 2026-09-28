(* Two conversions that the optimizer fuses into one, where one side is 64
   bits and the other at most 32; each argument is read from a string at run
   time. For 32 bits, the fused conversion is given the "_Core" function of the
   other size. Run: sml bug-32.sml *)
fun int s = valOf (IntInf.fromString s)
fun show (name, f, expected) =
      let val got = f () handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
fun a (x : IntInf.int) = Int64.toInt (Int64.fromLarge x)
val () = show ("Int64.toInt (Int64.fromLarge 5)", fn () => Int.toString (a (int "5")), "5")
fun b (x : IntInf.int) = Word32.fromLarge (Word64.fromLargeInt x)
val () = show ("Word32.fromLarge (Word64.fromLargeInt 0x200000005)", fn () => Word32.toString (b (int "8589934597")), "5")
fun c (w : Word32.word) = Word64.toLargeInt (Word32.toLarge w)
val () = show ("Word64.toLargeInt (Word32.toLarge 0wx1)", fn () => IntInf.toString (c (Word32.fromLargeInt (int "1"))), "1")
fun d (i : Int32.int) = Int64.toLarge (Int64.fromLarge (Int32.toLarge i))
val () = show ("Int64.toLarge (Int64.fromLarge (Int32.toLarge ~7))", fn () => IntInf.toString (d (Int32.fromLarge (int "~7"))), "~7")
val () = OS.Process.exit OS.Process.success
