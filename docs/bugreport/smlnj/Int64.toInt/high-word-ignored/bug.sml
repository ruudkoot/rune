(* Int64.toInt, Word64.toIntX and Position.toInt: a number that does not fit
   int must raise Overflow (on SML/NJ for 32 bits, int has 31 bits). The
   numbers are read from strings at run time. Run: sml bug.sml *)
fun i s = valOf (Int64.fromString s)
fun w s = valOf (StringCvt.scanString (Word64.scan StringCvt.HEX) s)
fun fits v = case (Int.minInt, Int.maxInt) of
                 (SOME lo, SOME hi) => Int.toLarge lo <= v andalso v <= Int.toLarge hi
               | _ => true
fun show (name, f, value) =
      let val v = valOf (IntInf.fromString value)
          val expected = if fits v then IntInf.toString v else "Overflow"
          val got = (Int.toString (f ())) handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
val () = show ("Int64.toInt 4294967296", fn () => Int64.toInt (i "4294967296"), "4294967296")
val () = show ("Int64.toInt 3221225472", fn () => Int64.toInt (i "3221225472"), "3221225472")
val () = show ("Int64.toInt ~4294967297", fn () => Int64.toInt (i "~4294967297"), "~4294967297")
val () = show ("Int64.toInt ~5", fn () => Int64.toInt (i "~5"), "~5")
val () = show ("Word64.toIntX 0wx100000000", fn () => Word64.toIntX (w "100000000"), "4294967296")
val () = show ("Word64.toIntX 0wxFFFFFFFF", fn () => Word64.toIntX (w "FFFFFFFF"), "4294967295")
val () = show ("Word64.toIntX 0wxFFFFFFFFFFFFFFFB", fn () => Word64.toIntX (w "FFFFFFFFFFFFFFFB"), "~5")
val () = show ("Position.toInt 4294967296", fn () => Position.toInt (valOf (Position.fromString "4294967296")), "4294967296")
val () = OS.Process.exit OS.Process.success
