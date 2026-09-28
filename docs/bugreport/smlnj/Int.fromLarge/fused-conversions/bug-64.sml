(* The same with Word64 and Int64. For 64 bits, the first two lines print ~1;
   for 32 bits, the compiler stops with "Compiler bug: Num64Cnv: test64To".
   Run: sml bug-64.sml *)
fun show (name, f) =
      let val got = f () handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", "Overflow: ",
                        if got = "Overflow" then "ok" else "WRONG", "\n"])
      end
fun toInt (w : Word64.word) = Int.fromLarge (Word64.toLargeInt w)
val () = show ("Int.fromLarge (Word64.toLargeInt 0wxFFFFFFFFFFFFFFFF)",
               fn () => Int.toString (toInt 0wxFFFFFFFFFFFFFFFF))
fun toInt64 (w : Word64.word) = Int64.fromLarge (Word64.toLargeInt w)
val () = show ("Int64.fromLarge (Word64.toLargeInt 0wxFFFFFFFFFFFFFFFF)",
               fn () => Int64.toString (toInt64 0wxFFFFFFFFFFFFFFFF))
fun narrow (i : Int64.int) = Int.fromLarge (Int64.toLarge i)
val () = print ("Int.fromLarge (Int64.toLarge 5) = " ^ Int.toString (narrow 5) ^ ", expected 5\n")
val () = OS.Process.exit OS.Process.success
